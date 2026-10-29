# Cyclone: data area $9300–$E27F, and game-wide graphics/asset formats

Area owner: `data`. ctl: `re/ctl/data.ctl` (covers exactly 9300–E27F). This note also covers asset
extraction for the whole game, and describes the graphics and data tables in the other data regions
(60AC–65FF, 661C–6EFF, 6F24–7377, E4E0–F349, F511–F74D, F784–FE91). The routines named here belong to
other areas. I read them only to work out the formats.

Evidence tags: **CODE** = read from the disassembly, **OBSERVED** = seen in emulation (read/write
tracer, screenshots, pixel comparisons), **INFERRED** = interpretation.

## 1. What 9300–E27F contains

| Range | Size | Contents |
|---|---|---|
| 9300–DDFF | 19200 | **Island tile store**: 150 rows × 128 bytes. One byte per map cell (tile ID). 14 island blocks are packed into it (CODE 76D2/775E/7777; OBSERVED by the read tracer: only 7806/7842/7970/79AB (window copy), 8D83 (map screen), 5EFE/5F41 (crate placement), 607F (survivor placement) and 9266 read it). |
| DE00–E27F | 1152 | **Aircraft sprite**: 16 frames × 72 bytes, 24×24 px, column-major (CODE 8995–89B2). |

No code sits in this range. base.ctl had it as a single `b` block, which is correct. Row 0 (9300–937F) is
all zeros. The crash sequence 9246 also uses 9300–9347 as a blank 72-byte sprite: it LDIRs this into the
sprite buffer 6950 to clear it (CODE 9260).

## 2. World model (remake-critical)

### 2.1 Coordinates
- Position variables (CODE 76E9…, OBSERVED): `7500` = X low (local), `7501` = X sector, `7502` = Y low,
  `7503` = Y sector. (X, Y) is the world cell at the **top-left of the 23×29 window buffer F74E**.
  World x grows east (to the right), and world y grows south (down the screen) in the north view.
- **1 tile = 1 character cell = 8×8 px.** The isometric look comes from stacking char cells upwards
  (see 3). It is not a projection.
- World = 3×3 sectors of 256×256 cells (768×768). All 14 islands lie inside it. The islands' sectors and
  ranges come from the table at F230.
- Initial position (copied from 7564 to 7500 at game start, CODE 5B1B): X = 0139h (313), Y = 0170h (368),
  in sector (1,1) on BASE ISLAND.
- Visible landscape: 23 columns × 22 rows of chars (screen cols 0–22, rows 0–21). 762C draws 8+8+6 rows
  (CODE). The buffer has 29 rows, because rows 22–28 hold tiles whose tall columns reach up into the
  visible area.
- Helicopter footprint: window cells cols 10–12, rows 13–15. 7E10 copies them to 7A81–7A89 (column by
  column, bottom to top). The helicopter composite area is cols 10–12, rows 5–15 (7ADC, 7F21). So the
  helicopter's ground cell is world (X+11, Y+14). At the start position this is (324,382), the white
  helipad tile 1F on Base Island (OBSERVED in world_grid.bin).

### 2.2 Island table F230 (14 records × 20 bytes, FF terminator at F348) — CODE 76E5–775D, 8D5D, 8DE2
Each frame, 76D2 clears the window (sea = 0). It then takes the **first** record where:
`rec[0] == 7501`, `rec[1] == 7503`, `rec[2] <= 7500` and `7500-1 < rec[3]` (8-bit), and
`rec[4] <= 7502` and `7502-1 < rec[5]`.

| Byte | Meaning |
|---|---|
| 0, 1 | sector X, sector Y |
| 2, 3 | local X activation range. Always data_x0−22 … data_x1+22 |
| 4, 5 | local Y activation range. Always data_y0−28 … data_y1+28 (Kokola: +29) |
| 6, 7 | data_x0, data_x1. The window is horizontally fully inside the block when data_x0 ≤ X < data_x1 |
| 8, 9 | data_y0, data_y1 (same for Y). For Kokola, data_y0 > data_y1, which is harmless because bits 4 and 5 are tested exclusively |
| 10, 11 | address of the block's top-left cell in the 9300 store |
| 12, 13 | map-screen bitmap address of the silhouette |
| 14 | silhouette samples per pixel row minus 1 (E+1 pixels, one per 4 tiles) |
| 15 | silhouette pixel rows (one per 4 tile rows) |
| 16, 17 | map-screen bitmap address of the island's name |
| 18 | attribute-file high byte for the name (78h is written under each name cell) |
| 19 | unused (0) |

