# Cyclone: front end, game flow and main loop (area `frontend`)

Ranges: **$5B00-$7377** and **$E280-$FFFF**. Control file: `re/ctl/frontend.ctl`. Snapshot: `re/snapshots/init.z80`.

Evidence tags: **CODE** = read from the disassembly; **OBS** = seen in emulation (my harness drives `skoolkit` CSimulator, scripted keys, per-frame hooks and PC breakpoints); **INF** = my interpretation.

---------------------------------------------------------------------------------------------------

## 1. Memory map of my ranges

| Range | Type | Contents |
|---|---|---|
| 5B00-5BF1 | code | GameStart / LevelStart / LifeStart / **MainLoop** (copied from F78A at init; lives in the printer buffer) |
| 5BF2-5BFA | text | " NO FUEL " (9 chars); 5BFB-5BFF zero |
| 5C00-5EEB | data | ROM system variables + BASIC loader (unused; only SEED $5C76 = RNG state for $8B74) |
| 5EEC-5F58 | code | **ShuffleCrates** (copied from F88A at init; always called through `JP $5EEC` at FE92) |
| 5F59-5F60 | data | crate tiles 8B 57 2F 0F / plain tiles 58 30 10 04 |
| 5F61-5FD2 | data | 38 crate candidate cells (flag, map address) |
| 5FD3-5FDB | data | last copied byte + leftovers below the main block |
| 5FDC-600E | code | **CrashNoise** (interrupt-time sound while $7505=1) |
| 600F-6017 | zero | unused |
| 6018-6071 | words | 45 survivor candidate cells (map addresses) |
| 6072-60AB | code | **PlaceSurvivors** |
| 60AC-60B1 | data | plain tiles 58 30 10 -> survivor tiles 89 55 2D |
| 60B2-60DF | zero | unused |
| 60E0-62FF | font | 8x8 font, chars $17-$5A, base $6028 |
| 6300-72FF | tables | two **tile column tables** (A pages 63-6B north view, B pages 6C-74 south view), sparse; their unused low ends hold: |
| 6600-661B | code | **AddScore40** (6600) / **AddScore** (6602) |
| 661C-662E | text | `FF 'S' score[7] FF 'H' hiscore[7] FF` |
| 6700/6800/6900/6A00 (+72 each) | gfx | rotor overlay frames, idle set (landed / out of fuel) |
| 6848-6887 | text | HUD rows 22-23 (WIND / DANGER / FORCE) |
| 6950-6997 | buffer | helicopter sprite buffer (24x24) |
| 6A4F-6AC9 | text | island names + " ISLAND" suffix |
| 6B00-6BDF | font | 4x8 font ('?'=space, '@', A-Z; base $6908) |
| 6F00-6F23 | code | **PrintScore** (6F00) / PrintBackwards (6F06) |
| 7000/7100 (+72 each) | gfx | rotor overlay frames, flight set |
| 7148-7187 | attrs | rows 22-23 attributes |
| 7200-72A7 | attrs | HUD panel attributes (21 rows x 8) |
| 7300-7377 | layout | HUD panel glyph layout (15 rows x 8, glyphs at $7400+8n) |
| E280-E2E7 | code | **MainMenu** |
| E2E8-E324 | code | DrawMenu |
| E325-E3A5 | text | menu strings (E40F format) |
| E3A6-E3B3 | attrs | menu row attributes |
| E3B4-E3F7 | code | **InfoScreen** |
| E3F8-E40E | code | GetKey (ROM key scan) |
| E40F-E435 | code | PrintStrings (8x8) |
| E436-E439 | junk | unused |
| E43A-E4DF | code | DrawInfoTexts |
| E4E0-E503 | text | info headings / key letters / map symbols |
| E504-E516 | data | info screen rules |
| E517-E69B | text | info screen texts (4x8 font) |
| E69C-E6F2 | data | info text line positions (29 x 3) |
| E6F3-E6FF | junk | unused |
| E700-E73F | data | aircraft direction -> INC/DEC/NOP opcodes (16 x 4) |
| E740-E86B | data | aircraft course script (15 x 20) |
| E86C-E8CB | data | aircraft table (19 x 5 + FF) |
| E8CC-E92B | data | aircraft start positions (19 x 5 + FF); E92C-E92F zero |
| E930-EDAF | gfx | helicopter frames, 16 headings x 72 bytes |
| EDB0-F22F | gfx | helicopter mask/shadow frames, 16 x 72 |
| F230-F348 | data | 14 island records x 20 bytes + FF |
| F34A-F38A | code | **AnimateSurvivors** |
| F38B-F399 | zero | unused |
| F39A-F510 | code | **Winch** (contains the IM2 target `F3F3: JP $83C2`) |
| F511-F54F | data | winch tile tables, rope + crate / survivor graphics |
| F550-F6B7 | gfx | 5 crash debris overlay frames (72 bytes each) |
| F6B8-F74D | buffer | (load-time junk) overflow rows above the view buffer at run time |
| F74E-F783 | code | **Init** (runs once; area then reused as the view buffer) |
| F78A-F888 | dup | source copy of 5B00-5BFE (identical; overwritten at run time) |
| F88A-F971 | dup | source copy of 5EEC-5FD3 (identical; overwritten at run time) |
| F74E-F9E8 | buffer | view buffer, 29 rows x 23 cells (F9E9-F9FF spare row) |
| FA00-FDFF | gfx | terrain glyphs for char codes 00-7F (5F-7F dynamic) |
| FE00-FE91 | attrs | attribute per char code 00-91 (FE5F-FE7F dynamic) |
| FE92-FE94 | code | `JP $5EEC` (written by init) |
| FE95-FE97 | dead | loader remnant (`CALL $FE9F`) |
| FE98-FE9E | code | **Entry** (USR 65176): `LD SP,$FEFF / EI / JP $F74E` |
| FE9F-FEFF | dead | loader's LD-BYTES clone (half destroyed); stack grows down into FEE5-FEFE |
| FF00-FFFF | table | IM2 vector table, 256 x $F3 |

