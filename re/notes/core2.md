# core2: $7FD6–$8A79

Control file: `re/ctl/core2.ctl` (validated: `sna2skool.py -c ctl/core2.ctl -s 0x7FD6 -e 0x8A7A snapshots/init.z80` runs with no errors).

Tags: **CODE** = read from the disassembly. **OBSERVED** = seen in emulation. I used a breakpoint harness on skoolkit's
Simulator with scripted keys, starting from a game-start snapshot (info.z80 → SPACE, 2, 6). Pokes are noted where
I used them, e.g. `5B93=0` switches the cyclone wind off. **INFERRED** = my interpretation.

Timing reference (OBSERVED): one main-loop iteration (5B3C → 5BE3) takes about 5.5 frames when hovering or sitting on the
pad. It takes about 4.3 frames when flying low over the sea at full speed. All "per iteration" numbers below are per
main-loop iteration, not per 50 Hz frame. The only per-frame code in this range is the interrupt handler 83C2.

Units: X and Y are 16-bit map coordinates. +X is east and +Y is south: in the north view +Y runs down the screen
(OBSERVED: an aircraft with direction code $20, which steps Y by +2, moves down the screen). Altitude 750D is in pixels,
0..60.

## Routine summary

| Addr | Name | Called from |
|---|---|---|
| 7FD6 | Read controls → 7522 (keyboard; 8023 IF2, 8052 Kempston, 8079 Protek) | main loop 5B8C |
| 80A6 | 4 unused bytes | — |
| 80AA | M (map) / N (view) keys, then falls into 8135 | 5BAC |
| 80F9 | Set view NORTH (8104 = SOUTH) + patch renderer pages, then falls into 8135 | 5B36 (life start), from 80AA |
| 8135 | Flight controls: turn, thrust/coast/move, climb, descend | fall-through |
| 826F | Movement opcode table (16 bytes) | 81DC |
| 827F | "SOUTH" | 810B |
| 8284 | Time bar countdown | 5BD7 |
| 82A7 | Burn fuel | 8475 (JP), 92A9 |
| 82D4 / 82FB | Altimeter bar up / down one pixel | 8228, 8B16 / 8260 |
| 8321 | Round start: crate boxes, round bonus, difficulty | 5B26 |
| 83C2 | Interrupt handler (rotor/winch sound, crash noise) | IM2 → F3F3 JP 83C2 |
| 843A | Refill time bar, 40 pts per remaining line | 5B29 |
| 8470 | Refuel on base pad / else burn fuel | 5BD4 |
| 84AE | Init altimeter bar (alt=8) | 5B39 |
| 84D6 | Clear screen (attr 7) | 5B00, E293, E3B4 |
| 84F4 | Draw HUD | 5B06, 83BA, E3C5 |
| 8580/8582/8585 | VIEW box: set attrs + print 5-char text | 84F4 fall-through, 80FD, 80E6, 810E |
| 859A | Print string, main font 6028 | many (HUD, map 8EC1.., menu E451..) |
| 85B9–85D0 | "BEWARE", "AIRCRAFT", VIEW glyph codes, "NORTH" | 84F4/8582 |
| 85D4 | Foreground slope tiles cover the helicopter | 5B57 |
| 86AF | Draw helicopter sprite into its view window | 5B4E, 9281 |
| 87BC | Update and print high score | 5B09, E3EA |
| 87EF | Aircraft height level (variable) | 87F0/89CA, 8B36 |
| 87F0 | Aircraft: schedule, movement, warning, placement in view | 5B3F |
| 8A69–8A79 | Aircraft schedule pointer/counter, " NO TIME " text, padding | 87F0, 92CD |

Unused/padding: 80A6–80A9, 82D1–82D3, 8320, 83BE–83C1 (00 00 44 00), 8435–8439, 84F2–84F3, 85D1–85D3, 86AC–86AE,
87B9–87BB (bytes 22 09 75 = a leftover `LD ($7509),HL`, never reached), 87ED–87EE, 8A6C–8A6D, 8A77–8A79 (09 1A 6F).
No references to any of these were found (searched the whole image for the 16-bit address).

Changes from base.ctl: base.ctl's split was already right (87EF is data, 87F0 is code). I added blocks for the text
and unused areas. I also made 8135 a separate routine for the fall-through flight-control part, and merged
8580/8582/8585 into one routine with three documented entry points.

