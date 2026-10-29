c $7FD6 Read the selected control device into the input bitmap 7522
D $7FD6 Called once per main-loop iteration (5B8C). Reads the device chosen on the main menu (7FD5 = menu key - "2": 0 keyboard, 1 Sinclair Interface 2, 2 Kempston, 3 Protek/AGF cursor) and stores a 5-bit control word in 7522: bit 0 = forward thrust, bit 1 = descend, bit 2 = climb, bit 3 = turn right (clockwise), bit 4 = turn left. The cyclone code at 7378 may later OR random bits into 7522 (wind buffeting).
R $7FD6 I:(7FD5) control method 0-3
R $7FD6 O:(7522) control bits (0 fwd, 1 down, 2 up, 3 right, 4 left)
N $7FD6 Keyboard (7FD5=0). Any key in a half-row counts, so the documented keys X / 1 / Q are really whole half-rows.
 $7FD6 Dispatch on the control method
 $7FE8 B accumulates the control bits
 $7FEA Half-row SHIFT/Z/X/C/V: any key = forward (bit 0)
 $7FF6 Half-row 1-5: any key = climb (bit 2)
 $8002 Half-row Q-T: any key = descend (bit 1)
 $800E Half-row P/O/I/U/Y: P = turn right (bit 3), O = turn left (bit 4)
 $801E Store the control word
N $8023 Sinclair Interface 2 (7FD5=1): both joystick ports are read and merged.
 $8023 Keys 0,9,8,7,6 (port 2: fire, up, down, right, left) map directly onto bits 0-4
 $802B Keys 1-5 (port 1): 5 fire -> bit 0
 $8035 4 (up) -> bit 1 (descend)
 $803B 3 (down) -> bit 2 (climb)
 $8041 2 (right) -> bit 3
 $8047 1 (left) -> bit 4
N $8052 Kempston (7FD5=2): port 31, active-high bits 0 right, 1 left, 2 down, 3 up, 4 fire. Joystick forward (up) descends, pulling back climbs, like an aircraft stick.
 $8054 Fire -> forward (bit 0)
 $805C Up -> descend (bit 1)
 $8062 Down -> climb (bit 2)
 $8068 Right -> bit 3
 $806E Left -> bit 4
N $8079 Protek/AGF cursor joystick (7FD5=3): 5 left, 6 down, 7 up, 8 right, 0 fire.
 $807B Key 5 -> left (bit 4)
 $8085 Half-row 0-6: 6 -> climb (bit 2)
 $808F 7 -> descend (bit 1)
 $8095 8 -> right (bit 3)
 $809B 0 -> forward (bit 0)
u $80A6 Unused
B $80A6,4,4
c $80AA Check the M (map) and N (view) keys, then process the flight controls
D $80AA Called once per main-loop iteration (5BAC) except when the helicopter is landed away from the base with an empty tank. Reads half-row SPACE/SYM/M/N/B once. M toggles between the island view and the map; N toggles the view direction NORTH/SOUTH. Both are edge-triggered through latch bits in 7526 and each press beeps. Execution then falls through into the flight-control code at 8135.
R $80AA I:(7526) key latches / mode flags: bit0 M held, bit1 map mode, bit2 N held, bit3 map just left, bit4 map just entered
R $80AA I:(7504) view direction 0=north 1=south
N $80AA 7526 bit 4 is consumed by the main loop (5B6F: redraw the map); bit 3 is set on leaving the map but nothing ever clears or tests it.
 $80AA HL = mode flags
 $80AD Read half-row SPACE/SYM/M/N/B
 $80B1 M (bit 2) not pressed: clear the M latch
 $80B5 M still held from the previous iteration: ignore
 $80B9 Beep: BEEPER HL=$0361, DE=30 (about 489 Hz for 61 ms)
 $80C6 Set the M latch
 $80C8 In map mode?
 $80CC Yes: leave map mode, set bit 3 ("map just left")
 $80D2 No: enter map mode, set bit 4 ("map just entered": main loop draws the map)
 $80D8 M released: clear the latch
 $80DA N (bit 3) not pressed: clear the N latch
 $80DE N still held: ignore
 $80E2 Set the N latch
 $80E4 Blank the VIEW box (attribute $7F white on white) while beeping
 $80E9 Beep: BEEPER HL=$0300, DE=40 (about 548 Hz for 73 ms)
 $80F2 Currently facing south? Then switch to north (80F9), else to south (8104)