CODE for all addresses; the duplicate status of F78A/F88A verified byte-for-byte in init.z80 (OBS).

---------------------------------------------------------------------------------------------------

## 2. Boot, loader, init, IM2

**Tape** (CODE, tapinfo): BASIC "Cyclone1" line 10: `BORDER NOT PI: INK NOT PI: PAPER NOT PI: CLEAR VAL "24539": LOAD "Cyclone2"SCREEN$: LOAD "Cyclone4"CODE: LOAD "Cyclone3"CODE: RANDOMIZE USR VAL "65176"`. Blocks: Cyclone2 = screen 4000/6912; Cyclone4 = FE00/512; Cyclone3 = 5FDC/40630 (ends at FE91, so it overwrites FE00-FE91 of Cyclone4).

**Original loader in Cyclone4** (CODE, decoded from the TAP block): FE00 `DI; HL=FE80; loop: A=R XOR (HL) -> (HL)` up to FFFF (R-register decryption, here harmless/plain), FE13-FE7F filler bytes $13..$7F; FE80 `DI; SP=0; IX=4000 DE=1B00 CALL FE9F; IX=5FDC DE=9EB6 CALL FE9F;` then FE98. FE9F is a copy of ROM LD-BYTES (FF27/FF2B edge routines, FF49 LD-RET); FF53-FFFF held an 8x8 font. In this TAP the ROM loads everything and only FE98 is used.

**Entry FE98**: `LD SP,$FEFF; EI; JP $F74E`. Stack occupies the top of the old loader (OBS: FEE5-FEFE written during play).

**Init F74E** (CODE): DI; LDIR F78A->5B00 (255 B); LDIR F88A->5EEC (232 B); writes `C3 EC 5E` at FE92; fills FF00-FFFF with $F3 (`LD BC,$00F3; LD (HL),C; INC HL; DJNZ` with B=0 = 256 times); `I=$FF; IM 2; EI; JP $E280`.

