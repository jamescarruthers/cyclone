c $8A7A Landing / terrain-collision check
D $8A7A Called once per main-loop iteration (5B54). Does nothing while landed (7515=1). Otherwise (a) every other group of 4 calls updates 7533, the target height level (0-7) of the helicopter's own tile column, from the altitude; (b) compares altitude/4 with the height class of each of the 9 footprint cells (7A8B, filled by 7ADC) and decides between "still flying", "touch-down" and "crash". Touch-down then requires every footprint cell's top tile to be landable; landing on 9 helipad tiles sets 752E=1. A crash is signalled by 7505=1 (main loop then jumps to the death sequence at 9246).
R $8A7A I:(7515) 1 = landed (routine returns at once)
R $8A7A I:(750D) altitude in pixels (0..60)
R $8A7A I:(7514) 1 = helicopter tried to descend below altitude 0 (set by 8269)
R $8A7A I:(751B) descent speed 0..3 (pixels per iteration while 'down' held)
R $8A7A I:(7A81) 9 raw terrain codes under the helicopter (3x3, filled by 7E10)
R $8A7A I:(7A8B) 9 height classes of those cells, in units of 4 altitude pixels (filled by 7ADC)
N $8A7A Footprint order in 7A81/7A8B: view-buffer cells (row15,col10),(14,10),(13,10),(15,11),(14,11),(13,11),(15,12),(14,12),(13,12).
 $8A7A Landed? Then nothing to do.
 $8A80 B = altitude/4 (arithmetic shifts)
 $8A88 7534 = free-running call counter
 $8A8C Only when bit 2 of the counter is set (4 calls in every 8)...
 $8A90 ...7533 = min((altitude>>3)+1, 7): helicopter tile-column level that 89CA steps 87EF towards
 $8A9B Count in C the footprint cells whose height class is <= altitude/4 (clear cells)
 $8AA2 altitude/4 < height class? Then this cell is touching/above the helicopter: go to 8B30
 $8AAA Flag 7514 set (pressing down at altitude 0)?
 $8AB1 With 7514 set: anything less than 9 clear cells is a crash...
 $8AB7 ...and so is a descent speed of 3; otherwise try to touch down
 $8AC1 7514 clear: 9 clear cells = still flying, return
 $8AC5 0 clear cells = all 9 cells reached: try to touch down; 1..8 = partly over an obstacle/edge: crash
 $8ACA Touch-down: examine the top tile of each footprint cell's tile stack. C counts helipad tiles.
 $8AD0 L = raw terrain code; the stack for code L is the bytes at $6300+L, $6400+L, ... terminated by $FF
 $8AD4 Find the first page (from $64) holding $FF for this code...
 $8ADA ...and step back to the topmost tile of the stack
 $8ADC Tiles $80-$FF are special (8B1D)
 $8AE0 Ordinary tiles $2D-$7F cannot be landed on: crash
 $8AE4 Tiles $00-$02 (sea) cannot be landed on: crash
 $8AE8 Next footprint cell
 $8AEB All 9 cells were helipad tiles ($83/$89)?
 $8AF0 Then 752E=1: landed on the base helipad (refuelling allowed; required to finish a round)
 $8AF5 7515=1: landed
 $8AFA Clear 7514
 $8AFE Round the altitude UP to a multiple of 8: new = ((alt+7)>>3)*8
 $8B10 B = (new-old)+1
 $8B13 Raise the altimeter bar by new-old pixels (82D4 once per pixel)
 $8B1D Special top tile: $80 or $86 = crash
 $8B25 $83 or $89 = helipad tile: count it (C=C+1); any other $80-$FF tile is landable
 $8B30 Cell height class (HL) is above altitude/4. E = altitude/4
 $8B32 Height class < 15: low obstacle (ground). Go to 8B4E
 $8B36 Height class >= 15 (very tall object). Not seen executed. A = 87EF (current helicopter tile level), E = altitude/8
 $8B3B 87EF-1 = altitude/8: crash
 $8B40 87EF=7: crash only if altitude/8 = 7 (8B49)
 $8B44 Otherwise count the cell as clear and continue the loop
 $8B4E Low obstacle reached: a descent speed of 3 is a hard landing = crash
 $8B55 Otherwise kill the descent speed (soft contact) and continue the loop WITHOUT counting the cell as clear
 $8B5D 7505=1: helicopter destroyed
