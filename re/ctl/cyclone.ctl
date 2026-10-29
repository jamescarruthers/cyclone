@ $5B00 start
@ $5B00 org

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
D $6F00 Prints the string ending at $6624 right-to-left from row 19 column 31 (screen address $507F) until a $FF byte, using the 8x8 font (#R$6028), 7 pixel lines per character. Entry #R$6F06 (from #R$87BC) prints the high score with DE=$509F, BC=$662D.
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
c $7378 Cyclone buffeting of the controls
D $7378 Called from the main loop (5B94) after the controls have been read (7FD6) when the heli-cyclone map distance #R$7550 is below 5 (level 1) or 6 (later levels; the CP operand at 5B93 is patched by 8321). Adds random control inputs to #R$7522 so the helicopter is thrown about; very close to the cyclone it forces DOWN+LEFT (a descending spin).
R $7378 A Cyclone distance (#R$7550), 0..5
N $7378 Random bits come from L of the RNG at $8B74 (each bit ~50%). dist 4..5: bits 1/3/4 (down, right, left) may be added; dist 2..3: bits 0/1/3/4 (also forward); dist 0..1: controls are replaced by $12 (down+left) and the turn timer is run down one extra step.
 $7378 Save the distance
 $7379 No effect while landed
 $737F Two NOPs (patched-out code)
 $7382 Distance 4 or 5?
 $7386 RND
 $738A Keep random down/right/left bits (mask $1A)
 $738C OR them into the control bits
 $7392 Distance 2 or 3?
 $7396 RND
 $739A Random forward/down/right/left (mask $1B)
 $73A2 Distance 0 or 1: speed up a turn in progress
 $73A9 Decrement the turn timer if non-zero
 $73AA Force controls = down + turn left
u $73B0 Unused code fragment
D $73B0 Never referenced (no caller found statically or during emulation). Bytes would be NOP / RET NZ / set the crash flag #R$7505 to 1 / RET.
C $73B0,8
b $73B8 South-view terrain pillar table, page $73 (8th pillar level), codes $B8-$FF
D $73B8 Part of the south-view pillar tables $6C00-$73FF (see #R$7E10): byte $7300+code is the 8th (topmost) tile of the pillar drawn for map code 'code' in south view. Only codes $E4-$FF ever reach this level; $FF = end of pillar. (The bytes below $73B8 belong to the HUD layout table at $7300, outside this range.)
B $73B8,44,8 $FF: codes $B8-$E3 never have an 8th level
B $73E4,28,8 8th-level pillar tiles for codes $E4-$FF ($FF = none)
b $7400 HUD / panel 8x8 character set (codes $00-$1B)
D $7400 Character k is at $7400+8*k. Drawn by 84F4 (HUD layout table $7300, LD H,$74) and by 8E5C/E43A (map and info-screen borders). The trailing $FF bytes at $74E0 also terminate south-view pillars at page $74 (9th level).
B $7400,56,8 Chars $00-$06: HUD panel pieces (lettering/bars)
B $7438,8 Char $07: map-border top-left corner piece
B $7440,8 Char $08: map-border top edge (up arrow)
B $7448,8 Char $09: map-border top-right corner piece
B $7450,16,8 Chars $0A-$0B: HUD panel pieces
B $7460,8 Char $0C: map-border left edge (left arrow)
B $7468,8 Char $0D: compass centre ring
B $7470,8 Char $0E: map-border right edge (right arrow)
B $7478,8 Char $0F: HUD panel piece
B $7480,8 Char $10: map-border bottom-left corner piece
B $7488,8 Char $11: map-border bottom edge (down arrow)
B $7490,8 Char $12: map-border bottom-right corner piece
B $7498,72,8 Chars $13-$1B: HUD panel pieces (incl. letters A, S, F, T at $74B8-$74D0)
B $74E0,32,8 $FF filler (also = end markers for pillar page $74)
b $7500 LIVE GAME VARIABLES ($7500-$7563)
D $7500 The 100-byte variable block. At game start 5B1B copies the initial values #R$7564 here (LDIR 100 bytes); after each lost life 92B3 copies #R$75C8 over it, skipping bytes whose reset value is $FF. Variable names below are those used in re/notes/core1.md (the glossary).
W $7500,2 POS_X: X: world X of view-window origin (16-bit, tiles); heli ground tile = X+11; +1 = east
W $7502,2 POS_Y: Y: world Y of view-window origin (16-bit, tiles); heli ground tile = Y+14; -1 = north
B $7504,1 VIEW: View direction: 0 = view north, 1 = view south (world rotated 180 deg); toggled by N
B $7505,1 CRASHED: Crash flag: 1 = helicopter destroyed (set by 8A7A at 8B5F)
B $7506,1 HEADING: Heading 0-15 (22.5 deg units, 0=N 4=E 8=S 12=W); changes in steps of 2
B $7507,1 HEADING_DISP: Displayed heading / sprite frame 0-15 (odd = mid-turn frame)
B $7508,1 HEADING_NEXT: Heading at end of current turn (7506+-2 mod 16)
W $7509,2 TMP_GFX: Scratch pointer: tile-graphics/target pointer (7BB8, 7F21, 85D4) or column-list ptr (86AF)
W $750B,2 TMP_ATTR: Scratch pointer into tile-attribute table FE00-FE7F (7BB8, 7F21, 85D4, 86AF)
B $750D,1 ALTITUDE: Altitude in pixels 0..60 ($3C); climb/descent 1..3 per loop
W $750E,2 TMP_SPR: Scratch: shadow sprite source pointer (ED68+72*(frame+1)), +8 per cell
W $7510,2 TMP_LIST: Scratch: pointer into 7A9F column list (7BB8)
W $7512,2 TMP_MASK: Scratch: 7BB8 second mask pointer (word); 86AF/F4DA byte column counter 0..2
B $7514,1 TOUCHDOWN: Touch-down flag: 1 = tried to descend below altitude 0 (8269); landing check in 8A7A
B $7515,1 LANDED: Landed flag: 1 = on the ground (8AF7); UP clears it (take-off, 820D)
B $7516,1 NO_FUEL: Out-of-fuel flag: 1 = fuel bar empty (82C1); forces descent, no climb/thrust
B $7517,1 FUEL_TICK: Fuel tick: drain one fuel line every 49 loops (0..$30)
W $7518,2 FUEL_PTR: FUEL bar pointer (screen addr, column $1C); $47BC = empty
B $751A,1 CLIMB_RATE: Climb rate 0..3 px/loop (ramps while UP held)
B $751B,1 DESCENT_RATE: Descent rate 0..3 px/loop (ramps while DOWN held or no fuel); >=3 on contact = crash
W $751C,2 TIME_PTR: TIME bar pointer (screen addr, column $1E); low byte $DE = time up
W $751E,2 ALT_PTR: ALTIMETER bar pointer (screen addr, column $18)
B $7520,1 Unused (never accessed: no static reference, no access in emulation)
B $7521,1 TURN_TIMER: Turn timer: 3 at start of a 45-deg turn, completes at 1; 0 = idle
B $7522,1 CONTROLS: Control bits: b0 forward, b1 down, b2 up, b3 right, b4 left
B $7523,1 Unused (never accessed: no static reference, no access in emulation)
B $7524,1 PLANE_COL: Aircraft view column (0..24 = buffer col+2, mirrored in south view)
B $7525,1 PLANE_ROW: Aircraft view row (0..30 = buffer row+2, mirrored in south view)
B $7526,1 UI_FLAGS: b0 M held, b1 map shown, b2 N held, b3 map closed (unused), b4 map needs drawing
B $7527,1 SPEED: Speed/momentum 0..7: +1/loop thrusting, -1/loop coasting; moves 1 tile/loop while >0
B $7528,1 TIME_TICK: Time tick: one TIME bar line lost every 255 loops (level 1), 15 fewer per level
W $7529,2 TMP_LIST2: Scratch: column-list pointer for heli body/rope occlusion (86AF, F4F8)
W $752B,2 TMP_ATTR2: Scratch: attribute pointer for heli body cells (86AF, F4F1)
B $752D,1 SOUND_OFF: 1 = interrupt sound effects off (menu E282, death sequence 9278)
B $752E,1 ON_PAD: 1 = landed on a complete 3x3 helipad (tiles $83/$89): refuel, level check
B $752F,1 PLANE_DRAWN: 1 = an aircraft sprite was built this loop (only the first one)
B $7530,1 PLANE_NEAR: Aircraft proximity: b0 X-window, b1 Y-window; 3 = BEWARE AIRCRAFT
B $7531,2 Unused (never accessed: no static reference, no access in emulation)
B $7533,1 HELI_LEVEL: Heli altitude level for aircraft: alt/8+1 (1..7)
B $7534,1 AIR_TICK: Free-running loop counter while airborne (bit 2 gates 7533 update)
B $7535,1 WAVE_X: Sea-wave pattern column phase 0..8 (wraps to 4)
B $7536,1 WAVE_Y: Sea-wave pattern row phase 0..6 (wraps to 3)
B $7537,1 WAVE_TICK: Wave re-seed counter 0..2
W $7538,2 WAVE_PTR: Wave pattern source pointer $01xx (ROM bytes as random data)
B $753A,1 ROTOR_FRAME: Rotor animation frame: 0..1 flying, 0..3 landed / no fuel
B $753B,1 MOVE_DIR: Direction of travel (heading latched while thrusting); used when coasting
W $753C,2 MAP_ROW_PTR: Map screen: pixel address of current island bitmap row (8D5D)
W $753E,2 MAP_PTR: Map screen: running pixel pointer within the row (8D5D)
B $7540,1 MAP_HX: Heli map column = X/32 clamped 0..22
B $7541,1 MAP_HY: Heli map row = Y/32 clamped 0..21
B $7542,1 MAP_BLINK: Map marker blink counter 0..6
W $7543,2 MAP_HATTR: Map: attribute address of heli marker
W $7545,2 MAP_HPIX: Map: pixel address of heli marker
W $7547,2 MAP_CATTR: Map: attribute address of cyclone marker
W $7549,2 MAP_CPIX: Map: pixel address of cyclone marker
B $754B,1 CYC_X: Cyclone map column 1..21 (start 2 or 20)
B $754C,1 CYC_Y: Cyclone map row 1..20 (start 2 or 19)
B $754D,1 OFF_MAP: Number of axes on which the heli is off the map grid (0..2)
B $754E,1 CYC_TICK: Cyclone move timer 0..24 (moves every 25 loops)
B $754F,1 CYC_LEG: Cyclone leg counter 0..8 (new random direction every 9 moves)
B $7550,1 CYC_DIST: Distance heli-cyclone on map grid = max(abs dx, abs dy), capped 15
B $7551,1 PICK_TILE: Replacement tile code written to the island map when a pickup starts
W $7552,2 ISLAND: Address of current island record (F230 table); $F294 = Base island
B $7554,1 CRATES: Crates collected this level 0..5
B $7555,1 WINCH: Winch countdown: 1..16 = object being winched up; 0 = idle
B $7556,1 ROPE_STATE: Rope lowering state 0..2 (F39A)
W $7557,2 PICK_SPR: Pointer to sprite of hooked object: $F52F crate, $F548 survivor
B $7559,2 Unused (never accessed: no static reference, no access in emulation)
B $755B,1 SURV_ANIM1: Survivor animation counter 0..7 (frame swap at 4 and 8)
B $755C,1 SURV_ANIM2: Survivor animation counter 0..5 (frame swap at 3 and 6)
B $755D,1 ROTOR_SND: Rotor sound phase 0..3 (interrupt 83C2)
B $755E,6 Unused (never accessed: no static reference, no access in emulation)
b $7564 Initial values of the variable block
D $7564 Copied to #R$7500 (100 bytes) by 5B1B at the start of every game. One sub-block per variable of #R$7500.
W $7564,2 Initial value of POS_X ($7500) = $0139
W $7566,2 Initial value of POS_Y ($7502) = $0170
B $7568,1 Initial value of VIEW ($7504) = $00
B $7569,1 Initial value of CRASHED ($7505) = $00
B $756A,1 Initial value of HEADING ($7506) = $04
B $756B,1 Initial value of HEADING_DISP ($7507) = $04
B $756C,1 Initial value of HEADING_NEXT ($7508) = $04
W $756D,2 Initial value of TMP_GFX ($7509) = $0000
W $756F,2 Initial value of TMP_ATTR ($750B) = $0000
B $7571,1 Initial value of ALTITUDE ($750D) = $08
W $7572,2 Initial value of TMP_SPR ($750E) = $0000
W $7574,2 Initial value of TMP_LIST ($7510) = $0000
W $7576,2 Initial value of TMP_MASK ($7512) = $0000
B $7578,1 Initial value of TOUCHDOWN ($7514) = $00
B $7579,1 Initial value of LANDED ($7515) = $01
B $757A,1 Initial value of NO_FUEL ($7516) = $00
B $757B,1 Initial value of FUEL_TICK ($7517) = $00
W $757C,2 Initial value of FUEL_PTR ($7518) = $47BC
B $757E,1 Initial value of CLIMB_RATE ($751A) = $00
B $757F,1 Initial value of DESCENT_RATE ($751B) = $00
W $7580,2 Initial value of TIME_PTR ($751C) = $0000
W $7582,2 Initial value of ALT_PTR ($751E) = $0000
B $7584,1 Initial value of unused $7520
B $7585,1 Initial value of TURN_TIMER ($7521) = $00
B $7586,1 Initial value of CONTROLS ($7522) = $00
B $7587,1 Initial value of unused $7523
B $7588,1 Initial value of PLANE_COL ($7524) = $00
B $7589,1 Initial value of PLANE_ROW ($7525) = $00
B $758A,1 Initial value of UI_FLAGS ($7526) = $00
B $758B,1 Initial value of SPEED ($7527) = $00
B $758C,1 Initial value of TIME_TICK ($7528) = $00
W $758D,2 Initial value of TMP_LIST2 ($7529) = $0000
W $758F,2 Initial value of TMP_ATTR2 ($752B) = $0000
B $7591,1 Initial value of SOUND_OFF ($752D) = $00
B $7592,1 Initial value of ON_PAD ($752E) = $01
B $7593,1 Initial value of PLANE_DRAWN ($752F) = $00
B $7594,1 Initial value of PLANE_NEAR ($7530) = $00
B $7595,2 Initial value of unused $7531-$7532
B $7597,1 Initial value of HELI_LEVEL ($7533) = $03
B $7598,1 Initial value of AIR_TICK ($7534) = $00
B $7599,1 Initial value of WAVE_X ($7535) = $00
B $759A,1 Initial value of WAVE_Y ($7536) = $00
B $759B,1 Initial value of WAVE_TICK ($7537) = $00
W $759C,2 Initial value of WAVE_PTR ($7538) = $0000
B $759E,1 Initial value of ROTOR_FRAME ($753A) = $00
B $759F,1 Initial value of MOVE_DIR ($753B) = $04
W $75A0,2 Initial value of MAP_ROW_PTR ($753C) = $0000
W $75A2,2 Initial value of MAP_PTR ($753E) = $0000
B $75A4,1 Initial value of MAP_HX ($7540) = $00
B $75A5,1 Initial value of MAP_HY ($7541) = $00
B $75A6,1 Initial value of MAP_BLINK ($7542) = $00
W $75A7,2 Initial value of MAP_HATTR ($7543) = $0000
W $75A9,2 Initial value of MAP_HPIX ($7545) = $0000
W $75AB,2 Initial value of MAP_CATTR ($7547) = $0000
W $75AD,2 Initial value of MAP_CPIX ($7549) = $0000
B $75AF,1 Initial value of CYC_X ($754B) = $02
B $75B0,1 Initial value of CYC_Y ($754C) = $02
B $75B1,1 Initial value of OFF_MAP ($754D) = $00
B $75B2,1 Initial value of CYC_TICK ($754E) = $00
B $75B3,1 Initial value of CYC_LEG ($754F) = $00
B $75B4,1 Initial value of CYC_DIST ($7550) = $00
B $75B5,1 Initial value of PICK_TILE ($7551) = $00
W $75B6,2 Initial value of ISLAND ($7552) = $0000
B $75B8,1 Initial value of CRATES ($7554) = $00
B $75B9,1 Initial value of WINCH ($7555) = $00
B $75BA,1 Initial value of ROPE_STATE ($7556) = $00
W $75BB,2 Initial value of PICK_SPR ($7557) = $0000
B $75BD,2 Initial value of unused $7559-$755A
B $75BF,1 Initial value of SURV_ANIM1 ($755B) = $00
B $75C0,1 Initial value of SURV_ANIM2 ($755C) = $00
B $75C1,1 Initial value of ROTOR_SND ($755D) = $00
B $75C2,6 Initial value of unused $755E-$7563
b $75C8 Per-life reset values of the variable block
D $75C8 After a lost life 92B3 copies these 100 bytes over #R$7500, except that a byte of $FF leaves the variable unchanged (time bar #R$751C, map marker pointers #R$7543-$754A, cyclone state #R$754B/#R$754C/#R$754E/#R$754F and crates #R$7554 survive a death). The values otherwise equal #R$7564.
W $75C8,2 Per-life reset value ($FF = keep) of POS_X ($7500) = $0139
W $75CA,2 Per-life reset value ($FF = keep) of POS_Y ($7502) = $0170
B $75CC,1 Per-life reset value ($FF = keep) of VIEW ($7504) = $00
B $75CD,1 Per-life reset value ($FF = keep) of CRASHED ($7505) = $00
B $75CE,1 Per-life reset value ($FF = keep) of HEADING ($7506) = $04
B $75CF,1 Per-life reset value ($FF = keep) of HEADING_DISP ($7507) = $04
B $75D0,1 Per-life reset value ($FF = keep) of HEADING_NEXT ($7508) = $04
W $75D1,2 Per-life reset value ($FF = keep) of TMP_GFX ($7509) = $0000
W $75D3,2 Per-life reset value ($FF = keep) of TMP_ATTR ($750B) = $0000
B $75D5,1 Per-life reset value ($FF = keep) of ALTITUDE ($750D) = $08
W $75D6,2 Per-life reset value ($FF = keep) of TMP_SPR ($750E) = $0000
W $75D8,2 Per-life reset value ($FF = keep) of TMP_LIST ($7510) = $0000
W $75DA,2 Per-life reset value ($FF = keep) of TMP_MASK ($7512) = $0000
B $75DC,1 Per-life reset value ($FF = keep) of TOUCHDOWN ($7514) = $00
B $75DD,1 Per-life reset value ($FF = keep) of LANDED ($7515) = $01
B $75DE,1 Per-life reset value ($FF = keep) of NO_FUEL ($7516) = $00
B $75DF,1 Per-life reset value ($FF = keep) of FUEL_TICK ($7517) = $00
W $75E0,2 Per-life reset value ($FF = keep) of FUEL_PTR ($7518) = $47BC
B $75E2,1 Per-life reset value ($FF = keep) of CLIMB_RATE ($751A) = $00
B $75E3,1 Per-life reset value ($FF = keep) of DESCENT_RATE ($751B) = $00
W $75E4,2 Per-life reset value ($FF = keep) of TIME_PTR ($751C) = $FFFF
W $75E6,2 Per-life reset value ($FF = keep) of ALT_PTR ($751E) = $0000
B $75E8,1 Per-life reset value ($FF = keep) of unused $7520
B $75E9,1 Per-life reset value ($FF = keep) of TURN_TIMER ($7521) = $00
B $75EA,1 Per-life reset value ($FF = keep) of CONTROLS ($7522) = $00
B $75EB,1 Per-life reset value ($FF = keep) of unused $7523
B $75EC,1 Per-life reset value ($FF = keep) of PLANE_COL ($7524) = $00
B $75ED,1 Per-life reset value ($FF = keep) of PLANE_ROW ($7525) = $00
B $75EE,1 Per-life reset value ($FF = keep) of UI_FLAGS ($7526) = $00
B $75EF,1 Per-life reset value ($FF = keep) of SPEED ($7527) = $00
B $75F0,1 Per-life reset value ($FF = keep) of TIME_TICK ($7528) = $00
W $75F1,2 Per-life reset value ($FF = keep) of TMP_LIST2 ($7529) = $0000
W $75F3,2 Per-life reset value ($FF = keep) of TMP_ATTR2 ($752B) = $0000
B $75F5,1 Per-life reset value ($FF = keep) of SOUND_OFF ($752D) = $00
B $75F6,1 Per-life reset value ($FF = keep) of ON_PAD ($752E) = $01
B $75F7,1 Per-life reset value ($FF = keep) of PLANE_DRAWN ($752F) = $00
B $75F8,1 Per-life reset value ($FF = keep) of PLANE_NEAR ($7530) = $00
B $75F9,2 Per-life reset value ($FF = keep) of unused $7531-$7532
B $75FB,1 Per-life reset value ($FF = keep) of HELI_LEVEL ($7533) = $03
B $75FC,1 Per-life reset value ($FF = keep) of AIR_TICK ($7534) = $00
B $75FD,1 Per-life reset value ($FF = keep) of WAVE_X ($7535) = $00
B $75FE,1 Per-life reset value ($FF = keep) of WAVE_Y ($7536) = $00
B $75FF,1 Per-life reset value ($FF = keep) of WAVE_TICK ($7537) = $00
W $7600,2 Per-life reset value ($FF = keep) of WAVE_PTR ($7538) = $0000
B $7602,1 Per-life reset value ($FF = keep) of ROTOR_FRAME ($753A) = $00
B $7603,1 Per-life reset value ($FF = keep) of MOVE_DIR ($753B) = $04
W $7604,2 Per-life reset value ($FF = keep) of MAP_ROW_PTR ($753C) = $0000
W $7606,2 Per-life reset value ($FF = keep) of MAP_PTR ($753E) = $0000
B $7608,1 Per-life reset value ($FF = keep) of MAP_HX ($7540) = $00
B $7609,1 Per-life reset value ($FF = keep) of MAP_HY ($7541) = $00
B $760A,1 Per-life reset value ($FF = keep) of MAP_BLINK ($7542) = $00
W $760B,2 Per-life reset value ($FF = keep) of MAP_HATTR ($7543) = $FFFF
W $760D,2 Per-life reset value ($FF = keep) of MAP_HPIX ($7545) = $FFFF
W $760F,2 Per-life reset value ($FF = keep) of MAP_CATTR ($7547) = $FFFF
W $7611,2 Per-life reset value ($FF = keep) of MAP_CPIX ($7549) = $FFFF
B $7613,1 Per-life reset value ($FF = keep) of CYC_X ($754B) = $FF
B $7614,1 Per-life reset value ($FF = keep) of CYC_Y ($754C) = $FF
B $7615,1 Per-life reset value ($FF = keep) of OFF_MAP ($754D) = $00
B $7616,1 Per-life reset value ($FF = keep) of CYC_TICK ($754E) = $FF
B $7617,1 Per-life reset value ($FF = keep) of CYC_LEG ($754F) = $FF
B $7618,1 Per-life reset value ($FF = keep) of CYC_DIST ($7550) = $00
B $7619,1 Per-life reset value ($FF = keep) of PICK_TILE ($7551) = $00
W $761A,2 Per-life reset value ($FF = keep) of ISLAND ($7552) = $0000
B $761C,1 Per-life reset value ($FF = keep) of CRATES ($7554) = $FF
B $761D,1 Per-life reset value ($FF = keep) of WINCH ($7555) = $00
B $761E,1 Per-life reset value ($FF = keep) of ROPE_STATE ($7556) = $00
W $761F,2 Per-life reset value ($FF = keep) of PICK_SPR ($7557) = $0000
B $7621,2 Per-life reset value ($FF = keep) of unused $7559-$755A
B $7623,1 Per-life reset value ($FF = keep) of SURV_ANIM1 ($755B) = $00
B $7624,1 Per-life reset value ($FF = keep) of SURV_ANIM2 ($755C) = $00
B $7625,1 Per-life reset value ($FF = keep) of ROTOR_SND ($755D) = $00
B $7626,6 Per-life reset value ($FF = keep) of unused $755E-$7563
c $762C Copy the view buffer to the screen
D $762C Draws the 23x22-cell landscape view (screen columns 0-22, character rows 0-21) from the first 22 rows of the 23x29 tile buffer at $F74E. For each cell: attribute = byte $FE00+code; if code < $80 the 8 pixel bytes are copied from the tile set at $FA00+8*code, codes >= $80 are solid-colour tiles whose pixels are not touched.
N $762C Called from the main loop (5B86) when the map is not shown, and twice per step of the death sequence (9246/9284).
 $762C E = screen column/row offset (low byte of screen and attribute address)
 $762E IX walks the view buffer row by row (23 bytes per row)
 $7632 Top third: 8 character rows
 $7634 23 columns
 $7637 L = tile code
 $763A Attribute of the tile = byte at $FE00+code
 $763C Attribute row in the top third ($58xx)
 $7640 Codes $80-$FF: attribute only
 $7644 Pixel row in the top third ($40xx)
 $7648 HL = 8*code...
 $764B ...+$FA00 = tile graphic
 $764F Copy 8 pixel lines
 $765D Skip the 9 columns right of the view (row stride 32)
 $7664 Middle third: 8 rows ($59xx / $48xx)
 $7696 Bottom third: 6 rows ($5Axx / $50xx)
u $76C9 Unused
B $76C9,9 Zero bytes
c $76D2 Build the view window from the island maps
D $76D2 Fills the 23x29 tile buffer at $F74E (row stride 23) with the part of the world map whose top-left world tile is (X,Y) = (#R$7500, #R$7502). Everything outside an island is sea (code 0). The island table at $F230 has 20-byte records ($FF-terminated, 14 islands). Record bytes used here: +0 X high byte (sector), +1 Y high byte, +2/+3 X-low range in which the island is visible (= +6-22 .. +7+22), +4/+5 Y-low range (= +8-28 .. +9+28), +6/+7 X-low range of a fully visible window (map column 0 is world X = +6), +8/+9 the same for Y (map row 0 is world Y = +8), +10/+11 address of the island tile map (row stride 128 bytes).
D $76D2 The island found is stored in #R$7552. The clip flags in C are: bit 2 X < +6 (window overhangs the island's west edge), bit 3 X >= +7 (east edge), bit 4 Y < +8 (north edge), bit 5 Y >= +9 (south edge); C (0..40) indexes a table of 4-byte JP slots: #R$78CF for the north view (#R$7504=0) or #R$7A37 for the south view, whose routines copy the visible rectangle (rotated 180 degrees for the south view).
N $76D2 Called every main-loop pass (5B3C) and by the death sequence (9257). World tile under the helicopter = (X+11, Y+14) = buffer cell (11,14) in both views.
 $76D2 Clear 256+256+155 = 667 = 23*29 bytes of the view buffer
 $76E5 IX = first island record
 $76E9 X high byte must match +0
 $76F1 Y high byte must match +1
 $76F9 X low byte must be in [+2, +3]
 $7707 Y low byte must be in [+4, +5]
 $7717 Next record (20 bytes)
 $771E Stop at the $FF terminator: open sea, buffer stays all sea
 $7724 Remember the current island
 $7728 C = clip flags
 $772B X < +6: bit 2 (west edge in view)
 $7737 X >= +7: bit 3 (east edge in view)
 $773E Y < +8: bit 4 (north edge in view)
 $774A Y >= +9: bit 5 (south edge in view)
 $7751 South view?
 $7756 Yes: use the south-view jump table
 $7759 North view: jump to slot 78CF+C
c $775E Map address of the window's first row (west edge clipped)
D $775E Returns HL = map base (+10/+11) + 128*(Y - (+8)): map address of column 0 of the window's first row.
R $775E IX Island record
c $7777 Map address of the window's first column (north edge clipped)
D $7777 Returns HL = map base + (X - (+6)): map row 0, window's first column.
R $7777 IX Island record
c $7789 Map address of the window origin
D $7789 Returns HL = map base + 128*(Y - (+8)) + (X - (+6)).
R $7789 IX Island record
c $77AD North view, island fills the window (slot 0)
D $77AD Copies 29 rows of 23 tiles from the map (window origin) to the buffer.
 $77B5 Full-width copy loop (A rows)
c $77B7 North view, west edge visible (slot 4)
D $77B7 Visible width w = X - (+2) + 1 columns, copied into the rightmost w buffer columns, 29 rows, from map column 0.
 $77BF Width for the clipped copy loop (operand at 783E)
 $77C3 DE = $F74E + 23 - w
 $77D0 Clipped copy loop
c $77D2 North view, east edge visible (slot 8)
D $77D2 Width w = (+3) - X + 1, copied into the leftmost w columns, 29 rows.
c $77E8 North view, north edge visible (slot 16)
D $77E8 n = Y - (+4) + 1 visible rows go to the bottom n buffer rows, 23 columns wide, starting at map row 0.
 $77EC n = visible rows
 $77F8 DE = $F9E9 - 23*n (start of buffer row 29-n)
N $7803 Full-width copy loop: A rows of 23 bytes, map stride 128.
 $7803 Copy one row of 23 tiles
 $7808 Map row stride 128
c $7810 North view, north-west corner visible (slot 20)
D $7810 w = X - (+2) + 1 columns, n = Y - (+4) + 1 rows, copied from map (0,0) to the bottom-right corner of the buffer.
 $7818 Width (operand of LD BC at 783D)
N $783D Clipped copy loop: A rows of w bytes (w in the self-modified operand at $783E), map stride 128, buffer stride 23.
 $783D w (self-modified operand)
c $7854 North view, north-east corner visible (slot 24)
D $7854 w = (+3) - X + 1, n = Y - (+4) + 1; to the bottom-left corner.
c $787D North view, south edge visible (slot 32)
D $787D n = (+5) - Y + 1 rows, full width, to the top of the buffer.
c $788F North view, south-west corner visible (slot 36)
D $788F w = X - (+2) + 1, n = (+5) - Y + 1; to the top-right corner.
c $78B1 North view, south-east corner visible (slot 40)
D $78B1 w = (+3) - X + 1, n = (+5) - Y + 1; to the top-left corner.
c $78CF North-view copy jump table
D $78CF Entered by JP (HL) at 775D with HL = $78CF + clip flags (0..40). Each slot is a 4-byte JP + padding; slots 12, 28 and 44+ cannot occur.
 $78CF 0: whole window on the island
B $78D2,1
 $78D3 4: west edge
B $78D6,1
 $78D7 8: east edge
B $78DA,5
 $78DF 16: north edge
B $78E2,1
 $78E3 20: north-west corner
B $78E6,1
 $78E7 24: north-east corner
B $78EA,5
 $78EF 32: south edge
B $78F2,1
 $78F3 36: south-west corner
B $78F6,1
 $78F7 40: south-east corner
B $78FA,30,8,8,8,6 Unused slots
c $7918 South-view dispatch
D $7918 Jumps to slot $7A37 + C (clip flags).
R $7918 BC Clip flags
c $791D South view, island fills the window (slot 0)
D $791D Copies the 29x23 window rotated by 180 degrees: map bytes are read forwards and written backwards from the last buffer byte $F9E8.
c $7927 South view, west edge visible (slot 4)
D $7927 w = X - (+2) + 1 columns go to the leftmost w buffer columns (reversed), 29 rows from the bottom up.
 $792F Width for loop 79A6 (operand at 79A7)
 $7933 DE = $F9D1 + w = last buffer row, column w-1
c $793F South view, east edge visible (slot 8)
D $793F w = (+3) - X + 1; into the rightmost w columns (reversed).
c $7955 South view, north edge visible (slot 16)
D $7955 n = Y - (+4) + 1 rows, full width, into the top n buffer rows (reversed).
N $796D Reversed full-width copy loop: A rows of 23 bytes, buffer written backwards.
 $7970 Copy one map byte, buffer pointer moves left
 $7976 Next map row (128 - 23)
c $797F South view, north-west corner visible (slot 20)
D $797F w = X - (+2) + 1, n = Y - (+4) + 1; into the top-left corner (reversed), from map (0,0). Falls into the clipped reversed copy loop at 79A6.
 $7987 Width (operand at 79A7)
N $79A6 Reversed clipped copy loop: A rows of w bytes (operand at $79A7); map +128 per row, buffer -23 per row.
 $79A6 w (self-modified operand)
c $79C2 South view, north-east corner visible (slot 24)
D $79C2 w = (+3) - X + 1, n = Y - (+4) + 1; into the top-right corner (reversed).
c $79E8 South view, south edge visible (slot 32)
D $79E8 n = (+5) - Y + 1 rows into the bottom rows (reversed).
c $79FA South view, south-west corner visible (slot 36)
D $79FA w = X - (+2) + 1, n = (+5) - Y + 1; bottom-left corner (reversed).
c $7A19 South view, south-east corner visible (slot 40)
D $7A19 w = (+3) - X + 1, n = (+5) - Y + 1; bottom-right corner (reversed).
c $7A37 South-view copy jump table
D $7A37 Entered by JP (HL) at 791C with HL = $7A37 + clip flags. Same layout as #R$78CF.
 $7A37 0: whole window
B $7A3A,1
 $7A3B 4: west edge
B $7A3E,1
 $7A3F 8: east edge
B $7A42,5
 $7A47 16: north edge
B $7A4A,1
 $7A4B 20: north-west corner
B $7A4E,1
 $7A4F 24: north-east corner
B $7A52,5
 $7A57 32: south edge
B $7A5A,1
 $7A5B 36: south-west corner
B $7A5E,1
 $7A5F 40: south-east corner
B $7A62,31,8,8,8,7 Unused slots
b $7A81 Ground-sampling and shadow work buffers
D $7A81 Filled every loop by #R$7E10 and #R$7ADC. The 3x3 block of cells under/around the helicopter is buffer columns 10-12, rows 13-15 (centre = column 11, row 14 = the world tile under the helicopter). All 3x3 lists are column-major, bottom row first: index 3*c+k = column 10+c, row 15-k.
B $7A81,9,3 Raw map codes of the 3x3 block (before projection; include aircraft tiles $F6-$FE and sea waves). $7A85 = tile under the helicopter (crate/survivor check F3A3). Read by 8ACA (landing check).
B $7A8A,1 Unused
B $7A8B,9,3 Terrain height level of each cell (0..17, units of 4 altitude pixels; see #R$7AC1); 0 for object tiles $17-$26. Read by 8A9B (collision check against altitude/4).
B $7A94,1 Unused
B $7A95,9,3 Shadow row offset of each cell = level/2 (rows); bit 7 = cell's top tile is $18; $FF = shadow cell hidden (#R$7B33).
B $7A9E,1 Unused
B $7A9F,33,11 Projected (displayed) tile codes of buffer columns 10, 11, 12, rows 15 up to 5 (11 per column, bottom first), copied at the moment the sprite tiles are inserted; used for shadow/body occlusion (7BB8, 86AF via $7AA2, F4F4 via $7AAC). Bit 7 may be set by 7D9C.
B $7AC0,1 Unused
B $7AC1,1 Base of the threshold table (never compared)
B $7AC2,18,9 Height thresholds: level = number of entries <= raw code: <$0F:0, $0F:1, $10-$2D:2, $2E-$2F:3, $30-$55:4, $56-$57:5, $58-$88:6, $89-$8B:7, $8C-$A4:8, $A5-$B1:9, $B2-$C1:10, $C2-$CF:11, $D0-$D8:12, $D9-$E3:13, $E4-$EB:14, $EC-$EF:15, $F0-$F5:16, $F6-$FE:17 (aircraft)
B $7AD4,8 Unused
c $7ADC Sample the ground under the helicopter and draw its shadow
D $7ADC Called from #R$7E10 (7F77) while the sprite tiles are being built, unless the helicopter has crashed. 1) Copies the already-projected codes of buffer columns 10-12, rows 15..5 to #R$7A9F. 2) Converts the 9 raw codes at #R$7A81 into terrain levels (#R$7A8B, threshold table #R$7AC1) and shadow row offsets (#R$7A95). 3) Hides shadow cells that would be covered by nearer terrain. 4) Jumps to #R$7BB8 to draw the shadow.
 $7ADC Buffer column 10, row 15
 $7AE3 3 columns
 $7AE5 11 rows each, bottom to top
 $7AEC Up one buffer row (-23)
 $7AF2 Next column, back to row 15 (+11*23+1)
 $7AFA IX = terrain levels, DE = raw codes
 $7B03 Level = number of thresholds <= code
 $7B0E Store the level (0..17)
 $7B11 Shadow row offset = level/2
 $7B16 First projected tile of this code (pillar page $63, or $6C in south view: operand at 7B18 patched by 80F9)
 $7B1A Object tiles $17-$26 (trees, buildings, people...)?
 $7B22 Tile $18: flag it in the shadow offset
 $7B2A Objects have no collision height
 $7B33 For each of the 3 columns: rows 15 (C), 14 (D), 13 (A)
 $7B48 Row 13 offset + 2 compared with row 15 offset
 $7B5E Row 13 offset + 1 compared with row 14 offset
 $7B73 Hide the row-13 shadow cell
 $7B77 Row 14 offset + 1 compared with row 15 offset
 $7B8D Hide the row-14 shadow cell
 $7B99 Draw the shadow
N $7ADC Hiding rule (per column, offsets h15, h14, h13 without bit 7): the row-13 cell is hidden if h13+2 < h15, or h13+1 < h14; the row-14 cell is hidden if h14+1 < h15. On equality the bit-7 flags (tile $18) decide.
u $7B9C Unused
B $7B9C,28,8,8,8,4 Zero bytes
c $7BB8 Draw the helicopter's shadow into the sprite tiles
D $7BB8 The shadow sprite (3x3 cells, frame #R$7507, +8 mod 16 in south view; data at $EDB0+72*frame, cell order column-major bottom-up, first byte $FF = empty cell) is drawn into the graphics of the sprite tiles $5F-$7F (built by #R$7E10 at $FCF8-$FDFF, attributes $FE5F-$FE7F). Each shadow cell (column 10+c, row 15-k) is raised by its ground offset h (#R$7A95), i.e. drawn into the sprite tile h rows higher, so the shadow lies on the terrain. The tile already displayed there (from #R$7A9F) decides how: < $17 flat ground: the cell is replaced by the shadow and its INK set to black; $17-$26 objects: the shadow is masked by mask tiles $23-$26 ($FB18-$FB37) and may continue into the tile below; $27-$2F: shadow ORed in, INK black; >= $30: not drawn (hidden). Offsets >= 8 (aircraft) draw at the base cell with attribute $68.
 $7BB8 Column list pointer
 $7BBE Graphic of sprite tile $69 (column 10, row 15)
 $7BC4 Attribute of sprite tile $69
 $7BCA Shadow frames base ($ED68 + 72*(frame+1))
 $7BD8 South view: frame + 8 (mod 16)
 $7BE5 Shadow cell pointer
 $7BE8 Shadow offsets of the 9 cells
 $7BEB 3 columns of 3 cells
 $7BF4 Empty shadow cell?
 $7BF9 Hidden cell?
 $7C00 Offset >= 8: plain OR at the base cell
 $7C05 Tile displayed h rows above this cell
 $7C0D >= $30: hidden behind it
 $7C11 $27-$2F: OR the shadow in
 $7C15 $17-$26: masked (objects)
 $7C1A Flat ground: attribute of the target tile, INK 0
 $7C26 Target graphic = (#R$7509) - 8*h
 $7C35 Replace the tile graphic by the shadow cell
 $7C3F Skip this cell
 $7C49 Next cell up: attribute -1, graphic -8, list +1
 $7C66 Next column: list +8, graphic +$70, attribute +$0E
 $7C88 Offset >= 8: attribute $68 (bright cyan paper, black ink) at the base cell
 $7C93 OR-type tile: attribute INK 0, then OR the shadow
 $7CBC Object tiles: choose the mask tile: $FB18 (tile $23) for codes $19, $1B, $21; $FB28 (tile $25) for the others; +8 (tiles $24/$26) when the cell is flagged (bit 7), except for $21/$22
 $7CE4 Mask the shadow cell into the temporary buffer #R$7DE5
 $7CF5 Remember the second mask tile
 $7CFD OR it into the target
 $7D0B Look at the tiles below for the rest of the shadow
 $7D20 Continue the shadow into a trunk/base tile ($1D-$20) using the second mask
 $7D4D Tiles $17-$1A / $1B-$26
 $7D9C Mark the list entry (bit 7) and replace the target graphic by the masked shadow
 $7DB2 Attribute $60 (bright green paper, black ink)...
 $7DBA ...or $68 (bright cyan) for flagged cells
b $7DE5 Shadow mask buffer and survivor animation frames
B $7DE5,8 Temporary masked shadow cell (#R$7BB8)
B $7DED,1 Unused
B $7DEE,7 Survivor animation frame A (copied to tile $31 lines 0-6, $FB88, by F34A)
B $7DF5,1 Unused
B $7DF6,7 Survivor animation frame B (tile $31)
B $7DFD,1 Unused
B $7DFE,8 Survivor animation frame C (copied to tile $32, $FB90)
B $7E06,8 Survivor animation frame D (tile $32)
B $7E0E,2 Unused
c $7E10 Project the terrain and insert the sprite tiles
D $7E10 Turns the flat map window built by #R$76D2 into the pseudo-3D view, in place in the 23x29 buffer at $F74E. Rows are processed from the top (far) to the bottom (near) - a painter's algorithm: each cell of code c becomes a 'pillar': pillar tile k (k=0,1,2...) is byte (P+k)*256+c and is written k rows above the cell; $FE = transparent (leave what is there), $FF = end of pillar. P = $63 in north view and $6C in south view (operands 7E35/7E41 patched by 80F9). Nearer pillars overwrite farther ones.
D $7E10 Row 0 only gets its base tile. Rows 1-23 get full pillars. After row 15 the helicopter sprite tiles are inserted (7F21). Rows 24-28 (below the screen) only contribute the parts of tall pillars that reach the visible area: row 24+j draws only for codes >= $54, $80, $B2, $D0, $E4 (j=0..4), starting with pillar tile 3+j at row 21.
N $7E10 First the 9 raw codes of the 3x3 block under the helicopter are saved in #R$7A81.
 $7E10 Buffer column 10, row 15
 $7E20 Up one row
 $7E26 Next column, back to row 15
 $7E2E Row 0: base tile only
 $7E34 Pillar page (operand patched: $63 north / $6C south)
 $7E3B Rows 1..23
 $7E40 Pillar page (operand patched)
 $7E47 Base tile
 $7E48 Write pillar tile
 $7E49 Up one row, next pillar level
 $7E4C $FE: transparent; $FF: end
 $7E59 Row 15 finished: insert the sprite tiles
 $7E62 Row 24: codes >= $54, pillar page P+3 (operand at 7E6D), from row 21
 $7E88 Row 25: codes >= $80, page P+4 (operand 7E93)
 $7EAE Row 26: codes >= $B2, page P+5 (operand 7EB9)
 $7ED4 Row 27: codes >= $D0, page P+6 (operand 7EDF)
 $7EFA Row 28: codes >= $E4, page P+7 (operand 7F05)
 $7F21 Insert sprite tiles: account for this row
 $7F24 Destination: graphic of tile $5F ($FA00+8*$5F)
 $7F2A Destination: attribute of tile $5F
 $7F30 Buffer column 10, row 5
 $7F33 3 columns x 11 rows (rows 5-15), top to bottom
 $7F3D Copy the cell's attribute
 $7F47 Copy the cell's graphic (tile 0's for solid tiles >= $80)
 $7F64 Next row (+23)
 $7F6B Next column, back to row 5
 $7F72 Draw the shadow unless crashed
 $7F7A Three NOPs (patched-out code)
 $7F7D Replace the 33 cells by the sprite tile codes #R$7F98
 $7F95 Continue with row 16
b $7F98 Sprite tile codes
D $7F98 Codes written into buffer columns 10-12, rows 5-15 (3 per row). Tile $5F+r+11*c is column 10+c, row 5+r, so each column's graphics form a contiguous 88-line strip ($FCF8, $FD50, $FDA8) into which the shadow (#R$7BB8) and the helicopter body (86AF) are drawn at pixel precision.
B $7F98,33,3
B $7FB9,1 End marker (not used)
B $7FBA,27,8,8,8,3 Unused
b $7FD5 Control method
D $7FD5 Set by the menu (E2BA: key - '2'): 0 = keyboard, 1 = Interface 2 (port $EFFE, keys 6-0), 2 = Kempston (port $1F), 3 = Protek/AGF (cursor keys 5-8 and 0). Read by 7FD6 to choose the input routine and by E299.
B $7FD5,1
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
b $9300 Island tile store
D $9300 The terrain of all 14 islands, one byte (tile ID) per map cell, stored as 150 rows of 128 bytes (stride 128). Each island is a rectangular block somewhere in this store, located by the island table at #R$F230 (record bytes 10-11 = address of the block's top-left cell, block width = rec[3]-rec[6]+1, height = rec[5]-rec[8]+1); blocks are packed side by side and may share sea rows. The window builder #R$76D2 copies a 23x29 part of the active island into the window buffer F74E (row stride 128 -> 23), the renderer #R$7E10 turns every tile into a column of character codes via the tables at 6300+level*256+tile, and #R$762C draws it.
D $9300 Tile IDs: 00 sea; 01-03 wave sparkles (only placed at run time by #R$8B91); 04-0E sea-level beach/rocks; 10-2C height 1; 30-54 height 2; 58-88 height 3; 8C-A4 height 4; B2-C1 height 5; D0-D8 height 6; E4-EB height 7 (class = count of #R$7AC2 entries <= tile, height = class/2). Odd classes are objects on that height: crates 0F/2F/57/8B (placed by #R$5EEC), survivors 2D-2E/55-56/89-8A (placed by #R$6072), houses and trees (A5-B1, C2-CF, D9-E3, EC-EF), aircraft F6-FE (written into the window only). See re/notes/data.md and re/assets/terrain/tiles.json.
D $9300 Row 0 (9300-937F) is all zeros; #R$9246 also uses its first 72 bytes as a blank sprite to clear the helicopter buffer 6950.
N $9300 Island blocks (index: name, block address, width x height, world position of the block's top-left cell):
N $9300 0: BANANA ISLAND at #R$9300 (store row 0, col 0), 55x29, world (626,412) = sector (2,1) local (114,156).
N $9300 1: ORTE ROCKS at #R$9D00 (store row 20, col 0), 54x30, world (414,540) = sector (1,2) local (158,28).
N $9300 2: KOKOLA ISLAND at #R$A900 (store row 44, col 0), 53x29, world (365,176) = sector (1,0) local (109,176).
N $9300 3: LAGOON ISLAND at #R$B600 (store row 70, col 0), 66x29, world (138,212) = sector (0,0) local (138,212).
N $9300 4: PEAK ISLAND at #R$C300 (store row 96, col 0), 40x29, world (574,116) = sector (2,0) local (62,116).
N $9300 5: BASE ISLAND at #R$CF80 (store row 121, col 0), 81x29, world (306,364) = sector (1,1) local (50,108).
N $9300 6: GILLIGANS ISLAND at $9354 (store row 0, col 84), 45x30, world (306,116) = sector (1,0) local (50,116).
N $9300 7: RED ISLAND at #R$9FD8 (store row 25, col 88), 41x29, world (398,604) = sector (1,2) local (142,92).
N $9300 8: SKEG ISLAND at #R$ADD8 (store row 53, col 88), 40x29, world (134,540) = sector (0,2) local (134,28).
N $9300 9: BONE ISLAND at $B843 (store row 74, col 67), 62x29, world (450,152) = sector (1,0) local (194,152).
N $9300 10: GIANTS GATEWAY at $9337 (store row 0, col 55), 30x41, world (430,296) = sector (1,1) local (174,40).
N $9300 11: CLAW ISLAND at $A735 (store row 40, col 53), 36x35, world (474,476) = sector (1,1) local (218,220).
N $9300 12: LUKELAND ISLES at #R$C628 (store row 102, col 40), 40x33, world (70,588) = sector (0,2) local (70,76).
N $9300 13: ENTERPRISE ISLAND at $C64F (store row 102, col 79), 50x48, world (90,460) = sector (0,1) local (90,204).
B $9300,19200,16
 $9300 Row 0: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9380 Row 1: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9400 Row 2: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9480 Row 3: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9500 Row 4: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9580 Row 5: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9600 Row 6: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9680 Row 7: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9700 Row 8: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9780 Row 9: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9800 Row 10: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9880 Row 11: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9900 Row 12: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9980 Row 13: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9A00 Row 14: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9A80 Row 15: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9B00 Row 16: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9B80 Row 17: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9C00 Row 18: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9C80 Row 19: 0:Banana cols 0-54; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9D00 Row 20: 0:Banana cols 0-54; 1:Orte cols 0-53; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9D80 Row 21: 0:Banana cols 0-54; 1:Orte cols 0-53; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9E00 Row 22: 0:Banana cols 0-54; 1:Orte cols 0-53; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9E80 Row 23: 0:Banana cols 0-54; 1:Orte cols 0-53; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9F00 Row 24: 0:Banana cols 0-54; 1:Orte cols 0-53; 6:Gilligans cols 84-128; 10:Giants cols 55-84
 $9F80 Row 25: 0:Banana cols 0-54; 1:Orte cols 0-53; 6:Gilligans cols 84-128; 7:Red cols 88-128; 10:Giants cols 55-84
 $A000 Row 26: 0:Banana cols 0-54; 1:Orte cols 0-53; 6:Gilligans cols 84-128; 7:Red cols 88-128; 10:Giants cols 55-84
 $A080 Row 27: 0:Banana cols 0-54; 1:Orte cols 0-53; 6:Gilligans cols 84-128; 7:Red cols 88-128; 10:Giants cols 55-84
 $A100 Row 28: 0:Banana cols 0-54; 1:Orte cols 0-53; 6:Gilligans cols 84-128; 7:Red cols 88-128; 10:Giants cols 55-84
 $A180 Row 29: 1:Orte cols 0-53; 6:Gilligans cols 84-128; 7:Red cols 88-128; 10:Giants cols 55-84
 $A200 Row 30: 1:Orte cols 0-53; 7:Red cols 88-128; 10:Giants cols 55-84
 $A280 Row 31: 1:Orte cols 0-53; 7:Red cols 88-128; 10:Giants cols 55-84
 $A300 Row 32: 1:Orte cols 0-53; 7:Red cols 88-128; 10:Giants cols 55-84
 $A380 Row 33: 1:Orte cols 0-53; 7:Red cols 88-128; 10:Giants cols 55-84
 $A400 Row 34: 1:Orte cols 0-53; 7:Red cols 88-128; 10:Giants cols 55-84
 $A480 Row 35: 1:Orte cols 0-53; 7:Red cols 88-128; 10:Giants cols 55-84
 $A500 Row 36: 1:Orte cols 0-53; 7:Red cols 88-128; 10:Giants cols 55-84
 $A580 Row 37: 1:Orte cols 0-53; 7:Red cols 88-128; 10:Giants cols 55-84
 $A600 Row 38: 1:Orte cols 0-53; 7:Red cols 88-128; 10:Giants cols 55-84
 $A680 Row 39: 1:Orte cols 0-53; 7:Red cols 88-128; 10:Giants cols 55-84
 $A700 Row 40: 1:Orte cols 0-53; 7:Red cols 88-128; 10:Giants cols 55-84; 11:Claw cols 53-88
 $A780 Row 41: 1:Orte cols 0-53; 7:Red cols 88-128; 11:Claw cols 53-88
 $A800 Row 42: 1:Orte cols 0-53; 7:Red cols 88-128; 11:Claw cols 53-88
 $A880 Row 43: 1:Orte cols 0-53; 7:Red cols 88-128; 11:Claw cols 53-88
 $A900 Row 44: 1:Orte cols 0-53; 2:Kokola cols 0-52; 7:Red cols 88-128; 11:Claw cols 53-88
 $A980 Row 45: 1:Orte cols 0-53; 2:Kokola cols 0-52; 7:Red cols 88-128; 11:Claw cols 53-88
 $AA00 Row 46: 1:Orte cols 0-53; 2:Kokola cols 0-52; 7:Red cols 88-128; 11:Claw cols 53-88
 $AA80 Row 47: 1:Orte cols 0-53; 2:Kokola cols 0-52; 7:Red cols 88-128; 11:Claw cols 53-88
 $AB00 Row 48: 1:Orte cols 0-53; 2:Kokola cols 0-52; 7:Red cols 88-128; 11:Claw cols 53-88
 $AB80 Row 49: 1:Orte cols 0-53; 2:Kokola cols 0-52; 7:Red cols 88-128; 11:Claw cols 53-88
 $AC00 Row 50: 2:Kokola cols 0-52; 7:Red cols 88-128; 11:Claw cols 53-88
 $AC80 Row 51: 2:Kokola cols 0-52; 7:Red cols 88-128; 11:Claw cols 53-88
 $AD00 Row 52: 2:Kokola cols 0-52; 7:Red cols 88-128; 11:Claw cols 53-88
 $AD80 Row 53: 2:Kokola cols 0-52; 7:Red cols 88-128; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $AE00 Row 54: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $AE80 Row 55: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $AF00 Row 56: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $AF80 Row 57: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B000 Row 58: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B080 Row 59: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B100 Row 60: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B180 Row 61: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B200 Row 62: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B280 Row 63: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B300 Row 64: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B380 Row 65: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B400 Row 66: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B480 Row 67: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B500 Row 68: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B580 Row 69: 2:Kokola cols 0-52; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B600 Row 70: 2:Kokola cols 0-52; 3:Lagoon cols 0-65; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B680 Row 71: 2:Kokola cols 0-52; 3:Lagoon cols 0-65; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B700 Row 72: 2:Kokola cols 0-52; 3:Lagoon cols 0-65; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B780 Row 73: 3:Lagoon cols 0-65; 8:Skeg cols 88-127; 11:Claw cols 53-88
 $B800 Row 74: 3:Lagoon cols 0-65; 8:Skeg cols 88-127; 9:Bone cols 67-128; 11:Claw cols 53-88
 $B880 Row 75: 3:Lagoon cols 0-65; 8:Skeg cols 88-127; 9:Bone cols 67-128
 $B900 Row 76: 3:Lagoon cols 0-65; 8:Skeg cols 88-127; 9:Bone cols 67-128
 $B980 Row 77: 3:Lagoon cols 0-65; 8:Skeg cols 88-127; 9:Bone cols 67-128
 $BA00 Row 78: 3:Lagoon cols 0-65; 8:Skeg cols 88-127; 9:Bone cols 67-128
 $BA80 Row 79: 3:Lagoon cols 0-65; 8:Skeg cols 88-127; 9:Bone cols 67-128
 $BB00 Row 80: 3:Lagoon cols 0-65; 8:Skeg cols 88-127; 9:Bone cols 67-128
 $BB80 Row 81: 3:Lagoon cols 0-65; 8:Skeg cols 88-127; 9:Bone cols 67-128
 $BC00 Row 82: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $BC80 Row 83: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $BD00 Row 84: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $BD80 Row 85: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $BE00 Row 86: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $BE80 Row 87: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $BF00 Row 88: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $BF80 Row 89: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $C000 Row 90: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $C080 Row 91: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $C100 Row 92: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $C180 Row 93: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $C200 Row 94: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $C280 Row 95: 3:Lagoon cols 0-65; 9:Bone cols 67-128
 $C300 Row 96: 3:Lagoon cols 0-65; 4:Peak cols 0-39; 9:Bone cols 67-128
 $C380 Row 97: 3:Lagoon cols 0-65; 4:Peak cols 0-39; 9:Bone cols 67-128
 $C400 Row 98: 3:Lagoon cols 0-65; 4:Peak cols 0-39; 9:Bone cols 67-128
 $C480 Row 99: 4:Peak cols 0-39; 9:Bone cols 67-128
 $C500 Row 100: 4:Peak cols 0-39; 9:Bone cols 67-128
 $C580 Row 101: 4:Peak cols 0-39; 9:Bone cols 67-128
 $C600 Row 102: 4:Peak cols 0-39; 9:Bone cols 67-128; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $C680 Row 103: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $C700 Row 104: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $C780 Row 105: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $C800 Row 106: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $C880 Row 107: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $C900 Row 108: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $C980 Row 109: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $CA00 Row 110: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $CA80 Row 111: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $CB00 Row 112: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $CB80 Row 113: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $CC00 Row 114: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $CC80 Row 115: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $CD00 Row 116: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $CD80 Row 117: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $CE00 Row 118: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $CE80 Row 119: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $CF00 Row 120: 4:Peak cols 0-39; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $CF80 Row 121: 4:Peak cols 0-39; 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D000 Row 122: 4:Peak cols 0-39; 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D080 Row 123: 4:Peak cols 0-39; 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D100 Row 124: 4:Peak cols 0-39; 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D180 Row 125: 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D200 Row 126: 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D280 Row 127: 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D300 Row 128: 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D380 Row 129: 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D400 Row 130: 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D480 Row 131: 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D500 Row 132: 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D580 Row 133: 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D600 Row 134: 5:Base cols 0-80; 12:Lukeland cols 40-79; 13:Enterprise cols 79-128
 $D680 Row 135: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $D700 Row 136: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $D780 Row 137: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $D800 Row 138: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $D880 Row 139: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $D900 Row 140: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $D980 Row 141: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $DA00 Row 142: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $DA80 Row 143: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $DB00 Row 144: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $DB80 Row 145: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $DC00 Row 146: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $DC80 Row 147: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $DD00 Row 148: 5:Base cols 0-80; 13:Enterprise cols 79-128
 $DD80 Row 149: 5:Base cols 0-80; 13:Enterprise cols 79-128
b $DE00 Aircraft sprite frames
D $DE00 16 frames of 72 bytes, one per direction (frame n = n*22.5 degrees clockwise from north/up; the code adds 8 modulo 16 in the south view). Each frame is a 24x24 image stored column-major: bytes 0-23 are the left 8-pixel column (top to bottom), 24-47 the middle column, 48-71 the right column; equivalently 9 characters in column order. #R$8995 copies the current frame (DDB8+72*(index+1)) to FBE0 (terrain chars 3C-44) and an AND AA/55 dithered copy to FB98 (chars 33-3B, the shadow); the plane is then drawn as window tiles F6-FE.
B $DE00,72,24 Frame 0 (0 degrees)
B $DE48,72,24 Frame 1 (22.5 degrees)
B $DE90,72,24 Frame 2 (45 degrees)
B $DED8,72,24 Frame 3 (67.5 degrees)
B $DF20,72,24 Frame 4 (90 degrees)
B $DF68,72,24 Frame 5 (112.5 degrees)
B $DFB0,72,24 Frame 6 (135 degrees)
B $DFF8,72,24 Frame 7 (157.5 degrees)
B $E040,72,24 Frame 8 (180 degrees)
B $E088,72,24 Frame 9 (202.5 degrees)
B $E0D0,72,24 Frame 10 (225 degrees)
B $E118,72,24 Frame 11 (247.5 degrees)
B $E160,72,24 Frame 12 (270 degrees)
B $E1A8,72,24 Frame 13 (292.5 degrees)
B $E1F0,72,24 Frame 14 (315 degrees)
B $E238,72,24 Frame 15 (337.5 degrees)
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
