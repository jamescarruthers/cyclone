# core3: $8A7A–$92FF

Control file: `re/ctl/core3.ctl` (validated with sna2skool, no errors).
Tags: **CODE** = read from the disassembly, **OBSERVED** = seen in emulation (CSimulator harness, scripted keys,
starting from a snapshot taken at game start: info.z80 → SPACE, 2, 6), **INFERRED** = my interpretation.

Timing reference (OBSERVED): one main-loop iteration (5B3C…5BE3) takes about **5.2 frames** when hovering or sitting
on the base pad and about 5–6.6 frames in flight, so roughly 8–10 iterations per second. All "per iteration" rates below
depend on this, because the game is not locked to the 50 Hz interrupt.

## Routine summary

| Addr | Name | Called from |
|---|---|---|
| 8A7A | Landing / terrain-collision check | main loop 5B54 |
| 8B63 | unused code fragment (IM 1 restore) + 7 zero bytes | — |
| 8B74 | RNG | 5F20, 5FDC/5EEC crate shuffle, 6093, 7386, 7396, 8375, 8BA6, 90B4, 90CB |
| 8B91 | Sea-wave animation in view buffer | 5B45, 925A |
| 8C66/8C77 | wave phase-step tables | 8B91 |
| 8C87 | unused code fragment (old IM2 set-up) | — |
| 8CA0 | Build helicopter sprite + rotor in 6950 | 5B48, 926C |
| 8D0E | Clear view window / map background | 5B03, 5B78 |
| 8D5D | Map: draw island shapes (falls into 8DE2) | 5B7B |
| 8DE2/8DEE | Print names in 4-px font | fall-through; E446 (info screen) |
| 8E5C | Map frame + north arrow | 5B7E |
| 8EE8 | Repeat an 8-byte char C times | 8E5C, E4C2/E4CA/E4D2 |
| 8F12 | Map-mode tick (delay, blinking markers) | 5B69 |
| 8F6A | Draw map markers | 5B81, fall-through from 8F12 |
| 9034 | Map positions, cyclone movement, WIND FORCE/DANGER | 5B89, 8F22, 8F5B, 8F67 |
| 91B4 | Compass dot, S bar, BEWARE AIRCRAFT colours | 5B42, E3E4 |
| 9246 | Death sequence | JP from 5B5F (7505=1) |
| 92C8 | "NO TIME" game over (entry) | JP from 5BD1 |
| 92D0 | message + lose life (entry) | JP from 5BEF ("NO FUEL") |
| 92ED | XOR next explosion overlay | 927B |

---

## 8B74 — RNG (CODE + OBSERVED)

Seed: ROM sysvar SEED at 5C76 (16 bit). Algorithm (multiplication-free Lehmer step):

```
DE = seed
A:H:L = D : E : $FD            ; = 256*seed + 253
A:HL -= seed ; A:HL -= seed    ; = 254*seed + 253   (borrow propagates into A)
HL = HL - A (with borrow)      ; reduce mod 65537 since 65536 ≡ -1
if borrow: HL += 1             ; add 65537 back
seed = HL ; return HL
```
Exactly: `seed' = ((254 * (seed + 1)) mod 65537) - 1` (16-bit). I ran the routine in the simulator for 3,206 seeds
(0–69, 65400–65535, 3,000 random) and it matched this formula every time. The sequence has full period 65,536 (it visits every
16-bit value). This is the ROM RND recurrence with multiplier 254 instead of 75. Returns HL (callers use L or H); A, D, E are corrupted.

## 8A7A — landing / terrain collision (CODE; landing and crash OBSERVED)

Inputs: 7515 landed, 750D altitude (pixels, 0..60), 7514 "tried to go below 0", 751B descent speed (1..3 while
'down' is held, set by 824C; 0 otherwise), 7A81[9] raw terrain codes of the 3×3 footprint (7E10), 7A8B[9] height class
of each (7ADC).