u $8B63 Unused code fragment (never called)
D $8B63 Disassembles as LD A,$F3 / LD A,$3E / LD I,A / IM 1 / EI / RET: a leftover interrupt-mode-1 restore. Followed by 7 zero bytes.
B $8B63,10,10
B $8B6D,7,7
c $8B74 Random number generator
D $8B74 Advances the 16-bit seed held in the ROM system variable SEED (5C76) and returns it in HL. The arithmetic is the classic Spectrum Lehmer step done without multiplication: new = ((254*(seed+1)) mod 65537) - 1 (verified for 3,206 seeds by emulation, including 0 and 65535). The sequence visits all 65,536 values (period 65536). Callers use L or H of the result.
R $8B74 I:(5C76) seed
R $8B74 O:HL new seed (also stored at 5C76)
R $8B74 O:A,D,E corrupted
 $8B74 DE = seed
 $8B78 Form the 24-bit number A:H:L = seed*256 + $FD
 $8B7C Subtract the seed twice (with borrow into A): A:HL = 254*seed + 253 = 254*(seed+1) - 1
 $8B85 Reduce modulo 65537 (65536 = -1): HL = HL - A
 $8B8A On borrow add 65537 back (i.e. +1 in 16 bits)
 $8B8D Store new seed
c $8B91 Animate sea waves in the view buffer
D $8B91 Called every main-loop iteration (5B45) and every step of the death sequence (925A), after 76D2 has rebuilt the view buffer (F74E, 23 columns x 22 rows of terrain codes) and before 7E10 converts codes to tile stacks. Puts random wave codes 0-3 into the empty (code 0 = open sea) cells of a sparse sheared lattice (7 rows x 4-5 columns, lattice vectors +5 cells across and +4 rows/+3 columns down). The lattice phase (7535 column 0..8, 7536 row 0..6) is shifted against the heading whenever the helicopter is moving, so the waves scroll with the motion; the random bytes are taken from ROM $0100+n, n re-randomised every 3rd call, so the wave pattern changes every 3 iterations.
R $8B91 I:(7527) speed (0 = hovering: phase unchanged)
R $8B91 I:(7506) heading 0,2,..14 (0=N, clockwise)
R $8B91 I:(7504) view: 0 = north, 1 = south (180 degree rotated)
N $8B91 Cell written = F705 + 7535 + 23*B + 5*i + 95*j (j=0..6 rows, i=0..3 or 4), where B = 7536 (view north) or, view south, B = 7536+2 if that is < 7 else 7536-2; F705 = F74E - 73 (3 rows and 4 columns before the buffer start). If 7535 < 4 the first lattice column is skipped (+5). Columns per row: 5 if 7535 in 0,1,4,5,6; 4 if 7535 in 2,3,7,8 (the row stride is always 95). Only cells containing 0 are changed, to (ROM byte AND 3).
 $8B91 7537 counts 0,1,2
 $8B9C Not the 3rd call: reuse the ROM pointer in 7538
 $8BA2 Every 3rd call: DE = $0100 + (L of a new random number) = pointer to "random" ROM bytes
 $8BB0 Keep the ROM pointer on the stack
 $8BB1 Speed 0: lattice phase unchanged
 $8BC6 Moving: choose the phase-step table for the current view
 $8BD5 Index it by heading (2 bytes per heading)
 $8BDF 7535 += dx; values outside 0..8 reset to 4
 $8BEA C = new column phase; E = $05+7535 (DE = F705+column phase)
 $8BF1 7536 += dy; values outside 0..6 reset to 3
 $8C00 B = row phase; adjusted by 2 rows for the south view
 $8C13 HL = F705 + column phase + 23*row phase
 $8C1C Default: 4 lattice columns per row, row skip 75 (self-modified operands at 8C47 and 8C5E)
 $8C26 Column phase < 4: start one lattice column (5 cells) further on
 $8C39 5 lattice columns per row, row skip 70
 $8C43 7 lattice rows
 $8C46 B = lattice columns (operand at 8C47 modified above)
 $8C4B Cell empty (open sea)?
 $8C4E Then set it to the next ROM byte AND 3 (wave code 0-3)
 $8C57 Next lattice column (+5 cells)
 $8C5D Next lattice row (operand at 8C5E modified above: 95 bytes per row in total)
 $8C64 Drop the ROM pointer
