"""Extract the terrain graphics: character set FA00, attribute table FE00, per-tile column tables
(pages 63xx-73xx), height-class boundaries (7AC2).

Outputs (re/assets/terrain/):
  charset.png        - the 128 terrain char codes 00-7F (FA00+code*8) in their own attribute colours,
                       plus the 16 solid-colour codes 80-8F, labelled (x4)
  charset_mono.png   - same bitmaps in black/white
  charset.json       - per code: bitmap (8 hex bytes), attribute + decoded colours, role
  tiles.json         - per tile ID 00-FF: height class (7AC2 rule), height, column codes per level
                       (FE = transparent), number of uses in the island data, inferred feature
  tiles_sheet.png    - every tile ID drawn as its stacked column over a sea cell, labelled (x3)
usage: extract_terrain.py [SNAPSHOT]
"""
import sys, os, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cyclone_data as cd
from PIL import Image, ImageDraw

RUNTIME = {}
for c in range(0x33, 0x3C): RUNTIME[c] = 'runtime: aircraft shadow char (copied by 89BC from the current aircraft frame, AND AA/55 dither)'
for c in range(0x3C, 0x45): RUNTIME[c] = 'runtime: aircraft char (current DE00 frame copied to FBE0 by 89B2)'
for c in range(0x5F, 0x80): RUNTIME[c] = 'runtime: helicopter composite buffer FCF8-FDFF (3 cols x 11 rows; background + shadow + heli)'

def role(code):
    if code in RUNTIME: return RUNTIME[code]
    if code >= 0x80: return 'solid colour cell (bitmap not drawn; ink = paper)'
    return {0x00: 'sea wave sparkle 1', 0x01: 'sea wave sparkle 2', 0x02: 'sea wave sparkle 3',
            0x30: 'crate (sea level)', 0x56: 'crate (on land)', 0x31: 'survivor frame A', 0x32: 'survivor frame B'}.get(code, 'terrain')

def feature(m, t, col, cls):
    if t == 0: return 'sea'
    if t in (1, 2, 3): return 'wave sparkle (placed at runtime by 8B91)'
    if t in (0x0F, 0x2F, 0x57, 0x8B): return 'crate (placed at runtime by 5EEC)'
    if t in (0x2D, 0x2E, 0x55, 0x56, 0x89, 0x8A): return 'survivor (placed at runtime by 6072; two animation frames)'
    if t >= 0xF6: return 'aircraft cell (written into the window by 8930-8982; shadow at level 0, plane 3 levels up)'
    if not col or col == [0]: return 'unused'
    s = set(col)
    if s & {0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55}: return 'tree'
    if s & {0x57, 0x58, 0x59, 0x5A, 0x2D, 0x2E}: return 'building'
    if 0x82 in s or 0x88 in s: return 'sand / track (yellow)'
    if s & {0x83, 0x89}: return 'white surface (helipad / concrete)'
    return 'ground'

