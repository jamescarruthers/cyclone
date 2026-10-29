"""Extract the Cyclone world (island placement table F230 + island tile store 9300-DDFF).

Outputs (re/assets/world/):
  world.json            - world geometry, the 14 island records (decoded + raw), each island's tile block,
                          crate/survivor candidate sites, start position, window/viewport constants
  world_grid.bin        - 768x768 bytes, row-major, tile ID per world cell (sea = 0); exact flat equivalent
  world_overview.png    - 1 px per tile, coloured by height class / feature (768x768, x2 scaled)
  world_render_north.png- every island rendered with the game's char-stacking renderer (8x8 px per cell),
                          cropped to the populated area, NORTH view
  islands/NN_name_north.png, NN_name_south.png - each island rendered alone (north and south views)
  map_screen_rebuilt.png - the in-game map screen silhouettes rebuilt from the table (8D5D algorithm)

usage: extract_world.py [SNAPSHOT]
"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cyclone_data as cd
from PIL import Image, ImageDraw

WORLD = 768  # 3 x 3 sectors of 256 x 256 tiles

def feature(t, cls):
    """Coarse feature category for a tile ID (INFERRED from its char column)."""
    if t == 0: return 'sea'
    if t in (1, 2, 3): return 'wave'
    if t in (0x0F, 0x2F, 0x57, 0x8B): return 'crate'
    if t in (0x2D, 0x2E, 0x55, 0x56, 0x89, 0x8A): return 'survivor'
    if t >= 0xF6: return 'aircraft'
    return 'land'

def overview_colour(m, t, cols):
    """Colour for the 1-px overview: colour of the top-most visible cell of the tile's column."""
    if t == 0:
        return (0, 0x9A, 0xC8)
    col = [c for c in cols[t] if c != 0xFE]
    if not col:
        return (255, 0, 255)
    top = col[-1]
    attr = m[cd.CHAR_ATTR + top]
    ink, paper = cd.attr_colours(attr)
    # darken by height so relief is visible
    h = cd.height_class(m, t) >> 1
    f = 0.55 + 0.45 * min(h, 6) / 6.0
    base = paper if top >= 0x80 else tuple((a + b) // 2 for a, b in zip(ink, paper))
    return tuple(int(v * f) for v in base)

def addr_to_world(isls, a):
    """Map a tile-store address to (island index, local x, local y, world x, world y)."""
    for isl in isls:
        off = a - isl['data_ptr']
        r, c = divmod(off, cd.MAP_STRIDE)
        if off >= 0 and 0 <= c < isl['width'] and 0 <= r < isl['height']:
            return isl['index'], c, r, isl['world_x'] + c, isl['world_y'] + r
    return None

def scr_addr(x_byte, y):
    return 0x4000 + ((y & 0xC0) << 5) + ((y & 7) << 8) + ((y & 0x38) << 2) + x_byte

def scr_xy(addr):
    a = addr - 0x4000
    return a & 31, ((a >> 5) & 0xC0) | ((a >> 2) & 0x38) | ((a >> 8) & 7)

def map_screen_exact(m, isls):
    """Re-implementation of 8D5D-8DDF (map-screen island silhouettes) into a 6144-byte bitmap.
    Per island: sample the tile block starting at (row 2, col 2); each pixel row samples every
    4th column (INC L x4, wrapping inside the 256-byte page exactly like the original) and
    successive pixel rows are 4 tile rows apart (INC H x2). A pixel is set when tile >= 0F.
    Record byte 14 = E: E+1 samples per pixel row; byte 15 = number of pixel rows."""
    scr = bytearray(6144)
    for isl in isls:
        xb, y = scr_xy(isl['map_pixel_addr'])
        hl = (isl['data_ptr'] + 0x0102) & 0xFFFF
        for _ in range(isl['map_pixel_rows']):
            e = isl['map_bytes_wide']
            p = hl
            out = scr_addr(xb, y)
            while True:
                c = 0
                b = 8
                while True:
                    c = (c << 1) & 0xFF
                    if m[p] >= 0x0F:
                        c |= 1
                    p = (p & 0xFF00) | ((p + 4) & 0xFF)
                    if e == 0:
                        c = (c << (b - 1)) & 0xFF
                        break
                    e -= 1
                    b -= 1
                    if b == 0:
                        break
                scr[out - 0x4000] = c
                out += 1
                if e == 0:
                    break
            y += 1
            hl = (hl + 0x200) & 0xFFFF
    return scr

def main(sna=cd.DEFAULT_SNA):
    m = cd.load(sna)
    out = os.path.join(cd.ASSETS, 'world')
    os.makedirs(os.path.join(out, 'islands'), exist_ok=True)
    isls = cd.islands(m)
    names = island_names_list(m)
    cols = cd.tile_columns(m)
    grid = bytearray(WORLD * WORLD)
    for isl in isls:
        isl['name'] = names[isl['index']]
        blk = cd.island_block(m, isl)
        isl['tiles_hex'] = [''.join(f'{v:02X}' for v in row) for row in blk]
        for r, row in enumerate(blk):
            for c, v in enumerate(row):
                x, y = isl['world_x'] + c, isl['world_y'] + r
                if v and 0 <= x < WORLD and 0 <= y < WORLD:
                    grid[y * WORLD + x] = v
    open(os.path.join(out, 'world_grid.bin'), 'wb').write(bytes(grid))

    # crate sites (5F61: 38 x [flag, addr lo, addr hi]) and survivor sites (6018: 45 x addr)
    crate_sites = []
    for i in range(38):
        a = 0x5F61 + 3 * i
        addr = cd.word(m, a + 1)
        w = addr_to_world(isls, addr)
        crate_sites.append({'record': a, 'addr': addr, 'tile_now': m[addr], 'island': w[0], 'local': [w[1], w[2]], 'world': [w[3], w[4]]} if w else {'record': a, 'addr': addr})
    surv_sites = []
    for i in range(45):
        addr = cd.word(m, 0x6018 + 2 * i)
        w = addr_to_world(isls, addr)
        surv_sites.append({'addr': addr, 'tile_now': m[addr], 'island': w[0], 'local': [w[1], w[2]], 'world': [w[3], w[4]]} if w else {'addr': addr})

    X0 = cd.word(m, 0x7564); Y0 = cd.word(m, 0x7566)
    doc = {
        'source': os.path.basename(sna),
        'world_size_tiles': [WORLD, WORLD],
        'sector_size': 256,
        'coordinates': ('Position variables 7500/7501 (X lo = local, hi = sector) and 7502/7503 (Y) give the '
                        'world cell at the TOP-LEFT of the 23x29 window buffer F74E. World x grows to the right '
                        '(east), y grows downwards (south) in the north view. One tile = one 8x8 character cell.'),
        'window': {'buffer': 0xF74E, 'cols': cd.WIN_W, 'rows': cd.WIN_H, 'visible_rows': cd.VIS_H,
                   'heli_footprint_cells': {'cols': [10, 12], 'rows': [13, 15]},
                   'heli_composite_cells': {'cols': [10, 12], 'rows': [5, 15]}},
        'start_position': {'X': X0, 'Y': Y0, 'heli_cell': [X0 + 11, Y0 + 14]},
        'tile_store': {'base': cd.MAP_BASE, 'stride': cd.MAP_STRIDE, 'rows': (cd.MAP_END - cd.MAP_BASE) // cd.MAP_STRIDE},
        'island_record_layout': {
            '0': 'sector X (must equal 7501)', '1': 'sector Y (must equal 7503)',
            '2,3': 'local X activation range: island drawn when 2 <= X <= 3 (= data_x0-22 .. data_x1+22)',
            '4,5': 'local Y activation range (= data_y0-28 .. data_y1+28)',
            '6,7': 'data_x0, data_x1: window fully inside horizontally when data_x0 <= X < data_x1; block col 0 = world x sector*256+data_x0',
            '8,9': 'data_y0, data_y1: block row 0 = world y sector*256+data_y0',
            '10,11': 'pointer to block (row 0, col 0) inside the 128-byte-stride tile store',
            '12,13': 'map-screen bitmap address of the silhouette', '14': 'silhouette width in pixels (one pixel per 4 tiles)',
            '15': 'silhouette height in pixel rows (one per 4 tile rows)', '16,17': 'map-screen bitmap address of the name',
            '18': 'attribute-file high byte for the name (attr = 78h written under each name cell)', '19': 'unused (0)'},
        'islands': [{k: v for k, v in isl.items()} for isl in isls],
        'crate_sites': crate_sites,
        'survivor_sites': surv_sites,
        'crate_tiles': {'by_height': {'0': 0x0F, '1': 0x2F, '2': 0x57, '3': 0x8B},
                        'replaces': {'0x00': 0x0F, '0x10': 0x2F, '0x30': 0x57, '0x58': 0x8B}},
        'survivor_tiles': {'replaces': {'0x10': [0x2D, 0x2E], '0x30': [0x55, 0x56], '0x58': [0x89, 0x8A]}},
    }
    json.dump(doc, open(os.path.join(out, 'world.json'), 'w'), indent=1)

    # overview
    ov = Image.new('RGB', (WORLD, WORLD), (0, 0x9A, 0xC8))
    px = ov.load()
    cache = {}
    for y in range(WORLD):
        for x in range(WORLD):
            t = grid[y * WORLD + x]
            if t:
                if t not in cache:
                    cache[t] = overview_colour(m, t, cols)
                px[x, y] = cache[t]
    d = ImageDraw.Draw(ov)
    for s in (256, 512):
        d.line([(s, 0), (s, WORLD - 1)], fill=(0, 0x70, 0x90)); d.line([(0, s), (WORLD - 1, s)], fill=(0, 0x70, 0x90))
    for isl in isls:
        d.text((isl['world_x'], isl['world_y'] - 10), isl['name'], fill=(255, 255, 255))
    for c in crate_sites:
        if 'world' in c:
            d.point(tuple(c['world']), fill=(255, 0, 0))
    ov.resize((WORLD * 2, WORLD * 2), Image.NEAREST).save(os.path.join(out, 'world_overview.png'))

    # full render (north view), cropped to populated area
    x0 = min(i['world_x'] for i in isls) - 2; y0 = min(i['world_y'] for i in isls) - 8
    x1 = max(i['world_x'] + i['width'] for i in isls) + 2; y1 = max(i['world_y'] + i['height'] for i in isls) + 2
    tiles = [[grid[y * WORLD + x] for x in range(x0, x1)] for y in range(y0, y1)]
    g = cd.stack(tiles, cols)
    img = cd.render_chars(m, g)
    img.save(os.path.join(out, 'world_render_north.png'))
    doc_crop = {'origin_world': [x0, y0], 'size_cells': [x1 - x0, y1 - y0]}

    # per island renders
    for isl in isls:
        blk = cd.island_block(m, isl)
        fn = f"{isl['index']:02d}_{isl['name'].lower().replace(' ', '_')}"
        cd.render_chars(m, cd.stack(blk, cols)).save(os.path.join(out, 'islands', fn + '_north.png'))
        rot = [row[::-1] for row in blk[::-1]]
        cd.render_chars(m, cd.stack(rot, cols)).save(os.path.join(out, 'islands', fn + '_south.png'))

    # map screen silhouettes
    scr = map_screen_exact(m, isls)
    ms = Image.new('RGB', (256, 192), (255, 255, 255)); mp = ms.load()
    for y in range(192):
        for xb in range(32):
            v = scr[((y & 0xC0) << 5) + ((y & 7) << 8) + ((y & 0x38) << 2) + xb]
            for b in range(8):
                if v & (0x80 >> b):
                    mp[xb * 8 + b, y] = (0, 0xC0, 0)
    d = ImageDraw.Draw(ms)
    for isl in isls:
        xb, y = scr_xy(isl['name_addr'])
        d.text((xb * 8, y), isl['name'], fill=(0, 0, 0))
    ms.resize((512, 384), Image.NEAREST).save(os.path.join(out, 'map_screen_rebuilt.png'))
    json.dump(doc_crop, open(os.path.join(out, 'world_render_north.json'), 'w'), indent=1)
    print('islands:', [(i['index'], i['name']) for i in isls])

def island_names_list(m):
    """Names in table order, decoded as 8DE2 does (3F = space, FD = append ' ISLAND', FE = next)."""
    names = []
    a = 0x6A50; cur = ''
    while True:
        c = m[a]; a += 1
        if c == 0xFF:
            break
        if c == 0xFE:
            names.append(cur); cur = ''; continue
        if c == 0xFD:
            names.append(cur + ' ISLAND'); cur = ''; continue
        cur += ' ' if c == 0x3F else chr(c)
    return names

if __name__ == '__main__':
    main(*(sys.argv[1:2]))