b $8C66 Wave phase steps, view north
D $8C66 (dx,dy) added to 7535/7536 per moving iteration, indexed by heading 7506 (0=N,2=NE,4=E,...,14=NW). The step is opposite to the direction of travel. Byte 8C76 is padding.
B $8C66,16,2
B $8C76,1
b $8C77 Wave phase steps, view south
D $8C77 As 8C66 but negated (view rotated 180 degrees).
B $8C77,16,2
u $8C87 Unused code fragment (never called)
D $8C87 Disassembles as an old interrupt set-up: LD HL,$FFFF / LD (HL),$18 / LD HL,$FFF4 / LD (HL),$C3 / INC HL / LD (HL),$C2 / INC HL / LD (HL),$83 (JR at FFFF + JP $83C2 at FFF4) / LD A,$3A / LD I,A / IM 2 / JP $E280. Superseded by the F74E init.
B $8C87,25,9
c $8CA0 Build the helicopter sprite (with rotor) in 6950
D $8CA0 Called every main-loop iteration (5B48) and for the first 3 steps of the death sequence. Copies the 72-byte (9 character, 3x3) helicopter graphic for sprite frame 7507 from E930+72*frame to the sprite buffer 6950-6997, then XORs one of the rotor overlays onto it. 86AF later draws 6950 into the view.
R $8CA0 I:(7507) displayed sprite heading frame 0-15 (moves one step at a time towards 7508)
R $8CA0 I:(7504) view 0 north / 1 south
R $8CA0 I:(7515) landed flag; (7516) fuel-empty flag
R $8CA0 I:(753A) rotor animation frame
N $8CA0 Frame used = 7507 (view north) or (7507+8) mod 16 (view south). For frames 10-15 the instruction at 8D02 becomes ADD A,A so the rotor overlay is shifted one pixel left (mirror-side frames). Rotor overlays (72 bytes each, XORed): flying: $7000+256*f, f = 753A cycling 0,1 (2-frame fast rotor); landed or out of fuel: $6700+256*f, f cycling 0,1,2,3 (4-frame slow rotor). (OBSERVED: 753A cycles 1,2,3,0 while landed, 0,1 in flight.)
 $8CA0 B = sprite frame
 $8CA4 South view: frame = (frame+8) AND 15 (RES 4)
 $8CB1 Frames 0-9: NOP at 8D02; frames 10-15: ADD A,A ($87) at 8D02
 $8CBD HL = E8E8 + 72*(frame+1) = E930 + 72*frame
 $8CC7 Copy the 72-byte graphic to 6950
 $8CCF Rotor overlay page: $70 (flying)...
 $8CD2 ...or $67 if landed or out of fuel, with a 4-frame cycle
 $8CEE Flying: 2-frame cycle
 $8CFA DE = (page+frame)*256
 $8D01 XOR 72 overlay bytes onto the sprite buffer
 $8D02 Self-modified: NOP, or ADD A,A (shift overlay left) for frames 10-15
u $8D0A Unused
B $8D0A,4,4
c $8D0E Clear the view window
D $8D0E Used at game start (5B03) and when the map screen is entered (5B78). Sets the 23x22-cell view window (columns 0-22, rows 0-21) to attribute $3F (white on white), clears its bitmap, then sets the inner 21x20 cells (columns 1-21, rows 1-20) to $7C (bright white paper, green ink: map land colour).
 $8D0E 22 rows x 23 attributes = $3F
 $8D21 Clear 22 rows x 23 columns x 8 pixel lines of bitmap
 $8D36 Next character row (screen address arithmetic via rotation of H)
 $8D49 Inner 20 rows x 21 columns = $7C