---

## 7FD6: read controls (CODE, OBSERVED for keyboard)

Output 7522: bit0 forward/thrust, bit1 descend, bit2 climb, bit3 turn right (clockwise), bit4 turn left.
7FD5 = menu key − '2' (E2B8): 0 keyboard, 1 Interface 2, 2 Kempston, 3 Protek/AGF.

* Keyboard: **any** key on a half-row counts. SHIFT/Z/X/C/V = forward. 1–5 = climb. Q–T = descend. Row DF: P (bit0) =
  right, O (bit1) = left. This matches the documented X / 1 / Q / P / O.
* Interface 2: keys 0,9,8,7,6 map straight onto bits 0..4 (fire, up→descend, down→climb, right, left). Keys 5,4,3,2,1
  (port 1) give the same functions.
* Kempston (port $1F, active high): fire→fwd, up→descend, down→climb, right, left. Pushing the stick forward makes the
  helicopter descend.
* Protek: 5 left, 6 climb, 7 descend, 8 right, 0 fwd.

The cyclone routine 7378 (called when 7550 < (5B93)) ORs random bits into 7522 afterwards. When 7550 ≥ 4 it uses mask
$1A, when 7550 ≥ 2 it uses $1B, and closer than that it forces 7522=$12 (descend+left). This is the wind buffeting,
OBSERVED as `in=1B` with only X held. 7378 belongs to another agent.

## 80AA / 80F9 / 8104: M and N keys, view direction (CODE + OBSERVED)

The routine reads half-row $7FFE once per iteration, so a press shorter than about 5 frames can be missed (OBSERVED: a
4-frame N press was ignored). It uses the latch bits in 7526. Both keys are edge-triggered.

* **M**: beep `BEEPER HL=$0361, DE=30` (≈489 Hz, 61 ms). It then toggles 7526 bit1, the map mode. Entering the map
  sets bit4: the main loop at 5B6F then clears bit4 and draws the map (8D0E, 8D5D, 8E5C, 8F6A). Leaving the map sets
  bit3, which nothing reads or clears. In map mode the main loop calls 8F12 instead of 762C/9034, but the flight keeps
  going (OBSERVED: the map screen with island names; 7526 = $13 → $03 → $02, then $09 → $08 on leaving).
* **N**: the VIEW box attributes are set to $7F (blank) while it beeps `HL=$0300, DE=40` (≈548 Hz, 73 ms). 7504 then
  toggles:
  * → north (80F9): 7504=0, "NORTH" with attr $38 (black on white), page base $63.
  * → south (8104): 7504=1, "SOUTH" (827F) with attr $78 (bright), page base $6C.
  * The base is patched into the renderer immediate operands 7B18, 7E35, 7E41 (= base), 7E6D (+3), 7E93 (+4),
    7EB9 (+5), 7EDF (+6) and 7F05 (+7). OBSERVED: 7B18 63→6C, 7E6D 66→6F, 7F05 6A→73.
  * Meaning (INFERRED, consistent with 87F0 and 8ACA): page base+L holds, for every tile code, the tile drawn at
    height level L. $FE means "nothing at this level, continue". $FF ends the stack. The south set holds the stacks as
    seen from the other side.
* There are only **two** view directions, N and S. 7504 also mirrors aircraft placement (8903) and swaps sprite
  directions (+8 mod 16).
* 5B36 calls 80F9 directly at the start of every life, which forces the NORTH view and also runs the flight-control
  code once.

## 8135: flight controls (CODE + OBSERVED)

**Turning.** Heading 7506 is 0–15 and always even (0 N, 2 NE, 4 E, …, 14 NW). Each turn moves it 2 steps (45°).
* On a turn key, with the turn timer 7521 = 0 and the helicopter not landed:
  * 7507 (sprite heading) = h∓1, 7508 (target) = h∓2 (mod 16), 7521 = 3.
  * The timer then counts down once per iteration. On the step from 2 to 1, 7506 = 7507 = 7508 = target.
  * So the in-between sprite shows for 2 iterations, and the next turn can start 4 iterations after the previous
    one: 45° per 4 iterations, a full circle in 32 iterations (≈3.5 s).
