"""Reference trace of the ORIGINAL game for verifying the Rust port.

Runs the original code under SkoolKit's C simulator from $5B00 (game start) with a scripted
keyboard, and prints the game state at every main-loop iteration ($5B3C) in exactly the format
of `cyclone --trace` (remake/src/trace.rs).

  python -I reftrace.py gen SEED N SCRIPT.txt          # make a random flight script
  python -I reftrace.py run SNAPSHOT SCRIPT.txt START.bin RUST_SCRIPT.txt > ref.trace
  python -I reftrace.py diff ref.trace rust.trace

`run` writes START.bin (memory at $5B00) for the Rust side and RUST_SCRIPT.txt (the script
plus the original's RNG seed at each iteration, because the original's crash noise calls the
RNG from the interrupt handler, which depends on exact interrupt timing).
"""
import random
import sys

from skoolkit.simutils import from_snapshot, PC, SP
from skoolkit.snapshot import Snapshot
from skoolkit import CSimulator
from skoolkit.simulator import Simulator
from skoolkit.trace import Tracer

ROWS = ["SHIFT Z X C V", "A S D F G", "Q W E R T", "1 2 3 4 5", "0 9 8 7 6",
        "P O I U Y", "ENTER L K J H", "SPACE SYM M N B"]
KEYMAP = {k: (r, b) for r, row in enumerate(ROWS) for b, k in enumerate(row.split())}


def keys_line(keys):
    rows = [0] * 8
    for k in keys.split():
        r, b = KEYMAP[k]
        rows[r] |= 1 << b
    return ' '.join(f'{v:02X}' for v in rows)


def gen(seed, n, out):
    rnd = random.Random(seed)
    lines = [''] * 45 + ['1'] * 12           # refuel on the pad, then climb
    acts = ['X', 'X O', 'X P', 'X 1', 'X Q', '', 'O', 'P', '1', 'Q', 'X', 'X', 'X 1', 'X O 1']
    while len(lines) < n:
        r = rnd.random()
        if r < 0.04:
            lines += ['M'] + [''] * rnd.randint(4, 30) + ['M']
        elif r < 0.08:
            lines += ['N']
        else:
            a = rnd.choice(acts)
            lines += [a] * rnd.randint(2, 40)
    with open(out, 'w') as f:
        for l in lines[:n]:
            f.write(keys_line(l) + '\n')


def fnv(bs):
    h = 0x811C9DC5
    for b in bs:
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h


def pixel_addr(line, col):
    return 0x4000 | ((line & 0xC0) << 5) | ((line & 7) << 8) | ((line & 0x38) << 2) | col


# render-only scratch pointers (762C/7BB8/86AF/8D5D are replaced by the 3D renderer) and the
# interrupt's rotor sound phase
SCRATCH = [0x09, 0x0A, 0x0B, 0x0C, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x29, 0x2A, 0x2B, 0x2C,
           0x3C, 0x3D, 0x3E, 0x3F, 0x5D]

HUD_ADDRS = []
for row in range(24):
    for col in (range(32) if row >= 22 else range(24, 32)):
        HUD_ADDRS += [pixel_addr(row * 8 + line, col) for line in range(8)] + [0x5800 + row * 32 + col]


def state_line(i, m):
    hx = lambda a, n: ''.join(f'{b:02X}' for b in m[a:a + n])
    v = list(m[0x7500:0x7564])
    for o in SCRATCH:
        v[o] = 0
    return (f"{i} seed={hx(0x5C76, 2)} v={''.join(f'{b:02X}' for b in v)} score={hx(0x661E, 7)} "
            f"misc={hx(0x87EF, 1)}{hx(0x8A69, 3)}{hx(0x5B93, 1)}{hx(0x828C, 1)}{hx(0x9245, 1)}{hx(0x7A81, 9)} "
            f"air={hx(0xE86C, 95)} store={fnv(m[0x9300:0xDE00]):08X} hud={fnv(m[a] for a in HUD_ADDRS):08X}")


def run(snapshot, script, start_bin, rust_script):
    snap = Snapshot.get(snapshot)
    sim = from_snapshot(CSimulator or Simulator, snap, {}, {'ay': [None] * 16}, {'fast_djnz': False, 'fast_ldir': False})
    tracer = Tracer(sim, 0, 0, 0, [0] * 16, 0, False)
    sim.set_tracer(tracer)
    m, r = sim.memory, sim.registers
    r[PC] = 0x5B00
    r[SP] = 0xFEFF
    open(start_bin, 'wb').write(bytes(m[:65536]))
    lines = [l.strip() for l in open(script)]
    keyboard = [0] * 8
    tracer.keyboard = keyboard
    out = open(rust_script, 'w')
    pc = 0x5B00
    i = 0
    while i < len(lines):
        t0 = r[25]
        stop, _ = sim.trace(pc, 0x5B3C, 0, t0 + 3500000 * 60, 1, None, None, keyboard, None, None)
        if r[PC] != 0x5B3C:
            print(f'# stopped at {r[PC]:04X} (game over?)', file=sys.stderr)
            break
        print(state_line(i, m))
        sys.stdout.flush()
        rows = [int(x, 16) for x in lines[i].split()]
        for k in range(8):
            keyboard[k] = rows[k]
        out.write(f"{lines[i]} seed={m[0x5C77]:02X}{m[0x5C76]:02X}\n")
        pc = 0x5B3C
        # step one instruction so the next trace call does not stop immediately
        sim.trace(pc, -1, 1, 0, 1, None, None, keyboard, None, None)
        pc = r[PC]
        i += 1
    out.close()