c $80F9 Set the view direction to NORTH
D $80F9 Also called directly at game start / after a death (5B36), so it then falls through into the flight controls once. Sets 7504=0, prints NORTH (attr $38), and patches the tile-page high bytes used by the renderer (7B18, 7E35, 7E41, 7E6D, 7E93, 7EB9, 7EDF, 7F05) to the north set $63,$63,$63,$66,$67,$68,$69,$6A. Entry 8104 does the same for SOUTH: 7504=1, attr $78, text SOUTH (827F), pages $6C,$6C,$6C,$6F,$70,$71,$72,$73. Each tile code has one byte per height level in page base+0, +1, +2...; the two sets hold the tile stacks as seen from the north and from the south.
 $80F9 7504 = 0 (north)
 $80FD Print NORTH with attribute $38
 $8100 North page base = $63
 $8104 7504 = 1 (south)
 $8109 Print SOUTH (827F) with attribute $78 (bright)
 $8111 South page base = $6C
 $8113 Patch the page bases into the renderer: base...
 $811C ...base+3...
 $8121 ...base+4 ... base+7
 $8133 N released: clear the N latch
c $8135 Flight controls: turning, thrust/coasting, climbing, descending
D $8135 Reached by fall-through from 80AA/80F9 once per main-loop iteration. Applies the control word 7522 to the helicopter: (1) turning in steps of 2 (=45 degrees) of the 16-step heading with a 3-iteration turn timer, (2) thrust: speed 7527 rises by 1 per iteration up to 7 while forward is held and decays by 1 when not, the helicopter moving one map unit along X and/or Y per iteration while speed>0 (direction 753B is latched while thrusting, so the craft coasts in the old direction after releasing), (3) climb/descent with an acceleration of 1,2,3 pixels per iteration, altitude 750D limited to 0..60.
R $8135 I:(7522) control bits
R $8135 I:(7515) 1 = landed (no turning or movement; climb = take off)
R $8135 I:(7516) 1 = fuel exhausted (no thrust, no climb, forced descent)
R $8135 O:(7500),(7502) map X and Y (16-bit)
R $8135 O:(7506) heading 0-15 (always even: 0 N, 2 NE, 4 E, 6 SE, 8 S, 10 SW, 12 W, 14 NW)
R $8135 O:(7507) heading shown by the sprite (odd during a turn)
R $8135 O:(750D) altitude 0-60 pixels
R $8135 O:(7514) set to 1 when trying to descend below altitude 0
 $8135 C = control bits for the rest of the routine
 $8139 Turn timer 7521 running?
 $8140 Count it down; when it reaches 1 the turn completes: heading = 7507 = target 7508
 $8152 Landed: skip turning and movement, only the climb key matters
 $815A Turn left (bit 4)?
 $815E 7507 = heading-1 (mod 16), the in-between sprite frame
 $816B 7508 = heading-2 (mod 16), the target heading
 $8175 Start the turn timer (3 iterations: the turn completes 2 iterations later, the next turn can start after 3)
 $817A Turn right (bit 3)?
 $817E 7507 = heading+1, 7508 = heading+2 (mod 16)
 $8193 Left pressed as well (timer already started)? Then cancel: no turn, timer 0
 $81A6 Start the turn timer
 $81AB Out of fuel: no thrust
 $81B2 Forward (bit 0) held: accelerate
 $81B6 Not thrusting: speed = max(speed-1, 0)
 $81C4 Stopped: no movement this iteration
 $81C6 Coasting: keep moving in the latched direction
 $81CB Thrusting: speed = min(speed+1, 7)
 $81D6 Latch the direction of travel = current heading
 $81DC Fetch the two movement opcodes for direction A from the table at 826F (bytes A and A+1)
 $81E4 Patch the X opcode at 81EF...
 $81E9 ...and the Y opcode at 81F6
 $81EC X = X + dx (self-modified: NOP / DEC HL / INC HL)
 $81F3 Y = Y + dy (self-modified)
 $81FA Climb key (bit 2)?
 $81FE Out of fuel: cannot climb
 $8205 Landed? Then this press is the take-off:
 $820C clear 7515 (landed) and 752E (on base pad) and return
 $8214 Climb rate 751A = min(rate+1, 3)
 $821F Raise the altitude by the climb rate, one pixel at a time, stopping at 60
 $8227 Raise the altimeter bar by one pixel
 $8232 Climb key released: climb rate 0
 $8236 Landed: no descent
 $823C Out of fuel: forced descent
 $8243 Descend key (bit 1)?
 $8247 No: descent rate 0
 $824C Descent rate 751B = min(rate+1, 3)
 $8257 Lower the altitude by the descent rate, one pixel at a time
 $825C Would go below 0: stop
 $8260 Lower the altimeter bar by one pixel
 $8269 7514 = 1: tried to descend at altitude 0 (8A7A then decides between landing and crashing)