c $8D5D Map screen: draw the island shapes
D $8D5D Used when the map screen is entered (5B7B), after 8D0E. For each of the 14 island records at F230 (20 bytes each, list ends with $FF) it renders the island's heightmap at 1/4 scale: one map pixel per 4x4 world units, pixel set if the sampled height byte is >= $0F. Falls through into 8DE2 to print the names.
R $8D5D I:F230 island table: +0A/+0B heightmap base, +0C/+0D map bitmap address (top-left), +0E width in pixels, +0F height in pixel rows
N $8D5D Heightmap format expected (same as the view builder 775E/7789): one byte per world unit, 128 bytes per world row, i.e. byte for (x,y) = base + 128*(y-y0) + (x-x0). The map samples pixel (px,py) at base + $102 + 4*px + $200*py, i.e. world offset (2+4*px, 2+4*py). Only the low byte is stepped (INC L x4), so a row must not cross a 256-byte page. Pixels are packed MSB first, 8 per screen byte; a final partial byte is padded with zero bits. 753C = start of current pixel row on screen, 753E = write pointer.
 $8D5D IX = first island record
 $8D61 753C = 753E = bitmap address of the island's top-left pixel
 $8D6D HL = heightmap base + $102 (2 world units in from the top-left corner)
 $8D76 D = pixel rows, E = pixels per row
 $8D7D Build one screen byte from up to 8 samples
 $8D83 Height >= $0F: land pixel
 $8D8A Next sample 4 bytes (4 world units) to the right
 $8D8E Row finished? Then pad the byte with zero bits
 $8D9B Store the byte and advance the screen pointer
 $8DA5 Loop until the row is complete
 $8DA9 Move 753C down one pixel line (handling character-row boundaries)
 $8DCF Next sample row: 4 world rows down (2 pages)
 $8DD5 Next island record
 $8DE1 Fall through to print the names
c $8DE2 Print island names (4-pixel-wide font)
D $8DE2 Prints the island names on the map in a half-width font, two characters per screen cell, black on bright white. Entry 8DE2 sets IX=F230, record stride 20 and the text pointer 6A4F; entry 8DEE is also used by the info screen (E446) with its own IX table (E68C), stride 3 (written to 8E0A) and text (E517).
R $8DE2 I:(IX+$10/$11) screen address one cell left of where the text starts; (IX+$12) attribute-file high byte ($58/$59/$5A) for that row
R $8DEE I:IX first position record, HL text pointer minus 1, (8E0A) record stride
N $8DE2 Text format (6A50-6AC9 for the map): ASCII bytes, with '?' ($3F) used as the space character. $FE = end of this name, move to the next record; $FD = append the shared suffix at 6AC2 ("?ISLAND", i.e. " ISLAND") which itself ends with $FC = return from suffix and move to the next record; $FF = end of all text. Glyphs: 8 bytes per character at 6908+8*code (only the left 4 pixels are used); even-numbered characters are copied into the next cell (and its attribute set to $78), odd-numbered characters are shifted right 4 pixels and ORed into the same cell. Map name order follows F230: BANANA, ORTE ROCKS, KOKOLA, LAGOON, PEAK, BASE, GILLIGANS, RED, SKEG, BONE, GIANTS GATEWAY, CLAW, LUKELAND ISLES, ENTERPRISE (ISLAND appended except for ORTE ROCKS, GIANTS GATEWAY, LUKELAND ISLES).
 $8DE2 Map: island records at F230, stride 20 (operand at 8E0A), text at 6A50
 $8DEE DE = name position (one cell to the left), C = character counter
 $8DF7 Next text byte
 $8DFD $FF: finished
 $8E00 $FE: next record
 $8E04 $FD: switch to the suffix text at 6AC2
 $8E08 $FC: end of suffix: restore the main text pointer and go to the next record
 $8E09 IX += stride (operand at 8E0A is self-modified: 20 for the map, 3 for the info screen)
 $8E10 Push the main text pointer and read the suffix from 6AC2 onwards
 $8E15 HL = 6908 + 8*code (glyph)
 $8E23 Odd character: OR the glyph shifted right 4 pixels into the current cell
 $8E3D Even character: move to the next cell and copy the glyph
 $8E47 Set the cell's attribute to $78
 $8E50 Next character