* Left and right together cancel the turn.
* OBSERVED: hd 4/3/2 → 4/3/2 → 2/2/2 → 2/2/2 → 2/1/0 …

**Thrust and movement.** Speed 7527 runs from 0 to 7.
* While forward is held (and fuel remains): speed = min(speed+1, 7) and direction 753B = heading.
* Otherwise speed = max(speed−1, 0).
* While the (post-update) speed is above 0, the helicopter moves **exactly 1 unit on each axis the direction uses,
  per iteration, whatever the speed** (OBSERVED: X goes up by 1 per iteration at speeds 1..7). Diagonals are
  therefore √2 faster.
* Releasing thrust at speed 7 gives 6 more iterations of coasting in the latched direction, even if you turn in the
  meantime (OBSERVED).
* So speed matters only for coasting, the rotor pitch (83C2), the speedometer (91B4) and the compass dot (91CE).
* The movement uses self-modifying code. The direction d indexes table 826F: byte d is patched into 81EF (X op) and
  byte d+1 into 81F6 (Y op), with $00 NOP, $23 INC HL, $2B DEC HL. The even entries give:

  | d | 0 N | 2 NE | 4 E | 6 SE | 8 S | 10 SW | 12 W | 14 NW |
  |---|---|---|---|---|---|---|---|---|
  | (dx,dy) | 0,−1 | +1,−1 | +1,0 | +1,+1 | 0,+1 | −1,+1 | −1,0 | −1,−1 |

  The odd entries are overlapping garbage and are never used. For d=15 the Y "opcode" would be the 'S' of "SOUTH"
  (LD D,E), which does no harm.
* When landed (7515=1), turning and movement are skipped.

**Climb.** Climb key, with fuel:
* If landed, the press is the **take-off**: 7515=0, 752E=0, RET. That iteration nothing else happens; the climb
  starts on the next one.
* Otherwise rate 751A = min(rate+1, 3), and altitude += rate one pixel at a time (each pixel calls 82D4), capped at
  **60**.
* Releasing the key resets the rate to 0.
* OBSERVED: alt 8→9→11→14→17→…, capped at 60.

**Descent.** The descend key, or an empty tank, while not landed:
* Rate 751B = min(rate+1, 3), and altitude −= rate one pixel at a time (82FB).
* Going below 0 instead sets 7514=1 and the descent stops. 8A7A (core3) then turns 7514 into a landing or a crash
  (crash over the sea: OBSERVED).
* An empty tank (7516=1) forces descent at 1, 2, 3, 3, … px per iteration, and also disables thrust and climbing
  (OBSERVED: from alt 60 to 0 in about 22 iterations, then a crash at sea).
* The landing code (8AB7, 8B4E) treats a descent rate of 3 as a hard landing.

## 8284: time-left bar "T" (CODE + OBSERVED)

* The T bar is column 30, rows 1–5 (40 pixel lines). Pointer 751C = the last erased line (the line above the top lit
  line); $471E = full.
* 7528 increments once per iteration. When it reaches (828C) it is reset and one line is erased (top first). So there
  is one line per (828C) iterations: 255 in round 1, then 240, 225, … (−15 per completed round, 83AD).
* After the 40th line, the 41st tick moves the pointer to $40DE and erases one byte of the compass graphic at row 6,
  col 30. The main loop (5BCC) sees L=$DE and jumps to 92C8, which prints " NO TIME " (8A6E), sets lives-lost to 2
  and loses a life, so out of time = game over.
* Total time for round 1 = 41 × 255 = 10,455 iterations ≈ 57,000 frames ≈ **19 minutes** at about 5.5
  frames/iteration. INFERRED from the rate; I did not run the full countdown.
* 7528 is reset on respawn (75C8 template) but 751C is kept, so the time keeps running across lives.

## 82A7 / 8470: fuel "F" bar (CODE + OBSERVED)

* The F bar is column 28, rows 1–5 (40 lines). Pointer 7518 = the last erased line: $471C full, $47BC empty.
* **Burn** (752E=0, i.e. anywhere except on the base helipad, including when landed elsewhere and while hovering):
  * 7517 counts 0..48. On the 49th iteration it resets and one line is erased.
  * The tick after the last line sets **7516=1 (tank empty)**.
  * A full tank lasts 41 × 49 = 2,009 iterations ≈ 3 min (OBSERVED rate: one line per 49 iterations).