1. If 7515=1 (landed) return.
2. `7534++`. When bit 2 of 7534 is set (4 calls out of every 8): `7533 = min((alt>>3)+1, 7)`. This is the target
   tile level of the helicopter's own tile column. 89CA moves 87EF one step towards it per call (INFERRED from 89CA–89DA).
3. `B = alt>>2`. For each cell i: if `B >= h[i]` the cell is clear (count C). Otherwise:
   * `h[i] < 15` (normal ground or obstacle): if `751B >= 3` (descent at 3 px/iteration) → **crash**; else `751B=0`. The
     cell is not counted.
   * `h[i] >= 15` (very tall, codes ≥ $EC; never executed in 15 min of play): crash if `87EF-1 == alt>>3`, or if
     `87EF==7` and `alt>>3==7`. Otherwise the cell counts as clear.
4. Decision:
   * 7514=0: C=9 → still flying (return). C=0 → touch-down test. C=1..8 → **crash**: only part of the helicopter
     is over higher ground, e.g. flying into a cliff, wall or building.
   * 7514=1: C≠9 → crash; C=9 with 751B=3 → crash; else touch-down test.
5. Touch-down test. For each footprint code L, find the top of its tile stack (`$6300+L, $6400+L, …` up to the first $FF)
   and take the last tile T:
   * T = $80 or $86 → crash. T = $83 or $89 → helipad tile (counted). Other T ≥ $80 → OK.
   * T < $80: T < 3 (sea) or T ≥ $2D → crash; $03..$2C → OK.
   * If all 9 are helipad tiles → `752E = 1` (on the base pad: refuelling allowed, needed to end a round).
   * `7515=1`, `7514=0`, altitude rounded **up** to a multiple of 8 (`((alt+7)>>3)<<3`), altimeter bar raised by the
     difference (82D4 per pixel).
6. Crash = `7505 = 1`.

OBSERVED: holding 'down' from altitude 59 crashed on the pad at alt 7 (751B=3). Tapping 'down' one iteration at a time
(751B=1) landed at alt 7, which was snapped to 8, with 752E=1. Flying east off the pad and descending crashed at alt 23 against a
raised wall (partial footprint).