def main(sna=cd.DEFAULT_SNA):
    m = cd.load(sna)
    out = os.path.join(cd.ASSETS, 'terrain')
    os.makedirs(out, exist_ok=True)
    cols = cd.tile_columns(m)
    used = collections.Counter()
    for isl in cd.islands(m):
        for row in cd.island_block(m, isl):
            used.update(row)

    # charset
    chars = {}
    for code in range(0x90):
        attr = m[cd.CHAR_ATTR + code]
        e = {'code': code, 'attr': cd.attr_desc(attr), 'role': role(code)}
        if code < 0x80:
            e['addr'] = cd.CHARSET + code * 8
            e['bitmap_hex'] = ''.join(f'{b:02X}' for b in m[cd.CHARSET + code * 8: cd.CHARSET + code * 8 + 8])
        chars[f'{code:02X}'] = e
    json.dump({'charset_addr': cd.CHARSET, 'attr_addr': cd.CHAR_ATTR,
               'note': 'char code c < 80h: bitmap FA00+8c drawn with attribute FE00+c; c >= 80h: only the attribute '
                       'FE00+c is written (ink == paper, i.e. a solid colour block). Drawn by 762C to rows 0-21, cols 0-22.',
               'chars': chars}, open(os.path.join(out, 'charset.json'), 'w'), indent=1)
    S = 4
    per = 16
    img = Image.new('RGB', (per * 12, 9 * 20), (60, 60, 90))
    mono = Image.new('RGB', (per * 12, 8 * 20), (60, 60, 90))
    for code in range(0x90):
        x0, y0 = (code % per) * 12, (code // per) * 20
        cd.render_chars(m, [[code]], img=img, ox=x0, oy=y0)
        if code < 0x80:
            mp = mono.load()
            for r in range(8):
                v = m[cd.CHARSET + code * 8 + r]
                for b in range(8):
                    mp[x0 + b, y0 + r] = (0, 0, 0) if v & (0x80 >> b) else (255, 255, 255)
    for im, name in ((img, 'charset.png'), (mono, 'charset_mono.png')):
        im = im.resize((im.width * S, im.height * S), Image.NEAREST)
        d = ImageDraw.Draw(im)
        for code in range(0x90 if name == 'charset.png' else 0x80):
            d.text(((code % per) * 12 * S, ((code // per) * 20 + 9) * S), f'{code:02X}', fill=(255, 255, 0))
        im.save(os.path.join(out, name))

    # tiles
    tiles = {}
    for t in range(256):
        cls = cd.height_class(m, t) if t < 0xFF else None
        col = cols[t]
        tiles[f'{t:02X}'] = {'tile': t, 'height_class': cls, 'height': None if cls is None else cls >> 1,
                             'odd_class_object': None if cls is None else bool(cls & 1),
                             'column': [f'{c:02X}' for c in col], 'levels': len(col),
                             'uses_in_island_data': used[t], 'feature': feature(m, t, col, cls)}
    bounds = []
    a = cd.HEIGHT_BOUNDS
    while True:
        bounds.append(m[a])
        if m[a] == 0xFF: break
        a += 1
    json.dump({'column_rule': 'level k char of tile t is byte ((63h+k)*256 + t); FE = transparent (keep what is behind); '
                              'FF terminates the column. A tile in window row y writes level k at row y-k; rows are '
                              'processed top to bottom so nearer (lower) rows overwrite farther ones (routine 7E10).',
               'height_class_rule': 'class = number of entries in the 7AC2 list that are <= t; height (levels) = class >> 1; '
                                    'odd classes are object tiles (crate/survivor/house/tree) standing on that height (7B03)',
               'height_bounds_7AC2': [f'{b:02X}' for b in bounds],
               'tiles': tiles}, open(os.path.join(out, 'tiles.json'), 'w'), indent=1)

    # tile sheet: 16 tiles per row, each drawn as a 1-wide column 10 cells tall over sea
    S = 3
    cw, chh = 3, 11   # cell width/height in chars
    sheet = Image.new('RGB', (16 * cw * 8, 16 * (chh * 8 + 10)), (60, 60, 90))
    for t in range(256):
        if t == 0xFF: continue
        gx, gy = (t % 16) * cw * 8, (t // 16) * (chh * 8 + 10)
        grid = [[0x80] * 1 for _ in range(chh)]
        for k, c in enumerate(cols[t]):
            if c != 0xFE and chh - 1 - k >= 0:
                grid[chh - 1 - k][0] = c
        cd.render_chars(m, grid, img=sheet, ox=gx + 8, oy=gy)
    sheet = sheet.resize((sheet.width * S, sheet.height * S), Image.NEAREST)
    d = ImageDraw.Draw(sheet)
    for t in range(255):
        gx, gy = (t % 16) * cw * 8, (t // 16) * (chh * 8 + 10)
        d.text((gx * S, (gy + chh * 8 + 1) * S), f'{t:02X}', fill=(255, 255, 0))
    sheet.save(os.path.join(out, 'tiles_sheet.png'))

if __name__ == '__main__':
    main(*(sys.argv[1:2]))