* **Refuel** (752E=1, landed on the 9 helipad tiles at base):
  * One line per iteration, with a beep (HL=$D0 ≈1.84 kHz, DE=16 ≈9 ms), until the pointer reaches row 0.
  * Each refuel step also clears 7516.
  * From empty this takes 40 iterations ≈ 4 s (OBSERVED: 47BC → 46BC → … → 471C).
* New game and every respawn restore 7518=$47BC (empty) and 752E=1 (on the pad): each life starts on the base pad
  with an empty tank that refuels automatically. During the death sequence, 92A9 calls 82A7 repeatedly to drain the
  bar visually.
* Landed away from base with an empty tank (7515=1, 7516=1, 752E=0): the main loop (5B97) jumps to 5BEC → 92D0
  " NO FUEL " and the life is lost.

## 82D4 / 82FB / 84AE: altimeter "A" bar (CODE + OBSERVED)

* The A bar is column 24. 84AE clears rows 1–7, lights all of row 8, and sets alt = 8, 751E = $4818 (the top lit
  line).
* Each altitude pixel above 8 lights one more line upwards (82D4). Altitude 60 reaches row 1, pixel line 4.
* 82FB clears the top line and moves down.
* Quirk (CODE): 8307 compares with $4F instead of $50. Below altitude 2 the pointer therefore skips row 8 line 7 and
  jumps to row 9. Row 8 line 7 then stays lit at altitude 0–1, and climbing back from 0 can draw a stray line at
  $4838.
* 8B16 (landing) calls 82D4 to follow the altitude being rounded up to a multiple of 8.

## 8321: round start (CODE + OBSERVED)

