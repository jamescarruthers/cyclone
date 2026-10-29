"""Shared decoding helpers for Cyclone (Vortex, 1985) data/asset extraction.

All addresses refer to the 48K memory image (snapshots/init.z80 unless stated).
See re/notes/data.md for the format descriptions these helpers implement.
"""
import os
from skoolkit.snapshot import make_snapshot

RE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SNA = os.path.join(RE_DIR, 'snapshots', 'init.z80')
ASSETS = os.path.join(RE_DIR, 'assets')

# ---------------------------------------------------------------- memory
def load(sna=DEFAULT_SNA):
    """Return the 64K memory image as a list of ints."""
    return make_snapshot(sna, None)[0]

def word(m, a):
    return m[a] + 256 * m[a + 1]

# ---------------------------------------------------------------- palette
# ZX Spectrum colours (normal, bright)
PAL = [
    [(0, 0, 0), (0, 0, 0xD7), (0xD7, 0, 0), (0xD7, 0, 0xD7), (0, 0xD7, 0), (0, 0xD7, 0xD7), (0xD7, 0xD7, 0), (0xD7, 0xD7, 0xD7)],
    [(0, 0, 0), (0, 0, 0xFF), (0xFF, 0, 0), (0xFF, 0, 0xFF), (0, 0xFF, 0), (0, 0xFF, 0xFF), (0xFF, 0xFF, 0), (0xFF, 0xFF, 0xFF)],
]
COLOUR_NAMES = ['black', 'blue', 'red', 'magenta', 'green', 'cyan', 'yellow', 'white']

def attr_colours(attr):
    """(ink_rgb, paper_rgb) for a Spectrum attribute byte (FLASH ignored)."""
    br = (attr >> 6) & 1
    return PAL[br][attr & 7], PAL[br][(attr >> 3) & 7]

def attr_desc(attr):
    return {'attr': attr, 'ink': attr & 7, 'paper': (attr >> 3) & 7,
            'bright': (attr >> 6) & 1, 'flash': attr >> 7,
            'ink_name': COLOUR_NAMES[attr & 7], 'paper_name': COLOUR_NAMES[(attr >> 3) & 7]}

# ---------------------------------------------------------------- terrain
MAP_BASE = 0x9300          # island tile store: 128 bytes per row
MAP_STRIDE = 128
MAP_END = 0xDE00           # 150 rows (9300-DDFF)
ISLAND_TABLE = 0xF230      # 14 records x 20 bytes, terminated by FF at F348
ISLAND_REC = 20
CHARSET = 0xFA00           # terrain character bitmaps, code*8 (codes 00-7F)
CHAR_ATTR = 0xFE00         # attribute for each code 00-8F (codes >=80: solid colour cells)
COLUMN_PAGES = 0x63        # level k char for tile t is at (0x63+k)*256 + t
HEIGHT_BOUNDS = 0x7AC2     # 17 ascending tile-ID boundaries -> height class (7ADC)
WIN_W, WIN_H, VIS_H = 23, 29, 22   # window buffer F74E: 23 cols x 29 rows, 22 rows visible

# Island names, in table order, matched by map-screen label position (see notes)
def island_names(m):
    """Decode the names printed on the map screen (8DE2): text at 6A50, FE separates islands."""
    names = []
    a = 0x6A50
    cur = ''
    while True:
        c = m[a]
        if c == 0xFF:
            names.append(cur); break
        if c == 0xFE:
            names.append(cur); cur = ''
        elif c == 0xFD:
            cur += MAPFONT_CHARS.get(m[0x6AC2], '?')
        else:
            cur += MAPFONT_CHARS.get(c, '?')
        a += 1
    return names

# map-screen font at 6908 + code*8 ; codes used by the names table
MAPFONT_CHARS = {}
for _i, _ch in enumerate('ABCDEFGHIJKLMNOPQRSTUVWXYZ'):
    MAPFONT_CHARS[0x41 + _i] = _ch
MAPFONT_CHARS[0x20] = ' '

def islands(m):
    """Parse the island placement table at F230."""
    out = []
    a = ISLAND_TABLE
    i = 0
    while m[a] != 0xFF:
        e = m[a:a + ISLAND_REC]
        ptr = e[10] + 256 * e[11]
        w = e[3] - e[6] + 1      # copy extent used by 77D2 (X >= data_x1 case)
        h = e[5] - e[8] + 1      # copy extent used by 787D (Y >= data_y1 case)
        out.append({
            'index': i, 'record': a,
            'sector_x': e[0], 'sector_y': e[1],
            'active_x': [e[2], e[3]], 'active_y': [e[4], e[5]],
            'data_x': [e[6], e[7]], 'data_y': [e[8], e[9]],
            'data_ptr': ptr,
            'store_row': (ptr - MAP_BASE) // MAP_STRIDE, 'store_col': (ptr - MAP_BASE) % MAP_STRIDE,
            'width': w, 'height': h,
            'world_x': e[0] * 256 + e[6], 'world_y': e[1] * 256 + e[8],
            'map_pixel_addr': e[12] + 256 * e[13], 'map_bytes_wide': e[14], 'map_pixel_rows': e[15],
            'name_addr': e[16] + 256 * e[17], 'name_attr_hi': e[18], 'spare': e[19],
            'raw': list(e),
        })
        a += ISLAND_REC
        i += 1
    return out

