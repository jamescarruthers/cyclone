"""Drive the Cyclone snapshot with scripted key presses; record code map + screenshots."""
import sys, json
from skoolkit import CSimulator
from skoolkit.simulator import Simulator
from skoolkit.simutils import from_snapshot, get_state
from skoolkit.snapshot import Snapshot, write_snapshot
from skoolkit.trace import Tracer
from skoolkit.graphics import Frame, scr_udgs
from skoolkit.components import get_image_writer

ROWS = ["SHIFT Z X C V", "A S D F G", "Q W E R T", "1 2 3 4 5", "0 9 8 7 6",
        "P O I U Y", "ENTER L K J H", "SPACE SYM M N B"]
KEYMAP = {k: (r, b) for r, row in enumerate(ROWS) for b, k in enumerate(row.split())}

def run(sna, script, total_frames, shots, outmap, outsna=None, prefix='shot'):
    snap = Snapshot.get(sna)
    sim = from_snapshot(CSimulator or Simulator, snap, {}, {'ay': [None]*16}, {'fast_djnz': False, 'fast_ldir': False})
    tracer = Tracer(sim, snap.border, 0, 0, list(snap.ay), snap.outfe, True)
    sim.set_tracer(tracer)
    # script: list of [start_frame, end_frame, "KEYS"]
    iw = get_image_writer()
    state = {'f0': None}
    def draw(scr, frame, border, kb):
        if state['f0'] is None: state['f0'] = frame
        f = frame - state['f0']
        for i in range(8): kb[i] = 0
        for a, b, keys in script:
            if a <= f < b:
                for k in keys.split():
                    r, bit = KEYMAP[k]; kb[r] |= 1 << bit
        if f in shots:
            with open(f'{prefix}_{f:05d}.png', 'wb') as fh:
                iw.write_image([Frame(scr_udgs(sim.memory, 0, 0, 32, 24), 1)], fh)
        return f < total_frames
    exec_map = set()
    tracer.run(sim.registers[24], -1, 0, 0, True, draw, exec_map, None, None, '$', '02X', '04X')
    old = set()
    try:
        old = {int(l.strip()[1:], 16) for l in open(outmap)}
    except FileNotFoundError: pass
    with open(outmap, 'w') as fh:
        for a in sorted(exec_map | old): fh.write(f'${a:04X}\n')
    print('new addrs', len(exec_map - old), 'total', len(exec_map | old))
    if outsna:
        ram, regs, st, m = get_state(sim)
        write_snapshot(outsna, ram, regs, st, m)

if __name__ == '__main__':
    cfg = json.load(open(sys.argv[1]))
    run(cfg['sna'], cfg['script'], cfg['frames'], set(cfg.get('shots', [])), cfg['map'], cfg.get('out'), cfg.get('prefix', 'shot'))