u $8E53 Unused
B $8E53,9,9
c $8E5C Map screen: draw frame and north indicator
D $8E5C Used when the map screen is entered (5B7E). Draws the frame around the 23x22 map using 8-byte characters from the HUD graphics at 7438-7497, then a 3-character north arrow at column 20, rows 17-19 (codes $4E 'N', $29, $2A from 8F0C in the main font at 6028) with attributes $78.
N $8E5C Frame pieces: 7438 top-left (row 0,col 0), 7440 x21 top edge, 7448 top-right (col 22); 7480 bottom-left (row 21), 7488 x21 bottom edge, 7490 bottom-right; 7460 x20 left edge (rows 1-20, col 0); 7470 x20 right edge (col 22).
c $8EE8 Draw a character C times
D $8EE8 Copies the 8-byte character at IX to screen address DE, C times, advancing DE by HL each time (HL=1: next column, HL=$20: next character row; also $40 from the info screen). Used by 8E5C and the info screen (E4C2-E4D2).
R $8EE8 I:IX 8-byte character
R $8EE8 I:DE screen address
R $8EE8 I:HL step (in character cells; 32 = one row down)
R $8EE8 I:C repeat count
R $8EE8 O:DE address after the last character
 $8EF7 DE += HL using the 'linear' form of the screen address (H rotated right 3 times) so that +32 crosses character rows and thirds correctly
b $8F0C Map north-indicator characters
D $8F0C Font codes printed by 8E5C at rows 17, 18 and 19 of column 20: 'N', arrow shaft/head ($29), arrow tail ($2A). 8F0F-8F11 unused.
B $8F0C,3,3
B $8F0F,3,3
c $8F12 Map screen: per-iteration update (blinking markers)
D $8F12 Called by the main loop instead of 762C/9034 while the map screen is shown (7526 bit 1). Wastes about 132,000 T-states (about 1.9 frames), then blinks the helicopter and cyclone markers with a 7-call cycle using counter 7542: calls 1-3 just update positions (9034), calls 4-6 remove the markers, call 7 resets the counter, updates positions and redraws the markers at their new cells (8F6A). OBSERVED: one map-mode iteration takes about 5.7 frames, so a blink cycle lasts about 40 frames.
 $8F12 Delay loop: 40 x 255 DJNZ
 $8F1B 7542 = 7542+1; 1..3: positions only
 $8F25 Remove the helicopter marker: restore its attribute (a saved $3F frame attribute is restored as $3A instead; never seen)
 $8F32 Restore the cyclone marker's attribute
 $8F39 Restore the 8 bitmap bytes under the helicopter marker
 $8F47 Restore the 8 bitmap bytes under the cyclone marker
 $8F55 Counter 4..6: done
 $8F5E Counter 7: reset to 0, restore helicopter attribute
 $8F67 Update positions, then fall through to redraw the markers
c $8F6A Map screen: draw helicopter and cyclone markers
D $8F6A Saves the attribute and the 8 bitmap bytes of the character cell (column 7540, row 7541) and prints the helicopter marker there (main-font code $28 'H'-like glyph) with attribute $7A (bright, white paper, red ink); then does the same for the cyclone at (754B, 754C) with code $27 (swirl). Called on map entry (5B81) and by 8F12.
R $8F6A I:(7540),(7541) helicopter map cell (column 0-22, row 0-21), from 9034
R $8F6A I:(754B),(754C) cyclone map cell
R $8F6A O:(7543) helicopter cell attribute address, (7545) its bitmap address, (9027) saved attribute, 901F-9026 saved bitmap
R $8F6A O:(7547) cyclone cell attribute address, (7549) its bitmap address, (9030) saved attribute, 9028-902F saved bitmap
 $8F6A Attribute address = 5800 + 32*row + column
 $8F82 Save it and set $7A
 $8F88 Bitmap address of the cell
 $8FAC Save the 8 pixel bytes
 $8FB7 Print the helicopter marker (code at 901D)
 $8FC3 Same for the cyclone
 $9014 Print the cyclone marker (code at 901E)