b $826F Movement opcode table
D $826F Indexed by the direction of travel d (0-15): byte d is the opcode applied to X, byte d+1 the opcode applied to Y ($00 NOP, $23 INC HL, $2B DEC HL). Only even d are used (headings are always even), giving N (0,-1), NE (+1,-1), E (+1,0), SE (+1,+1), S (0,+1), SW (-1,+1), W (-1,0), NW (-1,-1). For d=15 the Y opcode would be the 'S' at 827F (LD D,E, harmless).
B $826F,16,2
t $827F View direction text
T $827F,5 "SOUTH" (printed by 8104)
c $8284 Count down the time-left bar (T)
D $8284 Called once per main-loop iteration (5BD7). Every (828C) iterations ($FF=255 in round 1, 15 fewer each round) erases one pixel line from the top of the T bar (column 30, rows 1-5, 40 lines). When the pointer passes the bottom of the bar it becomes $40DE and the main loop (5BCC) jumps to 92C8: "NO TIME", game over.
R $8284 I:(7528) iteration counter
R $8284 I:(751C) screen address of the last erased line of the T bar, i.e. the line just above the top lit one ($471E = full)
N $8284 The comparison operand at 828C is patched by 8372 (reset to $FF on a new game) and 83AD (minus 15 on each completed round).
 $8284 Increment the time sub-counter
 $828B Not yet (828C) iterations: return (operand self-modified)
 $828E Reset the sub-counter
 $8292 Move the pointer one pixel line down (next row of cells when leaving a cell)
 $82A1 Erase that line of the bar
c $82A7 Burn fuel (F bar)
D $82A7 Jumped to from 8470 when not on the base pad (and called by 92A9 to drain the tank during the death sequence). Every 49 iterations erases one pixel line from the top of the F bar (column 28, rows 1-5, 40 lines). After the last line, 7516 is set to 1 (tank empty).
R $82A7 I:(7517) fuel sub-counter
R $82A7 I:(7518) screen address of the last erased line of the F bar, i.e. just above the top lit one ($471C = full, $47BC = empty)
R $82A7 O:(7516) 1 when the tank runs dry
 $82A7 Sub-counter 0..48
 $82B1 Move the pointer down one pixel line
 $82BA Off the bottom of the bar (row 5)? Then the tank is empty
 $82C5 Next character row
 $82CB Erase the line
u $82D1 Unused
B $82D1,3,3
c $82D4 Raise the altimeter bar by one pixel
D $82D4 Moves the altimeter pointer 751E up one pixel line in column 24 and lights it ($FF). The bar runs from row 8 upwards (row 8 is lit at altitude 8; altitude 60 reaches row 1, line 4). Called by the climb code (8228) and by the landing code (8B16) when the altitude is rounded up.
R $82D4 I:(751E) screen address of the top lit line of the A bar
 $82D6 Up one pixel line
 $82DB Crossing from the top line of row 8 into row 7 (screen third boundary)?
 $82DF Crossing a character row inside the top third?
 $82E3 Previous character row: H=$47, L=L-32
 $82E7 Third boundary: row 7 line 7 is $47F8
 $82F3 Light the line
