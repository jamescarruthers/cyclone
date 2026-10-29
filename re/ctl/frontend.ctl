c $5B00 Game start, per-level setup and main game loop
@ $5B00 label=GameStart
D $5B00 Copied here from #R$F78A by #R$F74E (it lives in the printer buffer). Entered from the main menu (#R$E280) when "6" is pressed. Clears the screen, draws the HUD, updates the high score with the last game's score, zeroes the score and loads the 100 live game variables at $7500-$7563 from their initial values at $7564. #R$5B26 starts a level (also re-entered when a level is completed), #R$5B36 starts a life (also re-entered after a life is lost, from $92C5), and #R$5B3C is the free-running per-iteration loop (no HALT / interrupt sync: one iteration takes ~270000-390000 T-states, i.e. ~3.9-5.6 TV frames, ~9-13 iterations per second; all game timers count iterations).
 $5B00 Clear the screen (pixels 0, attributes 7)
 $5B03 Clear/colour the 23x22 play area
 $5B06 Draw the HUD panel (right-hand 8 columns and bottom two rows)
 $5B09 Hi-score := score if score > hi-score; print "H" line
 $5B0C Score digits 1-6 := '.' (displayed as blank leading digits)...
 $5B16 ...and the last digit := '0'
 $5B18 Print the score
 $5B1B Copy 100 initial values (#R$7564) to the live variables at $7500
@ $5B26 label=LevelStart
N $5B26 Start of a level (first level, or after a level is completed).
 $5B26 Draw the 5 crate boxes; first level: randomise cyclone start corner; next level: award crate bonus, speed up the time bar; lives restored
 $5B29 Fill the time bar (40 lines); 40 points for every line still filled
 $5B2C Shuffle the 5 crates over 38 candidate map cells (FE92: JP #R$5EEC)
 $5B2F Put a survivor (random variant) on each of 45 candidate map cells
@ $5B36 label=LifeStart
N $5B36 Start of a life (also entered from $92C5 after a life has been lost).
 $5B36 View := NORTH (tile set A), print "NORTH"
 $5B39 Clear the altimeter bar; altitude ($750D) := 8
@ $5B3C label=MainLoop
N $5B3C Main loop: one iteration per game "tick".
 $5B3C Clear the view buffer at $F74E, fill it with map tile codes, find the island under the helicopter ($7552)
 $5B3F Move the aircraft; set collision-warning bits in $7530
 $5B42 HUD: compass needle, speedometer, BEWARE AIRCRAFT warning
 $5B45 Helicopter screen offset/drift ($7535/$7536; random every 3rd call)
 $5B48 Build the helicopter sprite (heading frame + rotor frame) in #R$6950
 $5B4B Render terrain: tile codes -> character codes using the tile column tables; save the 3x3 tiles under the helicopter at $7A81
 $5B4E Overlay helicopter and shadow (dynamic glyphs)
 $5B51 Winch: pick up a crate or survivor under the helicopter
 $5B54 Landing/collision test (sets $7505 crash, $7515 landed, $752E on landing pad)
 $5B57 Further sprite/overlay compositing (dynamic glyphs from $FD30)
 $5B5A Crashed ($7505=1)?
 $5B5F Yes: crash sequence, lose a life ($9246)
 $5B62 Map mode ($7526 bit 1)?
 $5B69 Map shown: delay, blink map markers, move cyclone ($8F12, falls into $9034)
 $5B6C Map just opened ($7526 bit 4)?
 $5B73 Yes: clear the flag...
 $5B78 ...clear the play area...
 $5B7B ...draw the islands...
 $5B7E ...draw the map frame and compass...
 $5B81 ...draw markers/labels
 $5B86 No map: copy the view buffer to the screen
 $5B89 Move the cyclone; set the cyclone proximity $7550 and WIND FORCE bar
 $5B8C Read the selected controller into the control word $7522
 $5B8F Cyclone proximity ($7550, 0=on top of it ... 15=far)
 $5B92 The operand of this CP (address $5B93) is modified: 5 on level 1 (#R$836D), 6 on later levels (#R$83AA)
 $5B94 Close to the cyclone: randomly perturb the control word (turbulence)
 $5B97 Landed ($7515=1)...
 $5B9E ...and out of fuel ($7516=1)...
 $5BA5 ...and not on a landing pad ($752E=0)?
 $5BAA Yes: "NO FUEL" - lose a life
 $5BAC Handle the M (map) and N (view) keys, then apply the control word: heading, speed, altitude
 $5BAF 5 crates collected ($7554)...
 $5BB6 ...and on a landing pad ($752E=1)...
 $5BBD ...on the island record at $F294 (BASE)?
 $5BC9 Yes: level complete, start the next level
 $5BCC Time bar pointer ($751C) moved past the last line?
 $5BD1 Yes: "NO TIME" - game over
 $5BD4 On a landing pad: refuel 1 line per iteration; else burn fuel (1 line per 49 iterations)
 $5BD7 Time bar: lose 1 line every N iterations (N = operand at $828C: 255, then -15 per level)
 $5BDA Animate the two survivor glyphs (chars $31 and $32)
 $5BDD Read keyboard half-row A-S-D-F-G
 $5BE1 Unless A and G are both held...
 $5BE3 ...loop
 $5BE9 A+G held: abandon the game, back to the main menu
 $5BEC "NO FUEL" message...
 $5BEF ...print it at row 3, lose a life ($92D0, shared with "NO TIME")
t $5BF2 Message: " NO FUEL "
T $5BF2,9 Printed by $92D0 (9 characters at row 3, column 7)
B $5BFB,5 Unused (copied with the routine)
b $5C00 ROM system variables and BASIC loader (not used by the game)
D $5C00 Standard 48K system variables ($5C00-$5CB5), followed by the channel area and the BASIC loader program (line 10: BORDER NOT PI: INK NOT PI: PAPER NOT PI: CLEAR VAL "24539": LOAD "Cyclone2"SCREEN$ : LOAD "Cyclone4"CODE : LOAD "Cyclone3"CODE : RANDOMIZE USR VAL "65176") and its variables. Only SEED ($5C76) is used: it is the state of the random number generator at $8B74.
B $5C00,748,16
c $5EEC Shuffle the five crates
@ $5EEC label=ShuffleCrates
D $5EEC Copied here from #R$F88A by #R$F74E; always called via the JP at #R$FE92. Called once per level start (#R$5B2C) and continuously (hundreds of times per second) from the main menu loop at #R$E29E, so the final crate layout depends on how long the player waits in the menu. Pass 1 removes the crates placed last time: for every one of the 38 candidate cells in #R$5F61 whose flag is $FF, the flag is cleared and the crate tile ($8B/$57/$2F/$0F, #R$5F59) is turned back into the plain tile ($58/$30/$10/$04, #R$5F5D); a cell whose crate was already winched up already holds the plain tile and is left alone. Pass 2 picks 5 different cells: random L from #R$8B74 until L<$4C, index=L/2 (0-37, uniform), retry if already flagged; flag it $FF and turn the plain tile into the matching crate tile ($58->$8B, $30->$57, $10->$2F, anything else->$0F).
 $5EEC 38 candidate cells
 $5EF2 Crate placed here last time?
 $5EF7 Clear the flag
 $5EFB DE = map cell address
 $5EFE A = tile code in the map
 $5F00 Look it up in the 4 crate tiles
 $5F13 Found: replace it with the plain tile
 $5F1D Now place 5 crates
 $5F20 Random number (HL)
 $5F24 Retry until L < 76
 $5F2A A = L/2 = 0..37
 $5F2D A = index*3
 $5F37 Cell already chosen? Try again
 $5F3B Flag it
 $5F41 A = current (plain) tile
 $5F49 Look it up in the first 3 plain tiles; DE stops on $5F5C ($0F) if not found
 $5F52 Store the crate tile
b $5F59 Crate tile codes and the plain tiles they replace
B $5F59,4 Crate tiles: $8B, $57, $2F, $0F (also #R$F511)
B $5F5D,4 Matching plain tiles: $58, $30, $10, $04 (also #R$F51B)
b $5F61 Crate candidate cells (38 entries)
D $5F61 38 three-byte entries: flag ($FF = a crate was put here by the last shuffle, $00 = not) and the address of the cell in the 128-byte-wide world map at $9300. Initially all flags are 0.
B $5F61,114,3
B $5FD3,1 Last byte of the copied block
b $5FD4 Leftover bytes below the main code block
B $5FD4,8
c $5FDC Interrupt: crash noise
@ $5FDC label=CrashNoise
D $5FDC Jumped to from the interrupt handler $83C2 while the crash flag $7505 is 1 (crash sequence). Once per frame: random HL (#R$8B74); if L < $46 there is no sound this frame (70/256), otherwise 3 square-wave cycles are played, with the high phase lasting (H AND $F0) loop passes and the low phase (L AND $F0) loop passes (~43 T-states per pass), which gives a random-pitch rasping noise. Border stays black. Exits through the interrupt handler's register restore at $842D.
 $5FDF No sound on 70 of 256 frames
 $5FE5 3 cycles
 $5FE8 High phase length = H AND $F0
 $5FF0 Speaker on (bit 4), border black
 $5FF9 Low phase length = L AND $F0
 $6001 Speaker off
 $600C Restore registers, EI, RET
s $600F Unused
S $600F,9
w $6018 Survivor candidate cells (45 entries)
D $6018 Addresses of 45 cells in the world map (#R$6072). Each is a plain tile ($58, $30 or $10) at load time; at each level start the plain tile is replaced by a survivor tile.
W $6018,90,2
c $6072 Put survivors on the map
@ $6072 label=PlaceSurvivors
D $6072 Called at each level start (#R$5B2F). For each of the 45 cells listed at #R$6018: if the map tile is a plain tile $58/$30/$10 (#R$60AC) it is replaced by the survivor tile $89/$55/$2D (#R$60AF) plus a random 0 or 1 (bit 0 of L from #R$8B74), so it becomes one of the two survivor variants $89/$8A, $55/$56, $2D/$2E (both are survivors to the winch, #R$F515). Cells that still hold a survivor (not rescued) or a crate are left alone. OBSERVED: at the start of a game all 45 cells hold survivors.
 $6072 45 cells
 $6079 HL = cell address
 $607F A = tile
 $6080 Look up the three plain tiles
 $6091 A = survivor tile
 $6093 Random variant (+0 or +1)
 $60A2 Store it
b $60AC Plain tiles and the survivor tiles they become (#R$6072)
B $60AC,3 Plain tiles $58, $30, $10
B $60AF,3 Survivor tiles $89, $55, $2D (+0/+1 at random)
s $60B2 Unused
S $60B2,46
b $60E0 8x8 font (characters $17-$5A, base address $6028)
D $60E0 Character code c is at $6028+8*c (codes below $17 would overlap code and data). Used by #R$E40F, $859A, #R$6F00. $17-$1F: CYCLONE logo (menu title, 9 characters); $20 space; $21 "!"; $22 blank; $23/$24 WIND FORCE bar end caps; $25/$26 DANGER bar end pattern; $27 cyclone symbol (map key); $28 helicopter-position symbol (map key); $29/$2A arrows; $2B ","; $2C-$2F "-./" glyphs; $30-$39 digits; $3A "|" and $3B "-" (HUD rules); $3C-$40 the large "VIEW" HUD label; $41-$5A A-Z.
B $60E0,72,8 CYCLONE logo ($17-$1F)
B $6128,64,8 $20-$27
B $6168,64,8 $28-$2F
B $61A8,80,8 Digits $30-$39
B $61F8,56,8 $3A-$40
B $6230,208,8 Letters A-Z ($41-$5A)
b $6300 Tile column table A (north view), row 0
D $6300 Two tile-graphics tables, A at pages $63-$6B (north view) and B at pages $6C-$74 (south view, a mirrored copy), select by $7504 via the self-modified page operands at $7B18 and $7E35-$7F05 (set at $8113). For map tile code t (0-255) the bytes at (page+0)*256+t, (page+1)*256+t, ... give the character codes of that tile's vertical stack, bottom first, drawn upwards in the view buffer (one row up = -23 bytes): a code < $FE is drawn, $FE = transparent (skip a row), $FF = end of column. Character codes < $80 use the glyphs at #R$FA00 and attributes at #R$FE00; codes >= $80 are solid attribute-only blocks. Column heights (incl. $FF): 1 for t<$10, then t>=$10:2, $30:3, $58:4, $8C:5, $B2:6, $D0:7, $E4:8 (tiles are sorted by height). The unused low ends of the higher pages hold unrelated data (sprites, text, HUD layouts, code), split out below.
B $6300,256,16
b $6400 Tile column table A, row 1
B $6400,256,16
b $6500 Tile column table A, row 2 (tiles $10-$FE used)
B $6500,256,16
c $6600 Add 40 points to the score
@ $6600 label=AddScore40
D $6600 Used by #R$843A (time bonus).
c $6602 Add B points to the score
@ $6602 label=AddScore
D $6602 The score is the 7-character string at #R$661E ('.' = blank leading digit). Adds 1 to the last digit B times with decimal carry (B=0 adds 256), then prints it via #R$6F00. On exit B=$66 (left over from #R$6F00), which #R$83A5 relies on by accident.
R $6602 B Number of points to add
 $6602 Last digit
 $6606 A blank leading digit counts as '0'
 $660D Carry?
 $6611 Yes: digit := '0', move one digit left
 $6619 Print the score
t $661C Score and high-score strings
D $661C Printed right-to-left (#R$6F00, #R$87BC) at row 19 (score) and row 20 (high score), column 31 backwards. Leading blank digits are '.'. The high score starts at 0 and is only updated by #R$87BC (at the next game start or on the info screen).
B $661C,1 Terminator for the right-to-left print
T $661D,1 "S" label
T $661E,7 Score (7 digits)
B $6625,1 Terminator
T $6626,1 "H" label
T $6627,7 High score (7 digits)
B $662E,1
b $662F Tile column table A, row 3 (tiles $30-$FE)
B $662F,209,16
b $6700 Rotor overlay frame 0 (idle set)
D $6700 Four 24x24-pixel (3 bytes x 24 lines) rotor frames at $6700, $6800, $6900, $6A00, XORed onto the helicopter sprite by $8CA0 (frame number cycles 0-3 in $753A) when the helicopter is landed ($7515=1) or out of fuel ($7516<>0). In normal flight the 2-frame set at #R$7000/#R$7100 is used instead.
B $6700,72,3
b $6748 Tile column table A, row 4 (tiles $58-$FE)
B $6748,184,16
b $6800 Rotor overlay frame 1 (idle set)
B $6800,72,3
t $6848 HUD bottom two rows (64 characters)
D $6848 Printed at rows 22-23 by #R$84F4 (via $859A): WIND FORCE bar end caps ($23/$24), "WIND", rule chars ($22), "DANGER", DANGER bar pattern ($25/$26), "FORCE". The crate boxes and bar contents are drawn with attributes.
T $6848,64
b $6888 Tile column table A, row 5 (tiles $8C-$FE)
B $6888,120,16
b $6900 Rotor overlay frame 2 (idle set)
B $6900,72,3
B $6948,8 Unused ($FF)
b $6950 Helicopter sprite buffer
D $6950 24x24 pixels (3 bytes x 24 lines). Rebuilt every iteration by $8CA0 (heading frame from #R$E930 + rotor overlay) and during the crash sequence ($9246: frame at $9300 XOR debris frames #R$F550).
B $6950,72,3
b $6998 Tile column table A, row 6 (tiles $B2-$FE)
B $6998,104,16
b $6A00 Rotor overlay frame 3 (idle set)
B $6A00,72,3
B $6A48,7 Unused ($FF)
t $6A4F Island names (map labels)
D $6A4F Printed by $8DE2/#R$8DEE in the 4x8 font (#R$6B00) at the label position of each island record (#R$F230), in record order. The first byte is skipped. '?' is a space; $FD = append " ISLAND" (#R$6AC2) and go to the next island; $FE = next island; $FF = end.
B $6A4F,1 Skipped
T $6A50,6
B $6A56,1 append " ISLAND", next line
T $6A57,10
B $6A61,1 next line
T $6A62,6
B $6A68,1 append " ISLAND", next line
T $6A69,6
B $6A6F,1 append " ISLAND", next line
T $6A70,4
B $6A74,1 append " ISLAND", next line
T $6A75,4
B $6A79,1 append " ISLAND", next line
T $6A7A,9
B $6A83,1 append " ISLAND", next line
T $6A84,3
B $6A87,1 append " ISLAND", next line
T $6A88,4
B $6A8C,1 append " ISLAND", next line
T $6A8D,4
B $6A91,1 append " ISLAND", next line
T $6A92,14
B $6AA0,1 next line
T $6AA1,4
B $6AA5,1 append " ISLAND", next line
T $6AA6,14
B $6AB4,1 next line
T $6AB5,10
B $6ABF,1 append " ISLAND", next line
B $6AC0,1 end of text
B $6AC1,1 Unused
T $6AC2,7 " ISLAND" suffix ('?' = space)
B $6AC9,1 End of suffix ($FC)
b $6ACA Tile column table A, row 7 (tiles $D0-$FE)
B $6ACA,54,16
b $6B00 4x8 font for the map labels and the info screen text
D $6B00 Base address $6908 (character c at $6908+8*c); only codes $3F ('?', blank = space) to $5A are present. Each glyph occupies the left 4 pixels (values $00-$70); #R$8DEE prints two characters per screen byte (the second one shifted right 4 pixels).
B $6B00,8 "?" (space)
B $6B08,8 "@" (unused)
B $6B10,208,8 A-Z
b $6BE0 Tile column table A, row 8 (terminators of tiles $E4-$E9)
B $6BE0,32,16
b $6C00 Tile column table B (south view), row 0
D $6C00 Same layout as #R$6300 for the south (rotated 180 degrees) view.
B $6C00,256,16
b $6D00 Tile column table B, row 1
B $6D00,256,16
b $6E00 Tile column table B, row 2
B $6E00,256,16
c $6F00 Print the score
@ $6F00 label=PrintScore
D $6F00 Prints the string ending at #R$6624 right-to-left from row 19 column 31 (screen address $507F) until a $FF byte, using the 8x8 font (#R$6028), 7 pixel lines per character. Entry #R$6F06 (from #R$87BC) prints the high score with DE=$509F, BC=$662D.
@ $6F06 label=PrintBackwards
 $6F06 Next character (BC moves backwards)
 $6F15 Copy 7 pixel lines
 $6F1E Back to the top line, one column left
b $6F24 Tile column table B, row 3
B $6F24,220,16
b $7000 Rotor overlay frame 0 (flight set)
D $7000 Two rotor frames ($7000 and $7100) used by $8CA0 in normal flight (alternating via $753A 0/1).
B $7000,72,3
b $7048 Tile column table B, row 4
B $7048,184,16
b $7100 Rotor overlay frame 1 (flight set)
B $7100,72,3
b $7148 Attributes for the bottom two screen rows
D $7148 64 attribute bytes copied to rows 22-23 ($5AC0) by #R$84F4: crate boxes (6 = yellow), WIND FORCE bar (5/$38), DANGER bar ($7A).
B $7148,64,16
b $7188 Tile column table B, row 5
B $7188,120,16
b $7200 HUD panel attributes
D $7200 21 rows x 8 bytes, copied to columns 24-31 of rows 0-20 by #R$84F4.
B $7200,168,8
b $72A8 Tile column table B, row 6
B $72A8,88,16
b $7300 HUD panel character layout
D $7300 15 rows x 8 bytes for columns 24-31 of rows 0-14, drawn by #R$84F4. Each byte is a HUD glyph number n (glyph at $7400+8*n: A/S/F/T bar headings, bar frames, compass rose, helicopter life icons...) or $FF = leave blank.
B $7300,120,8
c $E280 Main menu
@ $E280 label=MainMenu
D $E280 Entered after initialisation (#R$F74E), at game over ($92A6), from the info screen and when A+G abandons a game (#R$5BE9). Silences the engine sound, beeps, waits for all keys to be released, draws the menu and highlights the selected controller. While waiting for a key it calls the crate shuffle (#R$FE92) continuously. Keys: 1 = information screen (#R$E3B4); 2 = keyboard, 3 = Interface 2, 4 = Kempston, 5 = Protek/AGF (cursor) joystick: stored as 0-3 in the control method $7FD5 (initially 0); 6 = start the game (#R$5B00). Other keys are ignored.
 $E280 $752D=1: interrupt handler makes no engine sound
 $E285 Beep (pitch $0666, $55 cycles)
 $E28E Wait until no key is pressed
 $E293 Clear the screen
 $E296 Draw the menu
 $E299 Current control method (0-3)
@ $E29E label=MenuLoop
 $E29E Shuffle the crates again (randomises the layout while waiting)
 $E2A1 Read a key (carry set: none)
 $E2A6 Ignore anything but "1".."6"
 $E2B0 "1": information screen
 $E2B5 "6": start the game
 $E2B8 "2".."5": control method 0..3
 $E2BD Rows 11-14, all columns: bright cyan on black...
 $E2C7 ...except the selected row (11+method), columns 9-21: flashing bright cyan
 $E2D8 Click
 $E2E1 Wait for the key to be released
c $E2E8 Draw the main menu
@ $E2E8 label=DrawMenu
D $E2E8 Colours rows 5-17, columns 9-21 from the list at #R$E3A6 (one attribute per row), draws a horizontal line (pixel line 3) across the same 13 columns of each of those rows (visible only on the red rows that carry no text: rows 8, 10, 15, 17), then prints the strings at #R$E325.
 $E2E8 One attribute per row
 $E2FF Pixel line 3 of row 5, column 9
 $E30C Move to the same pixel line of the next character row (bit-rotation trick)
 $E31F Print the menu strings
b $E325 Main menu strings
D $E325 Format for #R$E40F: screen address (2 bytes), character codes (font #R$6028), $FF; the list ends with another $FF.
W $E325,2 Screen address $40A9 (row 5, column 9)
B $E327,13 Character codes (font at $6028; $17-$1F = CYCLONE logo glyphs)
B $E334,1 End of string
W $E335,2 Screen address $40E9 (row 7, column 9)
T $E337,13
B $E344,1 End of string
W $E345,2 Screen address $4829 (row 9, column 9)
T $E347,13
B $E354,1 End of string
W $E355,2 Screen address $4869 (row 11, column 9)
T $E357,13
B $E364,1 End of string
W $E365,2 Screen address $4889 (row 12, column 9)
T $E367,13
B $E374,1 End of string
W $E375,2 Screen address $48A9 (row 13, column 9)
T $E377,13
B $E384,1 End of string
W $E385,2 Screen address $48C9 (row 14, column 9)
T $E387,13
B $E394,1 End of string
W $E395,2 Screen address $5009 (row 16, column 9)
T $E397,13
B $E3A4,1 End of string
B $E3A5,1 End of list
b $E3A6 Main menu row attributes
D $E3A6 One attribute for 13 cells (columns 9-21) of each of rows 5-17 (#R$E2E8): logo row bright white; SELECT OPTION white; red rule rows; options white (rows 11-14 are recoloured by the highlight code).
B $E3A6,13,13
B $E3B3,1 End of list
c $E3B4 Information screen
@ $E3B4 label=InfoScreen
D $E3B4 Menu option 1. Draws the HUD panel and labels every HUD element, the key controls and the map symbols, then waits for any key and returns to the menu. Also updates the high score (#R$87BC).
 $E3B4 Clear the screen
 $E3B7 Beep (pitch $0400, $70 cycles)
 $E3C0 Wait until no key is pressed
 $E3C5 Draw the HUD panel
 $E3C8 Play area (23 x 22 cells): bright red ink on white paper
 $E3DB $7530=3: aircraft collision warning lit
 $E3E0 Speed $7527=0
 $E3E4 Draw compass/speedometer/warning
 $E3E7 Print the score
 $E3EA Update and print the high score
 $E3ED Print all the information texts
 $E3F0 Wait for a key
c $E3F8 Read the keyboard (ROM)
@ $E3F8 label=GetKey
D $E3F8 Uses ROM KEY-SCAN ($028E), K-TEST ($031E) and K-DECODE ($0333, L mode).
R $E3F8 O:A ASCII code of the key pressed (0 if none)
R $E3F8 O:F Carry clear if a single valid key is pressed, set if none
c $E40F Print a list of strings (8x8 font)
@ $E40F label=PrintStrings
D $E40F Each string: screen address (2 bytes), character codes, $FF; a second $FF ends the list. Characters are copied from the font at #R$6028 (8 pixel lines each).
R $E40F HL String list
b $E436 Unused
B $E436,4
c $E43A Print the information screen texts
@ $E43A label=DrawInfoTexts
D $E43A Prints the 29 lines of 4x8-font text at #R$E517 (positions from #R$E69C; the stride operand at $8E0A is set to 3 here, the map labels use 20), the two headings and the highlighted key letters/map symbols in the 8x8 font, horizontal rules (#R$E504), the leaving-map arrow (HUD glyph at $7460), crate glyph ($FB80, char $30) and survivor glyph ($FB90, char $32), and makes "PRESS ANY KEY" flash.
 $E43A Line position table base (IX+$10 = #R$E69C)
 $E43E Line-record stride 3 for $8DEE
 $E443 Print the small-font texts
 $E449 "KEY CONTROLS" at row 1, column 1
 $E454 "MAP INDICATORS" at row 8, column 1
 $E45F Draw horizontal rules (list at #R$E504)
 $E473 Single characters: "1" row 3 col 1, "O" row 3 col 7, "Q" row 4 col 1, "P" row 4 col 7, "X" row 5 col 1, "N" row 5 col 7, "M" row 6 col 1, "N" row 14 col 21, helicopter symbol row 10 col 1, cyclone symbol row 11 col 1
 $E4B6 Leaving-map arrow at row 12, column 1
 $E4C5 Crate glyph at row 14, column 1
 $E4CD Survivor glyph at row 16, column 1
 $E4D5 "PRESS ANY KEY" (row 18, columns 1-7) flashing
t $E4E0 Information screen headings and key letters
T $E4E0,12 "KEY CONTROLS"
T $E4EC,14 "MAP INDICATORS"
T $E4FA,8 Key letters 1 O Q P X N M N
B $E502,2 Map symbols: $28 helicopter position, $27 cyclone location
b $E504 Information screen horizontal rules
D $E504 Entries: length, screen address (2 bytes); all bytes are set to $FF. List ends with $FF.
B $E504,18,3
B $E516,1 End of list
t $E517 Information screen texts (4x8 font)
D $E517 Printed by #R$8DEE from E518 (first byte skipped): lines separated by $FE, '?' = space, $FF = end. Line n is printed at the screen position in entry n of #R$E69C.
B $E517,1 Skipped
T $E518,3
B $E51B,1 next line
T $E51C,5
B $E521,1 next line
T $E522,5
B $E527,1 next line
T $E528,6
B $E52E,1 next line
T $E52F,8
B $E537,1 next line
T $E538,12
B $E544,1 next line
T $E545,19
B $E558,1 next line
T $E559,20
B $E56D,1 next line
T $E56E,17
B $E57F,1 next line
T $E580,17
B $E591,1 next line
T $E592,20
B $E5A6,1 next line
T $E5A7,19
B $E5BA,1 next line
T $E5BB,21
B $E5D0,1 next line
T $E5D1,13
B $E5DE,1 next line
T $E5DF,13
B $E5EC,1 next line
T $E5ED,11
B $E5F8,1 next line
T $E5F9,10
B $E603,1 next line
T $E604,12
B $E610,1 next line
T $E611,10
B $E61B,1 next line
T $E61C,10
B $E626,1 next line
T $E627,8
B $E62F,1 next line
T $E630,8
B $E638,1 next line
T $E639,6
B $E63F,1 next line
T $E640,14
B $E64E,1 next line
T $E64F,9
B $E658,1 next line
T $E659,10
B $E663,1 next line
T $E664,8
B $E66C,1 next line
T $E66D,20
B $E681,1 next line
T $E682,24
B $E69A,1 end of text
B $E69B,1 end of text
b $E69C Information screen text line positions
D $E69C 29 entries: screen address (2 bytes), attribute page ($58/$59/$5A; the attribute of each cell written gets $78). Accessed as IX+$10..IX+$12 with IX=$E68C+3n.
B $E69C,87,3
b $E6F3 Unused
B $E6F3,13
b $E700 Aircraft movement opcodes
D $E700 16 directions x 4 bytes, patched into the aircraft mover at $8867/$8868 (X) and $8871/$8872 (Y) by $87F0: $03 = INC BC, $0B = DEC BC, $00 = NOP, so each axis moves -2..+2 per iteration.
B $E700,64,4
b $E740 Aircraft course script
D $E740 15 records of 20 bytes; $87F0 advances to the next record every 28 iterations (wrapping at $E85A to $E740). Each record is a list of new directions for the aircraft table (#R$E86C); a byte with bit 7 set also resets that aircraft's position from #R$E8CC; $FF ends a record.
B $E740,300,20
b $E86C Aircraft table
D $E86C 19 aircraft x 5 bytes: direction (0-15, index into #R$E700), X (word), Y (word); $FF ends the table. Updated by $87F0, which also sets the collision warning bits in $7530 when one is near the helicopter.
B $E86C,95,5
B $E8CB,1 End of table
b $E8CC Aircraft start positions
D $E8CC Same layout as #R$E86C; copied into it (4 bytes per aircraft) when the course script says so.
B $E8CC,95,5
B $E92B,1 End of table
B $E92C,4 Unused
b $E930 Helicopter frames (16 headings)
D $E930 16 frames x 72 bytes (24x24 pixels, 3 bytes x 24 lines), frame h at $E8E8+72*(h+1), h = heading $7507 (or heading+8 AND 15 in the south view). Used by $8CA0. The graphics agent decodes these.
B $E930,1152,3
b $EDB0 Helicopter mask/shadow frames (16 headings)
D $EDB0 16 frames x 72 bytes, frame h at $ED68+72*(h+1) (used by $7BB8; $FF bytes are transparent).
B $EDB0,1152,3
b $F230 Island records
D $F230 14 records of 20 bytes, terminated by $FF, in the order of the names at #R$6A4F: BANANA, ORTE ROCKS, KOKOLA, LAGOON, PEAK, BASE (#R$F294, the home island: level complete needs $7552=$F294), GILLIGANS, RED, SKEG, BONE, GIANTS GATEWAY, CLAW, LUKELAND ISLES, ENTERPRISE. +0/+1: world X and Y high bytes; +2/+3: X low range [min,max); +4/+5: Y low range [min,max) (bounding box tested by $76D2 to set $7552); +6..+9: X/Y origin bytes used to convert world coordinates to map cells (cell = base + (Y+$0E-[+8])*128 + (X+$0B-[+6]), #R$F444); +$0A/+$0B: address of the island's origin in the 128-byte-wide world map; +$0C/+$0D: screen address of the island bitmap on the map screen; +$0E/+$0F: its width/height; +$10/+$11: label screen address; +$12: label attribute page; +$13: 0.
B $F230,280,20
B $F348,1 End of records
B $F349,1 Unused
c $F34A Animate the survivor glyphs
@ $F34A label=AnimateSurvivors
D $F34A Called every main-loop iteration. Character $31 (glyph $FB88, 7 lines) alternates between the frames at $7DEE and $7DF6 every 4 iterations (counter $755B, 0-7); character $32 (glyph $FB90, 8 lines) alternates between $7DFE and $7E06 every 3 iterations (counter $755C, 0-5).
 $F34A Glyph of character $31
 $F350 Counter 1 reaches 4: frame 1
 $F35A Counter 1 reaches 8: frame 0, counter := 0
 $F36A Glyph of character $32
 $F370 Counter 2 reaches 3: frame 1
 $F37A Counter 2 reaches 6: frame 0, counter := 0
s $F38B Unused
S $F38B,15
c $F39A Winch: pick up crates and survivors
@ $F39A label=Winch
D $F39A Called every main-loop iteration. $7A85 is the tile under the helicopter (centre of the 3x3 tiles saved by $7E10). If it is a crate (#R$F511) or survivor (#R$F515) tile, a rope is lowered: E = vertical gap in pixel lines between the helicopter and the object (from the view-buffer addresses; RET if negative or >255). If E>=17 the rope just dangles (12 lines, then 16 lines max) and nothing happens. If E<17 the rope takes two iterations to reach the object (winch state $7556: 0 -> 1 -> 2, the step is skipped if E>=13), then the object is hooked: the map cell is overwritten with the plain tile (#R$F51B) so the object disappears from the world, and a crate increments $7554 and turns its HUD box red (attribute 2, boxes from the right). $7555 is then set to max(E,2)-1 and the object is reeled in by 1+$751B lines per iteration (faster while descending); when $7555 reaches 0 the points are scored: crate 250, survivor 50. When the helicopter moves off the object the rope is drawn retracted once (12 lines) and $7556 reset. While $7555<>0 the interrupt handler plays a winch beep.
 $F39A Object being reeled in ($7555=1-16)?
 $F3A3 Tile under the helicopter
 $F3A6 Crate tile?
 $F3B5 Survivor tile (either variant)?
 $F3C8 Nothing under the helicopter: retract a lowered rope
 $F3D6 Survivor: B = 1-3 (pair index from the end); sprite #R$F548
 $F3DC Crate: B = 1-4; sprite #R$F52F
 $F3DF $7557 = rope+object graphic
 $F3E2 $7551 = plain tile that replaces the object in the map
 $F3E6 Object position in the view buffer area
@ $F3F3 label=IM2Vector
 $F3F3 IM2 interrupt vector target (I=$FF, table at $FF00 is all $F3): JP to the interrupt handler $83C2. Skipped over by the JR above.
 $F3F6 DE = $FDA1-8*B
 $F3F9 Helicopter altitude
 $F403 DE = gap between helicopter and object
 $F408 Not in reach (gap < 0 or > 255)
 $F40F Gap >= 17: rope cannot reach
 $F414 Rope length 16...
 $F41C ...or 12 on the first iteration
 $F425 Winch state 2
 $F427 Draw the rope only (#R$F51F)
 $F42F Gap < 13: advance the winch state
 $F434 Not yet extended twice: keep extending
 $F439 Hooked: rope length = max(gap,2)-1
 $F444 IX = island record under the helicopter
 $F448 Island's map origin
 $F44E Map row = Y + 14 - origin Y ...
 $F45A ... * 128
 $F464 Map column = X + 11 - origin X
 $F46F Replace the object by the plain tile
 $F473 Winch state 0
 $F477 Survivor? Skip the crate count
 $F480 Crates collected + 1 (max 5)
 $F488 HUD crate box n (attributes $5ACA-2n, 2x2 cells) := red
 $F4A6 Draw rope + object
@ $F4AB label=WinchReel
 $F4AB Reeling in: rope length - 1 - descent rate ($751B), not below 0
 $F4B7 Still on the rope?
 $F4BB Arrived: 50 points for a survivor...
 $F4C6 ...250 for a crate
 $F4CC Draw rope (A lines) + object (8 lines) below the helicopter
 $F4D8 $7512 := 2
 $F50A Too long? Don't draw
 $F50E Draw C lines of graphic DE at HL ($86EA)
b $F511 Winch tables and graphics
B $F511,4 Crate tiles $8B, $57, $2F, $0F
B $F515,6 Survivor tiles (pairs) $89/$8A, $55/$56, $2D/$2E
B $F51B,4 Plain tiles that replace them: $58, $30, $10, $04
B $F51F,16 Rope (16 lines) above the crate
B $F52F,8 Hook and crate (#R$F39A pointer $7557)
B $F537,1
B $F538,16 Rope (16 lines) above the survivor
B $F548,8 Survivor (#R$F39A pointer $7557)
b $F550 Crash debris overlays
D $F550 5 frames x 72 bytes (24x24 pixels), XORed one after another onto the wreck sprite in #R$6950 during the first 5 iterations of the crash sequence ($9246/$92ED, pointer $9243).
B $F550,360,3
b $F6B8 Unused at load; overflow rows above the view buffer at run time
D $F6B8 Tall terrain columns are drawn upwards past the top row of the view buffer at #R$F74E, so this area is overwritten every iteration during play (observed $F6CD-$F74D).
B $F6B8,150,16
c $F74E Initialisation
@ $F74E label=Init
D $F74E Jumped to from the loader entry #R$FE98 after the tape has loaded. Copies the main-loop code to the printer buffer (#R$F78A -> #R$5B00, 255 bytes) and the crate shuffle to #R$5EEC (#R$F88A, 232 bytes), writes JP $5EEC at #R$FE92, fills the IM2 vector table $FF00-$FFFF with $F3 (vector $F3F3 for any data bus value, incl. $FFFF/$0000 = $F3 $F3 from the ROM), sets I=$FF and IM 2 and enters the main menu. After this runs, the area from here to $F9FF is reused as the view buffer, so this code and the two source copies are overwritten during play.
 $F765 FE92: JP $5EEC
 $F770 256 bytes of $F3 (B=0)
s $F784 Unused
S $F784,6
b $F78A Source copy of the routine at $5B00 (duplicate)
D $F78A Identical to #R$5B00-$5BFE (255 bytes) after #R$F74E has copied it. Overwritten at run time (view buffer). See #R$5B00 for the disassembly.
B $F78A,255,16
B $F889,1 Unused
b $F88A Source copy of the routine at $5EEC (duplicate)
D $F88A Identical to #R$5EEC-$5FD3 (232 bytes). Overwritten at run time (view buffer). See #R$5EEC.
B $F88A,232,16
s $F972 View buffer (rest)
D $F972 The view buffer occupies $F74E-$F9E8 (29 rows x 23 character cells; cleared every iteration by $76D2, row 0 at the top; $F8B1 = row 15 column 10 is the cell under the helicopter), $F9E9-$F9FF is a spare row used by $77F8/$7870.
S $F972,142
b $FA00 Terrain character glyphs ($00-$7F)
D $FA00 Glyph of character c (0-$7F) at $FA00+8*c, used by the view blitter $762C. $00-$5E are static terrain graphics ($30 = crate at $FB80; $31/$32 = the two survivors, animated by #R$F34A; $33-$3E are rebuilt by $89AC-$8A66 for the helicopter shadow). $5F-$7F ($FCF8-$FDFF) are dynamic glyphs rebuilt every iteration for the helicopter, rope and objects ($7F24, $85D4, $86AF, $7BB8). Codes $80+ have no glyph (solid colour).
B $FA00,760,8
B $FCF8,264,8 Dynamic glyphs $5F-$7F
b $FE00 Terrain character attributes
D $FE00 Attribute of character code c at $FE00+c (view blitter $762C: LD H,$FE / LD L,code). $FE5F-$FE7F hold the attributes of the dynamic glyphs (rebuilt at run time, 0 at load); $FE80-$FE91 the colours of the solid blocks $80-$91 (e.g. $87 green, $89/$83 landing pad).
B $FE00,95,16
B $FE5F,33,16 Dynamic glyph attributes
B $FE80,18,16 Solid block colours ($80-$91)
c $FE92 Jump to the crate shuffle
@ $FE92 label=ShuffleVector
D $FE92 Written by #R$F74E over the loader's LD DE,$9EB6. Called by #R$5B2C and the menu loop #R$E29E.
c $FE95 Unused remnant of the tape loader
D $FE95 Part of the original turbo loader (#R$FE98 is the old continuation). Never executed.
c $FE98 Program entry point (RANDOMIZE USR 65176)
@ $FE98 label=Entry
D $FE98 The BASIC loader loads the screen ("Cyclone2"), this 512-byte block at $FE00 ("Cyclone4") and the main block at $5FDC-$FE91 ("Cyclone3", which overwrites $FE00-$FE91) with the ROM, then calls here. In the original loader block $FE00 decrypted $FE80-$FFFF (XOR with R) and $FE80 loaded the screen and the main block with its own LD-BYTES at $FE9F before falling into this code; that path is not used by this version.
c $FE9F Unused remnant of the tape loader's LD-BYTES routine
D $FE9F A copy of the ROM's LD-BYTES ($0556) used by the original turbo loader; its second half ($FF00+) has been overwritten by the IM2 table. Never executed. The stack (SP=$FEFF) grows down into its last bytes (observed $FEE5-$FEFE in use).
b $FF00 IM2 vector table
D $FF00 256 bytes of $F3 (written by #R$F74E). With I=$FF the CPU reads the vector from $FFxx/$FFxx+1, always $F3F3 (for bus value $FF the second byte is $0000 in ROM, also $F3), which holds JP $83C2 (#R$F3F3).
B $FF00,256,16