def world_of(m, addr):
    """World cell (x, y) of a tile-store address (via the island records at F230)."""
    a = 0xF230
    while m[a] != 0xFF:
        base = m[a + 10] | m[a + 11] << 8
        w, h = m[a + 3] - m[a + 6] + 1, m[a + 5] - m[a + 8] + 1
        off = addr - base
        if 0 <= off < h * 128 and off % 128 < w:
            return m[a] * 256 + m[a + 6] + off % 128, m[a + 1] * 256 + m[a + 8] + off // 128
        a += 20
    return None


class Autopilot:
    """Flies the original game: refuel, collect every placed crate with the winch, return to
    the base pad and land (completing the round). Decides keys from the game memory."""
    CRATE_TILES = {0x8B: 3, 0x57: 2, 0x2F: 1, 0x0F: 0}

    def __init__(self):
        self.phase = 'refuel'
        self.tap = 0
        self.rounds = 0

    def targets(self, m):
        out = []
        for i in range(38):
            e = 0x5F61 + 3 * i
            if m[e] == 0xFF:
                cell = m[e + 1] | m[e + 2] << 8
                if m[cell] in self.CRATE_TILES:
                    wx, wy = world_of(m, cell)
                    out.append((wx - 11, wy - 14, self.CRATE_TILES[m[cell]]))
        return out

    def keys(self, m):
        w16 = lambda a: m[a] | m[a + 1] << 8
        sx = lambda v: v - 65536 if v >= 32768 else v
        x, y = sx(w16(0x7500)), sx(w16(0x7502))
        alt, heading, speed = m[0x750D], m[0x7506], m[0x7527]
        landed, on_pad, winch = m[0x7515], m[0x752E], m[0x7555]
        k = []
        if landed and self.phase in ('goto', 'descend', 'hold', 'home'):
            self.phase = 'refuel'          # respawned on the pad
        if self.phase == 'refuel':
            if m[0x7518] == 0x1C or not on_pad:
                self.phase = 'goto'
                return '1'                 # take off
            return ''
        if self.phase == 'done':
            return ''
        if self.phase == 'hold':
            if winch == 0 and m[0x7556] == 0:
                self.phase = 'goto'
            return ''
        if self.phase == 'descend':
            if winch:
                self.phase = 'hold'
                return ''
            self.tap ^= 1
            if alt > 8 * self.height + 9 and self.tap:
                return 'Q'
            return ''
        if self.phase == 'land':
            if landed:
                self.phase = 'refuel'
                self.rounds += 1
                return ''
            self.tap ^= 1
            return 'Q' if self.tap else ''
        tg = self.targets(m)
        if self.phase == 'goto':
            if not tg:
                if m[0x7554] == 5:
                    self.phase = 'home'
                else:
                    self.phase = 'done'
                    return ''
        if self.phase == 'home':
            tx, ty, th = 0x139, 0x170, None
        else:
            tx, ty, th = min(tg, key=lambda t: abs(t[0] - x) + abs(t[1] - y))
        if self.phase in ('goto', 'home'):
            if alt < 56:
                k.append('1')
            dx, dy = tx - x, ty - y
            if dx == 0 and dy == 0 and speed == 0:
                self.phase = 'descend' if th is not None else 'land'
                self.height = th
                return ' '.join(k)
            if dx:
                d, r = (4 if dx > 0 else 12), abs(dx)
            else:
                d, r = (8 if dy > 0 else 0), abs(dy)
            if heading != d:
                if speed == 0 and m[0x7521] == 0 and alt >= 40:
                    k.append('P' if (d - heading) % 16 <= 8 else 'O')
            elif alt >= 40:
                if r >= min(speed + 1, 7):
                    k.append('X')
            return ' '.join(k)
        return ''