Copy rule (all nine cases of the jump tables 78CF and 7A37 reduce to it, CODE): window cell (r,c) ←
`store[ptr + (7502 − data_y0 + r)*128 + (7500 − data_x0 + c)]` wherever
0 ≤ row < H = rec[5]−rec[8]+1 and 0 ≤ col < W = rec[3]−rec[6]+1. Cells outside the block stay sea.
- Block col 0 is at world x = sector_x*256 + data_x0, and row 0 is at world y = sector_y*256 + data_y0.
- Note: Gilligans' block (col 84, width 45) runs past column 127 into the next store row. Column 128 of
  row r is column 0 of row r+1, which is sea there, so nothing visible changes.
- No two island blocks overlap in world space, and no two activation rectangles overlap. Every block
  stays clear of the sector edges that a window could straddle. A flat 768×768 grid
  (`assets/world/world_grid.bin`) therefore reproduces the game's window **exactly**. OBSERVED: 100 %
  cell match against the real screen, see 6.

| # | Name (map label) | Block addr | W×H | World x,y of block | Sector | Land bbox (world) |
|---|---|---|---|---|---|---|
| 0 | BANANA ISLAND | 9300 | 55×29 | 626,412 | 2,1 | 628–678, 413–429 |
| 1 | ORTE ROCKS | 9D00 | 54×30 | 414,540 | 1,2 | 416–458, 549–563 |
| 2 | KOKOLA ISLAND | A900 | 53×29 | 365,176 | 1,0 | 366–416, 184–201 |
| 3 | LAGOON ISLAND | B600 | 66×29 | 138,212 | 0,0 | 140–201, 215–237 |
| 4 | PEAK ISLAND | C300 | 40×29 | 574,116 | 2,0 | 575–613, 120–140 |
| 5 | BASE ISLAND | CF80 | 81×29 | 306,364 | 1,1 | 307–384, 365–391 |
| 6 | GILLIGANS ISLAND | 9354 | 45×30 | 306,116 | 1,0 | 312–348, 117–138 |
| 7 | RED ISLAND | 9FD8 | 41×29 | 398,604 | 1,2 | 399–433, 612–629 |
| 8 | SKEG ISLAND | ADD8 | 40×29 | 134,540 | 0,2 | 138–171, 541–560 |
| 9 | BONE ISLAND | B843 | 62×29 | 450,152 | 1,0 | 451–509, 160–179 |
| 10 | GIANTS GATEWAY | 9337 | 30×41 | 430,296 | 1,1 | 430–456, 297–335 |
| 11 | CLAW ISLAND | A735 | 36×35 | 474,476 | 1,1 | 475–508, 477–509 |
| 12 | LUKELAND ISLES | C628 | 40×33 | 70,588 | 0,2 | 70–107, 591–618 |
| 13 | ENTERPRISE ISLAND | C64F | 50×48 | 90,460 | 0,1 | 91–137, 461–506 |

### 2.3 Views
`7504` = 0 for the north view and non-zero for the south view. With 7504 ≠ 0 the copy routines 791D–7A34
write the window in reverse (DE decrements, and rows start at F9E8). This is a **180° rotation** using
the same tile IDs (CODE). There is no east or west view. Every sprite frame index gets +8 (mod 16) in the
south view (CODE 8995, 8CA0, 7BCD). OBSERVED: the flight_01360 south-view frame matches after rotating.

### 2.4 Map screen (CODE 8D5D–8E52; OBSERVED byte-exact)
Each record's silhouette starts at block (row 2, col 2). Each pixel row samples E+1 cells, 4 columns
apart (`INC L` ×4, which wraps inside the 256-byte page exactly as in the original). Pixel rows are 4
store rows apart. A pixel is set when tile ≥ 0F. The names come from 6A50: map-font codes, 3F = space,
FD = append " ISLAND" (text at 6AC2, ending FC), FE = next island, FF = end. Two 4-px glyphs share one
cell. The rebuilt bitmap matches play1.z80's map screen in 136/138 bytes; the 2 differing bytes are where
the LUKELAND ISLES label overprints the silhouette. → `assets/world/map_screen_rebuilt.png`.

### 2.5 Run-time map edits
- **Crates** (CODE 5EEC, table 5F61: 38 × [flag, addr]). Five distinct random sites are chosen and their
  tile is replaced: 58→8B, 30→57, 10→2F, 00→0F (lists at 5F59/5F5D). Sites flagged FF are restored on the
  next shuffle. The site list, converted to world coordinates, is in `world.json:crate_sites`.