* The five crate boxes (rows 22–23, cols 0–9, 2×2 cells each, glyphs # $ % & from 6848) are blanked (attr 0). They
  are then lit one by one (attr 6, yellow). Each box gets a beep (HL=$3E8 ≈425 Hz, DE=44 ≈104 ms) and a delay of
  200×255 DJNZ (≈666,000 T ≈ 0.19 s), so about 1.5 s in total.
* **New game** (7554 ≠ 5):
  * 5B93 = 5: the wind (7378) acts while the cyclone distance 7550 < 5.
  * 828C = 255.
  * Random cyclone start corner from RNG 8B74: 754B = 2 or 20 (L bit0), 754C = 2 or 19 (L bit1).
* **Round complete** (7554 = 5; the main loop gets here when 7554=5, 752E=1 and 7552 = $F294, the base island
  record):
  * 7554 = 0.
  * **Round bonus**: B = 250 − 64×lives_lost (mod 256), then 6602 is called twice. The first call adds B. The second
    adds whatever B the score printer 6F00 leaves, which is always $66 = 102 (BC ends at 661C). So the bonus is
    **352 / 288 / 224 points** for 0 / 1 / 2 lives lost. OBSERVED: B1=250, B2=102, score "......0" → "....352".
  * 5B93 = 6 (fixed for every later round).
  * 828C −= 15.
* Both paths then set 9245 = 0 (lives lost; all three helicopters come back each round) and redraw the HUD (84F4).
* Then 843A (from the main loop) gives the **time bonus: 40 points per still-lit line of the T bar** (max 40 lines =
  1600). OBSERVED: with 24 lines left, the score went from 352 to 1312 (+960).
* A completed round does **not** reload 7500–7563, so the helicopter stays on the pad. The time bar is refilled.

## 83C2: interrupt handler (CODE; timings computed)

* Entered 50×/s (I=$FF, the table FF00–FFFF is all $F3, so the vector is F3F3, which holds JP 83C2). It saves AF,
  IX, BC, DE and HL, ends with EI and RET, and its DI covers the beeps.
* 752D=1 → silent. 752D is set by the menu (E282) and incremented during the death sequence (9275).
* 7505=1 (destroyed) → JP 5FDC. This is the explosion noise: random-length speaker pulses from RNG bits (H and L high
  nibbles) for 3 bursts, skipped when L < $46. It returns via JP 842D.
* Landed (7515) or empty tank (7516) → no rotor sound.
* 7555 ≠ 0 (winch in use, set by F39A–F4B4) → `BEEPER HL=$32, DE=8` (≈5.5 kHz, 1.5 ms) before the chop.
* **Rotor chop**: phase 755D cycles 0..3.
  * On the 0→1 interrupt: a "high" burst of C=10 cycles, half-periods E=D=18.
  * On the other three interrupts: a "low" burst of C=6 cycles, half-periods 36.
  * Both half-periods are reduced by 2×speed (7527).
  * One cycle takes 47 + 13·(D+E) T-states. At speed 0: high = 515 T (≈6.9 kHz, 10 cycles = 1.45 ms), low = 983 T
    (≈3.6 kHz, 6 cycles = 1.66 ms). At speed 7: high D=E=4 → 151 T (≈23 kHz), low D=E=22 → 619 T (≈5.7 kHz).
  * The pattern is H L L L, repeating at 12.5 Hz. The bursts are output on bit 4 of port $FE with the border black.

## 84D6 / 84F4 / 8580 / 859A: screen and HUD (CODE + OBSERVED)

* 84D6: bitmap 0, attributes $07.
* 84F4, panel columns 24–31:
  * Attributes from 7200 (21 rows × 8). Bar cells are $7A (bright, white paper, red ink) in cols 24/26/28/30, rows
    1–5, and col 24 also in rows 6–8.
  * The compass occupies rows 8–10, cols 28–30, with its centre at row 9 col 29 ($42).
  * VIEW box: rows 13–14, cols 27–31, attr $38. BEWARE AIRCRAFT: rows 16–17, attr $3F (white on white, invisible).
    S/H score lines: rows 19–20, attr $38.
  * Graphics: tile map 7300 (15×8 codes, $FF = blank, tile n at 7400+8n). Tiles $17–$1A are the A S F T letters on
    row 0, $1B is the bar scale in cols 25/27/29/31, $02–$16 the compass rose (rows 7–11), and $00 $01 the three
    lives icons at rows 10, 12 and 14 (cols 24–25).
  * Bottom rows 22–23 come from 6848 with attributes from 7148:
    * Crate boxes: cols 0–9, attr 6.
    * "WIND" / "FORCE": attr 7.
    * Wind scale ticks `"`: row 22, cols 16–25, attr 5.
    * "DANGER": attr $38.
    * Wind bar: row 23, cols 16–31, attr $7A.
  * Then "BEWARE" (5019), "AIRCRAFT" (5038), the VIEW glyphs $3C–$40 at row 13 col 27, and NORTH (8580).
* 859A: C characters from HL at DE. Glyph = 6028 + 8·code, 8 lines, one cell to the right per character.
* The score is printed by 6F00 (other range) right-to-left at row 19, ending at col 31, from 6624 down to the $FF at
  661C. "S" is the score, "H" the high score (87BC prints from 662D at 509F, row 20).

## 87BC: high score (CODE)

* The score (661E, 7 chars) is compared with the high score (6627) as ASCII strings. Leading '.' ($2E) sorts below '0'.
* If the score is greater, it is copied to the high score. The high score is then printed at row 20.
* Called at the start of each game (5B09, before 5B0C clears the score to "......0") and from E3EA. So the high score
  updates when the next game starts, or when E3EA runs.

## 86AF: draw the helicopter (CODE + OBSERVED values, INFERRED purpose of the modes)

* The helicopter window is view-buffer tiles $5F–$7F (built by 7F21, another agent): 3 screen columns × 11 cells.
  * Bitmaps at FCF8 (tile $5F + 11·col + cell, 8 bytes each, so each column is 88 contiguous pixel lines).
  * Attributes at FE5F.
  * View-buffer cells F7CB + 23·cell + col hold these codes (OBSERVED: F86C.. = $66, $71, $7C).
* The sprite 6950 (24×24, column-major, built by 8CA0) is drawn with its top line at line 62 − altitude of each
  column. Altitude 8 → lines 54–77. Altitude 60 → lines 2–25. One pixel of altitude is one pixel up on screen.
* The sprite is drawn in cell-sized pieces:
  * Empty piece: the cell is left alone.
  * Background code (table at 7AA2+C, stepping down; from the renderer) below $1B (sea and other low tiles) and the
    cell's ink ≠ 0: **solid** copy. The rest of the cell is cleared, so e.g. white wave dots do not turn black.
  * Otherwise **OR** draw, with each sprite byte also cleared from the next pixel line (`buf[i] |= s[i];
    buf[i+1] &= ~s[i]`). This gives a 1-pixel dark cut under the sprite.
  * After drawing, the cell's ink is set to 0 (black).

## 85D4: foreground slopes in front of the helicopter (CODE; purpose INFERRED)

* For view-buffer cells F86C + 23i + j (i = 0..3 → window cells 7–10, j = 0..2): if the cell holds a slope tile
  $19–$1C and the window cell's ink is 0 (the helicopter was drawn there), the window cell is changed:
  * bitmap = (bitmap AND mask) OR edge, where mask = tile $23 (codes $19, $1B) or tile $25 ($1A, $1C), and edge =
    tile $17 (blank) for $19/$1A, $1B for $1B, $1C for $1C;
  * the attribute becomes $60 (bright green paper);
  * if anything remains, the view cell's code is replaced by the window tile code ($5F+11j+7+i).
* Effect: a hillside slope that lies in front of the helicopter in the isometric view cuts a triangular piece out of
  it.
* Codes $3C–$44 (aircraft tiles) are ORed into the window instead (8689–86AA). Never executed in the emulation runs
  or in exec_map.

## 87F0: aircraft (CODE + OBSERVED)

**Live table E86C**: 19 records of 5 bytes (direction code d, X word, Y word), ended by $FF at E8CB.
* Start positions are at E8CC+5n: the copy table, whose first byte is unused; positions are copied from E8CD+5n.
* Direction codes are multiples of 4; d/4 is the direction 0..15 (N, NNE, NE, ENE, E, … clockwise).
* E700+d holds 4 opcodes ($00 NOP, $03 INC BC, $0B DEC BC), two for X and two for Y. They are patched into 8867/8868
  and 8871/8872.

| d/4 | 0 N | 1 | 2 NE | 3 | 4 E | 5 | 6 SE | 7 | 8 S | 9 | 10 SW | 11 | 12 W | 13 | 14 NW | 15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dx,dy | 0,−2 | +1,−2 | +2,−2 | +2,−1 | +2,0 | +2,+1 | +2,+2 | +1,+2 | 0,+2 | −1,+2 | −2,+2 | −2,+1 | −2,0 | −2,−1 | −2,−2 | −1,−2 |

Aircraft move **2 units per iteration** on their main axis, twice the helicopter's speed (OBSERVED: Y += 2 per
iteration).