def auto(snapshot, n, script, start_bin, rust_script):
    """Like `run`, but the keys come from the Autopilot (recorded to SCRIPT)."""
    snap = Snapshot.get(snapshot)
    sim = from_snapshot(CSimulator or Simulator, snap, {}, {'ay': [None] * 16}, {'fast_djnz': False, 'fast_ldir': False})
    tracer = Tracer(sim, 0, 0, 0, [0] * 16, 0, False)
    sim.set_tracer(tracer)
    m, r = sim.memory, sim.registers
    r[PC] = 0x5B00
    r[SP] = 0xFEFF
    open(start_bin, 'wb').write(bytes(m[:65536]))
    keyboard = [0] * 8
    tracer.keyboard = keyboard
    ap = Autopilot()
    out, rec = open(rust_script, 'w'), open(script, 'w')
    pc = 0x5B00
    for i in range(int(n)):
        sim.trace(pc, 0x5B3C, 0, r[25] + 3500000 * 60, 1, None, None, keyboard, None, None)
        if r[PC] != 0x5B3C:
            print(f'# stopped at {r[PC]:04X}', file=sys.stderr)
            break
        print(state_line(i, m))
        line = keys_line(ap.keys(m))
        rows = [int(v, 16) for v in line.split()]
        for j in range(8):
            keyboard[j] = rows[j]
        rec.write(line + '\n')
        out.write(f"{line} seed={m[0x5C77]:02X}{m[0x5C76]:02X}\n")
        sim.trace(0x5B3C, -1, 1, 0, 1, None, None, keyboard, None, None)
        pc = r[PC]
    print(f'# autopilot: phase {ap.phase}, rounds completed {ap.rounds}, score {bytes(m[0x661E:0x6625]).decode()}', file=sys.stderr)


FIELDS = {0x00: 'POS_X', 0x02: 'POS_Y', 0x04: 'VIEW', 0x05: 'CRASHED', 0x06: 'HEADING', 0x07: 'HEADING_DISP',
          0x0D: 'ALT', 0x14: 'TOUCHDOWN', 0x15: 'LANDED', 0x16: 'NO_FUEL', 0x17: 'FUEL_TICK', 0x18: 'FUEL_PTR',
          0x1A: 'CLIMB', 0x1B: 'DESCENT', 0x1C: 'TIME_PTR', 0x1E: 'ALT_PTR', 0x21: 'TURN', 0x22: 'CONTROLS',
          0x26: 'UI', 0x27: 'SPEED', 0x28: 'TIME_TICK', 0x2E: 'ON_PAD', 0x30: 'PLANE_NEAR', 0x33: 'HELI_LEVEL',
          0x3B: 'MOVE_DIR', 0x4B: 'CYC_X', 0x4C: 'CYC_Y', 0x50: 'CYC_DIST', 0x54: 'CRATES', 0x55: 'WINCH'}


def diff(a, b):
    la = [l.split() for l in open(a) if l[0].isdigit()]
    lb = [l.split() for l in open(b) if l[0].isdigit()]
    n = min(len(la), len(lb))
    bad = 0
    resync = 0
    for i in range(n):
        if la[i] != lb[i]:
            fa = dict(x.split('=') for x in la[i][1:])
            fb = dict(x.split('=') for x in lb[i][1:])
            v = bytes.fromhex(fa['v'])
            diffs = [k for k in fa if fa[k] != fb.get(k)]
            # ... and the last crash-sequence frame drew sea waves from that RNG, so the wave
            # codes saved under the helicopter (last 9 bytes of misc) may differ too
            misc_waves_only = fa['misc'][:-18] == fb['misc'][:-18]
            if (set(diffs) <= {'seed', 'misc'} and misc_waves_only and v[0x0D] == 8 and v[0x15] == 1):
                # first iteration of a new life: the original's crash noise called the RNG from
                # the interrupt handler a timing-dependent number of times (resynchronised)
                resync += 1
                continue
            msgs = []
            for k in fa:
                if fa[k] != fb.get(k):
                    if k == 'v':
                        offs = [j for j in range(0, len(fa[k]), 2) if fa[k][j:j + 2] != fb[k][j:j + 2]]
                        msgs.append('v: ' + ', '.join(f"75{o // 2:02X}({FIELDS.get(o // 2, '')}) {fa[k][o:o + 2]}/{fb[k][o:o + 2]}" for o in offs))
                    else:
                        msgs.append(f'{k}: {fa[k]} / {fb.get(k)}')
            print(f'iteration {i}: ' + '; '.join(msgs))
            bad += 1
            if bad >= 8:
                break
    print(f'compared {n} iterations ({len(la)} ref, {len(lb)} rust); '
          f'{"MISMATCH" if bad else "identical"} ({resync} post-crash RNG resyncs)')


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'gen':
        gen(int(sys.argv[2]), int(sys.argv[3]), sys.argv[4])
    elif cmd == 'run':
        run(*sys.argv[2:6])
    elif cmd == 'auto':
        auto(*sys.argv[2:7])
    elif cmd == 'diff':
        diff(sys.argv[2], sys.argv[3])
