# core1: $7378-$7FD5. Variable block, view-window builder, 3D terrain projection, shadow renderer

Evidence tags: **CODE** = read from the disassembly; **OBS** = seen in emulation (my tracers, see below);
**INF** = my interpretation.

Emulation tools (scratch, not in re/): `agents/core1/acc.py` runs a snapshot under the Python SkoolKit
simulator with scripted keys and pokes. It logs every (PC, address, R/W) access to a watched range and
dumps $7500-$7563 every frame. Scenarios: s1 (4200 frames: climb, fly, turns, N view toggles, M map, dives,
two crashes), s2 (teleport over a crate with pokes, winch pickup, out of fuel, crash), s3 (clean thrust,
coast, turn and cyclone buffeting). Every reader and writer in the glossary is the union of the static
references in build/base.skool and the dynamic access log. No indexed (IX/IY/HL) access to the variable
block was found apart from the two block copies (5B24 LDIR, 92C0 reset loop).

Timing: in emulation one main-loop pass (5B3C..5BE3) takes about 5.4 frames (OBS: 4-6 frames, mean 5.57).
The game has no frame lock, so every "per loop" figure below is in passes of the main loop. A pass is
about 0.11 s, or about 9 passes/s. (SkoolKit does not emulate memory contention, so real hardware is
probably a little slower.)

## 1. Memory map of the range