**Schedule.** 8A6B counts iterations 0..27. Every 28th iteration, 8A69 += 20, wrapping to E740 after E858: 15
records, used in the order E754, E768, …, E858, E740, so a full cycle is 420 iterations.
* Each record has one byte per aircraft (19) and a final $FF.
* A byte sets that aircraft's direction. With bit 7 set it also **respawns** the aircraft at its start position.

Decoded schedule (* = respawn):

| # | start X,Y | schedule (E754…E858, E740) |
|---|---|---|
| 0 | 196,−68 | SSE S S S *S S S S S S S SSW S S S |
| 1 | 516,−68 | S S S S S S S S *S S S S S S S |
| 2 | 796,388 | W *WSW SW WSW SW SW WSW W W WSW W WNW NW NW WNW |
| 3 | 796,380 | (same as 2) |
| 4–6 | 36,768/752/736 | NE NNE NE NE NE ENE NE NNE NE NE NE NNE N N *NE (a formation of 3) |
| 7, 8 | 332/320,−68 | *S S SSE S SSW S SSW SW SSW S SSE S S S S (pair) |
| 9 | 670,772 | *N N N N N N N N N N N NNE NNE N N |
| 10 | 52,772 | N *N N … N |
| 11 | −52,248 | *E E … E |
| 12 | −52,437 | E×9 ENE NE ENE E E *E |
| 13 | 352,772 | NE NE NE ENE NE NE ENE E E E *N N N N NNE |
| 14 | −52,172 | E E ENE E E ENE ENE ENE E ENE E E E *E E |
| 15 | 696,772 | N NNW NNW NW NNW N N N N *N N N N N N |
| 16 | 788,540 | WNW W WSW W W WNW W W W W *W W W W W |
| 17 | 812,492 | W W W WNW NW NW NW NW NW NW NW WNW WNW W *W |
| 18 | 572,772 | N N NNW NW NNW N NNW N N N N *N N N N |