- **Survivors** (CODE 6072, table 6018: 45 addresses). If the tile is 58/30/10, it becomes 89/55/2D, plus
  1 when a random bit is set (so 8A/56/2E). → `world.json:survivor_sites`.
- **Wave sparkles** (CODE 8B91). Tiles 1–3 (from ROM bytes &3) are written into sea cells of the window on
  a lattice of every 5th column and every ~3rd row. The lattice offset 7535/7536 drifts with the wind
  direction 7506 (table 8C66/8C77). These are visual only, and they never touch the store.
- **Aircraft** (CODE 8930–8982) are written into the window as tiles F6–FE. Each of these has the shadow
  char 33–3B at level 0 and the plane char 3C–44 at level 3.

## 3. Terrain rendering (remake-critical)

### 3.1 Column tables, pages 63xx–73xx (CODE 7E10–7F20)
The char code for tile `t` at stack level `k` is the byte at `(63h+k)*256 + t`. FE = transparent (skip
this level), and FF ends the column. The renderer processes the window top row first. Row 0 writes level
0 only. Rows 1–23 write all levels. Rows 24–28 write only levels ≥ 3, 4, 5, 6, 7 (thresholds: tile ≥ 54,
80, B2, D0, E4). A tile in row y writes level k into row y−k, **overwriting** what is there. This is a
painter's algorithm in which nearer (lower) rows win.

This is equivalent to "stack every column and clip to rows 0–21". `cd.stack()` in
`tools/cyclone_data.py` implements it, and section 6 verifies it.

Ground of height h is drawn as h dark-green "face" cells (87) under one bright top cell (81). That gives
the stepped look. Edge and slope chars (17–2C, 5B–5E) add the black cliff ticks and diagonals.

The column pages overlap other data. The low tile indices of the higher pages hold unrelated tables,
which no tile ever reaches:
- 6600–661B: code
- 661C–6623: score digits
- 6700–6747, 6800–, 6900–, 6A00–: rotor frames
- 6848: bottom-bar text
- 6908+: map font
- 6950: sprite buffer
- 6A50: names
- 7000/7100: rotors
- 7148: attrs
- 7200, 7300: HUD

The full per-tile columns are in `assets/terrain/tiles.json`.

### 3.2 Height classes, 7AC2 (CODE 7B03)
The list is `0F 10 2E 30 56 58 89 8C A5 B2 C2 D0 D9 E4 EC F0 F6 FF`. class = number of entries ≤ tile,
and height = class >> 1. An odd class marks an object standing on that height. 7ADC uses this to compute
the ground height under the helicopter. If the level-0 char is between 17 and 26 the class is forced to 0;
for char 18, bit 7 is also set.

| Tiles | Height | Kind (INFERRED from the graphics) |
|---|---|---|
| 00 | 0 | sea (solid bright cyan) |
| 01–03 | 0 | wave sparkle chars 00–02 (white dots on cyan) |
| 04–0E | 0 | beach (82 = bright yellow) and sea-level rocks and shores (chars 03–06, 10–15) |
| 0F | 0 | crate floating at sea level (char 30) |
| 10–2C | 1 | grass, edges, slopes, sand/track (24,25) and helipad (1F) |
| 2D/2E, 2F | 1 | survivor (chars 31/32), crate (char 56) |
| 30–54 / 55–56 / 57 | 2 | ground / survivor / crate |
| 58–88 / 89–8A / 8B | 3 | ground and houses (82–85) / survivor / crate |
| 8C–A4, A5–B1 | 4 | ground and houses, trees (A6–B1: chars 46–55) |
| B2–C1, C2–CF | 5 | buildings, trees |
| D0–D8, D9–E3 | 6 | tall buildings, trees |
| E4–EB | 7 | tallest buildings (8 levels) |
| F6–FE | – | aircraft cells (run time only) |

### 3.3 Character set FA00 and attributes FE00 (CODE 762C)
- Code c < 80h: the bitmap is FA00+8c (8 bytes, top to bottom). The attribute is FE00+c.
- Code ≥ 80h: **only** the attribute is written, and ink = paper, so it is a solid block. Codes 80–8F:
  80/86 bright cyan (sea), 81 bright green (grass top), 82 bright yellow, 83 bright white, 84 bright red,
  85 bright magenta, 87 green (cliff face), 88 yellow, 89 white, 8A red, 8B magenta, 8C bright blue,
  8D blue, 8E/8F black.