| Addr | Type | Contents |
|---|---|---|
| 7378-73AF | code | 7378 cyclone buffeting of the controls |
| 73B0-73B7 | unused code | `NOP; RET NZ; LD A,1; LD (7505),A; RET`. Nothing references it |
| 73B8-73FF | data | South-view pillar page $73 (8th pillar level) for codes $B8-$FF. $FF except $73E4-$73E9 |
| 7400-74DF | data | HUD 8x8 font, 28 chars (codes 0-$1B), char k at $7400+8k. 7438-7490 are the map-border/compass pieces listed in the brief. $74B8/C0/C8/D0 = letters A S F T |
| 74E0-74FF | data | $FF filler. Also ends south-view pillars on page $74 |
| 7500-7563 | vars | **Live variable block** (glossary in section 3) |
| 7564-75C7 | data | Initial values. 5B1B LDIR copies them to 7500 (100 bytes) at every game start |
| 75C8-762B | data | Per-life reset values. 92B3 copies them over 7500 after a death, skipping $FF bytes |
| 762C-76C8 | code | 762C blits the 23x22 view from the tile buffer to the screen |
| 76C9-76D1 | unused | 9 zero bytes |
| 76D2-775D | code | 76D2 builds the 23x29 view window from the island maps. Ends with JP (HL) at 775D |
| 775E-7788 | code | Map address helpers 775E, 7777, 7789 |
| 77AD-78CE | code | North-view copy routines for the 9 clip cases |
| 78CF-7917 | code+pad | North-view jump table (4-byte `JP nn` slots) |
| 7918-791C | code | South-view dispatch `LD HL,7A37; ADD HL,BC; JP (HL)` (the brief's "791C indirect jump") |
| 791D-7A36 | code | South-view (rotated 180 degrees) copy routines |
| 7A37-7A80 | code+pad | South-view jump table |
| 7A81-7AC0 | work | Ground sampling and shadow buffers (section 4) |
| 7AC1-7AD3 | data | Terrain height threshold table |
| 7AD4-7ADB | unused | zeros |
| 7ADC-7B9B | code | 7ADC samples the ground under the heli and hides shadow cells |
| 7B9C-7BB7 | unused | zeros |
| 7BB8-7DE4 | code | 7BB8 draws the shadow into the sprite tiles |
| 7DE5-7E0F | data | 8-byte mask temp, 4 survivor animation frames |
| 7E10-7F97 | code | 7E10 terrain projection (pillars) and sprite-tile insertion |
| 7F98-7FB8 | data | 33 sprite tile codes (11 rows x 3) |
| 7FB9-7FD4 | unused | $FF then zeros |
| 7FD5 | var | Control method 0-3 |

None of my routines handles physics. The flight model is in 80F9/8135 (core2's range). My code is the
landscape renderer and the variable block. Section 6 still documents all the mechanics I needed to
explain the variables.

## 2. World model and coordinate system (CODE+OBS)

* **World**: 14 rectangular islands. Island table at $F230: 20-byte records, $FF-terminated at $F348.
  Each island has its own tile map with a row stride of 128 bytes. Two islands may share the same
  128-byte rows, for example $9300 and $9354. Everything outside the islands is sea.
* **Coordinates**: X = 16-bit word at 7500, Y = word at 7502. Unit = 1 map tile = one 8x8 character
  cell on screen. North = -Y, East = +X. The high bytes (0..2) select a "sector" that each island
  record names (+0, +1). Map screen: column = X>>5 (0..22), row = Y>>5 (0..21), so the world is
  about 736 x 704 tiles.
* (X,Y) is the world tile in the **top-left corner of the 23x29 view window** (north view). The
  helicopter is always drawn over buffer cell (11,14). The tile under it is world (X+11, Y+14) in both
  views. F39A writes picked-up tiles back to the map at exactly (Y+14, X+11) (F451 `ADD A,$0E`, F467
  `ADD A,$0B`). The aircraft code uses the same offsets.
* Start / respawn: X=$0139, Y=$0170, heading 4 (E), altitude 8, landed on the Base island pad.
  The Base island record is $F294 (sector 1,1; X-low $1C-$82, Y-low $50-$88).
* Island record layout (bytes I could identify from my code; the rest are used by 8D5D/8DEE for the
  map screen):

| Off | Meaning |
|---|---|
| +0,+1 | X / Y high byte (sector) the island lives in |
| +2,+3 | X-low range in which any part of the island is in the window (= +6-22 .. +7+22) |
| +4,+5 | Y-low range (= +8-28 .. +9+28) |
| +6,+7 | X-low range for which the window lies fully inside the map. Map column 0 = world X (+6) |
| +8,+9 | Same for Y. Map row 0 = world Y (+8). Often +8 = +9, which means the map is exactly 29 rows high |
| +10,+11 | Address of the island tile map (row stride 128). Map width = (+7)-(+6)+23, height = (+9)-(+8)+29 |
| +12..+19 | Map-screen data: screen address, bitmap size, label pointer, attribute byte (used by 8D5D/8DEE) |

Island records (X/Y ranges are low bytes):

| Rec | Sector | X vis | Y vis | map X0-X1 | map Y0-Y1 | map |
|---|---|---|---|---|---|---|
| F230 | 2,1 | 5C-A8 | 80-B8 | 72-92 | 9C-9C | 9300 |
| F244 | 1,2 | 88-D3 | 00-39 | 9E-BD | 1C-1D | 9D00 |
| F258 | 1,0 | 57-A1 | 94-CC | 6D-8B | B0-AF | A900 |
| F26C | 0,0 | 74-CB | B8-F0 | 8A-B5 | D4-D4 | B600 |
| F280 | 2,0 | 28-65 | 58-90 | 3E-4F | 74-74 | C300 |
| F294 | 1,1 | 1C-82 | 50-88 | 32-6C | 6C-6C | CF80 (Base island) |
| F2A8 | 1,0 | 1C-5E | 58-91 | 32-48 | 74-75 | 9354 |
| F2BC | 1,2 | 78-B6 | 40-78 | 8E-A0 | 5C-5C | 9FD8 |
| F2D0 | 0,2 | 70-AD | 00-38 | 86-97 | 1C-1C | ADD8 |
| F2E4 | 1,0 | AC-FF | 7C-B4 | C2-E9 | 98-98 | B843 |
| F2F8 | 1,1 | 98-CB | 0C-50 | AE-B5 | 28-34 | 9337 |
| F30C | 1,1 | C4-FD | C0-FE | DA-E7 | DC-E2 | A735 |
| F320 | 0,2 | 30-6D | 30-6C | 46-57 | 4C-50 | C628 |
| F334 | 0,1 | 44-8B | B0-FB | 5A-75 | CC-DF | C64F |

(F258 has Y0=$B0 > Y1=$AF. The code tests the Y < Y0 case first, so the two clip bits never clash and
the island simply behaves as a 29-row map at Y0=$B0. INF: a harmless data quirk.)

### Views
* **North view** (7504=0): buffer cell (c,r) = world (X+c, Y+r). Screen up = north.
* **South view** (7504=1): buffer cell (c,r) = world (X+22-c, Y+28-r). This is the same window
  rotated 180 degrees about the heli cell (11,14). All sprite frames get +8 (mod 16). The projection
  uses the second set of pillar tables ($6C00-$73FF instead of $6300-$6AFF) so the faces of hills and
  buildings seen from the other side look right. Only these **two** views exist. N toggles between
  them (80AA). E/W views do not exist in the code (the brief's "N/S/E/W" is wrong, CODE).

## 3. VARIABLE GLOSSARY ($7500-$7563)

Init = value copied from $7564+ at game start. The per-life reset value (from $75C8+) is the same
unless the glossary says it survives a death. The reset table has $FF (= keep) for 751C/751D,
7543-754C, 754E, 754F and 7554. "Written by" / "Read by" list the containing routine start address
(80F9 = flight control, which starts at 80AA/8135). 5B24 (init LDIR) and 92C0 (reset loop) write every
byte and are left out.

| Addr | Name | Init | Meaning / units / range | Written by (routine) | Read by (routine) | Evidence |
|---|---|---|---|---|---|---|
| 7500-7501 | POS_X | $0139 | World X coordinate (16-bit, unit = 1 map tile = one 8x8 cell) of the top-left corner of the 23x29 view window in north view. The tile directly under the helicopter is world (X+11, Y+14). Heading 4 (E) increments, 12 (W) decrements. High byte (7501, 0..2) must equal island record +0. Only writer in play: 80F9 movement (patched INC HL/DEC HL at 81EF). Reset to $0139 each life. | 80F9 | 5B00 76D2 7777 7789 77AD 797F 80F9 87F0 9034 9246 F39A | OBS+CODE |
| 7502-7503 | POS_Y | $0170 | World Y (16-bit) of the view-window origin; heading 0 (N) decrements, 8 (S) increments. High byte 7503 (0..2) must equal island record +1. Writer 81F7 (patched INC/DEC at 81F6). | 80F9 | 76D2 775E 7789 77AD 7955 797F 80F9 87F0 9034 F39A | OBS+CODE |
| 7504 | VIEW | 0 | 0 = VIEW NORTH, 1 = VIEW SOUTH (view buffer is the same window rotated 180 deg; sprite frames +8 mod 16). Toggled by N in 80AA (writes at 80FA/8106, which also patch the projection-table page operands 7B18/7E35/7E41 = $63/$6C and 7E6D..7F05 = $66..$6A / $6F..$73). Read by 76D2, 7BB8, 87F0, 8B91, 8CA0. | 80F9 | 76D2 7BB8 80AA 87F0 8B91 8CA0 | OBS+CODE |
| 7505 | CRASHED | 0 | 1 = crashed (set only at 8B5F by the collision/landing check 8A7A). Main loop 5B5A -> 9246 death sequence; interrupt 83D1 -> crash noise 5FDC; 7F72 skips the shadow. Reset to 0 each life. | 8A7A | 5B00 7E10 83C2 | OBS+CODE |
| 7506 | HEADING | 4 | Current heading, 0..15 in 22.5 degree units (0=N, 4=E, 8=S, 12=W). Turns move it by +-2 (45 deg) so it stays even. Indexes the move table 826F (pairs of patch opcodes). Written 8149 (end of turn). | 80F9 | 80F9 8B91 91B4 | OBS+CODE |
| 7507 | HEADING_DISP | 4 | Heading shown by the helicopter body (8CA0) and shadow (7BB8) sprites, 0..15. During a turn it is set to heading+-1 (the in-between frame), then equals 7506 when the turn completes. | 80F9 | 7BB8 8CA0 | OBS+CODE |
| 7508 | HEADING_NEXT | 4 | Target heading of the turn in progress (7506+-2 mod 16); copied into 7506 and 7507 when the turn timer 7521 reaches 1 (8146). | 80F9 | 80F9 | CODE |
| 7509-750A | TMP_GFX | 0 | Scratch 16-bit pointer, not persistent. 7BB8: destination tile graphic in the tile set (starts FD48 = tile $69, -8 per cell up); 7F21: destination when copying graphics into the sprite tiles (from FCF8 = tile $5F); 85D4: tile graphics pointer (from FD30); 86AF: pointer into the 7A9F projected-code column list. | 7BB8 7E10 85D4 86AF | 7BB8 7E10 85D4 86AF | CODE |
| 750B-750C | TMP_ATTR | 0 | Scratch pointer into the per-tile attribute table FE00+code (sprite tiles $5F-$7F live at FE5F-FE7F): 7BB8 starts FE69, 7F21 FE5F, 85D4 FE66, 86AF FE66-rows. | 7BB8 7E10 85D4 86AF | 7BB8 7E10 85D4 86AF | CODE |
| 750D | ALTITUDE | 8 | Altitude in pixels, 0..$3C (60). UP adds 751A (1..3) per loop up to 60; DOWN/no-fuel subtracts 751B (1..3), trying to go below 0 sets 7514. Landing rounds it up to a multiple of 8 (8AFE). 84AE sets 8 at game start (heli parked on the pad). Uses: body drawn alt pixels above the ground row (86AF), collision level alt/4 vs terrain level (8A7A), aircraft level alt/8+1 (7533), winch length (F3F9). +2 once at the start of the death sequence (9252). | 80F9 84AE 8A7A 9246 | 80F9 86AF 8A7A 9246 F39A | OBS+CODE |
| 750E-750F | TMP_SPR | 0 | 7BB8 only: pointer to the current 8-byte cell of the shadow sprite (frame f = 7507 (+8 in south view): EDB0+72*f, 9 cells column-major bottom-up; first byte $FF = empty cell). | 7BB8 | 7BB8 | CODE |
| 7510-7511 | TMP_LIST | 0 | 7BB8 only: pointer to the entry of the 7A9F projected-code column list for the current shadow cell. | 7BB8 | 7BB8 | CODE |
| 7512-7513 | TMP_MASK | 0 | Word use (7CF5/7D21): pointer to the second mask tile when a shadow cell straddles an object tile. Byte use (7512 only): column counter 0..2 in 86AF (heli body) and F4D8 (rope). | 7BB8 86AF F39A | 7BB8 86AF | CODE |
| 7514 | TOUCHDOWN | 0 | Set to 1 when DOWN would take altitude below 0 (8269). 8A7A then requires all 9 ground cells at or below the heli level and descent rate <3, else crash; on success 7515=1 and this is cleared (8AFB). | 80F9 8A7A | 8A7A | CODE |
| 7515 | LANDED | 1 | 1 = landed. Set by the landing check (8AF7), cleared by pressing UP (820D, which also clears 752E and ends the control routine for that loop). While 1: no turning or moving (8152), collision check skipped (8A7A), cyclone buffeting ignored (7379), rotor sound off (83DF), slow rotor animation (8CD2). Start of game/life: 1. | 80F9 8A7A | 5B00 7378 80F9 83C2 8A7A 8CA0 | OBS+CODE |
| 7516 | NO_FUEL | 0 | 1 = fuel exhausted (82C1). Forces descent as if DOWN held (823C), disables UP (81FE) and thrust (81AB), silences rotor (83D9). Cleared when refuelling on the pad (84AA). 5B97: LANDED and NO_FUEL and not ON_PAD -> "NO FUEL" message and a life is lost (5BEC->92D0). Observed: heli that took off after only ~2 refuel loops (~2 lines) ran dry 467 frames later (s2) and then crashed. | 82A7 8470 | 5B00 80F9 83C2 8CA0 9246 | OBS+CODE |
| 7517 | FUEL_TICK | 0 | Fuel consumption timer: incremented each loop when not on the pad (82A7); when it exceeds $30 it resets and the fuel bar loses one pixel line, i.e. 49 loops per line, 40 lines per tank = 1960 loops (~3.6 min at ~5.5 frames/loop). When on the pad (8470) the bar gains one line every loop. | 82A7 8470 | 82A7 8470 | OBS+CODE |
| 7518-7519 | FUEL_PTR | $47BC | Screen address of the current top line of the FUEL bar (char column $1C). $47BC (row 5 line 7) = empty, full when the low byte reaches $1C (top of row 1 reached). 40 lines. Starts empty so the player refuels on the base pad (OBSERVED 7519 $47->$40 over 40 loops). | 82A7 8470 | 82A7 8470 | OBS+CODE |
| 751A | CLIMB_RATE | 0 | Climb acceleration: +1 per loop while UP held, max 3; altitude rises by this many pixels per loop (capped at 60). 0 when UP released. | 80F9 | 80F9 | OBS+CODE |
| 751B | DESCENT_RATE | 0 | Descent acceleration: +1 per loop while DOWN held (or out of fuel), max 3; altitude drops this many pixels per loop. Touching terrain with rate >=3 crashes (8AB7, 8B4E); a gentle contact resets it to 0 (8B56). Also accelerates the winch (F4AB). | 80F9 8A7A | 80F9 8A7A F39A | OBS+CODE |
| 751C-751D | TIME_PTR | (843A) | Screen address of the drain point of the TIME bar (char column $1E). 843A refills the bar (rows 1-5, 40 lines) at the start of each level and leaves $471E; 8284 clears one line every TIME_TICK period. When the low byte reaches $DE (5BCC) -> out of time (92C8, game over). Preserved across lives (reset value $FF). | 8284 843A | 5B00 8284 | OBS+CODE |
| 751E-751F | ALT_PTR | (84AE) | Screen address of the top line of the ALTIMETER bar (column $18); 82D4 moves it up one line (lighting it) per altitude pixel gained, 82FB down. Set by 84AE ($4818 after drawing 8 lines). | 82D4 82FB 84AE | 82D4 82FB | CODE |
| 7520 | (unused) | 0 | No reference anywhere (static scan for the address bytes + emulated access log). | - | - | CODE+OBS |
| 7521 | TURN_TIMER | 0 | Set to 3 when a turn starts (8177/81A8). Each loop it is decremented; at 1 the turn completes (7506=7507=7508), at 0 a new turn may start: a 45 degree turn takes 4 loops. LEFT+RIGHT together cancels. 7378 (cyclone) decrements it extra. | 80F9 | 7378 80F9 | OBS+CODE |
| 7522 | CONTROLS | 0 | Control state for this loop, written by 7FD6 (keyboard/joystick per 7FD5): bit0 forward (thrust), bit1 down, bit2 up, bit3 turn right, bit4 turn left. 7378 ORs random bits ($1A/$1B masks) or forces $12 near the cyclone. Read by 8135. | 7378 7FD6 | 7378 80F9 | OBS+CODE |
| 7523 | (unused) | 0 | No reference anywhere (static scan for the address bytes + emulated access log). | - | - | CODE+OBS |
| 7524 | PLANE_COL | 0 | 87F0: column of the aircraft relative to the view window: planeX - X + 12 (0..24); buffer column of its left edge is this -2. South view: 24-c. (Aircraft world X is in heli-ground-tile coordinates.) | 87F0 | 87F0 | CODE |
| 7525 | PLANE_ROW | 0 | 87F0: row of the aircraft: planeY - Y + 15 (0..30); buffer row = this -2. South view: 30-r. | 87F0 | 87F0 | CODE |
| 7526 | UI_FLAGS | 0 | Bit0: M key held (debounce). Bit1: map screen is displayed (main loop runs 8F12 instead of the 762C view blit). Bit2: N key held (debounce). Bit3: set when the map is closed (never read). Bit4: map must be redrawn (5B6F -> 8D0E/8D5D/8E5C/8F6A, then cleared). | 5B00 80AA 80F9 | 5B00 80AA 80F9 | OBS+CODE |
| 7527 | SPEED | 0 | Forward momentum 0..7. Forward held: +1 per loop (max 7) and the move direction 753B := heading. Released (or no fuel): -1 per loop. After the update, if >0 the heli moves exactly 1 tile in X and/or Y (direction 753B) - speed does NOT scale the distance per loop, it only gives up to 6 loops of coasting after release (OBSERVED). Also: rotor pitch (83C2), speed bar (91B4), wave scroll (8BB1). | 80F9 E3B4 | 80F9 83C2 8B91 91B4 | OBS+CODE |
| 7528 | TIME_TICK | 0 | Incremented every loop (8284); when it reaches the threshold (operand at 828C: $FF on level 1, reduced by 15 each further level by 8321) it is reset and one TIME bar line is cleared. Level 1: about 41 ticks x 255 loops = ~10450 loops (~19 min). | 8284 843A | 8284 | OBS+CODE |
| 7529-752A | TMP_LIST2 | 0 | 86AF / F4F8: pointer into the 7A9F column list (codes in front of the helicopter body/rope). | 86AF F39A | 86AF | CODE |
| 752B-752C | TMP_ATTR2 | 0 | 86AF / F4F1: pointer into the sprite-tile attribute table (FE66-rows...). | 86AF F39A | 86AF | CODE |
| 752D | SOUND_OFF | 0 | When 1 the interrupt handler 83C2 does nothing (no rotor/winch sound). Set to 1 by the menu (E282) and at step $12 of the death sequence (9278); 0 at game start. | 9246 E280 | 83C2 9246 | CODE |
| 752E | ON_PAD | 1 | 1 = landed with all nine cells helipad tiles ($83/$89) (8AF2). While 1: refuel instead of fuel drain (8470), and if on Base island with 5 crates -> next level (5BB6). Cleared on take-off (8210). Starts 1. | 80F9 8A7A | 5B00 8470 | OBS+CODE |
| 752F | PLANE_DRAWN | 0 | Cleared at 87F1; set at 898C when the first visible aircraft has its sprite built (later aircraft in the same loop are not drawn). | 87F0 | 87F0 | CODE |
| 7530 | PLANE_NEAR | 0 | Cleared each loop (87F4). Bit0: some aircraft with planeX-X+22 in 0..44; bit1: planeY-Y+25 in 0..50. Value 3 makes 91B4 flash the BEWARE AIRCRAFT warning. (Info screen E3DD also writes it.) | 87F0 E3B4 | 87F0 91B4 | OBS+CODE |
| 7531-7532 | (unused) | 0 | No reference anywhere (static scan for the address bytes + emulated access log). | - | - | CODE+OBS |
| 7533 | HELI_LEVEL | 3 | Updated by 8A7A in 4 of every 8 airborne loops: (alt>>3)+1, max 7. The aircraft altitude level (87EF) moves 1 step toward it each loop (89CA); a collision needs the two to match (8B36). | 8A7A | 87F0 | OBS+CODE |
| 7534 | AIR_TICK | 0 | Incremented every airborne loop (8A8B). | 8A7A | 8A7A | OBS+CODE |
| 7535 | WAVE_X | 0 | Column phase of the random sea-wave sparkle grid (8B91; grid spacing 5 columns); shifted per loop while moving by the heading table 8C66 (north) / 8C77 (south), values >=9 (incl. -1) wrap to 4. | 8B91 | 8B91 | OBS+CODE |
| 7536 | WAVE_Y | 0 | Row phase of the wave grid (spacing 4 rows); >=7 wraps to 3. | 8B91 | 8B91 | OBS+CODE |
| 7537 | WAVE_TICK | 0 | Every 3rd loop (when it wraps) a new random wave pattern pointer is chosen (8BA6). | 8B91 | 8B91 | OBS+CODE |
| 7538-7539 | WAVE_PTR | 0 | Pointer $0100+RND into the ROM; its bytes AND 3 give the wave tile codes 0..3 written into empty sea cells (8C50). | 8B91 | 8B91 | OBS+CODE |
| 753A | ROTOR_FRAME | 0 | 8CA0: index of the rotor XOR overlay applied to the heli body sprite: airborne 0..1 using pages $70/$71, landed or out of fuel 0..3 using pages $67..$6A. | 8CA0 | 8CA0 | OBS+CODE |
| 753B | MOVE_DIR | 4 | Set to 7506 every loop forward is held (81D9); while coasting the heli keeps moving in this direction even if it turns (OBSERVED). Compass shows it when SPEED>0 (91DA). | 80F9 | 80F9 91B4 | OBS+CODE |
| 753C-753D | MAP_ROW_PTR | 0 | 8D5D: screen address where the current island row of the map is drawn (from island record +12/+13, down one pixel line per row). | 8D5D | 8D5D | CODE |
| 753E-753F | MAP_PTR | 0 | 8D5D: running output pointer within the row. | 8D5D | 8D5D | CODE |
| 7540 | MAP_HX | 0 | 9034: helicopter column on the 23x22 map grid = X>>5 (0..22; outside -> 0 or 22 and 754D++). | 9034 | 8F6A 9034 | OBS+CODE |
| 7541 | MAP_HY | 0 | 9034: helicopter row = Y>>5 (0..21; outside -> 0 or 21 and 754D++). | 9034 | 8F6A 9034 | OBS+CODE |
| 7542 | MAP_BLINK | 0 | 8F12: incremented each loop while the map is shown; markers drawn for values 4..6, removed and reset at 7. | 8F12 | 8F12 | OBS+CODE |
| 7543-7544 | MAP_HATTR | 0 | 8F6A: attribute address of the heli marker (original attribute saved at 9027, marker attr $7A). | 8F6A | 8F12 | CODE |
| 7545-7546 | MAP_HPIX | 0 | 8F6A: pixel address of the heli marker (8 bytes underneath saved at 901F). | 8F6A | 8F12 8F6A | CODE |
| 7547-7548 | MAP_CATTR | 0 | 8F6A: attribute address of the cyclone marker (saved at 9030). | 8F6A | 8F12 | CODE |
| 7549-754A | MAP_CPIX | 0 | 8F6A: pixel address of the cyclone marker (saved gfx at 9028). | 8F6A | 8F12 8F6A | CODE |
| 754B | CYC_X | 2 | Cyclone column on the map grid, kept in 1..21. 8321 places it at 2 or $14 at random at game start; moved +-1 by 9034. | 8321 9034 | 8F6A 9034 | OBS+CODE |
| 754C | CYC_Y | 2 | Cyclone row, kept in 1..20; initial 2 or $13 at random. | 8321 9034 | 8F6A 9034 | OBS+CODE |
| 754D | OFF_MAP | 0 | 9034: counts X and Y out of the map range; used to adjust the DANGER bar (9140). | 9034 | 9034 | CODE |
| 754E | CYC_TICK | 0 | 9034: +1 per loop; at 25 -> 0 and the cyclone moves one map cell. Forced to $18 after hitting an edge (moves again next loop). | 9034 | 9034 | OBS+CODE |
| 754F | CYC_LEG | 0 | 9034: +1 per cyclone move; at 9 a new direction set (16 random choices from 9178) is chosen. Forced to 8 at an edge. | 9034 | 9034 | OBS+CODE |
| 7550 | CYC_DIST | 0 | Chebyshev distance between (7540,7541) and (754B,754C), max 15 (9138). Drives the DANGER bar; DANGER flashes when <6; <5 (level 1) or <6 (later levels: operand 5B93) calls 7378 buffeting. | 9034 | 5B00 9034 | OBS+CODE |
| 7551 | PICK_TILE | 0 | F3E3: tile code (from F51B) that replaces the crate/survivor tile in the island map (written at F472, world tile (X+11,Y+14)). | F39A | F39A | OBS+CODE |
| 7552-7553 | ISLAND | 0 | 76D2 (7724): island record whose window area contains (X,Y); unchanged over open sea. 5BBD: =$F294 (Base island) + ON_PAD + 5 crates -> next level. F444: used to locate the island map for removing picked-up objects. | 76D2 | 5B00 F39A | OBS+CODE |
| 7554 | CRATES | 0 | Incremented when a crate pickup starts (F48A, not for survivors); HUD box at 5ACA-2*n turned red ($02). 5 crates + on Base pad = level complete (5BAF). Reset at level start (8391); kept over lives (reset $FF). | 8321 F39A | 5B00 8321 F39A | OBS+CODE |
| 7555 | WINCH | 0 | Set to rope length-1 when an object is hooked (F441); each loop decreases by 1+min(751B,...) (F4AB); at 0 the pickup completes: +50 (survivor) or +250 (crate) via 6602. Interrupt beeps while non-zero (83E4). OBSERVED: $0D,9,5,4,3,2,1,0. | F39A | 83C2 F39A | OBS+CODE |
| 7556 | ROPE_STATE | 0 | F39A: 0 = no rope; 1/2 = rope being lowered over an object (OBSERVED 1 then 2 before the hook); reset on hook (F474) or when leaving the object. | F39A | F39A | OBS+CODE |
| 7557-7558 | PICK_SPR | 0 | F3DF: sprite of the object being lowered/winched ($F52F crate, $F548 survivor); low byte compared at F477/F4BB. | F39A | F39A | OBS+CODE |
| 7559-755A | (unused) | 0 | No reference anywhere (static scan for the address bytes + emulated access log). | - | - | CODE+OBS |
| 755B | SURV_ANIM1 | 0 | F34A: survivor waving animation; at 4 copies 7DEE, at 8 copies 7DF6 (7 bytes) into tile $31 graphics (FB88) and resets. | F34A | F34A | OBS+CODE |
| 755C | SURV_ANIM2 | 0 | F34A: at 3 copies 7DFE, at 6 copies 7E06 (8 bytes) into tile $32 graphics (FB90). | F34A | F34A | OBS+CODE |
| 755D | ROTOR_SND | 0 | Interrupt: phases 0-1 = 10 short pulses (delays $12), phases 2-3 = 6 long pulses ($24); delays reduced by 2*SPEED. | 83C2 | 83C2 | OBS+CODE |
| 755E-7563 | (unused) | 0 | No reference anywhere (static scan for the address bytes + emulated access log). | - | - | CODE+OBS |

**Unused bytes** (CODE+OBS: no static reference, no access in any emulated scenario): 7520, 7523, 7531,
7532, 7559, 755A, 755E-7563. 7558 is only the high byte of the word 7557.

### Quick reference by topic
* Position/view: 7500 X, 7502 Y, 7504 view, 7552 current island.
* Flight: 750D altitude (px, 0-60), 751A climb rate, 751B descent rate, 7506 heading, 7507 displayed
  heading, 7508 target heading, 7521 turn timer, 7527 speed (momentum 0-7), 753B travel direction,
  7522 controls, 7514 touchdown, 7515 landed, 752E on pad, 7505 crashed.
* Resources: 7518 fuel bar pointer, 7517 fuel tick, 7516 out of fuel, 751C time bar pointer, 7528 time
  tick, 751E altimeter bar pointer. Lives = 3 - (9245) (lives lost; 9245 is not in this block).
* Cyclone: 754B/754C position on the map grid, 754E move timer, 754F leg counter, 7550 distance,
  7540/7541 heli on the map grid, 754D off-map count.
* Aircraft: 7524/7525 view position, 7530 proximity bits, 752F drawn flag, 7533 heli level. The aircraft
  level itself is at 87EF; the aircraft list is at E86C.
* Pickups: 7554 crates (0-5), 7555 winch countdown, 7556 rope state, 7557 object sprite, 7551
  replacement tile. Score is ASCII digits at 661E-6624 (not in this block).
* Animation/scratch: 7535-7539 sea waves, 753A rotor frame, 755B/755C survivor animation, 755D rotor
  sound, 7526 UI flags, 7509/750B/750E/7510/7512/7529/752B renderer scratch pointers, 753C/753E map
  drawing, 7542-754A map markers.

## 4. Other variables and tables in this range

| Addr | Meaning | Users |
|---|---|---|
| 7A81-7A89 | Raw map codes (before projection, including aircraft tiles $F6-$FE and wave codes 1-3) of buffer columns 10-12, rows 15/14/13. Column-major, bottom first: index 3c+k = (col 10+c, row 15-k). **7A85 = tile directly under the helicopter** | W 7E10. R 7ADC, 8ACA (landing check), F3A3 (crate/survivor check) |
| 7A8B-7A93 | Terrain level of the same 9 cells, 0..17 (unit = 4 altitude px). 0 for object tiles $17-$26 | W 7ADC. R 8A9B (collision) |
| 7A95-7A9D | Shadow offset = level>>1 (rows). Bit 7 = base tile is $18. $FF = cell hidden | W 7ADC. R 7BB8 |
| 7A9F-7ABF | 33 projected codes: columns 10, 11, 12 (11 each), rows 15 up to 5, bottom first. Bit 7 set by 7D9C to mark a cell that got a masked shadow | W 7ADC, 7D9C. R 7BB8, 86AF (via 7AA2 + (alt+1)/8), F4F4 (via 7AAC) |
| 7AC1-7AD3 | Height thresholds (7AC2-7AD3, 18 bytes): 0F 10 2E 30 56 58 89 8C A5 B2 C2 D0 D9 E4 EC F0 F6 FF. level(code) = number of entries <= code. Code $FF itself must never occur (the loop would run off the table) | 7ADC |
| 7DE5-7DEC | 8-byte temp for a masked shadow cell | 7BB8 |
| 7DEE/7DF6 (7 bytes each) | Survivor animation frames copied into tile $31 lines 0-6 (FB88) | F34A |
| 7DFE/7E06 (8 bytes each) | Survivor animation frames for tile $32 (FB90) | F34A |
| 7F98-7FB8 | Sprite tile codes. Row r (0..10 = buffer rows 5..15) = $5F+r, $6A+r, $75+r | 7F7D |
| 7FD5 | Control method: 0 keyboard, 1 Interface 2, 2 Kempston, 3 Protek/AGF (= menu key - '2', E2BA) | R 7FD6, E299 |
| 783E | Self-modified operand of `LD BC,nn` at 783D: width of the north-view clipped copy | W 77BF, 7818, 785D, 7897, 78BA |
| 79A7 | Self-modified operand of `LD B,n` at 79A6: width of the south-view clipped copy | W 792F, 7948, 7987, 79CB, 7A02, 7A22 |
| 7B18 | Operand of `LD H,$63` at 7B17: pillar page for the first-tile lookup ($63 N / $6C S) | W 8113 |
| 7E35, 7E41 | Operand of `LD D,$63`: pillar base page ($63 N / $6C S) | W 8116, 8119 |
| 7E6D, 7E93, 7EB9, 7EDF, 7F05 | Pillar pages P+3..P+7 for rows 24-28 ($66..$6A N / $6F..$73 S) | W 811E-812E |

Related tables outside my range, used by my code: $F74E-$F9E8 view tile buffer (23 x 29, row stride 23);
$FA00+8*code tile graphics (tiles $00-$7F); $FE00+code tile attributes; $6300-$6AFF (north) and
$6C00-$73FF (south) pillar tables; $ED68+72*(f+1) shadow sprite frames (16 frames x 9 cells x 8 bytes,
$EDB0-$F22F); $E930+72*f helicopter body frames (8CA0); $F230 island table.

## 5. Routines

### 7378: cyclone buffeting (CODE, OBS)
Called by the main loop at 5B94 when `CYC_DIST(7550) < 5`. The `CP 5` operand at 5B93 is set to 5 by
8321 at game start and to 6 after each completed level. Input A = distance.
```
if LANDED: return
if d >= 4: CONTROLS |= RND & $1A          ; random down / right / left
elif d >= 2: CONTROLS |= RND & $1B        ; random forward / down / right / left
else: if TURN_TIMER: TURN_TIMER -= 1; CONTROLS = $12   ; forced down + left (spin and sink)
```
RND = L from 8B74, the RNG that updates SEED 5C76. It runs after 7FD6 has read the player's input, so
random bits only add to what the player presses (except for d<2). OBS (s1, s3): with distance 2-4 the
heli turned and changed speed on its own and lost altitude, and in s1 it was dragged down into a crash.

### 762C: view blit (CODE)
Copies buffer rows 0-21 (23 cells each, sequential from $F74E) to screen columns 0-22, rows 0-21, in
three passes for the screen thirds (8, 8, 6 rows). attr = (FE00+code). If code < $80, 8 pixel bytes
come from FA00+8*code. Codes $80-$FF are solid tiles (INK = PAPER). Only their attribute is written,
which saves time.

### 76D2: view-window builder (CODE, OBS)
1. Clears the 667-byte buffer F74E-F9E8 to 0 (raw sea).
2. Linear search of F230 for the island whose sector = (X>>8, Y>>8) and whose visibility ranges contain
   (X&255, Y&255). None: return (open sea). Found: `ISLAND(7552) = record` (OBS 7552 = $F294 on base,
   $F244 at the s2 crate site).
3. Clip flags: bit2 = X < X0, else bit3 = X >= X1. bit4 = Y < Y0, else bit5 = Y >= Y1. (X0 = +6,
   X1 = +7, Y0 = +8, Y1 = +9, xlo = +2, xhi = +3, ylo = +4, yhi = +5.)
4. Dispatch through a 4-byte-slot table (78CF north, 7A37 south). Width w and rows n of the visible
   rectangle:

| Slot | Case | w (cols) | n (rows) | map source | buffer destination (north) |
|---|---|---|---|---|---|
| 0 | inside | 23 | 29 | (X-X0, Y-Y0) | (0,0) |
| 4 | W edge | X-xlo+1 | 29 | (0, Y-Y0) | right-aligned: column 23-w |
| 8 | E edge | xhi-X+1 | 29 | (X-X0, Y-Y0) | column 0 |
| 16 | N edge | 23 | Y-ylo+1 | (X-X0, 0) | bottom-aligned: row 29-n |
| 20 | NW | X-xlo+1 | Y-ylo+1 | (0,0) | (23-w, 29-n) |
| 24 | NE | xhi-X+1 | Y-ylo+1 | (X-X0, 0) | (0, 29-n) |
| 32 | S edge | 23 | yhi-Y+1 | (X-X0, Y-Y0) | (0,0) |
| 36 | SW | X-xlo+1 | yhi-Y+1 | (0, Y-Y0) | (23-w, 0) |
| 40 | SE | xhi-X+1 | yhi-Y+1 | (X-X0, Y-Y0) | (0,0) |

   The map address is base + 128*row + col (helpers 775E = row only, 7777 = column only, 7789 =
   both). Copy loops: 7803 (full width, A rows), 783D (w from 783E), south 796D (full width,
   reversed), 79A6 (w from 79A7, reversed). The south routines write the same rectangle mirrored in
   both axes: north buffer cell (c,r) goes to south cell (22-c, 28-r), so the south buffer starts at
   F9E8 and runs backwards.
   For a remake: `buf[r][c] = worldTile(X+c, Y+r)` (north) or `worldTile(X+22-c, Y+28-r)` (south),
   where worldTile is the island map byte when inside an island rectangle, else 0. At most one island
   is ever visible; islands are more than 23x29 tiles apart.

### 7E10: terrain projection and sprite tiles (CODE, OBS by screenshots)
Runs every loop after 87F0 (aircraft tiles placed), 8B91 (sea waves placed) and 8CA0 (heli body sprite
built).
1. Save the raw 3x3 block (cols 10-12, rows 15..13) to 7A81.
2. Row 0: `cell = T0[code]`.
3. Rows 1..23, top to bottom: for each cell with raw code c, write `T_k[c]` at row r-k for k = 0,1,2...
   T_k is page P+k (P = $63 north, $6C south). Entry $FE = transparent (skip, keep moving up),
   $FF = stop. Nearer rows overwrite farther rows (painter's algorithm), so hills and buildings hide
   what is behind them. Examples (north pages): raw 00 -> 80 (solid sea); 03 -> 02; 10 -> 87,81;
   30 -> 87,87,81; 58 -> 87,87,87,81; B2 -> 89x5,83; D0 -> 89x6,83; E4 -> 87,87,5A,5A,5A,5A,59,2E;
   aircraft F6 -> 33,FE,FE,3C (the aircraft body tiles $3C-$44 are drawn 87EF rows above their shadow;
   87F0 rewrites those pillar entries).
4. After row 15 (7F21): copy the 33 cells of columns 10-12, rows 5-15 (graphics, plus attribute
   FE00+code) into the 33 private sprite tiles $5F-$7F (graphics FCF8-FDFF, attributes FE5F-FE7F).
   Solid tiles ($80+) copy tile 0's graphic. Then call 7ADC (shadow) unless CRASHED, and replace those
   33 buffer cells with the sprite tile codes 7F98. Because columns are contiguous in the tile set,
   each sprite column is an 88-line bitmap strip. The shadow (7BB8) and body (86AF) can therefore be
   drawn at any pixel height. The remaining rows 16-23 are projected afterwards and can cover the
   sprite tiles, so terrain in front hides the helicopter.
5. Rows 24..28 (off screen): row 24+j adds only the part of tall pillars that reaches row 21: codes >=
   ($54, $80, $B2, $D0, $E4)[j], starting at pillar level 3+j on row 21.

### 7ADC: ground sampling and shadow visibility (CODE, OBS)
1. Copy the projected codes of cols 10-12, rows 15..5 into 7A9F (33 bytes).
2. For each of the 9 raw codes: `level = count(thresholds <= code)`, `7A8B[i] = level`,
   `7A95[i] = level >> 1`. If the first projected tile T0[code] is in $17-$26 (objects such as trees,
   houses and people; INF), then `7A8B[i] = 0` (no collision height) and, for T0 = $18, bit 7 of
   7A95[i] is set.
3. Per column, with offsets h15, h14, h13: hide row-13 if h13+2 < h15 or h13+1 < h14; hide row-14 if
   h14+1 < h15. Equal cases are decided by the bit-7 flags (see the ctl comments at 7B33-7B91).
4. Jump to 7BB8.

### 7BB8: shadow drawing (CODE)
Frame f = HEADING_DISP (+8 mod 16 in the south view). Source = EDB0 + 72f (9 cells, column-major,
bottom first, $FF = empty cell). Each shadow cell (col 10+c, row 15-k) goes into the sprite tile h
rows higher (h = 7A95 entry). The tile displayed there (projected code T from 7A9F, bit 7 ignored)
decides how:
* T < $17 (flat ground/sea): attribute INK := 0, cell graphic **replaced** by the shadow.
* $17 <= T < $27 (objects): the shadow is ANDed with a mask tile ($23 at FB18 for $19/$1B/$21, $25
  at FB28 otherwise, +8 = $24/$26 when flagged). It is ORed or copied in, and for $21/$22 it continues
  into the trunk tile below ($1D-$20) with the second half of the mask. Some cases set the attribute
  to $60 (green paper, black ink) or $68 (cyan paper).
* $27 <= T < $30: INK := 0, shadow ORed in.
* T >= $30: not drawn (the cell is hidden by something tall).
* h >= 8 (cell is an aircraft tile, level 16-17): attribute $68 and OR at the unraised cell.

### Helpers and dispatch
775E, 7777, 7789: map addresses (see 76D2). 7918: south dispatch. 78CF, 7A37: jump tables.
77AD-78CE, 791D-7A36: the 18 copy routines. Each is a short entry that computes w, n, source and
destination and then jumps into one of the four copy loops.

## 6. Game mechanics needed to explain the variables (owned by other areas; evidence noted)

**Flight controls (80AA/8135, CODE+OBS).** Every loop:
* Turning: only when TURN_TIMER = 0 and not LANDED. LEFT gives disp = h-1, target = h-2; RIGHT gives
  +1/+2 (mod 16); TURN_TIMER = 3. Pressing both cancels. The turn completes when the timer reaches 1.
  Result: **45 degrees per 4 loops**, 8 effective headings, 16 sprite frames (OBS: 1004-1023 = 19
  frames per 45 degrees).
* Thrust: FORWARD (and not NO_FUEL) gives SPEED = min(SPEED+1, 7) and MOVE_DIR = heading. Otherwise
  SPEED = max(SPEED-1, 0), and if it reaches 0 there is no move. While SPEED > 0 the position changes
  by exactly one tile per loop in each axis given by the 826F table for MOVE_DIR:
  0 N (0,-1), 2 NE (+1,-1), 4 E (+1,0), 6 SE (+1,+1), 8 S (0,+1), 10 SW (-1,+1), 12 W (-1,0),
  14 NW (-1,-1). Diagonals are not normalised. **Speed does not change the rate**: it only gives
  momentum. After FORWARD is released the heli coasts 6 more tiles from speed 7 (OBS s3: X $42 to
  $48), still in MOVE_DIR even if it turns meanwhile (OBS).
* UP (not NO_FUEL): if LANDED: take off (LANDED = ON_PAD = 0) and end the routine. Otherwise
  CLIMB_RATE = min(+1, 3) and the altitude rises by CLIMB_RATE pixels (max 60). Not pressed:
  CLIMB_RATE = 0.
* DOWN or NO_FUEL (and not LANDED): DESCENT_RATE = min(+1, 3) and the altitude falls by that much.
  Trying to go below 0 sets TOUCHDOWN. Not pressed: DESCENT_RATE = 0.
* OBS: climbing from 8 to 60 took about 19 loops (rates 1, 2, 3, 3, ...; frames 502-610).

**Collision and landing (8A7A, CODE+OBS).** b = alt>>2. For each of the 9 cells: if b >= level, count
it (C). Otherwise, for level < 15: crash if DESCENT_RATE >= 3, else DESCENT_RATE = 0 (soft contact,
not counted). For level >= 15 (aircraft tiles): crash if alt>>3 = aircraft level - 1 (or both are 7),
else count it. Then:
* TOUCHDOWN set: crash unless C = 9 and DESCENT_RATE < 3, otherwise go to the landing check.
* Not set: C = 9 means flying clear; C = 0 means landing check; 0 < C < 9 means crash (clipped a
  hillside).
* Landing check: every cell's top pillar tile must be landable. Codes < 3 (water) or $2D-$7F crash, as
  do $80 (sea) and $86. $83/$89 are helipad tiles. If all 9 are pad: ON_PAD = 1. Then LANDED = 1,
  TOUCHDOWN = 0 and altitude = (alt+7) & ~7 (the bar is updated to match).
* OBS s2: out of fuel, descending at rate 3 over a crate site, crash at frame 794.

**Fuel (8470/82A7, CODE+OBS).** 40 bar lines. Drains one line per 49 loops whenever not ON_PAD (even
when landed elsewhere). On the pad it refills one line per loop with a beep. Empty sets NO_FUEL
(forced descent). NO_FUEL + LANDED + not ON_PAD prints "NO FUEL" and costs a life (5B97).

**Time (8284/843A, CODE).** 40-line bar refilled at each level start. One line is lost every T loops,
T = 255 on level 1 and 15 fewer per level after that (operand at 828C). When the pointer low byte
reaches $DE, "NO TIME" is shown and the game is over (92C8 sets lives lost = 2 and then takes the life
path). Level 1 is about 41 x 255 loops, roughly 19 minutes of emulated time.

**Lives (9246/928A, CODE).** 3 lives; 9245 counts lives lost. Death sequence: altitude +2 once, then 24
redraw steps. The body sprite (6950) is cleared each step; the normal body is drawn for the first 3
steps and the explosion frames (72 bytes each, from F550, 92ED) are XORed in for the first 5. Sound is
muted when the step counter reaches $12 (7th step). The life icon turns red. On the 3rd loss: JP
E280 (menu). Otherwise the fuel bar is drained to empty, the variables are restored from 75C8 and play
resumes at 5B36 on the Base pad (refuel needed).

**Cyclone (9034, CODE+OBS).** Position on the 23x22 map grid: (754B, 754C) in 1..21 x 1..20. Start
column 2 or 20, row 2 or 19 (random corner, 8321). It moves one grid cell (= 32 world tiles) every 25
loops. Every 9 moves (or on reaching an edge) it picks one of 16 direction sets from 9178; each move
picks a random member of the set (dx,dy table 9198: W, NW, N, NE, SW, S, SE, E). Distance =
max(|hx-cx|, |hy-cy|) in grid cells, capped 15. DANGER flashes below 6; buffeting below 5 (later
levels below 6), see 7378.

**Aircraft (87F0, CODE+OBS).** The list is at E86C (5-byte records: type/direction, X word, Y word in
heli-ground-tile coordinates), driven by a script E740-E85A advanced every 28 loops (8A6B). An
aircraft is drawn when within -12..+12 columns and -15..+15 rows of the heli. BEWARE AIRCRAFT shows
when PLANE_NEAR = 3. The aircraft altitude level (87EF) chases HELI_LEVEL by 1 per loop.

**Pickups (F39A, CODE+OBS s2).** The tile under the heli (7A85) is matched against the crate codes $8B,
$57, $2F, $0F (replacement tiles $58, $30, $10, $04) and the survivor pairs $89/$8A, $55/$56,
$2D/$2E. The rope length depends on the altitude above the object. On the hook: WINCH = length-1,
the map tile is replaced and CRATES += 1 (crates only). WINCH counts down by 1 + DESCENT_RATE per
loop. At 0 the score goes up by 50 (survivor) or 250 (crate). OBS: hooked at frame 629 with altitude
about $23, winch $0D to 0 in 7 loops. **Level completion**: CRATES = 5 and ON_PAD and ISLAND = $F294.
Bonus = 2 x (250 - 64 x lives lost). The cyclone keeps its position, the time bar is refilled, and
the difficulty patches apply (5B93 = 6, 828C -= 15).

**Sea waves (8B91, CODE+OBS).** Every loop, raw-sea cells (code 0) on a lattice of every 5th column
and every 4th row (phase 7535/7536) get a random wave code 0-3 from ROM bytes $01xx (re-seeded every 3
loops). The lattice phase shifts with the heading table while moving, so the waves scroll with the
ground.

## 7. External routines called or referenced (one-line guesses)
* 5B00/5B36/5B3C: game start / per-life entry / main loop. 5EEC (via FE92): random placement of 5
  crates among 38 candidate map positions. 5FDC: crash noise (interrupt). 6072: random tile variants.
  6600/6602: add B to the score and reprint it (6F00). 7FD6: read the controls into 7522.
  80AA: M/N keys plus flight control. 80F9: set north view (also the 5B36 entry). 8284: time bar tick.
  82A7: fuel drain. 82D4/82FB: altimeter bar up/down. 8321: level start (crate boxes, cyclone corner,
  difficulty). 83C2: IM2 interrupt (rotor/winch/crash sounds). 843A: fill the time bar. 8470: refuel
  or drain. 84AE: reset the altimeter. 84D6: clear the screen. 84F4: draw the HUD (font 7400, layout
  7300). 8580/8582/8585: print VIEW NORTH/SOUTH. 859A: print chars (font 6028). 85D4: redraw
  foreground object tiles over the heli sprite tiles. 86AF: draw the heli body (6950) into the sprite
  tiles at altitude. 87BC: high-score update. 87F0: aircraft. 8A7A: collision/landing. 8B74: RNG.
  8B91: sea waves. 8CA0: build the heli body frame + rotor overlay into 6950. 8D0E: clear the view
  area. 8D5D/8DEE: draw the map islands and labels. 8E5C/8EE8: map border (chars 7438-7490).
  8F12/8F6A: map markers (heli/cyclone) blinking. 9034: cyclone movement and distance. 91B4: compass,
  speed bar, BEWARE AIRCRAFT. 9246: death sequence. E280: main menu. E3B4: info screen. F34A: survivor
  animation. F39A: winch/pickup.

## 8. Open questions
* Exact visual meaning of the tile codes (which codes are trees, houses, survivors, pads). I only know
  them from how the code treats them ($17-$26 objects, $83/$89 pad, <3 water, $F6-$FE aircraft, $3C-$44
  aircraft body). The data/graphics agent should confirm.
* Levels 15-16 (raw codes $EC-$F5) are handled like aircraft in 8B30. Do such raw codes occur in island
  maps, or only as aircraft tiles?
* The full rope-length and rope-state logic in F39A (7556 values, 13/17 pixel thresholds) needs a
  closer read by the frontend agent. My notes on 7555/7556 rest on one observed pickup.
* 7526 bit 3 is written but never read (leftover?).
* The 73B2 fragment (sets CRASHED) and the NOPs at 737F and 7F7A look like removed debug or cheat code.