INFERRED: the aircraft enter from the map edges (Y −68 or 772, X −52 or ~800), cross the archipelago and are
recycled. 8A69 is not in the 7500 block, so the schedule phase carries over between lives and games.

**Warning.** For each aircraft: dx = aX − hX and dy = aY − hY (16-bit).
* |dx| ≤ 22 sets 7530 bit0. If also |dy| ≤ 25, bit1 is set.
* 91B4 shows BEWARE AIRCRAFT (attr $FA, flashing red on white) when 7530 = 3, and attr $3F (invisible) otherwise.
  OBSERVED.

**Visibility and placement.** If |dx| ≤ 12 and |dy| ≤ 15:
* 7524 = dx+12 (0..24) and 7525 = dy+15 (0..30). The south view mirrors them: 24−x and 30−y.
* Codes $F6–$FE are written as a 3×3 block at F71E + 7524 + 23·7525. Columns are F6/F7/F8, F9/FA/FB and FC/FD/FE
  (top to bottom).
  * Column c is written only if 7524+c is in 2..24.
  * When 7525 = 30, only the top row is written.
* **Only the first** such aircraft in a frame gets its graphics built (752F):
  * Sprite n = d/4 (south view: (n+8) mod 16), copied from DDB8 + 72·(n+1) (72 bytes, 3×3 tiles, column-major) to
    tiles $3C–$44 (FBE0).
  * A checkerboard-dithered copy (AND $AA/$55) goes to tiles $33–$3B (FB98): the **shadow**.
  * Later aircraft in the window still get the $F6–$FE codes, so they would show the first one's sprite and level
    (INFERRED).
* **Height**:
  * The tile stacks of codes $F6–$FE are page $63 = shadow tiles $33–$3B (ground), then pages $64.. = $FE (empty) up
    to the aircraft level L = 87EF, where tiles $3C–$44 sit, followed by $FF.
  * Both the north ($64–$6B) and south ($6D–$74) sets are rewritten.
  * Each level is one tile row higher on screen (renderer stride −23 per level).
  * **87EF moves one level per drawn frame towards 7533**, the helicopter's level (min(alt/8+1, 7), computed in
    8A7A). So **aircraft always home in on the helicopter's altitude band** (OBSERVED: 87EF 1→2→3→4 while
    7533=4).
  * At L=2 the shadow's row 0 is ORed into the aircraft's row 2; at L=1 shadow rows 0–1 are ORed into aircraft rows
    1–2, so the shadow shows through where they overlap.
* **Collision** (OBSERVED; code in 8A7A, core3): the $F6–$FE cells have height class $11 (≥15) in 7A8B. 8B36 then
  crashes the helicopter when 87EF−1 = alt>>3, i.e. when the aircraft is drawn at the helicopter's level. Emulation:
  helicopter teleported 20 units south of aircraft 0, alt 29; crash at the frame where the aircraft cells
  (F8, FB, FE) entered the footprint, with 87EF=4 and alt>>3=3. **Note for core3:** 87EF is the *aircraft* height
  level that follows the helicopter's level, not the helicopter's own level.

---

## Variables touched (meaning / initial value: new game from 7564 → respawn template 75C8, FF = kept)