def island_block(m, isl):
    """Return the island's tile block as list of rows (height x width)."""
    p = isl['data_ptr']
    return [[m[p + r * MAP_STRIDE + c] for c in range(isl['width'])] for r in range(isl['height'])]

def tile_columns(m):
    """For each tile ID 0-255: list of char codes for levels 0.. (FE = transparent), up to the FF terminator."""
    cols = {}
    for t in range(256):
        col = []
        for k in range(0, 0x100 - COLUMN_PAGES):
            v = m[(COLUMN_PAGES + k) * 256 + t]
            if v == 0xFF:
                break
            col.append(v)
            if COLUMN_PAGES + k >= 0x73:
                break
        cols[t] = col
    return cols

def height_class(m, t):
    """Replicates 7B03-7B0C: count of boundaries in 7AC2.. that t is >= ; height = class>>1."""
    c = 0
    a = HEIGHT_BOUNDS
    while t >= m[a] and c < 17:   # list ends with FF; tile FF never occurs (it is the terminator)
        c += 1
        a += 1
    return c

def stack(tiles, cols, rows_out=None):
    """Painter's char stacking used by 7E10: tiles[y][x] -> char grid.
    Tile at row y writes level-k code at row y-k (FE = leave as is). Rows processed top to bottom.
    Returns grid of codes with len(tiles) rows (rows above 0 are clipped)."""
    h = len(tiles); w = len(tiles[0]) if h else 0
    grid = [[None] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            for k, code in enumerate(cols[tiles[y][x]]):
                if code == 0xFE:
                    continue
                yy = y - k
                if yy < 0:
                    break
                grid[yy][x] = code
    return grid

def render_chars(m, grid, scale=1, img=None, ox=0, oy=0, none_rgb=(0, 0, 0)):
    """Render a grid of char codes (FA00 bitmaps + FE00 attributes) to a PIL image."""
    from PIL import Image
    h = len(grid); w = len(grid[0]) if h else 0
    if img is None:
        img = Image.new('RGB', (w * 8, h * 8), none_rgb)
    px = img.load()
    for y in range(h):
        for x in range(w):
            code = grid[y][x]
            if code is None:
                continue
            attr = m[CHAR_ATTR + code]
            ink, paper = attr_colours(attr)
            for r in range(8):
                bits = m[CHARSET + code * 8 + r] if code < 0x80 else 0
                for b in range(8):
                    px[ox + x * 8 + b, oy + y * 8 + r] = ink if bits & (0x80 >> b) else paper
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    return img

def world_window(m, isls, X, Y, view=0):
    """Rebuild the 23x29 window buffer exactly like 76D2: first island whose sector matches
    (7501,7503)=(X>>8,Y>>8) and whose active range contains the local position, else all sea.
    X,Y are 16-bit (7500/7501, 7502/7503). Returns list of 29 rows of 23 tile IDs (view 0 = north)."""
    sx, sy, lx, ly = X >> 8, Y >> 8, X & 255, Y & 255
    win = [[0] * WIN_W for _ in range(WIN_H)]
    for isl in isls:
        if isl['sector_x'] != sx or isl['sector_y'] != sy:
            continue
        if not (isl['active_x'][0] <= lx and ((lx - 1) & 255) < isl['active_x'][1]):
            continue
        if not (isl['active_y'][0] <= ly and ((ly - 1) & 255) < isl['active_y'][1]):
            continue
        # window cell (r,c) <- island data (ly - data_y0 + r, lx - data_x0 + c) when inside the block
        for r in range(WIN_H):
            dr = ly - isl['data_y'][0] + r
            if not (0 <= dr < isl['height']):
                continue
            for c in range(WIN_W):
                dc = lx - isl['data_x'][0] + c
                if 0 <= dc < isl['width']:
                    win[r][c] = m[isl['data_ptr'] + dr * MAP_STRIDE + dc]
        break
    if view:
        win = [row[::-1] for row in win[::-1]]
    return win

def sprite_cm(m, a, cols=3, rows=24):
    """Column-major sprite: `cols` byte-columns of `rows` bytes each -> list of rows of pixel bits."""
    out = []
    for r in range(rows):
        row = []
        for c in range(cols):
            v = m[a + c * rows + r]
            row += [(v >> (7 - b)) & 1 for b in range(8)]
        out.append(row)
    return out

def sprite_rm(m, a, cols, rows):
    """Row-major sprite: `rows` rows of `cols` bytes."""
    out = []
    for r in range(rows):
        row = []
        for c in range(cols):
            v = m[a + r * cols + c]
            row += [(v >> (7 - b)) & 1 for b in range(8)]
        out.append(row)
    return out

def char_bits(m, a):
    return [[(m[a + r] >> (7 - b)) & 1 for b in range(8)] for r in range(8)]