c $82FB Lower the altimeter bar by one pixel
D $82FB Clears the top lit line of the altimeter bar and moves the pointer 751E down one line. Quirk: the test at 8307 uses $4F instead of $50, so below altitude 2 the pointer skips line 7 of row 8 and continues in row 9 (a stray line can then be drawn at $4838 when climbing back from altitude 0).
R $82FB I:(751E) screen address of the top lit line of the A bar
 $82FC Erase the current top line
 $8301 Down one pixel line
 $8303 Leaving the bottom of the top third?
 $8307 Quirk: should be $50
 $830F Next character row in the top third: H=$40, L=L+32
 $8315 Row 7 -> row 8: H=$48
c $8321 Start a round: crate boxes, round bonus, difficulty
D $8321 Called at 5B26 at the start of every round (new game, or after the 5th crate has been delivered to the base). Blanks the five crate boxes (attributes of rows 22-23, columns 0-9) and lights them one by one with a beep and a 0.19 s pause. On a new game (7554<>5) it resets the time-bar period to 255, sets the wind threshold 5B93 to 5 and picks a random cyclone starting corner (754B/754C). After a completed round (7554=5) it awards the round bonus, resets the crate counter, sets the wind threshold to 6 and shortens the time-bar period by 15. Finally clears the lives-lost counter 9245 and redraws the HUD.
R $8321 I:(7554) crates delivered (5 = round complete)
R $8321 I:(9245) lives lost this round (0-2)
R $8321 O:(5B93) wind threshold (operand of CP at 5B92: 7378 runs while 7550 < it)
R $8321 O:(828C) time-bar period in iterations
R $8321 O:(754B),(754C) cyclone start position (new game only)
 $8321 Attributes of the five 2x2 crate boxes (rows 22-23, columns 0-9) = 0: invisible
 $8332 Light the boxes one by one (ink 6 yellow)
 $834D Beep: BEEPER HL=$03E8, DE=44 (about 425 Hz for 104 ms)
 $8358 Delay: 200 x 255 DJNZ loops (about 666,000 T-states, 0.19 s)
 $8364 Round complete (5 crates delivered)?
 $836B New game: wind threshold 5
 $8370 Time-bar period 255 iterations
 $8375 Random cyclone corner: 754B = 2 or 20 (bit 0 of L), 754C = 2 or 19 (bit 1 of L)
 $8390 Round complete: crates delivered = 0
 $8394 B = 250 - 64 * lives lost (mod 256): 250, 186 or 122
 $83A2 Add B points; the second call adds whatever B the score printer 6F00 leaves, which is always $66 (102)
 $83A8 Wind threshold 6 for every later round
 $83AD Time-bar period 15 iterations shorter
 $83B6 Lives lost this round = 0 (all three helicopters restored)
 $83BA Redraw the HUD
u $83BE Unused
B $83BE,4,4
c $83C2 Interrupt handler: rotor and winch sounds, crash noise
D $83C2 Reached 50 times a second through the IM2 vector (FFFF->F3F3: JP 83C2). Silent when 752D=1 (menu, or after the crash sequence starts). When 7505=1 (helicopter destroyed) jumps to the explosion noise at 5FDC, which returns through 842D. Otherwise, unless landed (7515) or out of fuel (7516), plays one rotor 'chop': a 4-interrupt cycle of one short high burst (10 cycles, half-periods 18 DJNZ loops) and three lower bursts (6 cycles, half-periods 36), both half-periods shortened by 2*speed. While 7555 is non-zero (winch line moving) a short BEEPER tone (HL=50, DE=8) precedes the chop.
R $83C2 I:(752D) 1 = sound off
R $83C2 I:(7505) 1 = helicopter destroyed
R $83C2 I:(7515),(7516) landed / out of fuel: no rotor sound
R $83C2 I:(7555) winch counter (non-zero = winch sound)
R $83C2 I:(755D) rotor phase 0-3
R $83C2 I:(7527) speed 0-7
 $83C2 Save registers (IX too: the ROM BEEPER uses it)
 $83C9 Sound disabled?
 $83D1 Helicopter destroyed: explosion noise (5FDC, ends with JP 842D)
 $83D9 Landed or tank empty: silence
 $83E4 Winch running?
 $83EB Winch beep: BEEPER HL=$0032, DE=8 (about 5.5 kHz for 1.5 ms)
 $83F4 Advance the rotor phase
 $83FC Phase 0->1: high burst, C=10 cycles, half-periods 18/18
 $8404 Phases 1->2, 2->3, 3->0: low burst, C=6 cycles, half-periods 36/36
 $8412 Both half-periods -= 2 * speed
 $841D Speaker on (border black)
 $8424 Speaker off
 $842D Restore registers and return