**IM2**: any data-bus byte d gives vector word at $FF00+d -> $F3F3 (for d=$FF the high byte comes from ROM $0000 = $F3 too). $F3F3 holds `JP $83C2`, embedded in the Winch routine and jumped over by `JR $F3F6` at F3F1 (CODE). The handler $83C2 (other area) does only sound: CODE summary for cross-check:
- `752D==1` -> silent (set in menu; also INC'd at the 18th-last crash step).
- `7505==1` -> JP 5FDC crash noise.
- `7515 OR 7516 <> 0` (landed or out of fuel) -> silent.
- `7555<>0` (reeling in) -> ROM BEEPER DE=8, HL=$32 (winch click).
- Rotor chop: phase `755D` = 1,2,3,0,...; phase 1: 10 square cycles with half-periods D=E=$12-2*speed, phases 2,3,0: 6 cycles with D=E=$24-2*speed (loops of 13 T per count). Speed = `7527` (0-7). So pitch rises with speed; rhythm 1 high + 3 low bursts per 4 frames.
- Ends `EI; RET`. Interrupts are lost whenever ROM BEEPER runs (DI), so the engine sound stops during beeps (INF).

**CrashNoise 5FDC** (CODE): per interrupt: HL=RND; if L<$46 (70/256 frames) silent; else 3 cycles: high for (H AND $F0) passes, low for (L AND $F0) passes, ~43 T per pass (OUT $FE,$10 / OUT $FE,0; border black).

---------------------------------------------------------------------------------------------------

## 3. Main menu (E280) and control selection

Flow (CODE, OBS screenshots):
1. `752D=1` (engine silent). BEEPER HL=$0666, DE=$55. Wait until no key is pressed (E3F8 returns carry).
2. 84D6 CLS (pixels 0, attributes 7). E2E8 draws the menu:
   - attributes rows 5-17, columns 9-21 from E3A6: `47 00 07 42 47 42 07 07 07 07 42 47 42`;
   - a 13-byte horizontal line on pixel line 3 of each of rows 5-17 (visible only on the red-attribute text-free rows 8, 10, 15, 17);
   - strings (E40F): row 5 logo (chars $17-$1F "CYCLONE"), row 7 "SELECT OPTION", row 9 "1 INFORMATION", rows 11-14 "2 KEYBOARD" / "3 INTERFACE 2" / "4 KEMPSTON" / "5 PROTEK/AGF", row 16 "6 START GAME".
3. Highlight: rows 11-14 all 32 columns attr $45 (bright cyan); row 11+method, columns 9-21 attr $C5 (flash).
4. Loop E29E: `CALL $FE92` (crate shuffle) then read key. ~7,000-13,000 T per pass (OBS) = ~5-10 shuffles per frame, so the crate layout is effectively random per game (INF).
   - '1' -> E3B4 info screen; '6' -> JP 5B00; '2'..'5' -> `7FD5 = key-'2'` (0 keyboard, 1 Interface 2, 2 Kempston, 3 Protek/AGF), re-highlight, click (HL=$0300, DE=$60), wait for release. Anything else ignored. Initial `7FD5 = 0` (keyboard).

**GetKey E3F8**: ROM KEY-SCAN 028E (NZ -> none), K-TEST 031E (NC -> none), K-DECODE 0333 with C=0 (L mode), D=8. Out: A = ASCII, carry clear; none: A=0, carry set.

### 3.1 Input reading routine (7FD6, other area) and the control word $7522

Called once per main-loop iteration (5B8C). Writes `7522`. Bit layout (CODE):

| bit | meaning | consumer (CODE) |
|---|---|---|
| 0 | forward / thrust | 81B2: speed `7527` +1 per iteration up to 7, travel heading `753B` := heading; released (or out of fuel): speed -1 per iteration, coasting along `753B`. While speed>0 the helicopter moves exactly 1 world unit per iteration along `753B` whatever the speed (OBS: X +1/iteration at speeds 2..7); the step comes from the opcode table at 826F (INC/DEC/NOP HL patched into 81EF/81F6) |
| 1 | down (descend) | 8243: altitude `750D` decreases by `751B` per iteration, `751B` ramps 1..3 |
| 2 | up (climb) | 81FA: altitude +`751A` (ramps 1..3) up to $3C=60; from the ground it first clears landed (`7515=0`, `752E=0`) |
| 3 | right (rotate clockwise) | `7507` (displayed frame) := heading+1, `7508` := heading+2, `7521`=3; input ignored while `7521` counts 3->1, then `7506` := `7507` := heading+2. So the real heading moves in steps of 2/16 (8 movement directions: 0 N, 4 E, 8 S, 12 W; initial 4 = east) and the odd frame is only shown mid-turn; one turn step takes 3 iterations. Not processed while landed |
| 4 | left (rotate anticlockwise) | same with -1/-2; left+right together cancel |

Mapping per method (CODE, port reads):
- **0 Keyboard**: any of SHIFT Z X C V (port $FEFE) -> bit0; any of 1-5 ($F7FE) -> bit2; any of Q W E R T ($FBFE) -> bit1; P ($DFFE b0) -> bit3; O ($DFFE b1) -> bit4. (Info screen advertises 1/Q/O/P/X; whole half-rows work.)
- **1 Interface 2**: row $EFFE (0 9 8 7 6, inverted): 0(fire)->b0, 9(up)->b1, 8(down)->b2, 7(right)->b3, 6(left)->b4; plus row $F7FE: 5(fire)->b0, 4(up)->b1, 3(down)->b2, 2(right)->b3, 1(left)->b4. Both IF2 ports work.
- **2 Kempston**: `IN ($1F)`: b0 right->b3, b1 left->b4, b2 down->b2, b3 up->b1, b4 fire->b0.
- **3 Protek/AGF (cursor)**: 5(left, $F7FE b4)->b4; row $EFFE: 6(down)->b2, 7(up)->b1, 8(right)->b3, 0(fire)->b0.

Joystick convention (INF): stick forward/up = descend, stick back/down = climb, fire = thrust.

Other keys, read from the keyboard in every mode: **M** (map), **N** (view), handled by 80AA; **A+G together** = abandon game (5BDD). All read directly with IN.

`7378` (called when the cyclone is close) post-processes `7522` (CODE): if landed: nothing; proximity `7550`>=4: `7522 |= RND AND $1A` (random down/right/left); 2-3: `|= RND AND $1B` (also forward); <2: `7522 = $12` (forced down+left) and `7521` is decremented.

### 3.2 $7526 key/map flags (80AA, CODE + OBS)

| bit | meaning |
|---|---|
| 0 | M held (debounce) |
| 1 | map mode on |
| 2 | N held (debounce) |
| 3 | set when the map is closed; never tested (OBS: stays set) |
| 4 | map just opened: main loop draws the map once, then clears it |

M press: click (HL=$0361, DE=$1E); toggles bit 1 (on: set bits 1,4; off: clear bit 1, set bit 3).
N press: 80E4 click (HL=$0300, DE=$28) and toggles `7504` (0 = NORTH view, tile table A at page $63; 1 = SOUTH view, table B at $6C) and prints "NORTH"/"SOUTH" in the HUD (8580/8585). **Only two views exist (north/south, 180 degrees)** (CODE+OBS). Seen as 7526 = 00 -> 13 -> 03 -> 02 (map on) -> 09 -> 08 (map off), N: 7504 0 -> 1 -> 0 (OBS).

---------------------------------------------------------------------------------------------------

## 4. Information screen (E3B4)

CODE + OBS (screenshot): CLS; beep (HL=$0400, DE=$70); wait release; 84F4 HUD panel; play area 23x22 attr $7A; `7530=3` (BEWARE AIRCRAFT lit), `7527=0`; 91B4 gauges; 6F00 score; 87BC hi-score update/print; E43A texts; wait for any key; JP E280.

E43A: 8DEE prints the 29 small-font lines at E518 (line n at E69C+3n: screen address + attribute page; each written cell gets attr $78; the stride operand $8E0A is set to 3, the map uses $14). Then 8x8 headings "KEY CONTROLS" (row 1 col 1) and "MAP INDICATORS" (row 8 col 1), rules (E504: 14 bytes at $4401, $4441, $44E1, $4C21, $4CA1; 7 bytes at $5448; all $FF), key letters 1,O (row 3), Q,P (row 4), X,N (row 5), M (row 6), N (row 14 col 21), map symbols char $28 (row 10, helicopter position) and $27 (row 11, cyclone location), then glyph columns: HUD glyph $7460 (arrow, "leaving map area", row 12), $FB80 (crate char $30, row 14), $FB90 (survivor char $32, row 16), and attr $FA (flash) on row 18 columns 1-7 ("PRESS ANY KEY").

Texts (left column): UP, LEFT, DOWN, RIGHT, FORWARD, VIEW CHANGE, MAP OR MAIN SCREEN, HELICOPTER POSITION, CYCLONE LOCATION, LEAVING MAP AREA, COLLECT FIVE CRATES / AND RETURN TO BASE, RESCUE SURVIVORS FOR / EXTRA POINTS, PRESS ANY KEY, CRATES LEFT; right column: ALTIMETER, SPEEDOMETER, FUEL GAUGE, TIME LEFT, COMPASS, HEADING, LIVES, VIEW SELECTED / WITH KEY, COLLISION / WARNING, WIND SPEED INCREASES / WHEN APPROACHING CYCLONE.

---------------------------------------------------------------------------------------------------

## 5. Text printing and fonts

| Routine | Font | Format |
|---|---|---|
| E40F PrintStrings | 8x8 @ $6028+8c | list of `[addr lo, addr hi, codes..., FF]`, list ends with FF |
| 859A (other area) | 8x8 @ $6028 | HL = text, DE = screen address, C = length; 8 lines per char |
| 6F00 PrintScore / 6F06 | 8x8, 7 lines | BC = last char, printed right-to-left until $FF, from DE (score $507F row 19 col 31; hi $509F row 20 col 31) |
| 8DEE (other area) | 4x8 @ $6908+8c | two chars per cell; `?`=space, $FE next record (IX += stride at $8E0A), $FD append " ISLAND" (6AC2) then next, $FC end of suffix, $FF end; IX+$10/$11 = start address, IX+$12 = attribute page (cells get $78) |
| 8EE8 (other area) | raw 8-byte glyphs from IX | prints C glyphs, stepping DE by HL (screen-address stride) |

**8x8 font** chars (CODE, rendered): $17-$1F CYCLONE logo; $20 space; $21 !; $22 blank (rule fill in the HUD text); $23/$24 WIND FORCE bar caps; $25/$26 DANGER bar pattern; $27 cyclone symbol; $28 helicopter-position symbol; $29/$2A arrows; $2B ,; $2C-$2F; $30-$39 digits; $3A '|' $3B '-'; $3C-$40 large "VIEW" HUD label; $41-$5A A-Z. Chars $10-$16 would overlap code/tables (unused).
**4x8 font** at 6B00: '?' (blank) , '@', A-Z; glyph data in the left nibble.

HUD strings outside my range: 85B9 "BEWARE" ($5019, row 16 col 25), 85BF "AIRCRAFT" ($5038, row 17 col 24), 85C7 `<=>?@` = VIEW logo ($48BB), 85CC "NORTH" ($48DB, attr $38), 827F "SOUTH"; 8A6E " NO TIME " (9 chars).

---------------------------------------------------------------------------------------------------

## 6. Game flow

### 6.1 GameStart 5B00 (CODE, OBS)
1. 84D6 CLS; 8D0E play area: attributes $3F on columns 0-22 rows 0-21, pixels cleared, inner 21x20 (from row 1 col 1) attr $7C.
2. 84F4 HUD: attributes 7200 -> columns 24-31 rows 0-20, 7148 -> rows 22-23, glyph layout 7300 (cols 24-31 rows 0-14, glyphs $7400+8n), bottom text 6848, BEWARE / AIRCRAFT / VIEW / NORTH.
3. 87BC: if score (661E, 7 chars, compared as strings: '.' < '0') > hi-score (6627) copy it; print the hi-score. **The hi-score is therefore only updated at the next game start (or on the info screen).** OBS: score 1234 at game over -> menu shows nothing; after pressing 6 "H...1234".
4. Score := "......0", print.
5. LDIR 7564 -> 7500 (100 bytes): the initial variable values (section 8).

### 6.2 LevelStart 5B26 (first level, and after each completed level)
1. **8321** (CODE+OBS): clear attrs $5AC0-$5AC9/$5AE0-$5AE9; draw 5 crate boxes (2x2 cells at columns 0,2,4,6,8 of rows 22-23, attr 6) each with a beep (HL=$03E8, DE=$2C) and a 200x255 DJNZ delay.
   - If `7554 <> 5` (new game): `5B93 := 5` (turbulence threshold), `828C := $FF` (time tick period), cyclone start `754B := 2 or $14`, `754C := 2 or $13` (two random bits: one of four corners, INF).
   - If `7554 = 5` (level completed): `7554 := 0`; **bonus** = `AddScore(250 - 64*livesLost)` + `AddScore(B=$66)` = **352 / 288 / 224 points** for 0/1/2 lives lost in the level (the second call gets B=$66 left over from PrintScore instead of the same value - a bug; OBS 352 and 224); `5B93 := 6`; `828C -= 15` (timer faster).
   - Both: `9245 := 0` (**lives restored to 3 every level**, OBS), redraw HUD (84F4).
2. **843A** time bar fill: 40 pixel lines (column 30, rows 5..1 bottom-up). Lines already set give **40 points each** (time bonus, beep HL=$FF) - unset lines are filled (beep HL=$D0). `751C := $471E`. OBS: full bar at level end = 1600 points; game start (screen just cleared) = 0.
3. **FE92 -> 5EEC** crate shuffle; **6072** survivors (section 7).

### 6.3 LifeStart 5B36 (also from 92C5 after a lost life)
80F9: view NORTH (`7504=0`, tile pages $63..), print NORTH. 84AE: clear the altimeter bar (column 24 rows 1-7), set 8 lines at row 8, `751E=$4818`, altitude `750D=8`.

### 6.4 MainLoop 5B3C (per iteration, in order; CODE)
| # | call | purpose (one-line, other areas) |
|---|---|---|
| 1 | 76D2 | clear view buffer F74E-F9E8; find the island record containing (X,Y) -> `7552`; fill the buffer with map tile codes |
| 2 | 87F0 | move the 19 aircraft (script E740, table E86C); set `7530` bit0/bit1 when one is close in X/Y |
| 3 | 91B4 | HUD: compass needle (heading or travel heading), speed bar (rows 1-6 col 26), BEWARE AIRCRAFT attrs ($FA flash when `7530=3`) |
| 4 | 8B91 | helicopter screen offset `7535/7536` (drift/bob; new random every 3rd call) |
| 5 | 8CA0 | build helicopter sprite in 6950: frame E930+72h, rotor overlay XOR (flight set 7000/7100 alternating, idle set 6700-6A00 when landed/out of fuel) |
| 6 | 7E10 | save 3x3 tile codes under the helicopter (F8B1 -> 7A81..7A89, centre 7A85), then convert tile codes to stacked character codes via the tile column tables (render) |
| 7 | 86AF | overlay helicopter/shadow as dynamic glyphs |
| 8 | F39A | **Winch** (section 7) |
| 9 | 8A7A | landing/collision: crash `7505=1`; landed `7515=1`, altitude snapped to a multiple of 8; `752E=1` if all 9 cells under the helicopter are landing-pad chars $83/$89 |
| 10 | 85D4 | more dynamic-glyph compositing into the buffer (FD30/FE66 region) |
| 11 | - | **`7505=1` -> JP 9246 crash sequence** |
| 12 | - | if `7526` bit1 (map): 8F12 (delay 40x255 DJNZ ~133k T, blink markers, falls into 9034); if bit4: clear it, 8D0E + 8D5D (island bitmaps from F230) + 8E5C (frame, N arrow) + 8F6A (markers/labels). Else: 762C (blit buffer to screen: attr $FE00+c, glyph $FA00+8c for c<$80) and 9034 (cyclone movement, proximity `7550` 0-15, WIND FORCE bar row 23, DANGER flashes when `7550`<6) |
| 13 | 7FD6 | read controls -> `7522` |
| 14 | 7378 | only if `7550 < [5B93]` (5 on level 1, 6 later): turbulence |
| 15 | - | **`7515=1` and `7516=1` and `752E=0` -> "NO FUEL"** (5BEC) |
| 16 | 80AA | M/N keys; then (8135) apply `7522`: heading, speed, travel, climb/descend, fuel-out sinking |
| 17 | - | **`7554=5` and `752E=1` and `7552=$F294` (BASE record) -> JP 5B26 next level** |
| 18 | - | **low byte of `751C` = $DE -> 92C8 "NO TIME"** |
| 19 | 8470 | on pad (`752E<>0`): refuel 1 line per iteration (beep HL=$D0 DE=$10), `7516=0`; else 82A7: burn 1 fuel line every 49 iterations; empty -> `7516=1` |
| 20 | 8284 | time: every `[828C]` iterations (`7528` counter) clear one time-bar line |
| 21 | F34A | animate survivor glyphs |
| 22 | - | **A and G both held -> JP E280** |
| 23 | - | JP 5B3C |

### 6.5 Exits
- **Crash** (9246, CODE+OBS): 762C; debris pointer `9243 := $F550`; `750D += 2`; 24 iterations (B=$18..1): 76D2, 8B91, copy 72 bytes $9300 (wreck) -> 6950, 8CA0 if B>=$16 (3 frames still spinning), `752D+1` when B=$12 (engine/crash noise off), 92ED if B>=$14 (XOR debris frames F550+72k, k=0..4), 7E10, 86AF, 762C. Then mark life lost (below). OBS: ~135 frames.
- **NO FUEL** (5BEC): print " NO FUEL " at row 3 col 7 (attr $47), beep (HL=$0466, DE=$0300), lose a life. No crash animation. Out of fuel in the air: speed decays, climb disabled, forced sink with `751B` ramp to 3; touching ground with `751B>=3` is a crash (OBS: ran out at altitude 32 -> crash), a gentle landing gives NO FUEL.
- **Lose a life** (928A): attribute 2 (red) on 2 cells at `$5958 + 64*9245` (life icons rows 10/12/14, cols 24-25); `9245 += 1`; if 3 -> **JP E280 (game over: straight to the menu, no message, no table)**. Else 92A9: call 82A7 until `7516=1` (drain the fuel gauge), restore variables from 75C8 (bytes $FF = keep), JP 5B36. Kept across a life: `751C/751D` time, `7543-754C` and `754E/754F` cyclone/map-marker state, `7554` crates. Everything else (position back to base X=$0139 Y=$0170, altitude 8, landed on pad, fuel empty -> refuels, speed 0, heading 4) is reset. Collected crates/survivors stay removed from the map.
- **NO TIME** (92C8): `9245 := 2`, print " NO TIME ", beep, then the lose-a-life code -> 9245=3 -> **immediate game over regardless of lives** (OBS).
- **Level complete** (5BC9 -> 5B26): no message; bonus beeps; crates and survivors re-placed; helicopter stays on the base pad; cyclone keeps its position.
- **Abandon** A+G (OBS): JP E280.

### 6.6 Timing (OBS)
No HALT anywhere (CODE); the main loop is free running. Measured iteration lengths (69888 T = 1 frame): on the base pad 360k T (5.2 frames); flying low 375k; flying at speed 7 / altitude 60: 273k-371k (avg 327k = 4.7 frames); map mode 375k (dominated by the 8F12 delay). So ~9-13 iterations per second; every timer below counts iterations, not frames. The interrupt only makes sound.

| timer | rate |
|---|---|
| fuel | 40 lines, -1 line per 49 iterations off-pad (empty after ~2000 iterations, ~3.5 min); refuel +1 line per iteration on a pad (OBS 40 lines in ~220 frames) |
| time | 41 ticks to "NO TIME"; tick every 255 iterations on level 1 (~17-19 min), then 240, 225, ... (-15 per level; wraps after 17 levels, see open questions) |
| survivor animation | char $31 every 4 iterations, char $32 every 3 |
| crash | 24 iterations |

---------------------------------------------------------------------------------------------------

## 7. Crates, survivors and the winch

Tiles (map cell codes, CODE): plain $58 / $30 / $10 / $04 (four terrain heights, INF); crate versions $8B / $57 / $2F / $0F; survivor versions $89|$8A / $55|$56 / $2D|$2E (two survivor types; char $31 vs $32 likely, INF).

**ShuffleCrates 5EEC**: remove last placement (flags $FF -> crate tile back to plain), choose 5 distinct of 38 candidates: RND L<$4C (76), index L>>1 (uniform 0-37), set flag, plain->crate ($04 or anything unknown -> $0F). OBS: 5 crates placed, other candidates hold plain tiles.

**PlaceSurvivors 6072**: each of 45 cells with a plain tile $58/$30/$10 becomes $89/$55/$2D + (RND L AND 1). OBS at game start: all 45 occupied. Candidate lists do not overlap (CODE).

Candidate cells (map address, tile at load, row/col in the 128-wide world map from $9300; island attribution left to the map area):
- Crates: 9905(58 r12 c5), 96A5(58 r7 c37), 9A2F(30 r14 c47), A518(10 r36 c24), A489(58 r35 c9), B086(10 r59 c6), AE91(30 r55 c17), AF9B(30 r57 c27), B114(04 r60 c20), BAA6(10 r79 c38), BD09(58 r84 c9), BEBA(30 r87 c58), C623(10 r102 c35), C697(10 r103 c23), CE87(10 r119 c7), D41D(10 r130 c29), 95F3(58 r5 c115), 9C6B(04 r18 c107), A5E9(04 r37 c105), A8F7(30 r43 c119), AF60(10 r56 c96), AF6C(10 r56 c108), B66C(30 r70 c108), BF4B(58 r88 c75), BDFB(58 r85 c123), C2D3(58 r95 c83), 95C0(10 r5 c64), 9DCA(30 r21 c74), 9E39(04 r22 c57), A03C(58 r26 c60), A849(30 r42 c73), AE43(30 r54 c67), B6D4(30 r71 c84), CA31(30 r110 c49), C943(30 r108 c67), C95E(30 r108 c94), CDEC(30 r117 c108), DBE9(30 r145 c105).
- Survivors: 9809(30 r10 c9), 96AA(58 r7 c42), 95A9(58 r5 c41), A485(30 r35 c5), A386(30 r33 c6), A416(10 r34 c22), A41B(10 r34 c27), A39F(10 r33 c31), B186(10 r61 c6), B10A(10 r60 c10), B188(10 r61 c8), C027(10 r90 c39), C1A6(10 r93 c38), C1A8(10 r93 c40), C229(10 r94 c41), 9A6C(30 r14 c108), 9A77(30 r14 c119), 9C74(30 r18 c116), 9D73(30 r20 c115), A866(58 r42 c102), A869(58 r42 c105), A5E4(30 r37 c100), B4EC(30 r67 c108), B4ED(30 r67 c109), B56E(30 r68 c110), C0E0(58 r91 c96), C0E4(58 r91 c100), C162(58 r92 c98), 98C2(58 r11 c66), 98C5(58 r11 c69), 9BCA(58 r17 c74), 9C48(58 r18 c72), A0C5(58 r27 c69), B048(10 r58 c72), AFC9(10 r57 c73), AFCA(10 r57 c74), ABCB(30 r49 c75), AB4E(30 r48 c78), D46F(10 r130 c111), D471(10 r130 c113), D4F2(10 r131 c114), D4F3(10 r131 c115), D95C(30 r140 c92), D960(30 r140 c96), D8E1(30 r139 c97).

**Winch F39A** (CODE):
1. If `7555` in 1..16: reeling in. `7555 -= 1 + 751B` (clamped at 0; descending shortens the rope faster). Draw rope `7555` lines + object 8 lines. At 0: **score 250 for a crate, 50 for a survivor** (AddScore). Return.
2. T = `7A85` (tile under the helicopter). Crate tile -> graphic F52F, plain tile from F51B; survivor tile -> graphic F548. Neither: if `7556<>0` draw a 12-line retracted rope once, `7556=0`; return.
3. gap E = (FD96 - altitude `750D`) - (FDA1 - 8*B) as a 16-bit value; if >255 or negative: return (INF: pixel lines between the skid and the object).
4. E >= 17: rope dangles (12 lines first time, then 16), never reaches.
5. E < 17: state machine on `7556`: with E<13 the rope is drawn at 16 lines on the first iteration (0->2) and the object is hooked on the second; with 13<=E<17 the rope is drawn 12 lines (0->1), then 16 (->2), hook on the third. **Hook**: `7555 = max(E,2)-1`; map cell at `[7552]+0A/0B + (Y+$0E-[+8])*128 + (X+$0B-[+6])` := plain tile (object removed for good); `7556=0`; crate: `7554 += 1` (max 5) and HUD box n (attr $5ACA-2n, 2x2) := 2 (red; boxes empty right-to-left). Points only when it arrives (step 1).
6. Rope drawing: `7512=2`; HL/DE computed from altitude; `JP $86EA` with C = lines (refused if >= 25).

F511 tables: crate tiles `8B 57 2F 0F`, survivor pairs `89 8A 55 56 2D 2E`, plain `58 30 10 04`; F51F 16 rope lines ($08; $10 kink at F52D), F52F hook+crate `08 34 4A 66 7A 72 34 18`, F537 0, F538 16 rope lines, F548 survivor `18 00 3C 5A 18 18 18 00`.

**AnimateSurvivors F34A**: `755B` 0-7: at 4 copy 7DEE (7 bytes) to FB88, at 8 copy 7DF6 and reset; `755C` 0-5: at 3 copy 7DFE (8 bytes) to FB90, at 6 copy 7E06 and reset.

---------------------------------------------------------------------------------------------------

## 8. Variables touched (live block 7500-7563; init = value copied from 7564+i; restart = 75C8+i, FF = keep)

| addr | meaning | init | notes |
|---|---|---|---|
| 7500/7501 | helicopter world X (16-bit) | $0139 | X hi = island sector |
| 7502/7503 | world Y | $0170 | base pad start |
| 7504 | view: 0 north, 1 south | 0 | N key |
| 7505 | crash flag | 0 | 1 -> 9246; IRQ crash noise |
| 7506 | heading 0-15 | 4 | 7507/7508 derived frames (init 4,4) |
| 750D | altitude 0..$3C | 8 | +2 at crash; landed snaps to multiple of 8 |
| 7514 | hit ground while descending | 0 | (8269) |
| 7515 | landed | 1 | |
| 7516 | out of fuel | 0 | |
| 7517 | fuel / refuel tick counter | 0 | 0-48 |
| 7518/7519 | fuel bar pointer (col 28) | $47BC (empty) | full = $471C |
| 751A / 751B | climb / descent rate 0-3 | 0 | 751B also speeds winch reel-in |
| 751C/751D | time bar pointer (col 30) | set by 843A to $471E | NO TIME when low byte = $DE; kept on death |
| 751E/751F | altimeter bar pointer (col 24) | $4818 by 84AE | |
| 7521 | turn repeat counter | 0 | |
| 7522 | control word | - | section 3.1 |
| 7526 | key/map flags | 0 | section 3.2 |
| 7527 | speed 0-7 | 0 | rotor sound pitch |
| 7528 | time tick counter | 0 | compared with [828C] |
| 752D | engine sound mute | 0 (1 in menu) | |
| 752E | on a landing pad | 1 | refuel; level-complete condition |
| 7530 | aircraft proximity bits (b0 X, b1 Y; 3 = warning) | 0 | info screen forces 3 |
| 753A | rotor frame | 0 | |
| 753B | travel heading | 4 | |
| 754B/754C | cyclone start/map position | 2,2 then random corner | kept on death |
| 7550 | cyclone proximity 0-15 | 0 | <[5B93] turbulence, <6 DANGER |
| 7551 | replacement plain tile | | winch |
| 7552/7553 | island record under helicopter | | $F294 = BASE |
| 7554 | crates collected 0-5 | 0 | kept on death |
| 7555 | rope length while reeling in | 0 | IRQ winch beep |
| 7556 | winch state 0-2 | 0 | |
| 7557/7558 | rope+object graphic pointer | | F52F crate / F548 survivor |
| 755B / 755C | survivor animation counters | 0 | |
| 755D | rotor sound phase | 0 | IRQ |
| 7FD5 | control method 0-3 | 0 | menu |
| 9243/9244 | crash debris pointer | | |
| 9245 | lives lost this level 0-3 | 0 | reset each level start; 3 = game over |
| 5B93 | operand: turbulence threshold | 5 (6 from level 2) | self-modified |
| 828C | operand: time tick period | $FF, -15 per level | self-modified |
| 8E0A | operand: 8DEE line-record stride | 3 info / $14 map | self-modified |
| 661E-6624 / 6627-662D | score / hi-score ASCII | "......0" | |

---------------------------------------------------------------------------------------------------

## 9. Data blocks: tile column tables 6300-72FF / 6C00-74FF (CODE)

For tile t, table A: bytes at $6300+t, $6400+t, $6500+t, ... (one page per row upwards) are character codes, bottom first; $FE = transparent row, $FF = end. Table B (south view) is the same at $6C00+t... The renderer (7E10, self-modified page operands set by 8113: base, base+3, +4, +5, +6, +7) walks the column upwards (-23 bytes per row in the buffer). Heights including the $FF: t<$10:1, $10-$2F:2, $30-$57:3, $58-$8B:4, $8C-$B1:5, $B2-$CF:6, $D0-$E3:7, $E4-$E9:8 (a few codes in each band are shorter). Char codes <$80 -> glyph $FA00+8c and attribute $FE00+c; codes >= $80 -> solid colour from $FE00+c. The free low ends of pages $66-$6B / $6F-$73 hold the items listed in section 1 (verified: no tile column reaches them).

Other data in E280-FFFF: island records F230 (14 x 20; BASE = F294 X $11C-$181 Y $150-$187, map base $CF80); aircraft (E700-E92B); helicopter frames E930 (heading h at E8E8+72(h+1)), masks EDB0 (ED68+72(h+1)).

---------------------------------------------------------------------------------------------------

## 10. External routines called (one-line guesses for cross-check)

| addr | guess |
|---|---|
| 03B5 | ROM BEEPER (DE cycles, HL pitch) |
| 028E/031E/0333 | ROM KEY-SCAN / K-TEST / K-DECODE |
| 7378 | cyclone turbulence on the control word |
| 762C | blit view buffer (F74E) to the 23x22 play area |
| 76D2 | clear view buffer, find island, fill with map tiles |
| 7E10 | render terrain via the tile column tables; save 3x3 tiles under helicopter |
| 7FD6 | read controller -> 7522 |
| 80AA | M/N keys, then apply controls (8135) |
| 80F9 / 8104 | set NORTH / SOUTH view and tile tables |
| 8284 | time-bar tick |
| 82A7 | fuel consumption tick |
| 82D4 / 82FB | altimeter bar up / down one line |
| 8321 | level setup: crate boxes, bonus, thresholds, lives |
| 83C2 | interrupt handler (sound only) |
| 843A | fill time bar, time bonus |
| 8470 | refuel or consume fuel |
| 84AE | reset altimeter, altitude 8 |
| 84D6 | CLS |
| 84F4 | draw HUD panel |
| 8580/8585 | print view name (NORTH/SOUTH) |
| 859A | print C chars (8x8 font) |
| 85D4 | dynamic glyph compositing (helicopter/objects) |
| 86AF / 86EA | helicopter/shadow overlay / draw C lines of a 1-byte-wide graphic (rope) |
| 87BC | hi-score update and print |
| 87F0 | aircraft movement and proximity |
| 8A7A | landing / crash detection |
| 8B74 | RNG (ROM-style, state SEED $5C76), result in HL |
| 8B91 | helicopter screen drift |
| 8CA0 | build helicopter sprite with rotor overlay |
| 8D0E | clear/colour play area |
| 8D5D | draw island bitmaps on the map |
| 8DEE | 4x8 text printer |
| 8E5C | map frame and N indicator |
| 8EE8 | print glyph column |
| 8F12 | map mode update (delay, blink), falls into 9034 |
| 8F6A | map markers/labels |
| 9034 | cyclone movement and proximity |
| 91B4 | compass, speedometer, aircraft warning |
| 9246 | crash sequence + life lost / game over |
| 92C8 / 92D0 | NO TIME / print message + lose life |

---------------------------------------------------------------------------------------------------

## 11. Open questions
- Speed `7527` does not scale distance per iteration (OBS); check with the movement area whether it affects anything besides coasting time, rotor pitch, compass/speed bar and 8B91 drift (and possibly iteration length).
- Exact meaning of the 4 plain tile codes $58/$30/$10/$04 (terrain heights?) and of the two survivor variants (char $31 vs $32 graphics) - map/graphics areas.
- Which islands have landing-pad cells ($83/$89 chars) besides BASE (refuel possible there; level completion needs BASE).
- Time-tick period wraps after level 17 ($0F - 15 = $00 means a tick every iteration; level 18 gives $F1).
- `7526` bit 3 is set but never read (dead flag?).
- Score overflow past 9,999,999 would increment the 'S' label character (no guard).
- F6B8-F74D load-time contents (looks like stale sprite data) are never read before being overwritten.