| Addr | Meaning | Init (new / respawn) |
|---|---|---|
| 7500/01 | helicopter map X (16-bit, +E) | $0139 / $0139 |
| 7502/03 | helicopter map Y (16-bit, +S) | $0170 / $0170 |
| 7504 | view direction 0 N, 1 S | 0 / 0 |
| 7505 | 1 = helicopter destroyed (set by 8B5D) | 0 |
| 7506 | heading 0–15, even only | 4 (east) |
| 7507 | sprite heading (odd during turns), used by 8CA0/7BCD | 4 |
| 7508 | target heading of the current turn | 4 |
| 7509/0A, 750B/0C | work pointers: window bitmap / attribute (85D4, 86AF, renderer) | 0 |
| 750D | altitude in pixels 0–60 | 8 / 8 |
| 7512 | 86AF column counter 0–2 (renderer also uses it as a word at 7CF5) | 0 |
| 7514 | 1 = tried to descend below 0 (touch-down / crash test in 8A7A) | 0 |
| 7515 | 1 = landed | 1 / 1 |
| 7516 | 1 = fuel tank empty | 0 / 0 |
| 7517 | fuel sub-counter 0–48 | 0 |
| 7518/19 | F-bar pointer (last erased line; $471C full, $47BC empty) | $47BC / $47BC |
| 751A | climb rate 0–3 | 0 |
| 751B | descent rate 0–3 (3 = hard landing) | 0 |
| 751C/1D | T-bar pointer ($471E full; low byte $DE = out of time) | set by 843A / kept |
| 751E/1F | A-bar pointer (top lit line) | set by 84AE |
| 7521 | turn timer 3..0 | 0 |
| 7522 | control bits (0 fwd, 1 down, 2 up, 3 right, 4 left) | 0 |
| 7524 | aircraft block view column 0–24 (dx+12) | 0 |
| 7525 | aircraft block view row 0–30 (dy+15) | 0 |
| 7526 | key latches / map flags (b0 M held, b1 map mode, b2 N held, b3 map left, b4 map entered) | 0 |
| 7527 | speed 0–7 | 0 |
| 7528 | time sub-counter 0..(828C)−1 | 0 |
| 7529/2A, 752B/2C | 86AF piece pointers (background code, attribute) | 0 |
| 752D | 1 = interrupt sound off (menu / crash sequence) | 0 |
| 752E | 1 = landed on the base helipad (refuelling; needed to finish a round) | 1 / 1 |
| 752F | 1 = aircraft sprite already set up this iteration | 0 |
| 7530 | aircraft proximity bits (3 = BEWARE AIRCRAFT) | 0 |
| 7533 | helicopter height level min(alt/8+1, 7) (written by 8A7A) | 3 |
| 753B | direction of travel (latched while thrusting) | 4 |
| 754B/4C | cyclone position (set to 2/20, 2/19 at new game) | 2,2 / kept |
| 7550 | cyclone distance (wind when < (5B93)) | 0 |
| 7552/53 | pointer to the current island record (F294 = base) | 0 |
| 7554 | crates delivered (5 = round complete) | 0 / kept |
| 7555 | winch counter (≠0: winch beep) | 0 |
| 755D | rotor sound phase 0–3 | 0 |
| 5B93 | operand of CP at 5B92: wind threshold, 5 in round 1 and 6 later | 5 |
| 828C | operand of CP at 828B: T-bar period, 255 − 15·(round−1) | 255 |
| 81EF, 81F6 | self-modified X/Y movement opcodes | NOP |
| 8867/68, 8871/72 | self-modified aircraft X/Y opcodes | NOP |
| 87EF | aircraft height level 1–7 | 1 |
| 8A69/6A | aircraft schedule pointer | $E740 |
| 8A6B | aircraft schedule step 0–27 | 0 |
| 9245 | lives lost this round (0–2; 3 = game over) | reset by 8321 |
| 661E–6624 / 6627–662D | score / high score, 7 ASCII chars ('.' = leading blank) | "......0" |

## External routines called

* 03B5 ROM BEEPER (DE = cycles, HL = 437500/f − 30.125).
* 5FDC explosion noise (interrupt context).
* 6600 add 40 points. 6602 add B points (one unit at a time). Both end with JP 6F00, which prints the score (leaves
  B=$66).
* 6F06 print a digit string right-to-left until $FF.
* 8B74 RNG (seed 5C76).
* 84F4/859A are in my range. Renderer patch targets 7B18/7E35/… are in 7378–7FD5.
* 7F21 builds the helicopter window tiles. 7AA2 is the per-cell background code table. 762C copies the view buffer to
  the screen. 91B4 colours BEWARE AIRCRAFT from 7530.

## Open questions

1. The exact background code table that 86AF reads (7AA2+C, −1 per piece, +11 per column) is built by the renderer.
   The 7378–7FD5 agent should confirm its layout. The "solid vs OR" decision is my reading of the code.
2. 85D4's aircraft branch (8689) and the multiple-aircraft case (two in the window at once) were never seen. Is the
   shared-sprite behaviour visible in the real game?
3. 7526 bit3 ("map just left") is set but never used. Possibly a leftover.
4. 8A6C–8A6D ($C8 $FE) and 8A77–8A79 ($09 $1A $6F) are unreferenced. They may be assembler leftovers.
5. The time limit per round (≈19 min in round 1) is computed, not observed end-to-end.
