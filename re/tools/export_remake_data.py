"""Export the data files the Rust remake loads (remake/data/).

mem.bin  : 64 KB image = snapshots/init.z80 RAM (post-init, PC=E280) + ROM bytes $0100-$01FF
           (the only ROM bytes the game reads as data: random sea-wave codes, routine 8B91).
menu.scr : 6912-byte screen after CLS (84D6) + DrawMenu (E2E8).
info.scr : the information screen (from snapshots/info.z80).
map.scr  : the map screen as drawn by 8D0E + 8D5D + 8E5C (no markers).
loading.scr: the SCREEN$ block ("Cyclone2") from snapshots/cyclone.tap.
Run: python -I export_remake_data.py RE_DIR OUT_DIR
"""
import sys, os
from skoolkit import ROM48, read_bin_file
from skoolkit.snapshot import Snapshot
from skoolkit.simulator import Simulator
from skoolkit.simutils import from_snapshot, PC, SP

re_dir, out = sys.argv[1], sys.argv[2]
def load(name):
    snap = Snapshot.get(os.path.join(re_dir, 'snapshots', name))
    return from_snapshot(Simulator, snap, {}, {'ay': [None] * 16}, {})

def call(sim, addr):
    m, r = sim.memory, sim.registers
    sp = r[SP] = 0xFE00
    m[sp], m[sp + 1] = 0xFF, 0xFF           # sentinel return address $FFFF
    r[PC] = addr
    n = 0
    while r[PC] != 0xFFFF:
        sim.opcodes[m[r[PC]]]()
        n += 1
        assert n < 50_000_000

sim = load('init.z80')
mem = bytearray(sim.memory[:65536])
rom = read_bin_file(ROM48)
mem[0:0x4000] = bytes(0x4000)
mem[0x0100:0x0200] = rom[0x0100:0x0200]
open(os.path.join(out, 'mem.bin'), 'wb').write(mem)

s = load('init.z80'); call(s, 0x84D6); call(s, 0xE2E8)
open(os.path.join(out, 'menu.scr'), 'wb').write(bytes(s.memory[0x4000:0x5B00]))
s = load('info.z80')
open(os.path.join(out, 'info.scr'), 'wb').write(bytes(s.memory[0x4000:0x5B00]))
s = load('init.z80'); call(s, 0x84D6); call(s, 0x8D0E); call(s, 0x8D5D); call(s, 0x8E5C)
open(os.path.join(out, 'map.scr'), 'wb').write(bytes(s.memory[0x4000:0x5B00]))
tap = open(os.path.join(re_dir, 'snapshots', 'cyclone.tap'), 'rb').read()
i = 0
while i < len(tap):
    n = tap[i] | tap[i + 1] << 8
    blk = tap[i + 2:i + 2 + n]
    if blk[0] == 0xFF and n == 6914:
        open(os.path.join(out, 'loading.scr'), 'wb').write(blk[1:-1])
    i += 2 + n
print('ok')