u $8435 Unused
B $8435,5,5
c $843A Fill the time-left bar, paying 40 points per line still lit
D $843A Called at the start of every round (5B29). Walks the T bar (column 30) from row 5 line 7 up to row 1 line 0 (40 pixel lines). A line that is still lit from the previous round earns 40 points (6600) and a $FF-pitch beep; an unlit line is lit with a $D0-pitch beep. Leaves 751C = $471E (full bar) and resets the time sub-counter.
R $843A O:(751C) $471E
R $843A O:(7528) 0
 $843A Time sub-counter = 0
 $843E Start at the bottom line of row 5, column 30
 $8441 Line already lit?
 $8446 No: light it and beep with HL=$00D0 (about 1.84 kHz)
 $844E Yes: add 40 points, beep with HL=$00FF (about 1.53 kHz)
 $8455 DE=16 cycles (about 9-10 ms)
 $845C Up one pixel line; previous character row when leaving a cell
 $8468 Stop after row 1
c $8470 Fuel: refuel on the base pad, otherwise burn
D $8470 Called once per main-loop iteration (5BD4). When not on the base helipad (752E=0) jumps to 82A7 to burn fuel. On the pad, adds one pixel line to the F bar per iteration (with a $D0-pitch beep) until the bar is full (pointer reaches row 0, $471C), and clears the empty-tank flag 7516. A full refuel from empty takes 40 iterations (about 4 seconds).
R $8470 I:(752E) 1 = landed on the base helipad
R $8470 I:(7518) F-bar pointer
R $8470 O:(7516) 0
 $8470 Not on the pad: burn fuel
 $8478 Sub-counter (always passes)
 $8486 Bar full (pointer in row 0)?
 $848D Beep: BEEPER HL=$00D0, DE=16
 $8498 Light one line and move the pointer up
 $84A9 Tank not empty any more
c $84AE Initialise the altimeter bar
D $84AE Called at the start of a life (5B39). Clears column 24 in rows 1-7, lights all eight lines of row 8, and sets the altitude 750D to 8 with the pointer 751E = $4818 (top line of row 8).
R $84AE O:(750D) 8
R $84AE O:(751E) $4818
 $84AE Clear rows 1-7 of column 24
 $84C3 Light row 8 of column 24
c $84D6 Clear the screen
D $84D6 Bitmap to 0, all attributes to 7 (white ink on black). Called at game start (5B00) and by the menu/info screens (E293, E3B4).
 $84D6 192 x 32 bitmap bytes
 $84E5 24 x 32 attribute bytes
u $84F2 Unused
B $84F2,2,2
c $84F4 Draw the HUD
D $84F4 Draws the static instrument panel: attributes for columns 24-31 of rows 0-20 (from 7200, 21 x 8 bytes) and for rows 22-23 (7148, 64 bytes); panel graphics for columns 24-31 of rows 0-14 from the tile map 7300 (15 x 8 codes, $FF = leave blank; tile n at 7400+8n): A S F T letters, bar scales, compass rose, three helicopter (lives) icons; the bottom two rows of text from 6848 (crate boxes, WIND FORCE, DANGER); BEWARE / AIRCRAFT (invisible until 91B4 colours them); the VIEW label; then falls into 8580 to print NORTH. Called at game start (5B06), every round start (83BA) and from E3C5.
 $84F4 Panel attributes, rows 0-20 (21 rows of 8)
 $850A Rows 22-23 attributes
 $8515 Panel graphics: 15 rows x 8 cells of tile codes from 7300
 $8526 Tile bitmap at $7400 + 8 x code
 $853C Next character row (convert to a linear row address, add 25 cells, convert back)
 $8554 Rows 22-23 text (64 characters from 6848)
 $855F "BEWARE" at row 16, column 25
 $856A "AIRCRAFT" at row 17, column 24
 $8575 VIEW label (glyphs $3C-$40) at row 13, column 27