b $901D Map marker codes and save areas
B $901D,1,1 Helicopter marker character code ($28)
B $901E,1,1 Cyclone marker character code ($27)
B $901F,8,8 Saved bitmap under the helicopter marker
B $9027,1,1 Saved attribute under the helicopter marker
B $9028,8,8 Saved bitmap under the cyclone marker
B $9030,1,1 Saved attribute under the cyclone marker
B $9031,3,3 Unused
c $9034 Map positions, cyclone movement and wind-force/danger gauges
D $9034 Called every main-loop iteration in the normal view (5B89) and on calls 1-3 and 7 of the map blink cycle. (1) Converts the helicopter's world position to a map cell. (2) Every 25 calls moves the cyclone one map cell in a random direction chosen from the current 'regime', picking a new regime every 9 moves or when the cyclone hits the map edge. (3) Sets 7550 = Chebyshev distance helicopter-cyclone (max 15) and draws the WIND FORCE bar and DANGER warning.
R $9034 I:(7500) helicopter X (16-bit world units), (7502) helicopter Y (Y grows southwards)
R $9034 O:(7540) map column = X/32 clamped to 0..22; (7541) map row = Y/32 clamped to 0..21
R $9034 O:(754D) number of axes on which the helicopter is off the map (0-2)
R $9034 O:(754B),(754C) cyclone map column 1..21 / row 1..20
R $9034 O:(7550) distance to cyclone 0..15
N $9034 Off-map test: if X/32 >= 256 (only possible for 'negative' X >= $2000) the column is 0; if 23 <= X/32 < 256 it is 22; rows likewise use 21. (The checks of H against $80 at 9054/9087 can never succeed, as H <= 7 after the shifts; dead code.)
N $9034 Cyclone timing (OBSERVED, helicopter idling at base: 5.16 frames per main-loop iteration): one step every 25 iterations = about 129 frames (2.6 s); a regime lasts 9 steps (about 23 s) unless cut short at an edge.
 $9034 754D = 0
 $9038 HL = X >> 5
 $904F X/32 < 256?
 $9063 X/32 >= 23: column 22 and flag off-map
 $9068 7540 = column
 $906B HL = Y >> 5
 $9096 Y/32 >= 22: row 21 and flag off-map
 $909B 7541 = row
 $909E 754E counts calls 0..24; the cyclone moves when it reaches 25
 $90A7 754F counts moves 0..8
 $90B2 9th move: new regime = random entry of 9178 (L AND 15), stored into the AND/OR operands at 90D0/90D2
 $90CB Direction index = (H of a new random number AND mask) OR bits (operands at 90D0, 90D2): an even offset into 9198
 $90D8 New column must be 1..21...
 $90EA ...else stay and force a new regime next call (754F=8, 754E=24)
 $90F4 New row must be 1..20, else likewise force a new regime
 $9111 C = |cyclone column - helicopter column|
 $9120 A = |cyclone row - helicopter row|
 $912E 7550 = min(15, max of the two)
 $913B WIND FORCE bar at row 23, columns 16-31: (16-distance) cells of $52 (red) then distance cells of $7F (white); one fewer red cell if the helicopter is off the map
 $9149 Note the bar is drawn at 5AF0 = row 23 column 16
 $915D DANGER label (row 22, columns 26-31): $FA (flashing red on white) if distance < 6, else $38 (black on white)
 $916B Already that colour? Then return without rewriting
b $9178 Cyclone direction regimes
D $9178 16 (mask, bits) pairs, one chosen at random (L AND 15) every 9 cyclone moves; each step's direction offset is (random H AND mask) OR bits, indexing the (dx,dy) pairs at 9198, so each regime allows 2 or 4 equally likely directions: 0 W/NW; 1 SW/S; 2 NE/E; 3 SE/E; 4 W/SW; 5 W/NW/N/NE; 6 W/NW/SW/S; 7 N/NE/SE/E; 8 SW/S/SE/E; 9 N/NE; 10 W/NW; 11 SW/S; 12 SE/E; 13 W/NW/N/NE; 14 SW/S/SE/E; 15 N/NE. The current regime lives in the operands at 90D0/90D2 (never reset; $0E/$06 = NE/E in the loaded image).
B $9178,32,2
b $9198 Cyclone step directions
D $9198 (dx,dy) map-cell steps at even offsets 0-14: 0 W(-1,0), 2 NW(-1,-1), 4 N(0,-1), 6 NE(+1,-1), 8 SW(-1,+1), 10 S(0,+1), 12 SE(+1,+1), 14 E(+1,0). The bytes from 91A8 are never indexed.
B $9198,16,2
B $91A8,12,12 Unused
c $91B4 HUD: compass, speed bar, aircraft warning
D $91B4 Called every main-loop iteration (5B42) and by the info screen (E3E4). Redraws the compass direction dot, the S (speed) bar and the BEWARE AIRCRAFT warning colours.
R $91B4 I:(7527) speed 0..6
R $91B4 I:(7506) heading (used while hovering), (753B) direction of travel (used while moving); both 0,2,..14
R $91B4 I:(7530) aircraft warning state (3 = flash)
 $91B4 Clear the 8 compass ring cells around the centre at 593D (row 9, column 29) to attribute 0
 $91CE Direction = heading 7506 if hovering, else travel direction 753B
 $91E0 Offset of the ring cell for this direction from the table at 9232
 $91E9 Light it: $47 (bright white on black)
 $91EB Speed bar: column 26 from row 5 upwards, 5 cells: min(speed,5) cells of $52 (red) then the rest $7F (white)
 $920F BEWARE AIRCRAFT panel (rows 16-17, columns 24-31): $FA (flashing) if 7530 = 3, else $3F
 $921F Already that colour? Return
