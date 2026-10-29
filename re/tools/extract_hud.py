"""Extract fonts, HUD graphics and reference screens.

Outputs (re/assets/hud/):
  font_main.png / .json   6028+code*8, codes 16-5F (main font: digits 30-39, letters 41-5A, HUD glyphs)
  font_hud.png  / .json   7400+code*8, codes 00-1F (right-hand instrument panel pieces)
  font_map.png  / .json   6908+code*8, codes 3F-5A (map-screen 4-px font; '?'(3F) = space)
  hud_static.png          the play screen frame as drawn by the game's own init code (8D0E + 84F4) run in
                          the simulator on a blank screen (x2)
  hud_layout.json         7300 panel char map (15x8), 7200 panel attributes (21x8), 7148 bottom attributes (64),
                          6848 bottom-row text codes (64)
  screens/*.png           reference screenshots from the shipped snapshots (map screen, info screen)
usage: extract_hud.py [SNAPSHOT]
"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cyclone_data as cd
from PIL import Image, ImageDraw
from skoolkit.simulator import Simulator

S = 4

def font_sheet(m, base, codes, path, width=8):
    per = 16
    n = len(codes)
    img = Image.new('RGB', (per * 12, ((n + per - 1) // per) * 20), (60, 60, 90))
    px = img.load()
    for i, c in enumerate(codes):
        x0, y0 = (i % per) * 12, (i // per) * 20
        for r in range(8):
            v = m[base + c * 8 + r]
            for b in range(width):
                px[x0 + b, y0 + r] = (0, 0, 0) if v & (0x80 >> b) else (255, 255, 255)
    img = img.resize((img.width * S, img.height * S), Image.NEAREST)
    d = ImageDraw.Draw(img)
    for i, c in enumerate(codes):
        d.text(((i % per) * 12 * S, ((i // per) * 20 + 9) * S), f'{c:02X}', fill=(255, 255, 0))
    img.save(path)
    return {f'{c:02X}': ''.join(f'{b:02X}' for b in m[base + c * 8: base + c * 8 + 8]) for c in codes}

def screen_png(m, path, scale=2):
    img = Image.new('RGB', (256, 192))
    px = img.load()
    for y in range(192):
        for xb in range(32):
            v = m[0x4000 + ((y & 0xC0) << 5) + ((y & 7) << 8) + ((y & 0x38) << 2) + xb]
            ink, paper = cd.attr_colours(m[0x5800 + (y >> 3) * 32 + xb])
            for b in range(8):
                px[xb * 8 + b, y] = ink if v & (0x80 >> b) else paper
    img.resize((256 * scale, 192 * scale), Image.NEAREST).save(path)

def call(mem, addr, stop=0xFFF0, sp=0xFEF0, maxops=5000000):
    """Run routine `addr` in the simulator until it returns to `stop`."""
    mem[sp] = stop & 255; mem[sp + 1] = stop >> 8
    sim = Simulator(mem, {'SP': sp, 'PC': addr})
    n = 0
    while sim.registers[24] != stop and n < maxops:
        sim.run(sim.registers[24], stop)
        n += 1
    return mem

def main(sna=cd.DEFAULT_SNA):
    m = cd.load(sna)
    out = os.path.join(cd.ASSETS, 'hud')
    os.makedirs(os.path.join(out, 'screens'), exist_ok=True)
    meta = {}
    meta['font_main'] = {'addr': 0x6028, 'rule': 'glyph = 6028 + code*8 (routines 859A, E42B, 6F00 (7 rows))',
                         'glyphs': font_sheet(m, 0x6028, list(range(0x16, 0x60)), os.path.join(out, 'font_main.png'))}
    meta['font_hud'] = {'addr': 0x7400, 'rule': 'glyph = 7400 + code*8, codes 00-1F, placed by 84F4 from the 7300 map',
                        'glyphs': font_sheet(m, 0x7400, list(range(0x20)), os.path.join(out, 'font_hud.png'))}
    meta['font_map'] = {'addr': 0x6908, 'rule': 'glyph = 6908 + code*8; only the left 4 px are used: 8DE2 prints two '
                                                'characters per cell (odd ones shifted right 4 and ORed)',
                        'glyphs': font_sheet(m, 0x6908, list(range(0x3F, 0x5B)), os.path.join(out, 'font_map.png'))}
    json.dump(meta, open(os.path.join(out, 'fonts.json'), 'w'), indent=1)

    layout = {
        'panel_chars_7300': [[f'{m[0x7300 + r * 8 + c]:02X}' for c in range(8)] for r in range(15)],
        'panel_chars_note': '15 rows x 8 cols at screen cols 24-31, rows 0-14; FF = leave blank; glyph 7400+code*8',
        'panel_attrs_7200': [[f'{m[0x7200 + r * 8 + c]:02X}' for c in range(8)] for r in range(21)],
        'panel_attrs_note': '21 rows x 8 cols -> 5818 + row*32 (cols 24-31, rows 0-20)',
        'bottom_attrs_7148': [f'{b:02X}' for b in m[0x7148:0x7188]],
        'bottom_attrs_note': '64 bytes -> 5AC0 (rows 22-23, full width)',
        'bottom_text_6848': [f'{b:02X}' for b in m[0x6848:0x6888]],
        'bottom_text_note': '64 main-font codes -> 50C0 (rows 22-23): crate boxes, WIND FORCE, DANGER',
        'strings': {'85B9': 'BEWARE (at 5019)', '85BF': 'AIRCRAFT (at 5038)', '85C7': 'codes 3C-40 = "VIEW" glyphs (at 48BB)',
                    '85CC': 'NORTH (at 48DB, attr 38)'},
        'play_area': '23 x 22 chars at cols 0-22, rows 0-21 (8D0E clears it, attr 3F)',
    }
    json.dump(layout, open(os.path.join(out, 'hud_layout.json'), 'w'), indent=1)

    # static HUD by running the game's own routines on a blank screen
    mem = list(m)
    for a in range(0x4000, 0x5B00):
        mem[a] = 0 if a < 0x5800 else 0x38
    call(mem, 0x8D0E)
    call(mem, 0x84F4)
    screen_png(mem, os.path.join(out, 'hud_static.png'))

    snaps = os.path.join(cd.RE_DIR, 'snapshots')
    for name, fn in (('map_screen_ingame.png', 'play1.z80'), ('info_screen.png', 'info.z80')):
        screen_png(cd.load(os.path.join(snaps, fn)), os.path.join(out, 'screens', name))

if __name__ == '__main__':
    main(*(sys.argv[1:2]))