c $8580 Print the view direction box
D $8580 Entry 8580: NORTH with attribute $38. Entry 8582 (A preset): NORTH with attribute A. Entry 8585 (A, HL preset): the 5-character text at HL with attribute A. Sets the attributes of rows 13-14, columns 27-31 (the VIEW box) to A and prints the text at row 14, column 27, then falls into 859A.
R $8580 I:A attribute (entries 8582, 8585)
R $8580 I:HL text address (entry 8585)
 $8582 Text NORTH
 $8585 Row 14, column 27; 5 characters
 $858A Colour rows 13 and 14, columns 27-31
c $859A Print a string in the main font
D $859A Prints C characters from HL at screen address DE (left to right, character cells), using the 8x8 font at 6028 (character code n at 6028+8n). Used throughout the game, the map (8EC1...) and the menu/info screens.
R $859A I:HL string
R $859A I:DE screen address of the first cell
R $859A I:C character count
R $859A O:HL address after the string
 $859E Glyph address = $6028 + 8 x code
 $85A8 Copy 8 pixel lines
t $85B9 HUD texts
T $85B9,6 "BEWARE"
T $85BF,8 "AIRCRAFT"
B $85C7,5,5 Glyph codes $3C-$40 of the main font, which hold the VIEW label
T $85CC,5 "NORTH"
u $85D1 Unused
B $85D1,3,3
c $85D4 Let foreground slope tiles cover the helicopter
D $85D4 Called once per main-loop iteration (5B57), after the view has been built (7E10) and the helicopter drawn (86AF), before the view is copied to the screen (762C). Looks at the lower part of the helicopter's 3x11-cell window: view-buffer cells F86C + 23*i + j (i = 0-3 = window cells 7-10, j = 0-2 = window columns). Where such a cell holds a slope tile in front of the helicopter (codes $19-$1C) and the window cell's attribute has ink 0 (helicopter pixels were drawn there by 86AF), the window cell's bitmap is ANDed with a triangular mask (tile $23 for odd codes, $25 for even) and ORed with the slope edge (tile $17 blank for $19/$1A, $1B or $1C), its attribute set to $60 (bright green paper), and the cell's code replaced by the window tile code so the merged picture is displayed. Aircraft tiles $3C-$44 in those cells (8689, never seen executed) are ORed in instead.
R $85D4 I:(F86C) view buffer (23 cells per row)
R $85D4 I:(FCF8) window tile bitmaps (tiles $5F-$7F: 3 columns x 11 cells, column-major, 8 bytes each)
R $85D4 I:(FE5F) window tile attributes (FE00+code)
 $85D4 7509 = bitmap of window tile $66 (column 0, cell 7)
 $85DA 750B = its attribute
 $85E0 First view-buffer cell to test; 3 columns...
 $85E5 A' = window tile code $66
 $85E7 ...of 4 cells
 $85EA A = view-buffer code
 $85F3 Codes $1D and up: only aircraft tiles $3C-$44 are handled
 $85F8 Codes below $19: nothing to do
 $85FE Slope tile: only where the helicopter has been drawn (ink 0)
 $8605 Attribute $60
 $860B Mask: tile $23 (codes $19/$1B) or tile $25 (codes $1A/$1C)
 $8617 Edge: tile $17 (blank) for $19/$1A...
 $861F ...tile $1B for $1B...
 $8627 ...tile $1C for $1C
 $862B 8 lines: window = (window AND mask) OR edge; C = OR of the results
 $8643 Anything left? Then show the window tile in this view cell
 $864C Skip the cell
 $8659 Next window tile code; next view-buffer row (+23)
 $8660 Next window column: skip window cells 0-6
 $8678 Back 4 rows, one column right (-4*23+1)
 $8681 Aircraft tiles $3C-$44
 $868B Only where the helicopter has been drawn
 $8696 OR the aircraft tile bitmap (FA00+8*code) into the window cell
