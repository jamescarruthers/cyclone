"""Verify the terrain decoding: rebuild the 23x22-char landscape view from the island data
(F230 table + 9300 tile store + 63xx column tables + FA00 charset + FE00 attributes) using the
position variables 7500-7504 held in a memory image, and compare cell-by-cell with the
screen memory (4000-5AFF) of the same image.

usage: verify_render.py IMAGE [OUT.png]
  IMAGE: a .z80/.sna snapshot or a raw 64K .bin memory dump taken during flight.
Output: match statistics; OUT.png = [actual | rebuilt | diff] side by side.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cyclone_data as cd
from PIL import Image

def screen_cell(m, x, y):
    a = 0x4000 + ((y & 0x18) << 8) + ((y & 7) << 5) + x
    return [m[a + (r << 8)] for r in range(8)], m[0x5800 + y * 32 + x]

def compare(m, grid):
    total = same = skipped = 0
    bad = []
    for y in range(cd.VIS_H):
        for x in range(cd.WIN_W):
            code = grid[y][x]
            bits, attr = screen_cell(m, x, y)
            if code is None:
                skipped += 1; continue
            # cells covered by the helicopter/shadow composite (cols 10-12, rows 5-15) or the
            # runtime sprite characters (33-44 aircraft, 5F-7F heli composite) are dynamic
            if (10 <= x <= 12 and 5 <= y <= 15) or 0x33 <= code <= 0x44 or 0x5F <= code <= 0x7F:
                skipped += 1; continue
            total += 1
            eattr = m[cd.CHAR_ATTR + code]
            if code >= 0x80:
                ok = attr == eattr or (((attr >> 3) & 7) == (attr & 7) == ((eattr >> 3) & 7) and (attr & 0x40) == (eattr & 0x40))
                # solid cell: pixels irrelevant when ink == paper
                ok = attr == eattr
            else:
                ebits = m[cd.CHARSET + code * 8: cd.CHARSET + code * 8 + 8]
                ok = attr == eattr and list(ebits) == bits
            if not ok and code == 0x80 and attr == m[cd.CHAR_ATTR + 1]:
                ok = True   # sea cell showing a wave sparkle (tiles 1-3 placed at runtime by 8B91)
            if ok:
                same += 1
            else:
                bad.append((x, y, code))
    return same, total, skipped, bad

def main(path, out=None):
    if path.endswith('.bin'):
        m = list(open(path, 'rb').read())
    else:
        m = cd.load(path)
    isls = cd.islands(m)
    X0 = m[0x7500] + 256 * m[0x7501]
    Y0 = m[0x7502] + 256 * m[0x7503]
    view = m[0x7504]
    cols = cd.tile_columns(m)
    best = None
    # the screen may still show the previous frame's position: also try small offsets
    for dx, dy in [(0, 0)] + [(a, b) for a in range(-3, 4) for b in range(-3, 4) if (a, b) != (0, 0)]:
        X, Y = X0 + dx, Y0 + dy
        g = cd.stack(cd.world_window(m, isls, X, Y, view), cols)[:cd.VIS_H]
        r = compare(m, g)
        if best is None or r[0] > best[0][0]:
            best = (r, X, Y, g, dx, dy)
        if r[0] == r[1]:
            break
    (same, total, skipped, bad), X, Y, grid, dx, dy = best
    print(f'{os.path.basename(path)}: X={X:04X} Y={Y:04X} view={view} compared={total} match={same} '
          f'({100.0 * same / max(1, total):.1f}%) skipped={skipped} offset_from_vars=({dx},{dy})')
    if bad[:10]:
        print('  first mismatches (x,y,code):', bad[:10])
    if out:
        actual = Image.new('RGB', (184, 176))
        apx = actual.load()
        for y in range(22):
            for x in range(23):
                bits, attr = screen_cell(m, x, y)
                ink, paper = cd.attr_colours(attr)
                for r in range(8):
                    for b in range(8):
                        apx[x * 8 + b, y * 8 + r] = ink if bits[r] & (0x80 >> b) else paper
        rebuilt = cd.render_chars(m, grid)
        diff = Image.new('RGB', (184, 176), (0, 0, 0))
        dpx = diff.load(); rpx = rebuilt.load()
        for yy in range(176):
            for xx in range(184):
                dpx[xx, yy] = (255, 0, 0) if apx[xx, yy] != rpx[xx, yy] else (40, 40, 40)
        img = Image.new('RGB', (184 * 3 + 16, 176), (90, 90, 90))
        img.paste(actual, (0, 0)); img.paste(rebuilt, (192, 0)); img.paste(diff, (384, 0))
        img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(out)
    return same, total

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