- Run-time chars:
  - 33–3B: aircraft shadow.
  - 3C–44: aircraft. FBE0 is filled by 8995 from DE00.
  - 5F–7F: helicopter composite. FCF8–FDFF = 3 columns × 11 chars (88 bytes per column, at FCF8, FD50
    and FDA8). 7F21 copies the terrain behind it there. The cell codes come from 7F98.
- Static chars 00–32, 45–5E: terrain, trees (45–55), houses (57–5E), crate (30, 56) and survivor
  (31, 32).

The 23×29 code buffer is drawn 8 rows at a time, writing attributes to 5800+ and bitmaps to 4000+.

## 4. Sprites (all 24×24, 72 bytes, column-major unless noted)
Column-major: bytes 0–23 = the left 8 px column, top to bottom; 24–47 = the middle column; 48–71 = the
right column. Frame index n = heading n×22.5° clockwise from north/up. OBSERVED: the HUD compass shows E
when 7507 = 4, and heli frame 4 points right.

| Asset | Address | Frames | Notes (CODE) |
|---|---|---|---|
| Helicopter | E930–EDAF | 16 | 8CA0: frame = E8E8+72*(7507(+8)+1), copied to 6950 |
| Rotor overlay (flight) | 7000, 7100 | 2 | XORed onto 6950. 753A cycles 0–1 |
| Rotor overlay (other state) | 6700, 6800, 6900, 6A00 | 4 | used when 7515 = 1 or 7516 ≠ 0. 753A cycles 0–3 (INFERRED: landed / spin-down) |
| Rotor shift | – | – | for heading frame > 9, 8D02 is patched to `ADD A,A`, so each rotor byte is shifted 1 px left (no carry between bytes) |
| Helicopter shadow | EDB0–F22F | 16 | 9 chars per frame. char j = col*3+k, where k = 0 bottom, 1 middle, 2 top. A first byte of FF means the char is empty. 7BB8 ORs each char into the composite, raised by the terrain height under it (7A95–7A9D). No dither in the data: the checkerboard is pre-drawn |
| Aircraft | DE00–E27F | 16 | index = aircraft record byte 0 (0–63) >> 2. The shadow is derived as byte AND AA (even byte) / 55 (odd byte) (89BC) |
| Explosion | F550–F6B7 | 5 | crash sequence 9246. 24 steps. Each step the 6950 buffer is cleared from 9300. Steps 24–22 also redraw the helicopter. Steps 24–20 XOR frame 0–4 (92ED) |
| Winch load | F51F–F536, F538–F54F | 1 + 1 | 8 px wide, 1 byte per row, rope above the load. Pointer 7557 = F52F (crate) or F548 (survivor). The drawn rows are [ptr − rope_len, ptr + 8) (F4CC) |

There are **no separate masks** anywhere. The helicopter is merged with OR/AND into the composite chars
(86AF–87B8). The aircraft and the shadows are plain chars or ORed. The helicopter's 6950 buffer is shared
with crash/rotor XOR.

## 5. Fonts, HUD and text
- **Main font** 6028 + code×8. Codes 30–39 are digits, 41–5A letters, and 16–2F/3A–40/5B–5F HUD glyphs
  (compass, lives helicopter icons, crate boxes, "VIEW"). Used by 859A, E40F (E42B) and 6F00 (7 rows,
  score). Codes below 16 are unrelated bytes.
- **HUD panel font** 7400 + code×8, codes 00–1F (gauge pieces, "A S F T").
  - Layout 7300: 15 rows × 8 codes for screen cols 24–31, rows 0–14. FF = blank.
  - Attributes 7200: 21 rows × 8. Bottom-row attributes 7148: 64 bytes at 5AC0.
  - Bottom text 6848: 64 codes at 50C0.
  - Strings BEWARE (85B9), AIRCRAFT (85BF), VIEW (85C7) and NORTH (85CC).

  All of these are drawn by 84F4. `hud_static.png` is that routine run in the simulator.
- **Map font** 6908 + code×8 (codes 3F–5A, 4 px wide). Island names are at 6A50. The info screen uses
  the same font: lines at E517–E69B, FE-separated, positions from the 3-byte records (lo, hi, attr-hi)
  at E696+, read through IX = E68C+10 (8E0A patched to step 3).
- **Info screen** E3B4/E43A: "KEY CONTROLS" (E4E0, main font, 4021), "MAP INDICATORS" (E4EC, 4801), the
  key glyphs "1OQPXNM" (E4FA…), fill lists at E504 (count, addr: write FF), and the icon blits via 8EE8
  from 7460, FB80 and FB90.