Landability by raw terrain code (OBSERVED, computed from the play1.z80 tile-stack pages with the rule above; F6–FE are the
helicopter's own dynamic columns):
* helipad (83/89 top): 1E 1F 45 51 75 80 86 87 A2 A3 B2 B3 D0 D1 E8 E9
* crash on touch-down: 00–03 0F 2A–2F 52–57 82–85 88–8B 9D–A1 A4–B1 B4–CF D2–E7 EA–FF
* everything else is landable ground.

Height class table used by 7ADC (core2 range, noted here because 8A7A depends on it): the class is the number of
thresholds at 7AC2 = `0F 10 2E 30 56 58 89 8C A5 B2 C2 D0 D9 E4 EC F0 F6 FF` that are ≤ the code. So code <$0F → 0,
$0F → 1, $10–$2D → 2, …, $EC–$EF → 15. The class is forced to 0 when the base tile ($63xx) is in $17–$26. A helicopter
at altitude a is above a cell of class h when `a>>2 >= h`.

## 8B91 — sea waves (CODE; phase stepping OBSERVED)

The view buffer F74E holds 23×22 terrain codes (row stride 23) from 76D2. 8B91 runs after 76D2 and before 7E10.
* ROM pointer: 7537 counts 0,1,2. Every 3rd call, 7538 = $0100 + (L of RNG), which is a pointer into ROM used as random bytes.
* Phase: if speed 7527 ≠ 0, `(dx,dy) = table[7506]`, where the table is 8C66 for the north view and 8C77 (negated) for the
  south view. `7535 += dx`, reset to 4 if outside 0..8. `7536 += dy`, reset to 3 if outside 0..6. Table 8C66 (north),
  indexed by heading: N(0,+1) NE(−1,+1) E(−1,0) SE(−1,−1) S(0,−1) SW(+1,−1) W(+1,0) NW(+1,+1). OBSERVED heading S:
  7536 went 0→3→2→1→0→3…
* Lattice: base = F705 + 7535 + 23·B, where F705 = F74E − 73. B = 7536 for the north view. For the south view,
  B = 7536+2 if that is <7, else 7536−2. If 7535<4, base += 5. There are 7 rows j and 5 columns i (7535 ∈ {0,1,4,5,6}) or 4
  columns (7535 ∈ {2,3,7,8}). Cell = base + 5i + 95j (95 = 4 rows + 3 columns). A cell is set to `ROM[ptr++] AND 3` only if it holds 0
  (open sea). Codes 0–3 are therefore sea / wave variants.
* The self-modified operands 8C47 (column count 4/5) and 8C5E (row skip $4B/$46) are set on every call.

## 8CA0 — helicopter sprite (CODE + OBSERVED)

* Frame f = 7507 (0..15, 16 headings). For the south view f = (f+8) AND 15. 7507 steps one frame per iteration towards
  7508 (OBSERVED 4→5→6, 3→2→1→0→15…). 7506 is the even 8-way heading.
* 6950..6997 (9 chars, 3×3) = 72 bytes from `E930 + 72·f` (E8E8+72·(f+1)).
* Rotor overlay XORed on: flying → `$7000 + 256·k`, k = 753A cycling 0,1. Landed (7515=1) or fuel empty (7516≠0) →
  `$6700 + 256·k`, k cycling 0..3. OBSERVED: landed 1,2,3,0,… and flying 0,1,…
* The instruction at 8D02 is NOP for frames 0–9 and ADD A,A ($87) for frames 10–15, which shifts the overlay 1 px left.
  OBSERVED 8D02=$87 when 7507 ≥ 10.

## 8D0E — clear view window (CODE)
22 rows × 23 cols: attributes $3F and bitmap 0. Inner rows 1–20 × cols 1–21: attribute $7C (bright white paper, green ink).

## Map screen (M key): 8D0E → 8D5D/8DE2 → 8E5C → 8F6A, then 8F12 each iteration (CODE + OBSERVED screenshot)

Entered when 7526 bit 4 is set (map mode is 7526 bit 1; both are handled by 80AA).

**8D5D island shapes.** Each of the 14 records at F230 (20 bytes, $FF-terminated) gives:
`+0A/+0B` heightmap base, `+0C/+0D` screen bitmap address of the top-left pixel, `+0E` width in pixels, `+0F` rows.
Pixel (px,py) is set iff `mem[base + $102 + 4·px + $200·py] >= $0F`. Packing is MSB-first, 8 px per byte, with the final byte zero-padded.
Only L is incremented (wraps inside the page). **Heightmap format required (for the data agent):** one byte per world unit, 128 bytes per
world row (same as 775E/7789: `base + 128·(y−y0) + (x−x0)`). The map is 1/4 scale, so 1 map pixel = 4×4 world units and the sample point is at offset
(+2,+2). Height ≥ 15 is drawn as land. Several islands share 128-byte rows (e.g. record 6 base = $9354 = record 0 base + $54).

Other F230 fields seen (CODE in 76D2, other agent's range): +0/+1 X/Y high byte, +2..+5 X/Y low-byte presence range,
+6..+9 heightmap extents (x0,x1,y0,y1), +10/+11 name screen address, +12 attribute high byte, +13 = 0.

**8DE2/8DEE name printer.** Text at 6A50 (entry pointer 6A4F, pre-incremented). It is ASCII with '?' as space. $FE = next
record. $FD = insert the suffix at 6AC2 "?ISLAND", which ends with $FC (return, then next record). $FF = end. Glyphs are at `6908 + 8·code`
(left 4 px used). Two characters share a cell: the even one is copied, the odd one is shifted right 4 and ORed in. Cell attribute
is $78. Position = (IX+10/11) + 1 cell, attribute row high byte (IX+12). Record stride is self-modified at 8E0A: 20 for the map
and 3 for the info screen (E43A sets 3 and uses IX=E68C, text E517). Record → name: F230 BANANA, F244 ORTE ROCKS, F258
KOKOLA, F26C LAGOON, F280 PEAK, F294 BASE, F2A8 GILLIGANS, F2BC RED, F2D0 SKEG, F2E4 BONE, F2F8 GIANTS GATEWAY, F30C
CLAW, F320 LUKELAND ISLES, F334 ENTERPRISE. "ISLAND" is appended to all except ORTE ROCKS, GIANTS GATEWAY and LUKELAND ISLES.

**8E5C frame.** It uses 8-byte chars from 7438 (TL), 7440 (top ×21), 7448 (TR), 7460 (left ×20), 7470 (right ×20, col 22), 7480 (BL,
row 21), 7488 (bottom ×21), 7490 (BR). North arrow: main-font codes $4E,$29,$2A (8F0C) at rows 17–19, col 20, attribute $78.
The main font for 859A is at `6028 + 8·code`.

**8EE8.** Copies the char at IX to DE, C times, with DE += HL (HL in cells: 1 = right, $20 = down).

**8F6A markers.** Helicopter at (col 7540,row 7541): saves the attribute (9027) and 8 bitmap bytes (901F), prints code $28 (901D,
an "H"), attribute $7A (red on bright white). Cyclone at (754B,754C): saves 9030/9028, prints code $27 (901E, swirl), attribute $7A.
Addresses go to 7543/7545 (heli attr/bitmap) and 7547/7549 (cyclone).

**8F12 tick.** Delay `40×255` DJNZ ≈ 132,000 T (~1.9 frames). Then `7542++`:
1–3 → 9034 only; 4–6 → restore both cells (a saved $3F attribute is restored as $3A; never seen); 7 → 7542=0,
restore, 9034, redraw markers. OBSERVED: ~5.7 frames per map iteration. Markers are shown for 4 calls and hidden for 3 (~40-frame cycle).
The cyclone keeps moving on the map, but only on 4 of the 7 calls.

## 9034 — map position, cyclone, wind force (CODE + OBSERVED)

* `7540 = X>>5` (X = 7500 word). If X>>5 ≥ 256 (i.e. X ≥ $2000, negative/wrapped) → 0; if 23..255 → 22. Each clamp
  does `754D++`. `7541 = Y>>5` clamped the same way to 0..21. The map is 23×22 cells of 32×32 world units
  (world 0..735 × 0..703). Y increases southwards (OBSERVED: heading S increases 7502). Start position $0139,$0170 →
  cell (9,11) (OBSERVED). The tests against $80 at 9054/9087 are dead code (H ≤ 7).
* Cyclone clock: `754E++`. At 25: `754E=0`, `754F++`. At 9: `754F=0`, new regime = `9178[2·(L AND 15)]` → (mask,
  bits) into the operands 90D0/90D2. Then step: `idx = (H AND mask) OR bits` (H of a fresh RNG), `(dx,dy) = 9198[idx]`.
  Column += dx only if the result is in 1..21. Row += dy only if the result is in 1..20. Otherwise that axis does not move and
  `754F=8, 754E=24`, which forces another step and a new regime on the next call.
* Direction table 9198 (dx,dy): 0 W, 2 NW, 4 N, 6 NE, 8 SW, 10 S, 12 SE, 14 E. Regimes (all equiprobable directions):
  0 W/NW · 1 SW/S · 2 NE/E · 3 SE/E · 4 W/SW · 5 W/NW/N/NE · 6 W/NW/SW/S · 7 N/NE/SE/E · 8 SW/S/SE/E · 9 N/NE ·
  10 W/NW · 11 SW/S · 12 SE/E · 13 W/NW/N/NE · 14 SW/S/SE/E · 15 N/NE. The regime operands persist across games ($0E/$06
  = NE/E in the image).
* Cyclone start (8321, other agent): column 2 or 20 (RNG L bit 0), row 2 or 19 (L bit 1), so one of the 4 corners. Reset table
  keeps 754B/754C on life loss.
* OBSERVED (idle at base): steps every 25 iterations ≈ 129 frames (2.6 s). Regime changes every 9 steps or sooner at edges.
  A sample run went (2,2)→(3,1)→(4,1)→(3,1)→(3,2)→(2,1)→… and later drifted S along column 1–3, then E along row 20.
* `7550 = min(15, max(|Δcol|,|Δrow|))` (Chebyshev). Main loop: if `7550 < (5B93)` (5 in round 1, 6 later; patched by
  8321) → 7378 (wind effects, core2).
* WIND FORCE bar (row 23, cols 16–31, attributes): `16−d` cells $52 (red), then d cells $7F. If 754D≠0, there is one red cell fewer.
  OBSERVED: d=9 → 7 red cells.
* DANGER label (row 22, cols 26–31): $FA (flashing red on white) if d<6, else $38. The routine skips the write if the attribute is unchanged.

## 91B4 — HUD indicators (CODE)
* The compass ring around 593D (row 9, col 29) is cleared to attribute 0. The ring cell for direction `dir = (7527==0 ? 7506 : 753B)` is set to
  $47, using offset word table 9232: N −32, NE −31, E +1, SE +33, S +32, SW +31, W −1, NW −33. (753B = direction of travel,
  OBSERVED to follow 7506 when moving.)
* S bar: col 26, rows 5→1 upwards. `min(7527,5)` cells $52 (red), the rest $7F. 7527 = speed 0..6 (OBSERVED: rises by 1
  per iteration with X held up to 6, and decays by 1 per iteration when released).
* BEWARE AIRCRAFT panel (rows 16–17, cols 24–31): $FA if 7530=3, else $3F.

## 9246 — death sequence (CODE + OBSERVED)

1. 762C render; `9243 = F550`; `750D += 2`.
2. 24 steps n=24..1: 76D2, 8B91, `6950 ← 72 zero bytes from 9300` (9300 is the zero border of the first heightmap),
   n≥22: 8CA0 (normal sprite), n=18: `752D++` (explosion sound flag for the interrupt handler), n≥20: 92ED (XOR overlay
   F550+72k, k=0..4, i.e. F550–F6B7), then 7E10, 86AF, 762C. OBSERVED: 24 steps = 132 frames. Steps 24–22 show the debris
   over the helicopter and 21–20 the debris alone; after that the sprite is blank.
3. Mark the life: attributes `5958 + 64·(9245)` and the next one = $02 (the helicopter icon at row 10/12/14 turns red).
   `9245++`; 3 → JP E280 (menu). OBSERVED: the first icon turned red.
4. Call 82A7 until 7516=1 (the fuel gauge is emptied; instantaneous). Then copy 75C8→7500 for 100 bytes, skipping $FF bytes, and
   JP 5B36. OBSERVED: restart on the base pad at $0139/$0170, alt 8, 7505=0, 6 frames after the sequence.
* 92C8 (751C reaches $DE → time bar exhausted, INFERRED): `9245=2` so the following increment ends the game. Message
  " NO TIME " (8A6E).
* 92D0 (from 5BEC: landed, 7516=1 fuel empty, 752E=0 off-pad): message " NO FUEL " (5BF2). It costs **one** life only.
  The 9 chars go to row 3 col 7, attribute $47, followed by BEEPER(DE=$0300, HL=$0466). Then step 3. (Not executed in the exec map.)
* 9245 is reset to 0 by 8321 at every round start (so lives are per round; 8394 also uses it for the round bonus).

## Variables touched (meaning as inferred here, for cross-check with core1)

| Addr | Init (7564 blk) | Reset (75C8) | Meaning |
|---|---|---|---|
| 7500/01 | $0139 | $0139 | helicopter world X (units; map cell = X/32) |
| 7502/03 | $0170 | $0170 | helicopter world Y (south = +) |
| 7504 | 0 | 0 | view: 0 = north, 1 = south (N key toggles; OBSERVED) |
| 7505 | 0 | 0 | 1 = helicopter destroyed (set by 8A7A) |
| 7506 | 4 | 4 | heading 0,2..14 (0=N clockwise; 4=E) |
| 7507 | 4 | 4 | displayed sprite frame 0..15 |
| 7508 | 4 | 4 | target sprite frame 0..15 |
| 750D | 8 | 8 | altitude in pixels (0..60; landed on base = 8) |
| 7514 | 0 | 0 | 1 = descended to/below altitude 0 |
| 7515 | 1 | 1 | 1 = landed |
| 7516 | 0 | 0 | 1 = fuel gauge empty |
| 7517 | 0 | 0 | fuel tick counter (82A7, 49 calls/pixel) |
| 751B | 0 | 0 | descent speed 0..3 (3 = hard landing) |
| 751C/1D | — | kept | time-bar pointer; $DE low byte = time out |
| 752D | | | explosion/sound trigger counter (incremented at step 18) |
| 752E | 1 | 1 | 1 = landed on helipad (all 9 tiles $83/$89) |
| 7527 | 0 | 0 | speed 0..6 |
| 7530 | | | aircraft warning state (3 = flash) |
| 7533 | 3 | 3 | target helicopter tile level 0..7 |
| 7534 | | | 8A7A call counter |
| 7535/7536 | 0 | 0 | wave lattice phase (col 0..8, row 0..6) |
| 7537 | | | 0..2 counter for the wave ROM pointer |
| 7538/39 | | | ROM pointer $01xx for random wave bytes |
| 753A | | | rotor frame (0..1 flying, 0..3 landed) |
| 753B | 4 | 4 | direction of travel (compass while moving) |
| 753C/753E | | | map draw: row start / write pointer |
| 7540/7541 | | kept | helicopter map col/row |
| 7542 | | kept | map blink counter 0..7 |
| 7543/45/47/49 | | kept | marker attr/bitmap addresses |
| 754B/754C | 2,2 | kept | cyclone map col (1..21) / row (1..20) |
| 754D | | 0 | helicopter off-map axis count |
| 754E/754F | | kept | cyclone step timer (0..24) / steps in regime (0..8) |
| 7550 | | 0 | distance to cyclone 0..15 |
| 7552/53 | | | current island record pointer (F294 = Base) |
| 7554 | | kept | crates collected (5 = round complete) |
| 87EF | | | current helicopter tile level (follows 7533) |
| 8C47, 8C5E, 8D02, 8E0A, 90D0, 90D2 | | | self-modified operands (see ctl) |
| 9243/44 | | | explosion overlay pointer |
| 9245 | | | lives lost in this round (0..3) |

Data addresses read here: 6300–6Exx tile-stack pages (top tile per code); 6700/6800/6900/6A00 and 7000/7100 rotor
overlays (72 B each); 6908 4-px font (codes $3F–$5A used); 6028 main font; 6950 sprite buffer (9 chars);
6A50–6AC9 map name text; 7438–7497 map frame chars; 7A81/7A8B footprint codes/heights; E930 helicopter frames
(16×72 B); F230 island table; F550 explosion overlays (5×72 B); F705/F74E view buffer; 9300 (72 zero bytes).

## External routines called (one-line guesses)
* 82D4: raise the altimeter (A) bar by one pixel (moves pointer 751E, writes $FF).
* 82A7: fuel tick. Every 49 calls it clears one pixel row of the F bar (pointer 7518). Sets 7516=1 when the bar is exhausted ($48BC).
* 859A: print C characters from HL at screen DE using the 8×8 font at 6028.
* 762C: render the view buffer F74E to the screen (tile bitmaps FA00+8·code, attributes FE00+code).
* 76D2: clear the view buffer and fill it from the current island's heightmap (island lookup in F230 → 7552).
* 7E10: copy footprint codes to 7A81 and expand terrain codes into iso tile stacks (pages 63xx+).
* 86AF: draw the helicopter sprite 6950 and its shadow into the view at the altitude offset.
* E280: main menu.

## Open questions
* Height class ≥15 collision branch (8B36–8B4C) never executed. Its exact meaning with 87EF is unclear.
* Which tiles $80/$86 are (crash on touch-down) and $83/$89 (pad). This needs the tile graphics from the data agent.
* 8F2F ($3F→$3A attribute substitution) is never executed. It would only apply on the frame border.
* Main-loop rate varies with screen content, so the real-time cyclone speed and wave rate vary slightly.