u $86AC Unused
B $86AC,3,3
c $86AF Draw the helicopter sprite into its view window
D $86AF Called once per main-loop iteration (5B4E; also 9281 during the crash sequence). Draws the 24x24 sprite at 6950 (3 columns x 24 lines, column-major) into the helicopter window tiles $5F-$7F (3 columns of 11 cells = 88 pixel lines each, bitmaps at FCF8). The sprite's top line is at line 62-altitude of each 88-line column, so the helicopter rises one pixel per altitude unit above its shadow. Each cell-sized piece is drawn either solid (copied, rest of the cell cleared) when the cell's background code is below $1B and its attribute ink is non-zero (e.g. white wave dots on the sea), or ORed with a one-pixel 'cut' under every sprite pixel; the cell's ink is then set to 0 (black). Empty pieces leave the cell untouched.
R $86AF I:(750D) altitude
R $86AF I:(6950) helicopter sprite (built by 8CA0)
R $86AF I:(7AA2) per-cell background codes of the window (from the renderer)
N $86AF Variables: 7509/7529 = pointer into the background-code table (7AA2+C, stepping down per piece, +11 per column), 750B/752B = window attribute pointer (FE66-C, +11 per column), 7512 = column counter 0-2, where C = (altitude+1)>>3.
 $86AF Column counter = 0
 $86B3 C = (altitude+1)>>3: number of cells the sprite is lifted
 $86B7 Attribute pointer = FE66 - C (window cell 7 - C of column 0)
 $86CD Background-code pointer = 7AA2 + C
 $86D7 DE = window bitmap FD36 - altitude (column 0, line 62-altitude)
 $86E5 HL = sprite; C = 24 lines per column
 $86EA Count in B the lines up to the next cell boundary, ORing the sprite bytes to see whether the piece is empty
 $8700 Empty piece: skip it (8741)
 $8709 Background code (bit 7 ignored)
 $8710 Code $1B or more: OR-draw
 $8714 Attribute ink 0: OR-draw
 $871E Solid draw: whole cell?
 $8725 Last piece (C=0): copy, then clear the rest of the cell (875A)
 $872A First piece: clear the cell from its first line, then copy
 $8741 Empty piece: advance all pointers
 $8752 More lines in this column?
 $875A Copy B lines then clear the remaining 8-B lines
 $8770 OR-draw: line |= sprite, next line &= NOT sprite
 $877E Ink of this window cell := 0 (black)
 $878D Next column: pointers + 11, DE + 64 (88 lines per column)
u $87B9 Unused (leftover LD ($7509),HL)
B $87B9,3,3
c $87BC Update and print the high score
D $87BC Compares the 7-character score at 661E with the high score at 6627 (ASCII digits, leading '.' which sorts below '0'). If the score is higher it is copied over the high score. Then prints the high score right-to-left on the H line (row 20, ending at column 31) via 6F06. Called at the start of each game (5B09, before the score is cleared) and from E3EA.
 $87BC Compare digit by digit from the left
 $87D2 First different digit: score lower? Then keep the old high score
 $87D9 Score higher: high score = score
 $87E4 Print the high score at $509F (row 20, column 31) leftwards from 662D