### Other data in the regions outside this area (described, not ctl'd here)
- **E700–E73F**: aircraft movement table. 16 directions × 4 bytes of opcodes (00 NOP / 03 INC BC /
  0B DEC BC), patched into 8867/8871 to step X and Y.
- **E740–E85A**: aircraft route script. 20-byte records, advanced every 28 frames (8A69, 8A6B).
- **E86C–E8E7**: aircraft state (records of 5 bytes: dir, X16, Y16; FF end).
- **F511–F51E**: tile lists for the winch (F39A):
  - F511 = crate tiles 8B 57 2F 0F
  - F515 = survivor tiles 89 8A 55 56 2D 2E
  - F51B = base tiles 58 30 10
- **F709–F74D, F74E–F9E8**: window buffer. It overlays the init code once that has run.
- **FB98–FC27**: aircraft char copies.
- **FE00–FE8F**: attributes.
- **7A81–7AC1**: helicopter-area work buffers.
- **7AC2**: height boundaries.
- **7F98**: composite cell codes (5F 6A 75 60 6B 76 …: 3 cols × 11 rows).

## 6. Verification (OBSERVED)
`tools/verify_render.py IMAGE [OUT.png]` rebuilds the 23×22 view from the store, the F230 table, the
63xx columns, FA00 and FE00, using 7500–7504 in that image. It then compares every cell with the screen
memory, skipping the helicopter composite and the run-time aircraft chars, and treating sea cells that
show a wave sparkle as matches. Because the capture can land between the screen redraw and the next
position update, it also tries offsets of ±3. Results (`assets/verification/verify_log.txt`, six
in-flight snapshots from a scripted flight):

- 100 % on 5 frames: Base Island at rest, flying east (offset −1,0, the screen lagging by one frame),
  diagonal, north, over sea.
- 96.8 % on the south-view frame. All 15 mismatches are aircraft-shadow tiles, which the rebuild does not
  insert.
- In the earlier scratch runs the only other misses were mid-redraw tearing: the top 8 rows new, the
  lower rows from the previous frame.

## 7. Asset files (re/assets/) and tools (re/tools/)
- `tools/cyclone_data.py`: shared decoders (island table, column tables, stacking renderer,
  column-major sprites, palette).
- `tools/extract_world.py` produces `world/`:
  - `world.json`: geometry, decoded and raw island records, every block's tiles as hex rows,
    crate/survivor sites with world coordinates, start position, window constants
  - `world_grid.bin`: 768×768, row-major
  - `world_overview.png`
  - `world_render_north.png` (+ `.json` crop origin = world (68,108))
  - `islands/NN_name_{north,south}.png`
  - `map_screen_rebuilt.png`
- `tools/extract_terrain.py` produces `terrain/`: `charset.png`, `charset_mono.png`, `charset.json`,
  `tiles.json`, `tiles_sheet.png`.
- `tools/extract_sprites.py` produces `sprites/`:
  - `helicopter.png` and `helicopter_transparent.png`
  - `helicopter_rotor.png`
  - `helicopter_composed.png` (heading × rotor)
  - `helicopter_shadow.png` (red = empty char)
  - `aircraft.png` and `aircraft_shadow.png`
  - `explosion.png`
  - `winch.png`
  - `sprites.json`
- `tools/extract_hud.py` produces `hud/`:
  - `font_main.png`, `font_hud.png` and `font_map.png`, with `fonts.json`
  - `hud_layout.json`
  - `hud_static.png`
  - `screens/map_screen_ingame.png` and `screens/info_screen.png`
- `tools/verify_render.py` produces `verification/flight_*.z80`, `*_compare.png` (actual | rebuilt |
  diff) and `verify_log.txt`.

## 8. Open questions
- No dedicated **cyclone graphic** was found in any data region. The traced reads during flight, the map
  screen and a crash touched none. The cyclone seems to show up only through the wind (7506 → wave drift,
  helicopter drift), the DANGER bar and the map. Someone should confirm with the agent that owns
  7FD6–8A79/8A7A–92FF, for example by flying into the cyclone and tracing.
- Why the two rotor sets exist (7000/7100 versus 6700–6A00), and the exact condition: 7515 = landed?
  7516 = ? (INFERRED).
- What the 17 ≤ char < 27 rule in 7B16 means exactly (it looks like "slope/edge chars count as height
  0", which is what makes them landable).
- Which aircraft record byte drives the frame index (8995 uses (IX+0)/4; the direction table E700 has 16
  entries). This is left to the aircraft code owner.
