"""Extract Cyclone sprites.

Outputs (re/assets/sprites/), PNG sheets are x4 scaled, transparent background where noted:
  helicopter.png        E930-EDAF  16 frames 24x24, column-major (3 byte-columns x 24 rows), frame = heading
  helicopter_rotor.png  7000/7100 (flight, 2 frames) and 6700/6800/6900/6A00 (4 frames), 24x24 XOR overlays
  helicopter_composed.png  every heading x rotor frame as the game shows it (frame XOR rotor)
  helicopter_shadow.png EDB0-F22F  16 frames, 9 chars each (3 columns, each bottom->top), FF-led char = empty
  aircraft.png          DE00-E27F  16 frames 24x24 column-major
  aircraft_shadow.png   the dithered shadow the game derives (AND AA/55 per byte)
  explosion.png         F550-F6B7  5 frames 24x24 column-major
  winch.png             F51F-F54F  winch rope / hook load graphics (8 px wide strips)
  sprites.json          addresses, sizes, formats, frame meaning
usage: extract_sprites.py [SNAPSHOT]
"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cyclone_data as cd
from PIL import Image, ImageDraw

S = 4
INK = (0, 0, 0, 255)
CLEAR = (0, 0, 0, 0)

def sheet(frames, w, h, labels=None, gap=4, ink=INK, bg=CLEAR, per_row=16):
    n = len(frames)
    cols = min(n, per_row); rows = (n + per_row - 1) // per_row
    lab = 10 if labels else 0
    img = Image.new('RGBA', (cols * (w + gap), rows * (h + gap + lab)), (0, 0, 0, 0))
    px = img.load()
    for i, f in enumerate(frames):
        x0 = (i % per_row) * (w + gap); y0 = (i // per_row) * (h + gap + lab)
        for y in range(h):
            for x in range(w):
                v = f[y][x]
                if isinstance(v, tuple):
                    px[x0 + x, y0 + y] = v
                else:
                    px[x0 + x, y0 + y] = ink if v else bg
    img = img.resize((img.width * S, img.height * S), Image.NEAREST)
    if labels:
        d = ImageDraw.Draw(img)
        for i, t in enumerate(labels):
            d.text(((i % per_row) * (w + gap) * S, ((i // per_row) * (h + gap + lab) + h + 1) * S), t, fill=(255, 255, 0, 255))
    return img

def white_bg(f):
    return [[(0, 0, 0, 255) if v else (255, 255, 255, 255) for v in row] for row in f]

def xor(a, b):
    return [[x ^ y for x, y in zip(ra, rb)] for ra, rb in zip(a, b)]

def shadow_frame(m, a):
    """9 chars: char index j = col*3 + k, k = 0 bottom .. 2 top (routine 7BB8). Returns 24x24, None = empty char."""
    img = [[0] * 24 for _ in range(24)]
    empty = []
    for col in range(3):
        for k in range(3):
            ch = a + (col * 3 + k) * 8
            r0 = (2 - k) * 8
            if m[ch] == 0xFF:
                empty.append(col * 3 + k)
                for y in range(8):
                    for x in range(8):
                        img[r0 + y][col * 8 + x] = None
                continue
            for y in range(8):
                for x in range(8):
                    img[r0 + y][col * 8 + x] = (m[ch + y] >> (7 - x)) & 1
    return img, empty

def main(sna=cd.DEFAULT_SNA):
    m = cd.load(sna)
    out = os.path.join(cd.ASSETS, 'sprites')
    os.makedirs(out, exist_ok=True)
    meta = {}
    hd = [f'{i:X} {i*22.5:g}' for i in range(16)]

    heli = [cd.sprite_cm(m, 0xE930 + 72 * i) for i in range(16)]
    sheet([white_bg(f) for f in heli], 24, 24, hd).save(os.path.join(out, 'helicopter.png'))
    sheet(heli, 24, 24, hd).save(os.path.join(out, 'helicopter_transparent.png'))
    meta['helicopter'] = {'addr': 0xE930, 'end': 0xEDAF, 'frames': 16, 'frame_bytes': 72, 'size_px': [24, 24],
                          'layout': 'column-major: bytes 0-23 = left 8-px column rows 0-23, 24-47 middle, 48-71 right',
                          'index': 'heading 7507 (0 = nose up/north, +1 = 22.5 deg clockwise); +8 mod 16 in the south view (7504<>0)',
                          'routine': '8CA0 copies frame to 6950, then XORs a rotor overlay; 86AF merges 6950 into the composite chars',
                          'mask': 'none: drawn with OR/AND into the composite buffer (see notes)'}
    rotors = {'7000': 0x7000, '7100': 0x7100, '6700': 0x6700, '6800': 0x6800, '6900': 0x6900, '6A00': 0x6A00}
    rot = {k: cd.sprite_cm(m, a) for k, a in rotors.items()}
    sheet([white_bg(f) for f in rot.values()], 24, 24, list(rotors)).save(os.path.join(out, 'helicopter_rotor.png'))
    meta['helicopter_rotor'] = {'frames': {k: f'{a:04X}' for k, a in rotors.items()}, 'size_px': [24, 24], 'layout': 'column-major, XOR overlay',
                                'use': '753A cycles 0-1 -> 7000/7100 normally; when 7515=1 or 7516<>0 it cycles 0-3 -> 6700/6800/6900/6A00. '
                                       'For heading frames >= 10 the XOR loop is patched (8D02 = ADD A,A) so the rotor byte is shifted left 1 px.'}
    comp = []; labs = []
    for i in range(16):
        for k in ('7000', '7100'):
            r = rot[k]
            if i >= 10:
                r = [[(row[x + 1] if x + 1 < 24 and (x % 8) != 7 else 0) for x in range(24)] for row in r]
            comp.append(white_bg(xor(heli[i], r))); labs.append(f'{i:X}/{k[:2]}')
    sheet(comp, 24, 24, labs, per_row=16).save(os.path.join(out, 'helicopter_composed.png'))

    sh = []; empt = {}
    for i in range(16):
        f, e = shadow_frame(m, 0xEDB0 + 72 * i)
        empt[i] = e
        sh.append([[(255, 0, 0, 90) if v is None else ((0, 0, 0, 255) if v else (255, 255, 255, 255)) for v in row] for row in f])
    sheet(sh, 24, 24, hd).save(os.path.join(out, 'helicopter_shadow.png'))
    meta['helicopter_shadow'] = {'addr': 0xEDB0, 'end': 0xF22F, 'frames': 16, 'frame_bytes': 72,
                                 'layout': '9 chars x 8 bytes; char j = column*3 + k, k=0 bottom, 1 middle, 2 top; a char whose first byte is FF is empty (skipped)',
                                 'empty_chars_per_frame': empt, 'index': 'same as helicopter (heading, +8 in south view)',
                                 'routine': '7BB8: each char is ORed into the composite at the ground height under that cell (7A95-7A9D)'}

    air = [cd.sprite_cm(m, 0xDE00 + 72 * i) for i in range(16)]
    sheet([white_bg(f) for f in air], 24, 24, hd).save(os.path.join(out, 'aircraft.png'))
    airsh = []
    for i in range(16):
        raw = m[0xDE00 + 72 * i: 0xDE00 + 72 * i + 72]
        d = [b & (0xAA if j % 2 == 0 else 0x55) for j, b in enumerate(raw)]
        airsh.append(white_bg(cd.sprite_cm(d, 0)))
    sheet(airsh, 24, 24, hd).save(os.path.join(out, 'aircraft_shadow.png'))
    meta['aircraft'] = {'addr': 0xDE00, 'end': 0xE27F, 'frames': 16, 'frame_bytes': 72, 'size_px': [24, 24],
                        'layout': 'column-major 3x24 = also 9 chars in column order (char j = col*3 + row)',
                        'index': 'aircraft direction byte (record +0, 0-63) >> 2; +8 mod 16 in south view',
                        'routine': '8995: frame copied to FBE0 (= terrain chars 3C-44) and an AND AA/55 dithered copy to FB98 '
                                   '(chars 33-3B, the shadow); the plane is then drawn as map tiles F6-FE (shadow at ground level, plane 3 rows higher)'}
    ex = [cd.sprite_cm(m, 0xF550 + 72 * i) for i in range(5)]
    sheet([white_bg(f) for f in ex], 24, 24, [str(i) for i in range(5)]).save(os.path.join(out, 'explosion.png'))
    meta['explosion'] = {'addr': 0xF550, 'end': 0xF6B7, 'frames': 5, 'frame_bytes': 72, 'size_px': [24, 24], 'layout': 'column-major',
                         'use': 'crash sequence 9246: 24 steps; sprite buffer 6950 cleared every step (from the zero row at 9300); '
                                'steps 24-22 redraw the helicopter (8CA0) and steps 24-20 XOR explosion frame 0..4 (92ED, pointer 9243)'}
    # winch graphics: F51F..F54F as one 8-px strip, split
    strip = [[(m[a] >> (7 - b)) & 1 for b in range(8)] for a in range(0xF51F, 0xF550)]
    parts = [('crate on rope', 0xF51F, 0xF537), ('survivor on rope', 0xF538, 0xF550)]
    fr = []
    for name, a, b in parts:
        rows = [[(m[x] >> (7 - bb)) & 1 for bb in range(8)] for x in range(a, b)]
        rows += [[0] * 8] * (25 - len(rows))
        fr.append(white_bg(rows))
    sheet(fr, 8, 25, ['crate', 'man'], gap=6).save(os.path.join(out, 'winch.png'))
    meta['winch'] = {'crate_on_rope': [0xF51F, 0xF536], 'survivor_on_rope': [0xF538, 0xF54F],
                     'layout': '1 byte (8 px) wide, one byte per pixel row; rope pixels (bit 3) above the load. '
                               'Drawn rows = [ptr - rope_len, ptr + 8): crate ptr F52F (crate body F530-F536), survivor ptr F548 (man F548-F54E)',
                     'use': 'F39A: when the tile under the helicopter (7A85) is a crate (F511 list) or survivor (F515 list) and the winch '
                            'is lowered (7555), pointer 7557 selects F52F (crate) or F548 (survivor); drawn into the composite column at FDA1'}
    json.dump(meta, open(os.path.join(out, 'sprites.json'), 'w'), indent=1)

if __name__ == '__main__':
    main(*(sys.argv[1:2]))