u $87ED Unused
B $87ED,2,2
b $87EF Aircraft height level
D $87EF Current height level (1-7) at which the aircraft sprite tiles are placed in the tile-stack pages; 89CA moves it one step per drawn frame towards the helicopter's level 7533. Initial value 1.
B $87EF,1,1
c $87F0 Aircraft: move, steer by schedule, warn, place in view
D $87F0 Called once per main-loop iteration (5B3F). (1) Every 28 iterations advances the schedule pointer 8A69 by 20 through 15 records at E740-E858 and applies the record to the 19 aircraft of the live table E86C (5 bytes each: direction code, X, Y): a byte with bit 7 set also respawns that aircraft at its start position (E8CD+5n). (2) Moves every aircraft by its direction code d (multiple of 4): the 4 bytes at E700+d are opcodes (NOP/INC BC/DEC BC) patched into 8867/8868 (X) and 8871/8872 (Y): 16 directions, 2 units per iteration on the main axis. (3) Proximity: |dx|<=22 and |dy|<=25 sets 7530=3 (BEWARE AIRCRAFT flashes, 91B4). (4) An aircraft within |dx|<=12, |dy|<=15 is placed in the view buffer as a 3x3 block of codes $F6-$FE at F71E + (dx+12) + 23*(dy+15) (mirrored for the south view); for the first such aircraft the sprite for its direction (DDB8+72*(n+1)) is copied to the aircraft tiles $3C-$44 (FBE0) and a dithered copy to the shadow tiles $33-$3B (FB98), and the tile-stack pages are updated so the shadow sits on the ground and the aircraft at height level 87EF.
R $87F0 I:(7500),(7502) helicopter X, Y
R $87F0 I:(7504) view direction
R $87F0 I:(7533) helicopter height level
R $87F0 O:(7530) bit 0 = aircraft near in X, bit 1 = near in X and Y (value 3 = warning)
R $87F0 O:(7524),(7525) view cell column/row of the aircraft block
R $87F0 O:(752F) 1 once an aircraft sprite has been set up this iteration
 $87F0 Clear the drawn flag and the warning bits
 $87F7 Schedule step counter 8A6B (0-27)
 $87FF 28th iteration: next schedule record
 $880A Past E858? Wrap to E740 (15 records)
 $881A BC = record, HL = live table
 $881F Next byte of the record ($FF = end)
 $8825 Bit 7 set: new direction and respawn
 $8829 Store the direction
 $882D Copy the 4-byte start position from 96 bytes further on
 $883D Bit 7 clear: just the new direction
 $8847 Move every aircraft
 $884A Direction code d
 $884C Opcode quartet at E700+d
 $884F First two opcodes for X...
 $8859 ...last two for Y
 $8863 BC = X
 $8867 X += dx (two self-modified opcodes)
 $886E BC = Y
 $8871 Y += dy (two self-modified opcodes)
 $8878 Until the $FF terminator
 $887D Proximity / visibility test for each aircraft
 $8883 HL = aircraft X - helicopter X + 22
 $8896 Outside 0..44: not near
 $889E Near in X: set bit 0
 $88A3 X inside the view window (dx = -12..12)? 7524 = dx+12
 $88AB HL = aircraft Y - helicopter Y + 25
 $88BD Outside 0..50: not near
 $88C6 Near in X and Y: set bit 1
 $88CB Y inside the view window (dy = -15..15)? Place it (88FF)
 $88D0 Next aircraft
 $88DD X near but outside the window: Y nearness test only
 $88FF 7525 = dy+15
 $8903 Facing south: mirror (7525 = 30-7525, 7524 = 24-7524)
 $8920 HL = F71E + 7524 + 23*7525
 $8930 Bottom row (7525=30): only the top row of the block
 $894C Full 3x3 block; columns clipped to 7524+c = 2..24
 $8958 Column 0: codes F6, F7, F8 downwards
 $896D Column 1: F9, FA, FB
 $897B Column 2: FC, FD, FE
 $8984 Sprite already set up this iteration? (Then later aircraft re-use it)
 $898D B = direction code / 4 = sprite number 0-15
 $899F Facing south: sprite (n+8) mod 16
 $89A5 Sprite address DDB8 + 72*(n+1)
 $89AC Copy it to the aircraft tiles $3C-$44 (FBE0)
 $89B4 Dithered copy (AND $AA/$55) to the shadow tiles $33-$3B (FB98)
 $89CA Step the aircraft level 87EF one towards the helicopter level 7533
 $89DD Rewrite the tile stacks of codes F6-FE in both page sets ($64.. north, $6D.. south): level L-1 = $FE (empty, continue), level L = tiles $3C-$44, level L+1 = $FF (end)
 $89E5 Level 1: tiles at page +1, end at +2
 $89F2 Level >= 2: empty marker $FE at page L-1
 $8A02 Aircraft tiles $3C-$44
 $8A13 End marker $FF
 $8A1D Level 2: the shadow row 0 overlaps aircraft row 2; level 1: shadow rows 0-1 overlap aircraft rows 1-2
 $8A29 Level 2: OR shadow row 0 into aircraft row 2 of each column
 $8A49 Level 1: OR shadow rows 0-1 into aircraft rows 1-2
b $8A69 Aircraft schedule variables and NO TIME message
D $8A69 8A69 = pointer to the current schedule record (E740-E858, initial E740), 8A6B = iteration counter 0-27 within the record, 8A6C-8A6D unused, 8A6E = " NO TIME " (printed at 4067 by 92CD).
W $8A69,2,2
B $8A6B,1,1
B $8A6C,2,2
T $8A6E,9 " NO TIME "
u $8A77 Unused
B $8A77,3,3