b $9232 Compass ring offsets and death-sequence variables
D $9232 Attribute offsets from the compass centre (593D) for directions 0=N,2=NE,4=E,6=SE,8=S,10=SW,12=W,14=NW.
W $9232,16,2
B $9242,1,1 Unused
W $9243,2,2 Death sequence: pointer to the next 72-byte explosion overlay (F550, F598, ...)
B $9245,1,1 Lives lost this round (0-3; reset to 0 by 8321 at the start of each round)
c $9246 Death sequence (helicopter destroyed)
D $9246 Entered from the main loop when 7505=1. Plays a 24-step explosion animation in the view, marks a life as lost (helicopter icon turned red), and either returns to the menu (3 lives lost) or resets the per-life variables and resumes the main loop at 5B36. OBSERVED: the 24 steps take about 132 frames (2.6 s).
N $9246 Per step (counter n = 24 down to 1): 76D2 rebuild view buffer, 8B91 waves; 6950 = 72 zero bytes (copied from 9300); n >= 22: 8CA0 rebuilds the normal helicopter sprite; n = 18: 752D+1 (explosion sound request for the interrupt handler); n >= 20: XOR the next explosion overlay (F550+72*k, k=0..4) onto 6950; then 7E10 (tile stacks), 86AF (draw sprite), 762C (render view). So the explosion overlays are shown over the helicopter for steps 24-22, alone for steps 21-20, and the sprite is blank from step 19.
N $9246 Life lost: attributes (row 10+2*k, columns 24-25), k = lives lost so far, are set to $02 (red ink); lives lost +1; 3 = game over (JP E280). Otherwise 82A7 (fuel-gauge tick) is called until 7516=1 (fuel gauge emptied), then every byte of the reset table 75C8-762B that is not $FF is copied over 7500-7563 (position $0139,$0170 on the base pad, landed, altitude 8, speed 0 ...; $FF entries such as the time bar pointer 751C/751D, 7543-754C markers/cyclone, 754E/754F, 7554 crates are kept) and play resumes at 5B36.
 $9246 Render the view once
 $9249 First explosion overlay at F550
 $924F Altitude +2 for the animation
 $9254 24 steps
 $925D Blank sprite: copy 72 zero bytes from 9300 to 6950
 $9268 Steps 24-22: normal helicopter sprite
 $9271 Step 18: explosion sound
 $9279 Steps 24-20: XOR an explosion overlay
 $928A Turn the next helicopter (life) icon red: 5958 + 64*lives lost
 $929D Lives lost +1; 3 = game over, back to the menu
 $92A9 Empty the fuel gauge
 $92B3 Copy the reset table 75C8 to 7500 (100 bytes), skipping $FF bytes
 $92C5 Resume the main loop
 $92C8 Time ran out (from 5BD1, 751C=$DE): set 2 lives lost so that the next one ends the game, message " NO TIME "
 $92D0 Entry from 5BEF with HL=5BF2 (" NO FUEL ", landed off the helipad with an empty tank: costs one life). Print the 9-character message at row 3, column 7, attributes $47
 $92E2 Beep: ROM BEEPER, DE=$0300 cycles, HL=$0466 pitch
 $92EB Join the life-lost code
c $92ED XOR the next explosion overlay onto the sprite
D $92ED XORs 72 bytes from (9243) onto the sprite buffer 6950 and advances 9243 by 72.
R $92ED I:(9243) overlay pointer
