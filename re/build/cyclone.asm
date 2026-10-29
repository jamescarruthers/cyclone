  ORG $5B00

; Game start, per-level setup and main game loop
;
; Copied here from F78A by Init (it lives in the printer buffer). Entered from
; the main menu (MainMenu) when "6" is pressed. Clears the screen, draws the
; HUD, updates the high score with the last game's score, zeroes the score and
; loads the 100 live game variables at $7500-$7563 from their initial values at
; $7564. LevelStart starts a level (also re-entered when a level is completed),
; LifeStart starts a life (also re-entered after a life is lost, from $92C5),
; and MainLoop is the free-running per-iteration loop (no HALT / interrupt
; sync: one iteration takes ~270000-390000 T-states, i.e. ~3.9-5.6 TV frames,
; ~9-13 iterations per second; all game timers count iterations).
GameStart:
  CALL $84D6              ; Clear the screen (pixels 0, attributes 7)
  CALL $8D0E              ; Clear/colour the 23x22 play area
  CALL $84F4              ; Draw the HUD panel (right-hand 8 columns and bottom
                          ; two rows)
  CALL $87BC              ; Hi-score := score if score > hi-score; print "H"
                          ; line
  LD B,$06                ; Score digits 1-6 := '.' (displayed as blank leading
  LD HL,$661E             ; digits)...
GameStart_0:
  LD (HL),$2E             ;
  INC HL                  ;
  DJNZ GameStart_0        ;
  LD (HL),$30             ; ...and the last digit := '0'
  CALL PrintScore         ; Print the score
  LD HL,$7564             ; Copy 100 initial values (7564) to the live
  LD DE,$7500             ; variables at $7500
  LD BC,$0064             ;
  LDIR                    ;
; Start of a level (first level, or after a level is completed).
LevelStart:
  CALL $8321              ; Draw the 5 crate boxes; first level: randomise
                          ; cyclone start corner; next level: award crate
                          ; bonus, speed up the time bar; lives restored
  CALL $843A              ; Fill the time bar (40 lines); 40 points for every
                          ; line still filled
  CALL ShuffleVector      ; Shuffle the 5 crates over 38 candidate map cells
                          ; (FE92: JP ShuffleCrates)
  CALL PlaceSurvivors     ; Put a survivor (random variant) on each of 45
  NOP                     ; candidate map cells
  NOP                     ;
  NOP                     ;
  NOP                     ;
; Start of a life (also entered from $92C5 after a life has been lost).
LifeStart:
  CALL $80F9              ; View := NORTH (tile set A), print "NORTH"
  CALL $84AE              ; Clear the altimeter bar; altitude ($750D) := 8
; Main loop: one iteration per game "tick".
MainLoop:
  CALL $76D2              ; Clear the view buffer at $F74E, fill it with map
                          ; tile codes, find the island under the helicopter
                          ; ($7552)
  CALL $87F0              ; Move the aircraft; set collision-warning bits in
                          ; $7530
  CALL $91B4              ; HUD: compass needle, speedometer, BEWARE AIRCRAFT
                          ; warning
  CALL $8B91              ; Helicopter screen offset/drift ($7535/$7536; random
                          ; every 3rd call)
  CALL $8CA0              ; Build the helicopter sprite (heading frame + rotor
                          ; frame) in 6950
  CALL $7E10              ; Render terrain: tile codes -> character codes using
                          ; the tile column tables; save the 3x3 tiles under
                          ; the helicopter at $7A81
  CALL $86AF              ; Overlay helicopter and shadow (dynamic glyphs)
  CALL Winch              ; Winch: pick up a crate or survivor under the
                          ; helicopter
  CALL $8A7A              ; Landing/collision test (sets $7505 crash, $7515
                          ; landed, $752E on landing pad)
  CALL $85D4              ; Further sprite/overlay compositing (dynamic glyphs
                          ; from $FD30)
  LD A,($7505)            ; Crashed ($7505=1)?
  CP $01                  ;
  JP Z,$9246              ; Yes: crash sequence, lose a life ($9246)
  LD A,($7526)            ; Map mode ($7526 bit 1)?
  BIT 1,A                 ;
  JR Z,GameStart_1        ;
  CALL $8F12              ; Map shown: delay, blink map markers, move cyclone
                          ; ($8F12, falls into $9034)
  LD A,($7526)            ; Map just opened ($7526 bit 4)?
  BIT 4,A                 ;
  JR Z,GameStart_2        ;
  RES 4,A                 ; Yes: clear the flag...
  LD ($7526),A            ;
  CALL $8D0E              ; ...clear the play area...
  CALL $8D5D              ; ...draw the islands...
  CALL $8E5C              ; ...draw the map frame and compass...
  CALL $8F6A              ; ...draw markers/labels
  JR GameStart_2          ;
GameStart_1:
  CALL $762C              ; No map: copy the view buffer to the screen
  CALL $9034              ; Move the cyclone; set the cyclone proximity $7550
                          ; and WIND FORCE bar
GameStart_2:
  CALL $7FD6              ; Read the selected controller into the control word
                          ; $7522
  LD A,($7550)            ; Cyclone proximity ($7550, 0=on top of it ...
                          ; 15=far)
  CP $05                  ; The operand of this CP (address $5B93) is modified:
                          ; 5 on level 1 (836D), 6 on later levels (83AA)
  CALL C,$7378            ; Close to the cyclone: randomly perturb the control
                          ; word (turbulence)
  LD A,($7515)            ; Landed ($7515=1)...
  CP $01                  ;
  JR NZ,GameStart_3       ;
  LD A,($7516)            ; ...and out of fuel ($7516=1)...
  CP $01                  ;
  JR NZ,GameStart_3       ;
  LD A,($752E)            ; ...and not on a landing pad ($752E=0)?
  CP $00                  ;
  JR Z,GameStart_5        ; Yes: "NO FUEL" - lose a life
GameStart_3:
  CALL $80AA              ; Handle the M (map) and N (view) keys, then apply
                          ; the control word: heading, speed, altitude
  LD A,($7554)            ; 5 crates collected ($7554)...
  CP $05                  ;
  JR NZ,GameStart_4       ;
  LD A,($752E)            ; ...and on a landing pad ($752E=1)...
  CP $01                  ;
  JR NZ,GameStart_4       ;
  LD A,($7552)            ; ...on the island record at $F294 (BASE)?
  CP $94                  ;
  JR NZ,GameStart_4       ;
  LD A,($7553)            ;
  CP $F2                  ;
  JP Z,LevelStart         ; Yes: level complete, start the next level
GameStart_4:
  LD A,($751C)            ; Time bar pointer ($751C) moved past the last line?
  CP $DE                  ;
  JP Z,$92C8              ; Yes: "NO TIME" - game over
  CALL $8470              ; On a landing pad: refuel 1 line per iteration; else
                          ; burn fuel (1 line per 49 iterations)
  CALL $8284              ; Time bar: lose 1 line every N iterations (N =
                          ; operand at $828C: 255, then -15 per level)
  CALL AnimateSurvivors   ; Animate the two survivor glyphs (chars $31 and $32)
  LD A,$FD                ; Read keyboard half-row A-S-D-F-G
  IN A,($FE)              ;
  AND $11                 ; Unless A and G are both held...
  JP NZ,MainLoop          ; ...loop
  NOP                     ;
  NOP                     ;
  NOP                     ;
  JP MainMenu             ; A+G held: abandon the game, back to the main menu
GameStart_5:
  LD HL,$5BF2             ; "NO FUEL" message...
  JP $92D0                ; ...print it at row 3, lose a life ($92D0, shared
                          ; with "NO TIME")

; Message: " NO FUEL "
  DEFM " NO FUEL "        ; Printed by $92D0 (9 characters at row 3, column 7)
  DEFB $00,$00,$00,$00,$00 ; Unused (copied with the routine)

; ROM system variables and BASIC loader (not used by the game)
;
; Standard 48K system variables ($5C00-$5CB5), followed by the channel area and
; the BASIC loader program (line 10: BORDER NOT PI: INK NOT PI: PAPER NOT PI:
; CLEAR VAL "24539": LOAD "Cyclone2"SCREEN$ : LOAD "Cyclone4"CODE : LOAD
; "Cyclone3"CODE : RANDOMIZE USR VAL "65176") and its variables. Only SEED
; ($5C76) is used: it is the state of the random number generator at $8B74.
  DEFB $FF,$00,$00,$00,$FF,$00,$23,$0D,$0D,$23,$05,$00,$00,$00,$11,$00
  DEFB $01,$00,$06,$00,$0B,$00,$01,$00,$01,$00,$06,$00,$10,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$3C,$40,$00,$FF,$CD,$00,$D8,$5F,$00
  DEFB $00,$00,$0A,$00,$FF,$0A,$00,$08,$07,$00,$00,$17,$5D,$00,$00,$B6
  DEFB $5C,$BB,$5C,$CB,$5C,$17,$5D,$CA,$5C,$18,$5D,$1B,$5D,$16,$5D,$AC
  DEFB $5D,$1D,$5D,$29,$5D,$29,$5D,$2D,$92,$5C,$00,$02,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$B6,$1A,$00,$00,$06,$00,$00,$58,$FF,$00,$00,$21
  DEFB $00,$5B,$21,$17,$C0,$40,$E0,$50,$21,$12,$21,$17,$03,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$DB,$5F,$FF,$FF,$F4,$09,$A8,$10,$4B,$F4,$09,$C4,$15,$53
  DEFB $81,$0F,$C4,$15,$52,$F4,$09,$C4,$15,$50,$80,$00,$0A,$48,$00,$E7
  DEFB $C3,$A7,$3A,$D9,$C3,$A7,$3A,$DA,$C3,$A7,$3A,$FD,$B0,$22,$32,$34
  DEFB $35,$33,$39,$22,$3A,$EF,$22,$43,$79,$63,$6C,$6F,$6E,$65,$32,$22
  DEFB $AA,$3A,$EF,$22,$43,$79,$63,$6C,$6F,$6E,$65,$34,$22,$AF,$3A,$EF
  DEFB $22,$43,$79,$63,$6C,$6F,$6E,$65,$33,$22,$AF,$3A,$F9,$C0,$B0,$22
  DEFB $36,$35,$31,$37,$36,$22,$0D,$80,$EF,$22,$22,$0D,$80,$36,$35,$31
  DEFB $37,$36,$0E,$00,$00,$98,$FE,$00,$0D,$00,$00,$98,$FE,$00,$00,$0A
  DEFB $00,$00,$6C,$6F,$6E,$65,$33,$20,$20,$B6,$9E,$DC,$5F,$3E,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

; Shuffle the five crates
;
; Copied here from F88A by Init; always called via the JP at ShuffleVector.
; Called once per level start (5B2C) and continuously (hundreds of times per
; second) from the main menu loop at MenuLoop, so the final crate layout
; depends on how long the player waits in the menu. Pass 1 removes the crates
; placed last time: for every one of the 38 candidate cells in 5F61 whose flag
; is $FF, the flag is cleared and the crate tile ($8B/$57/$2F/$0F, 5F59) is
; turned back into the plain tile ($58/$30/$10/$04, 5F5D); a cell whose crate
; was already winched up already holds the plain tile and is left alone. Pass 2
; picks 5 different cells: random L from 8B74 until L<$4C, index=L/2 (0-37,
; uniform), retry if already flagged; flag it $FF and turn the plain tile into
; the matching crate tile ($58->$8B, $30->$57, $10->$2F, anything else->$0F).
ShuffleCrates:
  LD HL,$5F61             ; 38 candidate cells
  LD B,$26                ;
ShuffleCrates_0:
  PUSH BC                 ;
  LD A,(HL)               ; Crate placed here last time?
  CP $FF                  ;
  JR NZ,ShuffleCrates_3   ;
  LD (HL),$00             ; Clear the flag
  PUSH HL                 ;
  INC HL                  ;
  LD E,(HL)               ; DE = map cell address
  INC HL                  ;
  LD D,(HL)               ;
  LD A,(DE)               ; A = tile code in the map
  PUSH DE                 ;
  LD DE,$5F5D             ; Look it up in the 4 crate tiles
  LD HL,$5F59             ;
  LD B,$04                ;
ShuffleCrates_1:
  CP (HL)                 ;
  JR Z,ShuffleCrates_2    ;
  INC HL                  ;
  INC DE                  ;
  DJNZ ShuffleCrates_1    ;
  POP DE                  ;
  POP HL                  ;
  JR ShuffleCrates_3      ;
ShuffleCrates_2:
  LD A,(DE)               ; Found: replace it with the plain tile
  POP DE                  ;
  POP HL                  ;
  LD (DE),A               ;
ShuffleCrates_3:
  INC HL                  ;
  INC HL                  ;
  INC HL                  ;
  POP BC                  ;
  DJNZ ShuffleCrates_0    ;
  LD B,$05                ; Now place 5 crates
ShuffleCrates_4:
  PUSH BC                 ;
ShuffleCrates_5:
  CALL $8B74              ; Random number (HL)
  LD A,L                  ;
  CP $4C                  ; Retry until L < 76
  JR NC,ShuffleCrates_5   ;
  NOP                     ;
  NOP                     ;
  SRA A                   ; A = L/2 = 0..37
  LD B,A                  ;
  ADD A,A                 ; A = index*3
  ADD A,B                 ;
  LD HL,$5F61             ;
  LD E,A                  ;
  LD D,$00                ;
  ADD HL,DE               ;
  LD A,(HL)               ;
  CP $FF                  ; Cell already chosen? Try again
  JR Z,ShuffleCrates_5    ;
  LD (HL),$FF             ; Flag it
  INC HL                  ;
  LD E,(HL)               ;
  INC HL                  ;
  LD D,(HL)               ;
  LD A,(DE)               ; A = current (plain) tile
  PUSH DE                 ;
  LD DE,$5F59             ;
  LD HL,$5F5D             ;
  LD B,$03                ; Look it up in the first 3 plain tiles; DE stops on
ShuffleCrates_6:
  CP (HL)                 ; $5F5C ($0F) if not found
  JR Z,ShuffleCrates_7    ;
  INC HL                  ;
  INC DE                  ;
  DJNZ ShuffleCrates_6    ;
ShuffleCrates_7:
  LD A,(DE)               ; Store the crate tile
  POP DE                  ;
  LD (DE),A               ;
  POP BC                  ;
  DJNZ ShuffleCrates_4    ;
  RET                     ;

; Crate tile codes and the plain tiles they replace
  DEFB $8B,$57,$2F,$0F    ; Crate tiles: $8B, $57, $2F, $0F (also F511)
  DEFB $58,$30,$10,$04    ; Matching plain tiles: $58, $30, $10, $04 (also
                          ; F51B)

; Crate candidate cells (38 entries)
;
; 38 three-byte entries: flag ($FF = a crate was put here by the last shuffle,
; $00 = not) and the address of the cell in the 128-byte-wide world map at
; $9300. Initially all flags are 0.
  DEFB $00,$05,$99
  DEFB $00,$A5,$96
  DEFB $00,$2F,$9A
  DEFB $00,$18,$A5
  DEFB $00,$89,$A4
  DEFB $00,$86,$B0
  DEFB $00,$91,$AE
  DEFB $00,$9B,$AF
  DEFB $00,$14,$B1
  DEFB $00,$A6,$BA
  DEFB $00,$09,$BD
  DEFB $00,$BA,$BE
  DEFB $00,$23,$C6
  DEFB $00,$97,$C6
  DEFB $00,$87,$CE
  DEFB $00,$1D,$D4
  DEFB $00,$F3,$95
  DEFB $00,$6B,$9C
  DEFB $00,$E9,$A5
  DEFB $00,$F7,$A8
  DEFB $00,$60,$AF
  DEFB $00,$6C,$AF
  DEFB $00,$6C,$B6
  DEFB $00,$4B,$BF
  DEFB $00,$FB,$BD
  DEFB $00,$D3,$C2
  DEFB $00,$C0,$95
  DEFB $00,$CA,$9D
  DEFB $00,$39,$9E
  DEFB $00,$3C,$A0
  DEFB $00,$49,$A8
  DEFB $00,$43,$AE
  DEFB $00,$D4,$B6
  DEFB $00,$31,$CA
  DEFB $00,$43,$C9
  DEFB $00,$5E,$C9
  DEFB $00,$EC,$CD
  DEFB $00,$E9,$DB
  DEFB $00                ; Last byte of the copied block

; Leftover bytes below the main code block
  DEFB $52,$1B,$76,$1B,$03,$13,$00,$3E

; Interrupt: crash noise
;
; Jumped to from the interrupt handler $83C2 while the crash flag $7505 is 1
; (crash sequence). Once per frame: random HL (8B74); if L < $46 there is no
; sound this frame (70/256), otherwise 3 square-wave cycles are played, with
; the high phase lasting (H AND $F0) loop passes and the low phase (L AND $F0)
; loop passes (~43 T-states per pass), which gives a random-pitch rasping
; noise. Border stays black. Exits through the interrupt handler's register
; restore at $842D.
CrashNoise:
  CALL $8B74
  LD A,L                  ; No sound on 70 of 256 frames
  CP $46                  ;
  JP C,$842D              ;
  LD B,$03                ; 3 cycles
CrashNoise_0:
  PUSH BC                 ;
  LD A,H                  ; High phase length = H AND $F0
  AND $F0                 ;
  CP $00                  ;
  JR Z,CrashNoise_3       ;
  LD B,A                  ;
CrashNoise_1:
  LD A,$10                ; Speaker on (bit 4), border black
  OUT ($FE),A             ;
  NOP                     ;
  NOP                     ;
  NOP                     ;
  DJNZ CrashNoise_1       ;
  LD A,L                  ; Low phase length = L AND $F0
  AND $F0                 ;
  CP $00                  ;
  JR Z,CrashNoise_3       ;
  LD B,A                  ;
CrashNoise_2:
  XOR A                   ; Speaker off
  OUT ($FE),A             ;
  NOP                     ;
  NOP                     ;
  NOP                     ;
  DJNZ CrashNoise_2       ;
CrashNoise_3:
  POP BC                  ;
  DJNZ CrashNoise_0       ;
  JP $842D                ; Restore registers, EI, RET

; Unused
  DEFS $09

; Survivor candidate cells (45 entries)
;
; Addresses of 45 cells in the world map (PlaceSurvivors). Each is a plain tile
; ($58, $30 or $10) at load time; at each level start the plain tile is
; replaced by a survivor tile.
  DEFW $9809
  DEFW $96AA
  DEFW $95A9
  DEFW $A485
  DEFW $A386
  DEFW $A416
  DEFW $A41B
  DEFW $A39F
  DEFW $B186
  DEFW $B10A
  DEFW $B188
  DEFW $C027
  DEFW $C1A6
  DEFW $C1A8
  DEFW $C229
  DEFW $9A6C
  DEFW $9A77
  DEFW $9C74
  DEFW $9D73
  DEFW $A866
  DEFW $A869
  DEFW $A5E4
  DEFW $B4EC
  DEFW $B4ED
  DEFW $B56E
  DEFW $C0E0
  DEFW $C0E4
  DEFW $C162
  DEFW $98C2
  DEFW $98C5
  DEFW $9BCA
  DEFW $9C48
  DEFW $A0C5
  DEFW $B048
  DEFW $AFC9
  DEFW $AFCA
  DEFW $ABCB
  DEFW $AB4E
  DEFW $D46F
  DEFW $D471
  DEFW $D4F2
  DEFW $D4F3
  DEFW $D95C
  DEFW $D960
  DEFW $D8E1

; Put survivors on the map
;
; Called at each level start (5B2F). For each of the 45 cells listed at 6018:
; if the map tile is a plain tile $58/$30/$10 (60AC) it is replaced by the
; survivor tile $89/$55/$2D (60AF) plus a random 0 or 1 (bit 0 of L from 8B74),
; so it becomes one of the two survivor variants $89/$8A, $55/$56, $2D/$2E
; (both are survivors to the winch, F515). Cells that still hold a survivor
; (not rescued) or a crate are left alone. OBSERVED: at the start of a game all
; 45 cells hold survivors.
PlaceSurvivors:
  LD B,$2D                ; 45 cells
  LD IX,$6018             ;
PlaceSurvivors_0:
  PUSH BC                 ;
  LD L,(IX+$00)           ; HL = cell address
  LD H,(IX+$01)           ;
  LD A,(HL)               ; A = tile
  LD HL,$60AC             ; Look up the three plain tiles
  LD DE,$60AF             ;
  LD B,$03                ;
PlaceSurvivors_1:
  CP (HL)                 ;
  JR Z,PlaceSurvivors_2   ;
  INC DE                  ;
  INC HL                  ;
  DJNZ PlaceSurvivors_1   ;
  JR PlaceSurvivors_4     ;
PlaceSurvivors_2:
  LD A,(DE)               ; A = survivor tile
  EX AF,AF'               ;
  CALL $8B74              ; Random variant (+0 or +1)
  EX AF,AF'               ;
  BIT 0,L                 ;
  JR Z,PlaceSurvivors_3   ;
  INC A                   ;
PlaceSurvivors_3:
  LD L,(IX+$00)           ;
  LD H,(IX+$01)           ;
  LD (HL),A               ; Store it
PlaceSurvivors_4:
  LD DE,$0002             ;
  ADD IX,DE               ;
  POP BC                  ;
  DJNZ PlaceSurvivors_0   ;
  RET                     ;

; Plain tiles and the survivor tiles they become (PlaceSurvivors)
  DEFB $58,$30,$10        ; Plain tiles $58, $30, $10
  DEFB $89,$55,$2D        ; Survivor tiles $89, $55, $2D (+0/+1 at random)

; Unused
  DEFS $2E

; 8x8 font (characters $17-$5A, base address $6028)
;
; Character code c is at $6028+8*c (codes below $17 would overlap code and
; data). Used by PrintStrings, $859A, PrintScore. $17-$1F: CYCLONE logo (menu
; title, 9 characters); $20 space; $21 "!"; $22 blank; $23/$24 WIND FORCE bar
; end caps; $25/$26 DANGER bar end pattern; $27 cyclone symbol (map key); $28
; helicopter-position symbol (map key); $29/$2A arrows; $2B ","; $2C-$2F "-./"
; glyphs; $30-$39 digits; $3A "|" and $3B "-" (HUD rules); $3C-$40 the large
; "VIEW" HUD label; $41-$5A A-Z.
  DEFB $3F,$7F,$60,$60,$60,$60,$7F,$3F ; CYCLONE logo ($17-$1F)
  DEFB $D8,$DC,$0E,$07,$03,$01,$C1,$C1 ;
  DEFB $19,$3B,$73,$E3,$C3,$83,$83,$81 ;
  DEFB $FE,$FE,$00,$00,$00,$00,$FE,$FE ;
  DEFB $C0,$C0,$C0,$C0,$C0,$C0,$FF,$FF ;
  DEFB $3F,$7F,$60,$60,$60,$60,$7F,$3F ;
  DEFB $CE,$EF,$6F,$6D,$6C,$6C,$EC,$CC ;
  DEFB $0C,$0D,$8D,$CD,$ED,$7D,$3D,$1C ;
  DEFB $FF,$FF,$80,$FF,$FF,$80,$FF,$FF ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; $20-$27
  DEFB $00,$60,$60,$60,$60,$00,$60,$00 ;
  DEFB $00,$00,$00,$80,$80,$80,$80,$80 ;
  DEFB $00,$03,$0C,$30,$40,$60,$78,$7E ;
  DEFB $00,$80,$60,$18,$04,$0C,$34,$EC ;
  DEFB $7F,$7F,$7F,$7F,$3F,$0F,$07,$01 ;
  DEFB $54,$AC,$54,$AC,$58,$B0,$40,$80 ;
  DEFB $3E,$41,$9C,$BA,$5D,$39,$82,$7C ;
  DEFB $00,$66,$66,$7E,$7E,$66,$66,$00 ; $28-$2F
  DEFB $00,$18,$3C,$7E,$5A,$18,$18,$18 ;
  DEFB $18,$18,$3C,$E7,$3C,$18,$18,$18 ;
  DEFB $FF,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$20,$40 ;
  DEFB $00,$00,$00,$3C,$3C,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$10,$00 ;
  DEFB $00,$06,$0C,$18,$30,$60,$40,$00 ;
  DEFB $00,$3C,$62,$62,$62,$62,$3C,$00 ; Digits $30-$39
  DEFB $00,$18,$38,$18,$18,$18,$3C,$00 ;
  DEFB $00,$3C,$66,$06,$3C,$60,$7E,$00 ;
  DEFB $00,$3C,$46,$1C,$06,$46,$3C,$00 ;
  DEFB $00,$0C,$1C,$2C,$4C,$7E,$0C,$00 ;
  DEFB $00,$7E,$60,$7C,$06,$46,$3C,$00 ;
  DEFB $00,$3C,$60,$7C,$66,$66,$3C,$00 ;
  DEFB $00,$7E,$0C,$18,$30,$30,$30,$00 ;
  DEFB $00,$3C,$66,$3C,$66,$66,$3C,$00 ;
  DEFB $00,$3C,$66,$66,$3E,$06,$3C,$00 ;
  DEFB $08,$08,$08,$08,$08,$08,$08,$08 ; $3A-$40
  DEFB $00,$00,$00,$00,$FF,$00,$00,$00 ;
  DEFB $00,$01,$01,$01,$01,$00,$00,$00 ;
  DEFB $00,$89,$89,$89,$89,$D1,$61,$00 ;
  DEFB $00,$9F,$98,$9F,$98,$98,$9F,$00 ;
  DEFB $00,$98,$18,$1A,$1A,$1D,$98,$00 ;
  DEFB $00,$80,$80,$80,$80,$80,$80,$00 ;
  DEFB $00,$3C,$62,$62,$7E,$62,$62,$00 ; Letters A-Z ($41-$5A)
  DEFB $00,$7C,$62,$7C,$62,$62,$7C,$00 ;
  DEFB $00,$3C,$62,$60,$60,$62,$3C,$00 ;
  DEFB $00,$78,$64,$62,$62,$64,$78,$00 ;
  DEFB $00,$7E,$60,$7C,$60,$60,$7E,$00 ;
  DEFB $00,$7E,$60,$7C,$60,$60,$60,$00 ;
  DEFB $00,$3C,$62,$60,$6E,$62,$3C,$00 ;
  DEFB $00,$62,$62,$7E,$62,$62,$62,$00 ;
  DEFB $00,$18,$18,$18,$18,$18,$18,$00 ;
  DEFB $00,$06,$06,$06,$46,$46,$3C,$00 ;
  DEFB $00,$64,$68,$70,$68,$64,$62,$00 ;
  DEFB $00,$60,$60,$60,$60,$60,$7E,$00 ;
  DEFB $00,$62,$76,$6A,$6A,$62,$62,$00 ;
  DEFB $00,$62,$72,$6A,$66,$62,$62,$00 ;
  DEFB $00,$3C,$62,$62,$62,$62,$3C,$00 ;
  DEFB $00,$7C,$62,$62,$7C,$60,$60,$00 ;
  DEFB $00,$3C,$62,$62,$62,$6A,$3C,$02 ;
  DEFB $00,$7C,$62,$62,$7C,$64,$62,$00 ;
  DEFB $00,$3C,$60,$3C,$06,$46,$3C,$00 ;
  DEFB $00,$7E,$18,$18,$18,$18,$18,$00 ;
  DEFB $00,$62,$62,$62,$62,$62,$3C,$00 ;
  DEFB $00,$62,$62,$62,$62,$34,$18,$00 ;
  DEFB $00,$62,$62,$6A,$6A,$76,$62,$00 ;
  DEFB $00,$26,$1C,$18,$34,$62,$42,$00 ;
  DEFB $00,$62,$62,$34,$18,$18,$18,$00 ;
  DEFB $00,$7E,$0C,$18,$30,$60,$7E,$00 ;

; Tile column table A (north view), row 0
;
; Two tile-graphics tables, A at pages $63-$6B (north view) and B at pages
; $6C-$74 (south view, a mirrored copy), select by $7504 via the self-modified
; page operands at $7B18 and $7E35-$7F05 (set at $8113). For map tile code t
; (0-255) the bytes at (page+0)*256+t, (page+1)*256+t, ... give the character
; codes of that tile's vertical stack, bottom first, drawn upwards in the view
; buffer (one row up = -23 bytes): a code < $FE is drawn, $FE = transparent
; (skip a row), $FF = end of column. Character codes < $80 use the glyphs at
; FA00 and attributes at FE00; codes >= $80 are solid attribute-only blocks.
; Column heights (incl. $FF): 1 for t<$10, then t>=$10:2, $30:3, $58:4, $8C:5,
; $B2:6, $D0:7, $E4:8 (tiles are sorted by height). The unused low ends of the
; higher pages hold unrelated data (sprites, text, HUD layouts, code), split
; out below.
  DEFB $80,$00,$01,$02,$82,$03,$04,$05,$06,$10,$11,$12,$13,$14,$15,$30
  DEFB $87,$87,$18,$87,$1E,$87,$1D,$87,$18,$87,$87,$87,$87,$89,$87,$89
  DEFB $87,$87,$87,$87,$87,$88,$87,$87,$87,$87,$00,$00,$00,$87,$87,$87
  DEFB $87,$87,$18,$87,$1E,$87,$1D,$87,$18,$87,$87,$87,$87,$18,$17,$17
  DEFB $18,$18,$17,$17,$18,$89,$87,$87,$87,$87,$87,$88,$87,$87,$87,$87
  DEFB $89,$87,$00,$00,$00,$87,$87,$87,$87,$87,$18,$87,$1E,$87,$1D,$87
  DEFB $18,$87,$87,$87,$87,$18,$17,$17,$18,$18,$17,$17,$18,$18,$17,$17
  DEFB $18,$18,$17,$17,$18,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$89
  DEFB $87,$87,$87,$87,$87,$87,$89,$89,$00,$87,$87,$87,$87,$87,$18,$87
  DEFB $1E,$87,$1D,$87,$18,$87,$87,$87,$87,$18,$17,$17,$18,$87,$87,$89
  DEFB $89,$87,$89,$89,$00,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87
  DEFB $87,$87,$89,$89,$87,$87,$87,$87,$87,$87,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87
  DEFB $89,$89,$87,$87,$87,$87,$00,$00,$00,$00,$87,$87,$87,$87,$87,$87
  DEFB $87,$87,$87,$87,$87,$87,$87,$87,$89,$89,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$00

; Tile column table A, row 1
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $81,$27,$19,$28,$22,$81,$21,$29,$1A,$2B,$28,$29,$2C,$87,$89,$83
  DEFB $0B,$0C,$0D,$0E,$88,$82,$07,$08,$09,$0A,$FF,$FF,$FF,$31,$32,$56
  DEFB $87,$87,$87,$87,$5C,$87,$5E,$87,$87,$87,$87,$87,$87,$87,$20,$1F
  DEFB $87,$87,$20,$1F,$87,$89,$87,$87,$87,$87,$87,$88,$87,$87,$87,$87
  DEFB $89,$87,$FF,$FF,$FF,$87,$87,$87,$87,$87,$87,$87,$5C,$87,$5E,$87
  DEFB $87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$20,$1F
  DEFB $87,$87,$20,$1F,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$89
  DEFB $87,$87,$5A,$89,$89,$89,$89,$5A,$FF,$87,$87,$87,$87,$87,$87,$87
  DEFB $5C,$87,$5E,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$89
  DEFB $89,$87,$89,$89,$FF,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87
  DEFB $87,$87,$89,$89,$87,$87,$87,$87,$87,$87,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87
  DEFB $89,$89,$87,$87,$87,$87,$FF,$FF,$FF,$FF,$87,$87,$87,$87,$87,$87
  DEFB $87,$87,$87,$87,$87,$87,$87,$87,$89,$89,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FF

; Tile column table A, row 2 (tiles $10-$FE used)
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $81,$27,$19,$28,$22,$81,$21,$29,$1A,$2B,$28,$29,$2C,$1B,$22,$21
  DEFB $1C,$19,$22,$21,$1A,$83,$0B,$0C,$0D,$0E,$88,$82,$07,$08,$09,$0A
  DEFB $87,$89,$FF,$FF,$FF,$31,$32,$56,$87,$87,$87,$87,$5B,$87,$5D,$87
  DEFB $87,$87,$87,$87,$87,$87,$20,$1F,$87,$87,$20,$1F,$87,$87,$5B,$5D
  DEFB $87,$87,$5B,$5D,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$89
  DEFB $87,$87,$59,$57,$57,$57,$89,$5A,$FF,$87,$87,$87,$87,$87,$87,$87
  DEFB $5B,$87,$5D,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$5A,$89,$89
  DEFB $89,$58,$89,$5A,$FF,$87,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4F
  DEFB $52,$55,$89,$5A,$5A,$89,$89,$89,$87,$87,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87
  DEFB $89,$5A,$5A,$89,$89,$89,$FF,$FF,$FF,$FF,$87,$87,$87,$87,$87,$87
  DEFB $87,$87,$87,$87,$5A,$89,$89,$89,$89,$5A,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FF

; Add 40 points to the score
;
; Used by 843A (time bonus).
AddScore40:
  LD B,$28

; Add B points to the score
;
; The score is the 7-character string at 661E ('.' = blank leading digit). Adds
; 1 to the last digit B times with decimal carry (B=0 adds 256), then prints it
; via PrintScore. On exit B=$66 (left over from PrintScore), which 83A5 relies
; on by accident.
;
; B Number of points to add
AddScore:
  LD HL,$6624             ; Last digit
AddScore_0:
  LD A,(HL)               ;
  CP $2E                  ; A blank leading digit counts as '0'
  JR NZ,AddScore_1        ;
  LD A,$30                ;
AddScore_1:
  INC A                   ;
  CP $3A                  ; Carry?
  JR NZ,AddScore_2        ;
  LD (HL),$30             ; Yes: digit := '0', move one digit left
  DEC HL                  ;
  JR AddScore_0           ;
AddScore_2:
  LD (HL),A               ;
  DJNZ AddScore           ;
  JP PrintScore           ; Print the score

; Score and high-score strings
;
; Printed right-to-left (PrintScore, 87BC) at row 19 (score) and row 20 (high
; score), column 31 backwards. Leading blank digits are '.'. The high score
; starts at 0 and is only updated by 87BC (at the next game start or on the
; info screen).
  DEFB $FF                ; Terminator for the right-to-left print
  DEFM "S"                ; "S" label
  DEFM "......0"          ; Score (7 digits)
  DEFB $FF                ; Terminator
  DEFM "H"                ; "H" label
  DEFM "......0"          ; High score (7 digits)
  DEFB $FF

; Tile column table A, row 3 (tiles $30-$FE)
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$81,$27,$19,$28,$22,$81,$21
  DEFB $29,$1A,$2B,$28,$29,$2C,$1B,$22,$21,$1C,$19,$22,$21,$1A,$1B,$22
  DEFB $21,$1C,$19,$22,$21,$1A,$83,$0B,$0C,$0D,$0E,$82,$07,$08,$09,$0A
  DEFB $87,$89,$88,$2E,$2D,$2E,$2D,$83,$83,$FF,$31,$32,$56,$87,$87,$87
  DEFB $87,$5B,$87,$5D,$87,$87,$87,$87,$87,$87,$87,$20,$1F,$87,$59,$57
  DEFB $57,$57,$59,$89,$5A,$FF,$87,$4B,$46,$4B,$4B,$4B,$4B,$4B,$4B,$4B
  DEFB $4E,$51,$54,$89,$5A,$5A,$89,$89,$89,$58,$89,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4F,$52
  DEFB $55,$89,$5A,$5A,$89,$89,$89,$FF,$FF,$FF,$FF,$87,$87,$87,$87,$87
  DEFB $87,$87,$87,$87,$87,$5A,$89,$89,$89,$89,$5A,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$3C,$3D,$3E,$3F,$40,$41,$42,$43,$44
  DEFB $FF

; Rotor overlay frame 0 (idle set)
;
; Four 24x24-pixel (3 bytes x 24 lines) rotor frames at $6700, $6800, $6900,
; $6A00, XORed onto the helicopter sprite by $8CA0 (frame number cycles 0-3 in
; $753A) when the helicopter is landed ($7515=1) or out of fuel ($7516<>0). In
; normal flight the 2-frame set at 7000/7100 is used instead.
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $07,$18,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$40
  DEFB $20,$20,$10
  DEFB $00,$00,$41
  DEFB $80,$00,$02
  DEFB $01,$01,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $0C,$F0,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$80
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00

; Tile column table A, row 4 (tiles $58-$FE)
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$81,$27,$19,$28,$22,$81,$21,$29,$1A,$2B,$28,$29
  DEFB $2C,$1B,$22,$21,$1C,$2E,$2D,$2E,$2D,$2E,$83,$83,$FF,$56,$4A,$4A
  DEFB $4A,$47,$4A,$48,$4A,$49,$4A,$4D,$50,$53,$89,$5A,$59,$57,$57,$57
  DEFB $59,$57,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$4B,$46,$4B,$4B
  DEFB $4B,$4B,$4B,$4B,$4B,$4E,$51,$54,$89,$5A,$5A,$89,$89,$89,$FF,$FF
  DEFB $FF,$FF,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4F,$52,$55,$5A,$89,$89,$89
  DEFB $89,$5A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; Rotor overlay frame 1 (idle set)
  DEFB $00,$00,$00
  DEFB $00,$04,$03
  DEFB $00,$00,$00
  DEFB $00,$00,$03
  DEFB $0C,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $C1,$00,$00
  DEFB $00,$C1,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$10,$60
  DEFB $80,$00,$00
  DEFB $00,$80,$60
  DEFB $18,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00

; HUD bottom two rows (64 characters)
;
; Printed at rows 22-23 by 84F4 (via $859A): WIND FORCE bar end caps ($23/$24),
; "WIND", rule chars ($22), "DANGER", DANGER bar pattern ($25/$26), "FORCE".
; The crate boxes and bar contents are drawn with attributes.
  DEFM "#$#$#$#$#$  WIND\"\"\"\"\"\"\"\"\"\"DANGER%&%&%&%&%& FORCE                "

; Tile column table A, row 5 (tiles $8C-$FE)
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$83,$83,$2E,$2D,$2E,$2D
  DEFB $2E,$2D,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$4A,$4A,$4A,$47
  DEFB $4A,$48,$4A,$49,$4A,$4D,$50,$53,$89,$5A,$59,$57,$57,$57,$FF,$FF
  DEFB $FF,$FF,$4B,$4B,$4B,$4B,$4B,$4B,$46,$4E,$51,$54,$5A,$89,$89,$89
  DEFB $89,$5A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; Rotor overlay frame 2 (idle set)
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $30,$0F,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$01
  DEFB $02,$02,$04
  DEFB $00,$00,$80
  DEFB $00,$00,$10
  DEFB $20,$20,$40
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $F0,$0C,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Unused ($FF)

; Helicopter sprite buffer
;
; 24x24 pixels (3 bytes x 24 lines). Rebuilt every iteration by $8CA0 (heading
; frame from E930 + rotor overlay) and during the crash sequence ($9246: frame
; at $9300 XOR debris frames F550).
  DEFB $00,$00,$00
  DEFB $00,$08,$06
  DEFB $00,$00,$00
  DEFB $07,$17,$11
  DEFB $67,$1F,$1F
  DEFB $0F,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $82,$10,$EE
  DEFB $EF,$7D,$FF
  DEFB $FF,$FF,$57
  DEFB $FF,$F8,$F8
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$20,$C3
  DEFB $03,$03,$03
  DEFB $07,$FF,$3F
  DEFB $CE,$FE,$C0
  DEFB $80,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00

; Tile column table A, row 6 (tiles $B2-$FE)
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$83,$83,$2E,$2D,$2E,$2D,$FF,$FF
  DEFB $FF,$FF,$4A,$4A,$48,$4A,$49,$4A,$49,$4D,$50,$53,$59,$57,$57,$57
  DEFB $89,$5A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; Rotor overlay frame 3 (idle set)
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$3F
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $08,$08,$08
  DEFB $00,$00,$80
  DEFB $00,$00,$08
  DEFB $08,$08,$08
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$FC
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF ; Unused ($FF)

; Island names (map labels)
;
; Printed by $8DE2/8DEE in the 4x8 font (6B00) at the label position of each
; island record (F230), in record order. The first byte is skipped. '?' is a
; space; $FD = append " ISLAND" (6AC2) and go to the next island; $FE = next
; island; $FF = end.
  DEFB $FF                ; Skipped
  DEFM "BANANA"
  DEFB $FD                ; append " ISLAND", next line
  DEFM "ORTE?ROCKS"
  DEFB $FE                ; next line
  DEFM "KOKOLA"
  DEFB $FD                ; append " ISLAND", next line
  DEFM "LAGOON"
  DEFB $FD                ; append " ISLAND", next line
  DEFM "PEAK"
  DEFB $FD                ; append " ISLAND", next line
  DEFM "BASE"
  DEFB $FD                ; append " ISLAND", next line
  DEFM "GILLIGANS"
  DEFB $FD                ; append " ISLAND", next line
  DEFM "RED"
  DEFB $FD                ; append " ISLAND", next line
  DEFM "SKEG"
  DEFB $FD                ; append " ISLAND", next line
  DEFM "BONE"
  DEFB $FD                ; append " ISLAND", next line
  DEFM "GIANTS?GATEWAY"
  DEFB $FE                ; next line
  DEFM "CLAW"
  DEFB $FD                ; append " ISLAND", next line
  DEFM "LUKELAND?ISLES"
  DEFB $FE                ; next line
  DEFM "ENTERPRISE"
  DEFB $FD                ; append " ISLAND", next line
  DEFB $FF                ; end of text
  DEFB $00                ; Unused
  DEFM "?ISLAND"          ; " ISLAND" suffix ('?' = space)
  DEFB $FC                ; End of suffix ($FC)

; Tile column table A, row 7 (tiles $D0-$FE)
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$2E,$2D,$2E,$2D,$83,$83
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF

; 4x8 font for the map labels and the info screen text
;
; Base address $6908 (character c at $6908+8*c); only codes $3F ('?', blank =
; space) to $5A are present. Each glyph occupies the left 4 pixels (values
; $00-$70); 8DEE prints two characters per screen byte (the second one shifted
; right 4 pixels).
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; "?" (space)
  DEFB $00,$00,$00,$00,$00,$20,$00,$00 ; "@" (unused)
  DEFB $00,$20,$50,$70,$50,$50,$00,$00 ; A-Z
  DEFB $00,$60,$50,$60,$50,$60,$00,$00 ;
  DEFB $00,$20,$50,$40,$50,$20,$00,$00 ;
  DEFB $00,$60,$50,$50,$50,$60,$00,$00 ;
  DEFB $00,$70,$40,$60,$40,$70,$00,$00 ;
  DEFB $00,$70,$40,$60,$40,$40,$00,$00 ;
  DEFB $00,$20,$50,$40,$50,$30,$00,$00 ;
  DEFB $00,$50,$50,$70,$50,$50,$00,$00 ;
  DEFB $00,$70,$20,$20,$20,$70,$00,$00 ;
  DEFB $00,$10,$10,$50,$50,$20,$00,$00 ;
  DEFB $00,$50,$50,$60,$50,$50,$00,$00 ;
  DEFB $00,$40,$40,$40,$40,$70,$00,$00 ;
  DEFB $00,$50,$70,$50,$50,$50,$00,$00 ;
  DEFB $00,$60,$50,$50,$50,$50,$00,$00 ;
  DEFB $00,$20,$50,$50,$50,$20,$00,$00 ;
  DEFB $00,$60,$50,$60,$40,$40,$00,$00 ;
  DEFB $00,$20,$50,$50,$70,$30,$00,$00 ;
  DEFB $00,$60,$50,$60,$50,$50,$00,$00 ;
  DEFB $00,$30,$40,$20,$10,$60,$00,$00 ;
  DEFB $00,$70,$20,$20,$20,$20,$00,$00 ;
  DEFB $00,$50,$50,$50,$50,$70,$00,$00 ;
  DEFB $00,$50,$50,$50,$50,$20,$00,$00 ;
  DEFB $00,$50,$50,$70,$70,$20,$00,$00 ;
  DEFB $00,$50,$50,$20,$50,$50,$00,$00 ;
  DEFB $00,$50,$50,$20,$20,$20,$00,$00 ;
  DEFB $00,$70,$10,$20,$40,$70,$00,$00 ;

; Tile column table A, row 8 (terminators of tiles $E4-$E9)
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; Tile column table B (south view), row 0
;
; Same layout as 6300 for the south (rotated 180 degrees) view.
  DEFB $80,$00,$01,$02,$82,$05,$06,$03,$04,$11,$10,$13,$12,$15,$14,$30
  DEFB $87,$87,$1D,$87,$18,$87,$18,$87,$1E,$87,$87,$87,$87,$89,$87,$89
  DEFB $87,$87,$87,$87,$87,$88,$87,$87,$87,$87,$00,$00,$00,$87,$87,$87
  DEFB $87,$87,$1D,$87,$18,$87,$18,$87,$1E,$87,$87,$87,$87,$17,$18,$18
  DEFB $17,$17,$18,$18,$17,$89,$87,$87,$87,$87,$87,$88,$87,$87,$87,$87
  DEFB $89,$87,$00,$00,$00,$87,$87,$87,$87,$87,$1D,$87,$18,$87,$18,$87
  DEFB $1E,$87,$87,$87,$87,$17,$18,$18,$17,$17,$18,$18,$17,$17,$18,$18
  DEFB $17,$17,$18,$18,$17,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$89
  DEFB $87,$87,$87,$87,$87,$87,$89,$89,$00,$87,$87,$87,$87,$87,$1D,$87
  DEFB $18,$87,$18,$87,$1E,$87,$87,$87,$87,$17,$18,$18,$17,$87,$87,$89
  DEFB $89,$87,$89,$89,$00,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87
  DEFB $87,$87,$89,$89,$87,$87,$87,$87,$87,$87,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87
  DEFB $89,$89,$87,$87,$87,$87,$00,$00,$00,$00,$87,$87,$87,$87,$87,$87
  DEFB $87,$87,$87,$87,$87,$87,$87,$87,$89,$89,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$00

; Tile column table B, row 1
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $81,$81,$21,$29,$1A,$27,$19,$28,$22,$29,$2C,$2B,$28,$87,$89,$83
  DEFB $0D,$0E,$0B,$0C,$88,$82,$09,$0A,$07,$08,$FF,$FF,$FF,$31,$32,$56
  DEFB $87,$87,$5E,$87,$87,$87,$87,$87,$5C,$87,$87,$87,$87,$1F,$87,$87
  DEFB $20,$1F,$87,$87,$20,$89,$87,$87,$87,$87,$87,$88,$87,$87,$87,$87
  DEFB $89,$87,$FF,$FF,$FF,$87,$87,$87,$87,$87,$5E,$87,$87,$87,$87,$87
  DEFB $5C,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$1F,$87,$87
  DEFB $20,$1F,$87,$87,$20,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$89
  DEFB $87,$87,$89,$5A,$89,$89,$89,$5A,$FF,$87,$87,$87,$87,$87,$5E,$87
  DEFB $87,$87,$87,$87,$5C,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$89
  DEFB $89,$87,$89,$89,$FF,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87
  DEFB $87,$87,$89,$89,$87,$87,$87,$87,$87,$87,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87
  DEFB $89,$89,$87,$87,$87,$87,$FF,$FF,$FF,$FF,$87,$87,$87,$87,$87,$87
  DEFB $87,$87,$87,$87,$87,$87,$87,$87,$89,$89,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FF

; Tile column table B, row 2
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $81,$81,$21,$29,$1A,$27,$19,$28,$22,$29,$2C,$2B,$28,$21,$1C,$1B
  DEFB $22,$21,$1A,$19,$22,$83,$0D,$0E,$0B,$0C,$88,$82,$09,$0A,$07,$08
  DEFB $87,$89,$FF,$FF,$FF,$31,$32,$56,$87,$87,$5D,$87,$87,$87,$87,$87
  DEFB $5B,$87,$87,$87,$87,$1F,$87,$87,$20,$1F,$87,$87,$20,$5D,$87,$87
  DEFB $5B,$5D,$87,$87,$5B,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$89
  DEFB $87,$87,$57,$59,$57,$57,$89,$5A,$FF,$87,$87,$87,$87,$87,$5D,$87
  DEFB $87,$87,$87,$87,$5B,$87,$87,$87,$87,$87,$87,$87,$87,$89,$5A,$89
  DEFB $89,$89,$89,$5A,$FF,$87,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4F
  DEFB $52,$55,$89,$5A,$89,$5A,$89,$89,$87,$87,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87
  DEFB $89,$5A,$89,$5A,$89,$89,$FF,$FF,$FF,$FF,$87,$87,$87,$87,$87,$87
  DEFB $87,$87,$87,$87,$89,$5A,$89,$89,$89,$5A,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FF

; Print the score
;
; Prints the string ending at $6624 right-to-left from row 19 column 31 (screen
; address $507F) until a $FF byte, using the 8x8 font (6028), 7 pixel lines per
; character. Entry PrintBackwards (from 87BC) prints the high score with
; DE=$509F, BC=$662D.
PrintScore:
  LD DE,$507F
  LD BC,$6624
; This entry point is used by the routine at 87BC.
PrintBackwards:
  LD A,(BC)               ; Next character (BC moves backwards)
  CP $FF                  ;
  RET Z                   ;
  PUSH BC                 ;
  LD L,A                  ;
  LD H,$00                ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  LD BC,$6028             ;
  ADD HL,BC               ;
  LD B,$07                ; Copy 7 pixel lines
PrintScore_0:
  LD A,(HL)               ;
  LD (DE),A               ;
  INC D                   ;
  INC HL                  ;
  DJNZ PrintScore_0       ;
  POP BC                  ;
  LD D,$50                ; Back to the top line, one column left
  DEC E                   ;
  DEC BC                  ;
  JR PrintBackwards       ;

; Tile column table B, row 3
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$81,$81,$21,$29,$1A,$27,$19,$28,$22,$29,$2C,$2B
  DEFB $28,$21,$1C,$1B,$22,$21,$1A,$19,$22,$21,$1C,$1B,$22,$21,$1A,$19
  DEFB $22,$83,$0D,$0E,$0B,$0C,$82,$09,$0A,$07,$08,$87,$89,$88,$2D,$2E
  DEFB $2D,$2E,$83,$83,$FF,$31,$32,$56,$87,$87,$5D,$87,$87,$87,$87,$87
  DEFB $5B,$87,$87,$87,$87,$1F,$87,$87,$20,$57,$59,$57,$57,$57,$89,$5A
  DEFB $FF,$87,$46,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4E,$51,$54,$89,$5A
  DEFB $89,$5A,$89,$89,$89,$58,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $4C,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4F,$52,$55,$89,$5A,$89,$5A
  DEFB $89,$89,$FF,$FF,$FF,$FF,$87,$87,$87,$87,$87,$87,$87,$87,$87,$87
  DEFB $89,$5A,$89,$89,$89,$5A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$3C,$3D,$3E,$3F,$40,$41,$42,$43,$44,$FF

; Rotor overlay frame 0 (flight set)
;
; Two rotor frames ($7000 and $7100) used by $8CA0 in normal flight
; (alternating via $753A 0/1).
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$20,$28
  DEFB $28,$24,$10
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$5C
  DEFB $00,$2C,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$1A,$00
  DEFB $1D,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $04,$12,$0A
  DEFB $0A,$02,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00

; Tile column table B, row 4
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$81,$81,$21,$29,$1A,$27,$19,$28,$22,$29,$2C,$2B
  DEFB $28,$21,$1C,$1B,$22,$2D,$2E,$2D,$2E,$2D,$83,$83,$FF,$56,$4A,$4A
  DEFB $47,$4A,$48,$4A,$49,$4A,$4A,$4D,$50,$53,$89,$5A,$57,$59,$57,$57
  DEFB $58,$59,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$46,$4B,$4B,$4B
  DEFB $4B,$4B,$4B,$4B,$4B,$4E,$51,$54,$89,$5A,$89,$5A,$89,$89,$FF,$FF
  DEFB $FF,$FF,$4C,$4C,$4C,$4C,$4C,$4C,$4C,$4F,$52,$55,$89,$5A,$89,$89
  DEFB $89,$5A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; Rotor overlay frame 1 (flight set)
  DEFB $00,$00,$00
  DEFB $03,$04,$01
  DEFB $00,$00,$00
  DEFB $25,$24,$12
  DEFB $10,$08,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$F0
  DEFB $00,$70,$80
  DEFB $30,$00,$00
  DEFB $00,$80,$06
  DEFB $00,$07,$00
  DEFB $07,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$08,$24
  DEFB $14,$52,$52
  DEFB $00,$00,$00
  DEFB $C0,$10,$60
  DEFB $80,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00

; Attributes for the bottom two screen rows
;
; 64 attribute bytes copied to rows 22-23 ($5AC0) by 84F4: crate boxes (6 =
; yellow), WIND FORCE bar (5/$38), DANGER bar ($7A).
  DEFB $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$00,$07,$07,$07,$07,$07
  DEFB $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$38,$38,$38,$38,$38,$38
  DEFB $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$00,$07,$07,$07,$07,$07
  DEFB $7A,$7A,$7A,$7A,$7A,$7A,$7A,$7A,$7A,$7A,$7A,$7A,$7A,$7A,$7A,$7A

; Tile column table B, row 5
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$83,$83,$2D,$2E,$2D,$2E
  DEFB $2D,$2E,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$4A,$4A,$47,$4A
  DEFB $48,$4A,$49,$4A,$4A,$4D,$50,$53,$89,$5A,$57,$59,$57,$57,$FF,$FF
  DEFB $FF,$FF,$4B,$4B,$4B,$4B,$4B,$46,$4B,$4E,$51,$54,$89,$5A,$89,$89
  DEFB $89,$5A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; HUD panel attributes
;
; 21 rows x 8 bytes, copied to columns 24-31 of rows 0-20 by 84F4.
  DEFB $07,$00,$07,$00,$07,$00,$07,$00
  DEFB $7A,$05,$7A,$05,$7A,$05,$7A,$05
  DEFB $7A,$05,$7A,$05,$7A,$05,$7A,$05
  DEFB $7A,$05,$7A,$05,$7A,$05,$7A,$05
  DEFB $7A,$05,$7A,$05,$7A,$05,$7A,$05
  DEFB $7A,$05,$7A,$05,$7A,$05,$7A,$05
  DEFB $7A,$05,$07,$07,$07,$07,$07,$07
  DEFB $7A,$05,$07,$07,$07,$07,$07,$07
  DEFB $7A,$05,$07,$07,$00,$00,$00,$07
  DEFB $00,$07,$07,$07,$00,$42,$00,$07
  DEFB $07,$07,$00,$07,$00,$00,$00,$07
  DEFB $07,$07,$07,$07,$07,$07,$07,$07
  DEFB $07,$07,$07,$07,$07,$07,$07,$07
  DEFB $07,$07,$07,$38,$38,$38,$38,$38
  DEFB $07,$07,$07,$38,$38,$38,$38,$38
  DEFB $07,$07,$07,$07,$07,$07,$07,$07
  DEFB $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F
  DEFB $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F
  DEFB $07,$07,$07,$07,$07,$07,$07,$07
  DEFB $38,$38,$38,$38,$38,$38,$38,$38
  DEFB $38,$38,$38,$38,$38,$38,$38,$38

; Tile column table B, row 6
  DEFB $07,$07,$07,$07,$07,$07,$07,$07,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$83,$83,$2D,$2E,$2D,$2E,$FF,$FF
  DEFB $FF,$FF,$4A,$48,$4A,$49,$4A,$49,$4A,$4D,$50,$53,$57,$59,$57,$57
  DEFB $89,$5A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; HUD panel character layout
;
; 15 rows x 8 bytes for columns 24-31 of rows 0-14, drawn by 84F4. Each byte is
; a HUD glyph number n (glyph at $7400+8*n: A/S/F/T bar headings, bar frames,
; compass rose, helicopter life icons...) or $FF = leave blank.
  DEFB $17,$FF,$18,$FF,$19,$FF,$1A,$FF
  DEFB $FF,$1B,$FF,$1B,$FF,$1B,$FF,$1B
  DEFB $FF,$1B,$FF,$1B,$FF,$1B,$FF,$1B
  DEFB $FF,$1B,$FF,$1B,$FF,$1B,$FF,$1B
  DEFB $FF,$1B,$FF,$1B,$FF,$1B,$FF,$1B
  DEFB $FF,$1B,$FF,$1B,$FF,$1B,$FF,$1B
  DEFB $FF,$1B,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$1B,$FF,$02,$03,$04,$03,$05
  DEFB $FF,$1B,$FF,$06,$07,$08,$09,$0A
  DEFB $FF,$FF,$FF,$0B,$0C,$0D,$0E,$0F
  DEFB $00,$01,$FF,$06,$10,$11,$12,$0A
  DEFB $FF,$FF,$FF,$13,$14,$15,$14,$16
  DEFB $00,$01,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  DEFB $00,$01,$FF,$FF,$FF,$FF,$FF,$FF

; Cyclone buffeting of the controls
;
; Called from the main loop (5B94) after the controls have been read (7FD6)
; when the heli-cyclone map distance 7550 is below 5 (level 1) or 6 (later
; levels; the CP operand at 5B93 is patched by 8321). Adds random control
; inputs to 7522 so the helicopter is thrown about; very close to the cyclone
; it forces DOWN+LEFT (a descending spin).
;
; A Cyclone distance (7550), 0..5
;
; Random bits come from L of the RNG at $8B74 (each bit ~50%). dist 4..5: bits
; 1/3/4 (down, right, left) may be added; dist 2..3: bits 0/1/3/4 (also
; forward); dist 0..1: controls are replaced by $12 (down+left) and the turn
; timer is run down one extra step.
  LD B,A                  ; Save the distance
  LD A,($7515)            ; No effect while landed
  CP $01                  ;
  RET Z                   ;
  NOP                     ; Two NOPs (patched-out code)
  NOP                     ;
  LD A,B                  ;
  CP $04                  ; Distance 4 or 5?
  JR C,$7392              ;
  CALL $8B74              ; RND
  LD A,L                  ;
  AND $1A                 ; Keep random down/right/left bits (mask $1A)
  LD HL,$7522             ; OR them into the control bits
  OR (HL)                 ;
  LD (HL),A               ;
  RET                     ;
  CP $02                  ; Distance 2 or 3?
  JR C,$73A2              ;
  CALL $8B74              ; RND
  LD A,L                  ;
  AND $1B                 ; Random forward/down/right/left (mask $1B)
  LD HL,$7522             ;
  OR (HL)                 ;
  LD (HL),A               ;
  RET                     ;
  LD HL,$7521             ; Distance 0 or 1: speed up a turn in progress
  XOR A                   ;
  CP (HL)                 ;
  JR Z,$73AA              ;
  DEC (HL)                ; Decrement the turn timer if non-zero
  LD A,$12                ; Force controls = down + turn left
  LD ($7522),A            ;
  RET                     ;

; Unused code fragment
;
; Never referenced (no caller found statically or during emulation). Bytes
; would be NOP / RET NZ / set the crash flag 7505 to 1 / RET.
  NOP
  RET NZ
  LD A,$01
  LD ($7505),A
  RET

; South-view terrain pillar table, page $73 (8th pillar level), codes $B8-$FF
;
; Part of the south-view pillar tables $6C00-$73FF (see 7E10): byte $7300+code
; is the 8th (topmost) tile of the pillar drawn for map code 'code' in south
; view. Only codes $E4-$FF ever reach this level; $FF = end of pillar. (The
; bytes below $73B8 belong to the HUD layout table at $7300, outside this
; range.)
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FF: codes $B8-$E3 never have an 8th
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; level
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;
  DEFB $FF,$FF,$FF,$FF                 ;
  DEFB $2D,$2E,$2D,$2E,$83,$83,$FF,$FF ; 8th-level pillar tiles for codes
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $E4-$FF ($FF = none)
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;
  DEFB $FF,$FF,$FF,$FF                 ;

; HUD / panel 8x8 character set (codes $00-$1B)
;
; Character k is at $7400+8*k. Drawn by 84F4 (HUD layout table $7300, LD H,$74)
; and by 8E5C/E43A (map and info-screen borders). The trailing $FF bytes at
; $74E0 also terminate south-view pillars at page $74 (9th level).
  DEFB $1F,$80,$C1,$7F,$0F,$07,$08,$00 ; Chars $00-$06: HUD panel pieces
  DEFB $FF,$40,$F0,$FC,$FE,$FE,$10,$00 ; (lettering/bars)
  DEFB $01,$03,$07,$0E,$1C,$38,$70,$E0 ;
  DEFB $FF,$FF,$00,$00,$00,$00,$00,$00 ;
  DEFB $FF,$80,$22,$32,$2A,$26,$22,$00 ;
  DEFB $80,$C0,$E0,$70,$38,$1C,$0E,$07 ;
  DEFB $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0 ;
  DEFB $00,$00,$3E,$3C,$3E,$3F,$2F,$07 ; Char $07: map-border top-left corner
                                       ; piece
  DEFB $18,$3C,$7E,$FF,$3C,$3C,$3C,$00 ; Char $08: map-border top edge (up
                                       ; arrow)
  DEFB $00,$00,$7C,$3C,$7C,$FC,$F4,$E0 ; Char $09: map-border top-right corner
                                       ; piece
  DEFB $03,$03,$03,$03,$03,$03,$03,$03 ; Chars $0A-$0B: HUD panel pieces
  DEFB $C0,$80,$AA,$AA,$AA,$AA,$BE,$80 ;
  DEFB $10,$30,$7E,$FE,$FE,$7E,$30,$10 ; Char $0C: map-border left edge (left
                                       ; arrow)
  DEFB $3C,$7E,$E7,$DB,$DB,$E7,$7E,$3C ; Char $0D: compass centre ring
  DEFB $08,$0C,$7E,$7F,$7F,$7E,$0C,$08 ; Char $0E: map-border right edge (right
                                       ; arrow)
  DEFB $03,$01,$7D,$41,$79,$41,$7D,$01 ; Char $0F: HUD panel piece
  DEFB $07,$2F,$3F,$3E,$3C,$3E,$00,$00 ; Char $10: map-border bottom-left
                                       ; corner piece
  DEFB $00,$3C,$3C,$3C,$FF,$7E,$3C,$18 ; Char $11: map-border bottom edge (down
                                       ; arrow)
  DEFB $E0,$F4,$FC,$7C,$3C,$7C,$00,$00 ; Char $12: map-border bottom-right
                                       ; corner piece
  DEFB $E0,$70,$38,$1C,$0E,$07,$03,$01 ; Chars $13-$1B: HUD panel pieces (incl.
  DEFB $00,$00,$00,$00,$00,$00,$FF,$FF ; letters A, S, F, T at $74B8-$74D0)
  DEFB $00,$3E,$20,$3E,$02,$3E,$80,$FF ;
  DEFB $07,$0E,$1C,$38,$70,$E0,$C0,$80 ;
  DEFB $00,$3C,$62,$62,$7E,$62,$00,$00 ;
  DEFB $00,$3E,$60,$7E,$02,$7C,$00,$00 ;
  DEFB $00,$7E,$60,$7E,$60,$60,$00,$00 ;
  DEFB $00,$7E,$18,$18,$18,$18,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$FF ;
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FF filler (also = end markers for
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; pillar page $74)
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;
  DEFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;

; LIVE GAME VARIABLES ($7500-$7563)
;
; The 100-byte variable block. At game start 5B1B copies the initial values
; 7564 here (LDIR 100 bytes); after each lost life 92B3 copies 75C8 over it,
; skipping bytes whose reset value is $FF. Variable names below are those used
; in re/notes/core1.md (the glossary).
  DEFW $0000              ; POS_X: X: world X of view-window origin (16-bit,
                          ; tiles); heli ground tile = X+11; +1 = east
  DEFW $0000              ; POS_Y: Y: world Y of view-window origin (16-bit,
                          ; tiles); heli ground tile = Y+14; -1 = north
  DEFB $00                ; VIEW: View direction: 0 = view north, 1 = view
                          ; south (world rotated 180 deg); toggled by N
  DEFB $00                ; CRASHED: Crash flag: 1 = helicopter destroyed (set
                          ; by 8A7A at 8B5F)
  DEFB $00                ; HEADING: Heading 0-15 (22.5 deg units, 0=N 4=E 8=S
                          ; 12=W); changes in steps of 2
  DEFB $00                ; HEADING_DISP: Displayed heading / sprite frame 0-15
                          ; (odd = mid-turn frame)
  DEFB $00                ; HEADING_NEXT: Heading at end of current turn
                          ; (7506+-2 mod 16)
  DEFW $0000              ; TMP_GFX: Scratch pointer: tile-graphics/target
                          ; pointer (7BB8, 7F21, 85D4) or column-list ptr
                          ; (86AF)
  DEFW $0000              ; TMP_ATTR: Scratch pointer into tile-attribute table
                          ; FE00-FE7F (7BB8, 7F21, 85D4, 86AF)
  DEFB $00                ; ALTITUDE: Altitude in pixels 0..60 ($3C);
                          ; climb/descent 1..3 per loop
  DEFW $0000              ; TMP_SPR: Scratch: shadow sprite source pointer
                          ; (ED68+72*(frame+1)), +8 per cell
  DEFW $0000              ; TMP_LIST: Scratch: pointer into 7A9F column list
                          ; (7BB8)
  DEFW $0000              ; TMP_MASK: Scratch: 7BB8 second mask pointer (word);
                          ; 86AF/F4DA byte column counter 0..2
  DEFB $00                ; TOUCHDOWN: Touch-down flag: 1 = tried to descend
                          ; below altitude 0 (8269); landing check in 8A7A
  DEFB $00                ; LANDED: Landed flag: 1 = on the ground (8AF7); UP
                          ; clears it (take-off, 820D)
  DEFB $00                ; NO_FUEL: Out-of-fuel flag: 1 = fuel bar empty
                          ; (82C1); forces descent, no climb/thrust
  DEFB $00                ; FUEL_TICK: Fuel tick: drain one fuel line every 49
                          ; loops (0..$30)
  DEFW $0000              ; FUEL_PTR: FUEL bar pointer (screen addr, column
                          ; $1C); $47BC = empty
  DEFB $00                ; CLIMB_RATE: Climb rate 0..3 px/loop (ramps while UP
                          ; held)
  DEFB $00                ; DESCENT_RATE: Descent rate 0..3 px/loop (ramps
                          ; while DOWN held or no fuel); >=3 on contact = crash
  DEFW $0000              ; TIME_PTR: TIME bar pointer (screen addr, column
                          ; $1E); low byte $DE = time up
  DEFW $0000              ; ALT_PTR: ALTIMETER bar pointer (screen addr, column
                          ; $18)
  DEFB $00                ; Unused (never accessed: no static reference, no
                          ; access in emulation)
  DEFB $00                ; TURN_TIMER: Turn timer: 3 at start of a 45-deg
                          ; turn, completes at 1; 0 = idle
  DEFB $00                ; CONTROLS: Control bits: b0 forward, b1 down, b2 up,
                          ; b3 right, b4 left
  DEFB $00                ; Unused (never accessed: no static reference, no
                          ; access in emulation)
  DEFB $00                ; PLANE_COL: Aircraft view column (0..24 = buffer
                          ; col+2, mirrored in south view)
  DEFB $00                ; PLANE_ROW: Aircraft view row (0..30 = buffer row+2,
                          ; mirrored in south view)
  DEFB $00                ; UI_FLAGS: b0 M held, b1 map shown, b2 N held, b3
                          ; map closed (unused), b4 map needs drawing
  DEFB $00                ; SPEED: Speed/momentum 0..7: +1/loop thrusting,
                          ; -1/loop coasting; moves 1 tile/loop while >0
  DEFB $00                ; TIME_TICK: Time tick: one TIME bar line lost every
                          ; 255 loops (level 1), 15 fewer per level
  DEFW $0000              ; TMP_LIST2: Scratch: column-list pointer for heli
                          ; body/rope occlusion (86AF, F4F8)
  DEFW $0000              ; TMP_ATTR2: Scratch: attribute pointer for heli body
                          ; cells (86AF, F4F1)
  DEFB $00                ; SOUND_OFF: 1 = interrupt sound effects off (menu
                          ; E282, death sequence 9278)
  DEFB $00                ; ON_PAD: 1 = landed on a complete 3x3 helipad (tiles
                          ; $83/$89): refuel, level check
  DEFB $00                ; PLANE_DRAWN: 1 = an aircraft sprite was built this
                          ; loop (only the first one)
  DEFB $00                ; PLANE_NEAR: Aircraft proximity: b0 X-window, b1
                          ; Y-window; 3 = BEWARE AIRCRAFT
  DEFB $00,$00            ; Unused (never accessed: no static reference, no
                          ; access in emulation)
  DEFB $00                ; HELI_LEVEL: Heli altitude level for aircraft:
                          ; alt/8+1 (1..7)
  DEFB $00                ; AIR_TICK: Free-running loop counter while airborne
                          ; (bit 2 gates 7533 update)
  DEFB $00                ; WAVE_X: Sea-wave pattern column phase 0..8 (wraps
                          ; to 4)
  DEFB $00                ; WAVE_Y: Sea-wave pattern row phase 0..6 (wraps to
                          ; 3)
  DEFB $00                ; WAVE_TICK: Wave re-seed counter 0..2
  DEFW $0000              ; WAVE_PTR: Wave pattern source pointer $01xx (ROM
                          ; bytes as random data)
  DEFB $00                ; ROTOR_FRAME: Rotor animation frame: 0..1 flying,
                          ; 0..3 landed / no fuel
  DEFB $00                ; MOVE_DIR: Direction of travel (heading latched
                          ; while thrusting); used when coasting
  DEFW $0000              ; MAP_ROW_PTR: Map screen: pixel address of current
                          ; island bitmap row (8D5D)
  DEFW $0000              ; MAP_PTR: Map screen: running pixel pointer within
                          ; the row (8D5D)
  DEFB $00                ; MAP_HX: Heli map column = X/32 clamped 0..22
  DEFB $00                ; MAP_HY: Heli map row = Y/32 clamped 0..21
  DEFB $00                ; MAP_BLINK: Map marker blink counter 0..6
  DEFW $0000              ; MAP_HATTR: Map: attribute address of heli marker
  DEFW $0000              ; MAP_HPIX: Map: pixel address of heli marker
  DEFW $0000              ; MAP_CATTR: Map: attribute address of cyclone marker
  DEFW $0000              ; MAP_CPIX: Map: pixel address of cyclone marker
  DEFB $00                ; CYC_X: Cyclone map column 1..21 (start 2 or 20)
  DEFB $00                ; CYC_Y: Cyclone map row 1..20 (start 2 or 19)
  DEFB $00                ; OFF_MAP: Number of axes on which the heli is off
                          ; the map grid (0..2)
  DEFB $18                ; CYC_TICK: Cyclone move timer 0..24 (moves every 25
                          ; loops)
  DEFB $11                ; CYC_LEG: Cyclone leg counter 0..8 (new random
                          ; direction every 9 moves)
  DEFB $03                ; CYC_DIST: Distance heli-cyclone on map grid =
                          ; max(abs dx, abs dy), capped 15
  DEFB $00                ; PICK_TILE: Replacement tile code written to the
                          ; island map when a pickup starts
  DEFW $0000              ; ISLAND: Address of current island record (F230
                          ; table); $F294 = Base island
  DEFB $00                ; CRATES: Crates collected this level 0..5
  DEFB $00                ; WINCH: Winch countdown: 1..16 = object being
                          ; winched up; 0 = idle
  DEFB $00                ; ROPE_STATE: Rope lowering state 0..2 (F39A)
  DEFW $0000              ; PICK_SPR: Pointer to sprite of hooked object: $F52F
                          ; crate, $F548 survivor
  DEFB $00,$00            ; Unused (never accessed: no static reference, no
                          ; access in emulation)
  DEFB $00                ; SURV_ANIM1: Survivor animation counter 0..7 (frame
                          ; swap at 4 and 8)
  DEFB $00                ; SURV_ANIM2: Survivor animation counter 0..5 (frame
                          ; swap at 3 and 6)
  DEFB $00                ; ROTOR_SND: Rotor sound phase 0..3 (interrupt 83C2)
  DEFB $00,$00,$00,$00,$00,$00 ; Unused (never accessed: no static reference,
                               ; no access in emulation)

; Initial values of the variable block
;
; Copied to 7500 (100 bytes) by 5B1B at the start of every game. One sub-block
; per variable of 7500.
  DEFW $0139              ; Initial value of POS_X ($7500) = $0139
  DEFW $0170              ; Initial value of POS_Y ($7502) = $0170
  DEFB $00                ; Initial value of VIEW ($7504) = $00
  DEFB $00                ; Initial value of CRASHED ($7505) = $00
  DEFB $04                ; Initial value of HEADING ($7506) = $04
  DEFB $04                ; Initial value of HEADING_DISP ($7507) = $04
  DEFB $04                ; Initial value of HEADING_NEXT ($7508) = $04
  DEFW $0000              ; Initial value of TMP_GFX ($7509) = $0000
  DEFW $0000              ; Initial value of TMP_ATTR ($750B) = $0000
  DEFB $08                ; Initial value of ALTITUDE ($750D) = $08
  DEFW $0000              ; Initial value of TMP_SPR ($750E) = $0000
  DEFW $0000              ; Initial value of TMP_LIST ($7510) = $0000
  DEFW $0000              ; Initial value of TMP_MASK ($7512) = $0000
  DEFB $00                ; Initial value of TOUCHDOWN ($7514) = $00
  DEFB $01                ; Initial value of LANDED ($7515) = $01
  DEFB $00                ; Initial value of NO_FUEL ($7516) = $00
  DEFB $00                ; Initial value of FUEL_TICK ($7517) = $00
  DEFW $47BC              ; Initial value of FUEL_PTR ($7518) = $47BC
  DEFB $00                ; Initial value of CLIMB_RATE ($751A) = $00
  DEFB $00                ; Initial value of DESCENT_RATE ($751B) = $00
  DEFW $0000              ; Initial value of TIME_PTR ($751C) = $0000
  DEFW $0000              ; Initial value of ALT_PTR ($751E) = $0000
  DEFB $00                ; Initial value of unused $7520
  DEFB $00                ; Initial value of TURN_TIMER ($7521) = $00
  DEFB $00                ; Initial value of CONTROLS ($7522) = $00
  DEFB $00                ; Initial value of unused $7523
  DEFB $00                ; Initial value of PLANE_COL ($7524) = $00
  DEFB $00                ; Initial value of PLANE_ROW ($7525) = $00
  DEFB $00                ; Initial value of UI_FLAGS ($7526) = $00
  DEFB $00                ; Initial value of SPEED ($7527) = $00
  DEFB $00                ; Initial value of TIME_TICK ($7528) = $00
  DEFW $0000              ; Initial value of TMP_LIST2 ($7529) = $0000
  DEFW $0000              ; Initial value of TMP_ATTR2 ($752B) = $0000
  DEFB $00                ; Initial value of SOUND_OFF ($752D) = $00
  DEFB $01                ; Initial value of ON_PAD ($752E) = $01
  DEFB $00                ; Initial value of PLANE_DRAWN ($752F) = $00
  DEFB $00                ; Initial value of PLANE_NEAR ($7530) = $00
  DEFB $00,$00            ; Initial value of unused $7531-$7532
  DEFB $03                ; Initial value of HELI_LEVEL ($7533) = $03
  DEFB $00                ; Initial value of AIR_TICK ($7534) = $00
  DEFB $00                ; Initial value of WAVE_X ($7535) = $00
  DEFB $00                ; Initial value of WAVE_Y ($7536) = $00
  DEFB $00                ; Initial value of WAVE_TICK ($7537) = $00
  DEFW $0000              ; Initial value of WAVE_PTR ($7538) = $0000
  DEFB $00                ; Initial value of ROTOR_FRAME ($753A) = $00
  DEFB $04                ; Initial value of MOVE_DIR ($753B) = $04
  DEFW $0000              ; Initial value of MAP_ROW_PTR ($753C) = $0000
  DEFW $0000              ; Initial value of MAP_PTR ($753E) = $0000
  DEFB $00                ; Initial value of MAP_HX ($7540) = $00
  DEFB $00                ; Initial value of MAP_HY ($7541) = $00
  DEFB $00                ; Initial value of MAP_BLINK ($7542) = $00
  DEFW $0000              ; Initial value of MAP_HATTR ($7543) = $0000
  DEFW $0000              ; Initial value of MAP_HPIX ($7545) = $0000
  DEFW $0000              ; Initial value of MAP_CATTR ($7547) = $0000
  DEFW $0000              ; Initial value of MAP_CPIX ($7549) = $0000
  DEFB $02                ; Initial value of CYC_X ($754B) = $02
  DEFB $02                ; Initial value of CYC_Y ($754C) = $02
  DEFB $00                ; Initial value of OFF_MAP ($754D) = $00
  DEFB $00                ; Initial value of CYC_TICK ($754E) = $00
  DEFB $00                ; Initial value of CYC_LEG ($754F) = $00
  DEFB $00                ; Initial value of CYC_DIST ($7550) = $00
  DEFB $00                ; Initial value of PICK_TILE ($7551) = $00
  DEFW $0000              ; Initial value of ISLAND ($7552) = $0000
  DEFB $00                ; Initial value of CRATES ($7554) = $00
  DEFB $00                ; Initial value of WINCH ($7555) = $00
  DEFB $00                ; Initial value of ROPE_STATE ($7556) = $00
  DEFW $0000              ; Initial value of PICK_SPR ($7557) = $0000
  DEFB $00,$00            ; Initial value of unused $7559-$755A
  DEFB $00                ; Initial value of SURV_ANIM1 ($755B) = $00
  DEFB $00                ; Initial value of SURV_ANIM2 ($755C) = $00
  DEFB $00                ; Initial value of ROTOR_SND ($755D) = $00
  DEFB $00,$00,$00,$00,$00,$00 ; Initial value of unused $755E-$7563

; Per-life reset values of the variable block
;
; After a lost life 92B3 copies these 100 bytes over 7500, except that a byte
; of $FF leaves the variable unchanged (time bar 751C, map marker pointers
; 7543-$754A, cyclone state 754B/754C/754E/754F and crates 7554 survive a
; death). The values otherwise equal 7564.
  DEFW $0139              ; Per-life reset value ($FF = keep) of POS_X ($7500)
                          ; = $0139
  DEFW $0170              ; Per-life reset value ($FF = keep) of POS_Y ($7502)
                          ; = $0170
  DEFB $00                ; Per-life reset value ($FF = keep) of VIEW ($7504) =
                          ; $00
  DEFB $00                ; Per-life reset value ($FF = keep) of CRASHED
                          ; ($7505) = $00
  DEFB $04                ; Per-life reset value ($FF = keep) of HEADING
                          ; ($7506) = $04
  DEFB $04                ; Per-life reset value ($FF = keep) of HEADING_DISP
                          ; ($7507) = $04
  DEFB $04                ; Per-life reset value ($FF = keep) of HEADING_NEXT
                          ; ($7508) = $04
  DEFW $0000              ; Per-life reset value ($FF = keep) of TMP_GFX
                          ; ($7509) = $0000
  DEFW $0000              ; Per-life reset value ($FF = keep) of TMP_ATTR
                          ; ($750B) = $0000
  DEFB $08                ; Per-life reset value ($FF = keep) of ALTITUDE
                          ; ($750D) = $08
  DEFW $0000              ; Per-life reset value ($FF = keep) of TMP_SPR
                          ; ($750E) = $0000
  DEFW $0000              ; Per-life reset value ($FF = keep) of TMP_LIST
                          ; ($7510) = $0000
  DEFW $0000              ; Per-life reset value ($FF = keep) of TMP_MASK
                          ; ($7512) = $0000
  DEFB $00                ; Per-life reset value ($FF = keep) of TOUCHDOWN
                          ; ($7514) = $00
  DEFB $01                ; Per-life reset value ($FF = keep) of LANDED ($7515)
                          ; = $01
  DEFB $00                ; Per-life reset value ($FF = keep) of NO_FUEL
                          ; ($7516) = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of FUEL_TICK
                          ; ($7517) = $00
  DEFW $47BC              ; Per-life reset value ($FF = keep) of FUEL_PTR
                          ; ($7518) = $47BC
  DEFB $00                ; Per-life reset value ($FF = keep) of CLIMB_RATE
                          ; ($751A) = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of DESCENT_RATE
                          ; ($751B) = $00
  DEFW $FFFF              ; Per-life reset value ($FF = keep) of TIME_PTR
                          ; ($751C) = $FFFF
  DEFW $0000              ; Per-life reset value ($FF = keep) of ALT_PTR
                          ; ($751E) = $0000
  DEFB $00                ; Per-life reset value ($FF = keep) of unused $7520
  DEFB $00                ; Per-life reset value ($FF = keep) of TURN_TIMER
                          ; ($7521) = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of CONTROLS
                          ; ($7522) = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of unused $7523
  DEFB $00                ; Per-life reset value ($FF = keep) of PLANE_COL
                          ; ($7524) = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of PLANE_ROW
                          ; ($7525) = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of UI_FLAGS
                          ; ($7526) = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of SPEED ($7527)
                          ; = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of TIME_TICK
                          ; ($7528) = $00
  DEFW $0000              ; Per-life reset value ($FF = keep) of TMP_LIST2
                          ; ($7529) = $0000
  DEFW $0000              ; Per-life reset value ($FF = keep) of TMP_ATTR2
                          ; ($752B) = $0000
  DEFB $00                ; Per-life reset value ($FF = keep) of SOUND_OFF
                          ; ($752D) = $00
  DEFB $01                ; Per-life reset value ($FF = keep) of ON_PAD ($752E)
                          ; = $01
  DEFB $00                ; Per-life reset value ($FF = keep) of PLANE_DRAWN
                          ; ($752F) = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of PLANE_NEAR
                          ; ($7530) = $00
  DEFB $00,$00            ; Per-life reset value ($FF = keep) of unused
                          ; $7531-$7532
  DEFB $03                ; Per-life reset value ($FF = keep) of HELI_LEVEL
                          ; ($7533) = $03
  DEFB $00                ; Per-life reset value ($FF = keep) of AIR_TICK
                          ; ($7534) = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of WAVE_X ($7535)
                          ; = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of WAVE_Y ($7536)
                          ; = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of WAVE_TICK
                          ; ($7537) = $00
  DEFW $0000              ; Per-life reset value ($FF = keep) of WAVE_PTR
                          ; ($7538) = $0000
  DEFB $00                ; Per-life reset value ($FF = keep) of ROTOR_FRAME
                          ; ($753A) = $00
  DEFB $04                ; Per-life reset value ($FF = keep) of MOVE_DIR
                          ; ($753B) = $04
  DEFW $0000              ; Per-life reset value ($FF = keep) of MAP_ROW_PTR
                          ; ($753C) = $0000
  DEFW $0000              ; Per-life reset value ($FF = keep) of MAP_PTR
                          ; ($753E) = $0000
  DEFB $00                ; Per-life reset value ($FF = keep) of MAP_HX ($7540)
                          ; = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of MAP_HY ($7541)
                          ; = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of MAP_BLINK
                          ; ($7542) = $00
  DEFW $FFFF              ; Per-life reset value ($FF = keep) of MAP_HATTR
                          ; ($7543) = $FFFF
  DEFW $FFFF              ; Per-life reset value ($FF = keep) of MAP_HPIX
                          ; ($7545) = $FFFF
  DEFW $FFFF              ; Per-life reset value ($FF = keep) of MAP_CATTR
                          ; ($7547) = $FFFF
  DEFW $FFFF              ; Per-life reset value ($FF = keep) of MAP_CPIX
                          ; ($7549) = $FFFF
  DEFB $FF                ; Per-life reset value ($FF = keep) of CYC_X ($754B)
                          ; = $FF
  DEFB $FF                ; Per-life reset value ($FF = keep) of CYC_Y ($754C)
                          ; = $FF
  DEFB $00                ; Per-life reset value ($FF = keep) of OFF_MAP
                          ; ($754D) = $00
  DEFB $FF                ; Per-life reset value ($FF = keep) of CYC_TICK
                          ; ($754E) = $FF
  DEFB $FF                ; Per-life reset value ($FF = keep) of CYC_LEG
                          ; ($754F) = $FF
  DEFB $00                ; Per-life reset value ($FF = keep) of CYC_DIST
                          ; ($7550) = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of PICK_TILE
                          ; ($7551) = $00
  DEFW $0000              ; Per-life reset value ($FF = keep) of ISLAND ($7552)
                          ; = $0000
  DEFB $FF                ; Per-life reset value ($FF = keep) of CRATES ($7554)
                          ; = $FF
  DEFB $00                ; Per-life reset value ($FF = keep) of WINCH ($7555)
                          ; = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of ROPE_STATE
                          ; ($7556) = $00
  DEFW $0000              ; Per-life reset value ($FF = keep) of PICK_SPR
                          ; ($7557) = $0000
  DEFB $00,$00            ; Per-life reset value ($FF = keep) of unused
                          ; $7559-$755A
  DEFB $00                ; Per-life reset value ($FF = keep) of SURV_ANIM1
                          ; ($755B) = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of SURV_ANIM2
                          ; ($755C) = $00
  DEFB $00                ; Per-life reset value ($FF = keep) of ROTOR_SND
                          ; ($755D) = $00
  DEFB $00,$00,$00,$00,$00,$00 ; Per-life reset value ($FF = keep) of unused
                               ; $755E-$7563

; Copy the view buffer to the screen
;
; Draws the 23x22-cell landscape view (screen columns 0-22, character rows
; 0-21) from the first 22 rows of the 23x29 tile buffer at $F74E. For each
; cell: attribute = byte $FE00+code; if code < $80 the 8 pixel bytes are copied
; from the tile set at $FA00+8*code, codes >= $80 are solid-colour tiles whose
; pixels are not touched.
;
; Called from the main loop (5B86) when the map is not shown, and twice per
; step of the death sequence (9246/9284).
  LD E,$00                ; E = screen column/row offset (low byte of screen
                          ; and attribute address)
  LD IX,Init              ; IX walks the view buffer row by row (23 bytes per
                          ; row)
  LD C,$08                ; Top third: 8 character rows
  LD B,$17                ; 23 columns
  PUSH BC                 ;
  LD L,(IX+$00)           ; L = tile code
  LD H,$FE                ; Attribute of the tile = byte at $FE00+code
  LD D,$58                ; Attribute row in the top third ($58xx)
  LD A,(HL)               ;
  LD (DE),A               ;
  BIT 7,L                 ; Codes $80-$FF: attribute only
  JR NZ,$7657             ;
  LD D,$40                ; Pixel row in the top third ($40xx)
  LD H,$00                ;
  ADD HL,HL               ; HL = 8*code...
  ADD HL,HL               ;
  ADD HL,HL               ;
  LD A,$FA                ; ...+$FA00 = tile graphic
  ADD A,H                 ;
  LD H,A                  ;
  LD B,$08                ; Copy 8 pixel lines
  LD A,(HL)               ;
  LD (DE),A               ;
  INC HL                  ;
  INC D                   ;
  DJNZ $7651              ;
  POP BC                  ;
  INC IX                  ;
  INC E                   ;
  DJNZ $7636              ;
  LD A,$09                ; Skip the 9 columns right of the view (row stride
  ADD A,E                 ; 32)
  LD E,A                  ;
  DEC C                   ;
  JR NZ,$7634             ;
  LD C,$08                ; Middle third: 8 rows ($59xx / $48xx)
  LD B,$17                ;
  PUSH BC                 ;
  LD L,(IX+$00)           ;
  LD H,$FE                ;
  LD D,$59                ;
  LD A,(HL)               ;
  LD (DE),A               ;
  BIT 7,L                 ;
  JR NZ,$7689             ;
  LD D,$48                ;
  LD H,$00                ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  LD A,$FA                ;
  ADD A,H                 ;
  LD H,A                  ;
  LD B,$08                ;
  LD A,(HL)               ;
  LD (DE),A               ;
  INC HL                  ;
  INC D                   ;
  DJNZ $7683              ;
  POP BC                  ;
  INC IX                  ;
  INC E                   ;
  DJNZ $7668              ;
  LD A,$09                ;
  ADD A,E                 ;
  LD E,A                  ;
  DEC C                   ;
  JR NZ,$7666             ;
  LD C,$06                ; Bottom third: 6 rows ($5Axx / $50xx)
  LD B,$17                ;
  PUSH BC                 ;
  LD L,(IX+$00)           ;
  LD H,$FE                ;
  LD D,$5A                ;
  LD A,(HL)               ;
  LD (DE),A               ;
  BIT 7,L                 ;
  JR NZ,$76BB             ;
  LD D,$50                ;
  LD H,$00                ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  LD A,$FA                ;
  ADD A,H                 ;
  LD H,A                  ;
  LD B,$08                ;
  LD A,(HL)               ;
  LD (DE),A               ;
  INC HL                  ;
  INC D                   ;
  DJNZ $76B5              ;
  POP BC                  ;
  INC IX                  ;
  INC E                   ;
  DJNZ $769A              ;
  LD A,$09                ;
  ADD A,E                 ;
  LD E,A                  ;
  DEC C                   ;
  JR NZ,$7698             ;
  RET                     ;

; Unused
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Zero bytes
  DEFB $00                             ;

; Build the view window from the island maps
;
; Fills the 23x29 tile buffer at $F74E (row stride 23) with the part of the
; world map whose top-left world tile is (X,Y) = (7500, 7502). Everything
; outside an island is sea (code 0). The island table at $F230 has 20-byte
; records ($FF-terminated, 14 islands). Record bytes used here: +0 X high byte
; (sector), +1 Y high byte, +2/+3 X-low range in which the island is visible (=
; +6-22 .. +7+22), +4/+5 Y-low range (= +8-28 .. +9+28), +6/+7 X-low range of a
; fully visible window (map column 0 is world X = +6), +8/+9 the same for Y
; (map row 0 is world Y = +8), +10/+11 address of the island tile map (row
; stride 128 bytes).
;
; The island found is stored in 7552. The clip flags in C are: bit 2 X < +6
; (window overhangs the island's west edge), bit 3 X >= +7 (east edge), bit 4 Y
; < +8 (north edge), bit 5 Y >= +9 (south edge); C (0..40) indexes a table of
; 4-byte JP slots: 78CF for the north view (7504=0) or 7A37 for the south view,
; whose routines copy the visible rectangle (rotated 180 degrees for the south
; view).
;
; Called every main-loop pass (5B3C) and by the death sequence (9257). World
; tile under the helicopter = (X+11, Y+14) = buffer cell (11,14) in both views.
  LD HL,Init              ; Clear 256+256+155 = 667 = 23*29 bytes of the view
  XOR A                   ; buffer
  LD B,A                  ;
  LD (HL),A               ;
  INC HL                  ;
  DJNZ $76D7              ;
  LD (HL),A               ;
  INC HL                  ;
  DJNZ $76DB              ;
  LD B,$9B                ;
  LD (HL),A               ;
  INC HL                  ;
  DJNZ $76E1              ;
  LD IX,$F230             ; IX = first island record
  LD A,($7501)            ; X high byte must match +0
  CP (IX+$00)             ;
  JR NZ,$7717             ;
  LD A,($7503)            ; Y high byte must match +1
  CP (IX+$01)             ;
  JR NZ,$7717             ;
  LD A,($7500)            ; X low byte must be in [+2, +3]
  CP (IX+$02)             ;
  JR C,$7717              ;
  DEC A                   ;
  CP (IX+$03)             ;
  JR NC,$7717             ;
  LD A,($7502)            ; Y low byte must be in [+4, +5]
  CP (IX+$04)             ;
  JR C,$7717              ;
  DEC A                   ;
  CP (IX+$05)             ;
  JR NC,$7717             ;
  JR $7724                ;
  LD BC,$0014             ; Next record (20 bytes)
  ADD IX,BC               ;
  LD A,$FF                ;
  CP (IX+$00)             ; Stop at the $FF terminator: open sea, buffer stays
  JR NZ,$76E9             ; all sea
  RET                     ;
  LD ($7552),IX           ; Remember the current island
  LD BC,$0000             ; C = clip flags
  LD A,($7500)            ; X < +6: bit 2 (west edge in view)
  CP (IX+$06)             ;
  JR NC,$7737             ;
  SET 2,C                 ;
  JR $773E                ;
  CP (IX+$07)             ; X >= +7: bit 3 (east edge in view)
  JR C,$773E              ;
  SET 3,C                 ;
  LD A,($7502)            ; Y < +8: bit 4 (north edge in view)
  CP (IX+$08)             ;
  JR NC,$774A             ;
  SET 4,C                 ;
  JR $7751                ;
  CP (IX+$09)             ; Y >= +9: bit 5 (south edge in view)
  JR C,$7751              ;
  SET 5,C                 ;
  LD A,($7504)            ; South view?
  CP $00                  ;
  JP NZ,$7918             ; Yes: use the south-view jump table
  LD HL,$78CF             ; North view: jump to slot 78CF+C
  ADD HL,BC               ;
  JP (HL)                 ;

; Map address of the window's first row (west edge clipped)
;
; Returns HL = map base (+10/+11) + 128*(Y - (+8)): map address of column 0 of
; the window's first row.
;
; IX Island record
  LD B,(IX+$0B)
  LD C,(IX+$0A)
  LD A,($7502)
  LD L,(IX+$08)
  SUB L
  LD L,A
  LD H,$00
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,BC
  RET

; Map address of the window's first column (north edge clipped)
;
; Returns HL = map base + (X - (+6)): map row 0, window's first column.
;
; IX Island record
  LD H,(IX+$0B)
  LD L,(IX+$0A)
  LD B,$00
  LD A,($7500)
  LD C,(IX+$06)
  SUB C
  LD C,A
  ADD HL,BC
  RET

; Map address of the window origin
;
; Returns HL = map base + 128*(Y - (+8)) + (X - (+6)).
;
; IX Island record
  LD B,(IX+$0B)
  LD C,(IX+$0A)
  LD A,($7502)
  LD L,(IX+$08)
  SUB L
  LD L,A
  LD H,$00
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,BC
  LD B,$00
  LD A,($7500)
  LD C,(IX+$06)
  SUB C
  LD C,A
  ADD HL,BC
  RET

; North view, island fills the window (slot 0)
;
; Copies 29 rows of 23 tiles from the map (window origin) to the buffer.
  CALL $7789
  LD DE,Init
  LD A,$1D
  JR $7803                ; Full-width copy loop (A rows)

; North view, west edge visible (slot 4)
;
; Visible width w = X - (+2) + 1 columns, copied into the rightmost w buffer
; columns, 29 rows, from map column 0.
  LD A,($7500)
  LD C,(IX+$02)
  SUB C
  INC A
  LD ($783E),A            ; Width for the clipped copy loop (operand at 783E)
  LD B,A                  ;
  LD A,$18                ; DE = $F74E + 23 - w
  SUB B                   ;
  LD DE,$F74D             ;
  ADD A,E                 ;
  LD E,A                  ;
  CALL $775E              ;
  LD A,$1D                ;
  JR $783D                ; Clipped copy loop

; North view, east edge visible (slot 8)
;
; Width w = (+3) - X + 1, copied into the leftmost w columns, 29 rows.
  LD A,($7500)
  LD C,A
  LD A,(IX+$03)
  SUB C
  INC A
  LD ($783E),A
  CALL $7789
  LD DE,Init
  LD A,$1D
  JR $783D

; North view, north edge visible (slot 16)
;
; n = Y - (+4) + 1 visible rows go to the bottom n buffer rows, 23 columns
; wide, starting at map row 0.
  CALL $7777
  PUSH HL
  LD A,($7502)            ; n = visible rows
  LD C,(IX+$04)           ;
  SUB C                   ;
  INC A                   ;
  LD B,A                  ;
  LD DE,$0017             ;
  LD HL,$F9E9             ; DE = $F9E9 - 23*n (start of buffer row 29-n)
  ADD A,$00               ;
  SBC HL,DE               ;
  DJNZ $77FB              ;
  EX DE,HL                ;
  POP HL                  ;
; Full-width copy loop: A rows of 23 bytes, map stride 128.
  LD BC,$0017             ; Copy one row of 23 tiles
  LDIR                    ;
  LD BC,$0069             ; Map row stride 128
  ADD HL,BC               ;
  DEC A                   ;
  JR NZ,$7803             ;
  RET                     ;

; North view, north-west corner visible (slot 20)
;
; w = X - (+2) + 1 columns, n = Y - (+4) + 1 rows, copied from map (0,0) to the
; bottom-right corner of the buffer.
  LD A,($7500)
  LD C,(IX+$02)
  SUB C
  INC A
  LD ($783E),A            ; Width (operand of LD BC at 783D)
  LD B,A                  ;
  LD A,$18                ;
  SUB B                   ;
  LD HL,$F9E8             ;
  ADD A,L                 ;
  LD L,A                  ;
  LD A,($7502)            ;
  LD C,(IX+$04)           ;
  SUB C                   ;
  INC A                   ;
  LD B,A                  ;
  LD DE,$0017             ;
  ADD A,$00               ;
  SBC HL,DE               ;
  DJNZ $7830              ;
  EX DE,HL                ;
  LD H,(IX+$0B)           ;
  LD L,(IX+$0A)           ;
; Clipped copy loop: A rows of w bytes (w in the self-modified operand at
; $783E), map stride 128, buffer stride 23.
  LD BC,$0017             ; w (self-modified operand)
  PUSH HL                 ;
  PUSH DE                 ;
  LDIR                    ;
  POP DE                  ;
  POP HL                  ;
  LD BC,$0080             ;
  ADD HL,BC               ;
  LD BC,$0017             ;
  EX DE,HL                ;
  ADD HL,BC               ;
  EX DE,HL                ;
  DEC A                   ;
  JR NZ,$783D             ;
  RET                     ;

; North view, north-east corner visible (slot 24)
;
; w = (+3) - X + 1, n = Y - (+4) + 1; to the bottom-left corner.
  LD A,($7500)
  LD C,A
  LD A,(IX+$03)
  SUB C
  INC A
  LD ($783E),A
  CALL $7777
  PUSH HL
  LD C,(IX+$04)
  LD A,($7502)
  SUB C
  INC A
  LD B,A
  LD DE,$0017
  LD HL,$F9E9
  ADD A,$00
  SBC HL,DE
  DJNZ $7873
  EX DE,HL
  POP HL
  JR $783D

; North view, south edge visible (slot 32)
;
; n = (+5) - Y + 1 rows, full width, to the top of the buffer.
  CALL $7789
  LD A,($7502)
  LD C,A
  LD A,(IX+$05)
  SUB C
  INC A
  LD DE,Init
  JP $7803

; North view, south-west corner visible (slot 36)
;
; w = X - (+2) + 1, n = (+5) - Y + 1; to the top-right corner.
  LD A,($7500)
  LD C,(IX+$02)
  SUB C
  INC A
  LD ($783E),A
  LD B,A
  LD A,$18
  SUB B
  LD DE,$F74D
  ADD A,E
  LD E,A
  CALL $775E
  LD A,($7502)
  LD C,A
  LD A,(IX+$05)
  SUB C
  INC A
  JR $783D

; North view, south-east corner visible (slot 40)
;
; w = (+3) - X + 1, n = (+5) - Y + 1; to the top-left corner.
  LD A,($7500)
  LD C,A
  LD A,(IX+$03)
  SUB C
  INC A
  LD ($783E),A
  CALL $7789
  LD A,($7502)
  LD C,A
  LD A,(IX+$05)
  SUB C
  INC A
  LD DE,Init
  JP $783D

; North-view copy jump table
;
; Entered by JP (HL) at 775D with HL = $78CF + clip flags (0..40). Each slot is
; a 4-byte JP + padding; slots 12, 28 and 44+ cannot occur.
  JP $77AD                ; 0: whole window on the island
  DEFB $00
  JP $77B7                ; 4: west edge
  DEFB $00
  JP $77D2                ; 8: east edge
  DEFB $00,$00,$00,$00,$00
  JP $77E8                ; 16: north edge
  DEFB $00
  JP $7810                ; 20: north-west corner
  DEFB $00
  JP $7854                ; 24: north-east corner
  DEFB $00,$00,$00,$00,$00
  JP $787D                ; 32: south edge
  DEFB $00
  JP $788F                ; 36: south-west corner
  DEFB $00
  JP $78B1                ; 40: south-east corner
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Unused slots
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00         ;

; South-view dispatch
;
; Jumps to slot $7A37 + C (clip flags).
;
; BC Clip flags
  LD HL,$7A37
  ADD HL,BC
  JP (HL)

; South view, island fills the window (slot 0)
;
; Copies the 29x23 window rotated by 180 degrees: map bytes are read forwards
; and written backwards from the last buffer byte $F9E8.
  CALL $7789
  LD DE,$F9E8
  LD A,$1D
  JR $796D

; South view, west edge visible (slot 4)
;
; w = X - (+2) + 1 columns go to the leftmost w buffer columns (reversed), 29
; rows from the bottom up.
  LD A,($7500)
  LD C,(IX+$02)
  SUB C
  INC A
  LD ($79A7),A            ; Width for loop 79A6 (operand at 79A7)
  LD B,A                  ;
  LD DE,$F9D1             ; DE = $F9D1 + w = last buffer row, column w-1
  ADD A,E                 ;
  LD E,A                  ;
  CALL $775E              ;
  LD A,$1D                ;
  JR $79A6                ;

; South view, east edge visible (slot 8)
;
; w = (+3) - X + 1; into the rightmost w columns (reversed).
  LD A,($7500)
  LD C,A
  LD A,(IX+$03)
  SUB C
  INC A
  LD ($79A7),A
  CALL $7789
  LD DE,$F9E8
  LD A,$1D
  JR $79A6

; South view, north edge visible (slot 16)
;
; n = Y - (+4) + 1 rows, full width, into the top n buffer rows (reversed).
  CALL $7777
  PUSH HL
  LD A,($7502)
  LD C,(IX+$04)
  SUB C
  INC A
  LD B,A
  LD DE,$0017
  LD HL,$F74D
  ADD HL,DE
  DJNZ $7968
  EX DE,HL
  POP HL
; Reversed full-width copy loop: A rows of 23 bytes, buffer written backwards.
  LD B,$17
  EX AF,AF'
  LD A,(HL)               ; Copy one map byte, buffer pointer moves left
  LD (DE),A               ;
  DEC DE                  ;
  INC HL                  ;
  DJNZ $7970              ;
  LD BC,$0069             ; Next map row (128 - 23)
  ADD HL,BC               ;
  EX AF,AF'               ;
  DEC A                   ;
  JR NZ,$796D             ;
  RET                     ;

; South view, north-west corner visible (slot 20)
;
; w = X - (+2) + 1, n = Y - (+4) + 1; into the top-left corner (reversed), from
; map (0,0). Falls into the clipped reversed copy loop at 79A6.
  LD A,($7500)
  LD C,(IX+$02)
  SUB C
  INC A
  LD ($79A7),A            ; Width (operand at 79A7)
  LD B,A                  ;
  LD HL,$F736             ;
  ADD A,L                 ;
  LD L,A                  ;
  LD A,($7502)            ;
  LD C,(IX+$04)           ;
  SUB C                   ;
  INC A                   ;
  LD B,A                  ;
  LD DE,$0017             ;
  ADD HL,DE               ;
  DJNZ $799C              ;
  EX DE,HL                ;
  LD H,(IX+$0B)           ;
  LD L,(IX+$0A)           ;
; Reversed clipped copy loop: A rows of w bytes (operand at $79A7); map +128
; per row, buffer -23 per row.
  LD B,$17                ; w (self-modified operand)
  EX AF,AF'               ;
  PUSH HL                 ;
  PUSH DE                 ;
  LD A,(HL)               ;
  LD (DE),A               ;
  DEC DE                  ;
  INC HL                  ;
  DJNZ $79AB              ;
  POP DE                  ;
  POP HL                  ;
  LD BC,$0080             ;
  ADD HL,BC               ;
  LD BC,$FFE9             ;
  EX DE,HL                ;
  ADD HL,BC               ;
  EX DE,HL                ;
  EX AF,AF'               ;
  DEC A                   ;
  JR NZ,$79A6             ;
  RET                     ;

; South view, north-east corner visible (slot 24)
;
; w = (+3) - X + 1, n = Y - (+4) + 1; into the top-right corner (reversed).
  LD A,($7500)
  LD C,A
  LD A,(IX+$03)
  SUB C
  INC A
  LD ($79A7),A
  CALL $7777
  PUSH HL
  LD C,(IX+$04)
  LD A,($7502)
  SUB C
  INC A
  LD B,A
  LD DE,$0017
  LD HL,$F74D
  ADD HL,DE
  DJNZ $79E1
  EX DE,HL
  POP HL
  JR $79A6

; South view, south edge visible (slot 32)
;
; n = (+5) - Y + 1 rows into the bottom rows (reversed).
  CALL $7789
  LD A,($7502)
  LD C,A
  LD A,(IX+$05)
  SUB C
  INC A
  LD DE,$F9E8
  JP $796D

; South view, south-west corner visible (slot 36)
;
; w = X - (+2) + 1, n = (+5) - Y + 1; bottom-left corner (reversed).
  LD A,($7500)
  LD C,(IX+$02)
  SUB C
  INC A
  LD ($79A7),A
  LD B,A
  LD DE,$F9D1
  ADD A,E
  LD E,A
  CALL $775E
  LD A,($7502)
  LD C,A
  LD A,(IX+$05)
  SUB C
  INC A
  JR $79A6

; South view, south-east corner visible (slot 40)
;
; w = (+3) - X + 1, n = (+5) - Y + 1; bottom-right corner (reversed).
  LD A,($7500)
  LD C,A
  LD A,(IX+$03)
  SUB C
  INC A
  LD ($79A7),A
  CALL $7789
  LD A,($7502)
  LD C,A
  LD A,(IX+$05)
  SUB C
  INC A
  LD DE,$F9E8
  JP $79A6

; South-view copy jump table
;
; Entered by JP (HL) at 791C with HL = $7A37 + clip flags. Same layout as 78CF.
  JP $791D                ; 0: whole window
  DEFB $00
  JP $7927                ; 4: west edge
  DEFB $00
  JP $793F                ; 8: east edge
  DEFB $00,$00,$00,$00,$00
  JP $7955                ; 16: north edge
  DEFB $00
  JP $797F                ; 20: north-west corner
  DEFB $00
  JP $79C2                ; 24: north-east corner
  DEFB $00,$00,$00,$00,$00
  JP $79E8                ; 32: south edge
  DEFB $00
  JP $79FA                ; 36: south-west corner
  DEFB $00
  JP $7A19                ; 40: south-east corner
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Unused slots
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00     ;

; Ground-sampling and shadow work buffers
;
; Filled every loop by 7E10 and 7ADC. The 3x3 block of cells under/around the
; helicopter is buffer columns 10-12, rows 13-15 (centre = column 11, row 14 =
; the world tile under the helicopter). All 3x3 lists are column-major, bottom
; row first: index 3*c+k = column 10+c, row 15-k.
  DEFB $00,$00,$00        ; Raw map codes of the 3x3 block (before projection;
  DEFB $00,$00,$00        ; include aircraft tiles $F6-$FE and sea waves).
  DEFB $00,$00,$00        ; $7A85 = tile under the helicopter (crate/survivor
                          ; check F3A3). Read by 8ACA (landing check).
  DEFB $00                ; Unused
  DEFB $00,$00,$00        ; Terrain height level of each cell (0..17, units of
  DEFB $00,$00,$00        ; 4 altitude pixels; see 7AC1); 0 for object tiles
  DEFB $00,$00,$00        ; $17-$26. Read by 8A9B (collision check against
                          ; altitude/4).
  DEFB $00                ; Unused
  DEFB $00,$00,$00        ; Shadow row offset of each cell = level/2 (rows);
  DEFB $00,$00,$00        ; bit 7 = cell's top tile is $18; $FF = shadow cell
  DEFB $00,$00,$00        ; hidden (7B33).
  DEFB $00                ; Unused
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Projected (displayed) tile
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; codes of buffer columns
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; 10, 11, 12, rows 15 up to
                                                   ; 5 (11 per column, bottom
                                                   ; first), copied at the
                                                   ; moment the sprite tiles
                                                   ; are inserted; used for
                                                   ; shadow/body occlusion
                                                   ; (7BB8, 86AF via $7AA2,
                                                   ; F4F4 via $7AAC). Bit 7 may
                                                   ; be set by 7D9C.
  DEFB $00                ; Unused
  DEFB $00                ; Base of the threshold table (never compared)
  DEFB $0F,$10,$2E,$30,$56,$58,$89,$8C,$A5 ; Height thresholds: level = number
  DEFB $B2,$C2,$D0,$D9,$E4,$EC,$F0,$F6,$FF ; of entries <= raw code: <$0F:0,
                                           ; $0F:1, $10-$2D:2, $2E-$2F:3,
                                           ; $30-$55:4, $56-$57:5, $58-$88:6,
                                           ; $89-$8B:7, $8C-$A4:8, $A5-$B1:9,
                                           ; $B2-$C1:10, $C2-$CF:11,
                                           ; $D0-$D8:12, $D9-$E3:13,
                                           ; $E4-$EB:14, $EC-$EF:15,
                                           ; $F0-$F5:16, $F6-$FE:17 (aircraft)
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Unused

; Sample the ground under the helicopter and draw its shadow
;
; Called from 7E10 (7F77) while the sprite tiles are being built, unless the
; helicopter has crashed. 1) Copies the already-projected codes of buffer
; columns 10-12, rows 15..5 to 7A9F. 2) Converts the 9 raw codes at 7A81 into
; terrain levels (7A8B, threshold table 7AC1) and shadow row offsets (7A95). 3)
; Hides shadow cells that would be covered by nearer terrain. 4) Jumps to 7BB8
; to draw the shadow.
;
; Hiding rule (per column, offsets h15, h14, h13 without bit 7): the row-13
; cell is hidden if h13+2 < h15, or h13+1 < h14; the row-14 cell is hidden if
; h14+1 < h15. On equality the bit-7 flags (tile $18) decide.
  LD HL,$F8B1             ; Buffer column 10, row 15
  LD DE,$7A9F             ;
  PUSH DE                 ;
  LD C,$03                ; 3 columns
  LD B,$0B                ; 11 rows each, bottom to top
  POP DE                  ;
  LD A,(HL)               ;
  LD (DE),A               ;
  INC DE                  ;
  PUSH DE                 ;
  LD DE,$FFE9             ; Up one buffer row (-23)
  ADD HL,DE               ;
  DJNZ $7AE7              ;
  LD DE,$00FE             ; Next column, back to row 15 (+11*23+1)
  ADD HL,DE               ;
  DEC C                   ;
  JR NZ,$7AE5             ;
  POP DE                  ;
  LD IX,$7A8B             ; IX = terrain levels, DE = raw codes
  LD DE,$7A81             ;
  LD B,$09                ;
  LD HL,$7AC1             ; Level = number of thresholds <= code
  LD A,(DE)               ;
  LD C,$FF                ;
  INC HL                  ;
  INC C                   ;
  CP (HL)                 ;
  JR NC,$7B09             ;
  LD (IX+$00),C           ; Store the level (0..17)
  SRA C                   ; Shadow row offset = level/2
  LD (IX+$0A),C           ;
  LD L,A                  ; First projected tile of this code (pillar page $63,
  LD H,$63                ; or $6C in south view: operand at 7B18 patched by
  LD A,(HL)               ; 80F9)
  CP $27                  ; Object tiles $17-$26 (trees, buildings, people...)?
  JR NC,$7B2E             ;
  CP $17                  ;
  JR C,$7B2E              ;
  CP $18                  ; Tile $18: flag it in the shadow offset
  JR NZ,$7B2A             ;
  SET 7,(IX+$0A)          ;
  LD (IX+$00),$00         ; Objects have no collision height
  INC IX                  ;
  INC DE                  ;
  DJNZ $7B03              ;
  LD IX,$7A95             ; For each of the 3 columns: rows 15 (C), 14 (D), 13
  LD B,$03                ; (A)
  LD C,(IX+$00)           ;
  RES 7,C                 ;
  LD D,(IX+$01)           ;
  RES 7,D                 ;
  LD A,(IX+$02)           ;
  RES 7,A                 ;
  INC A                   ; Row 13 offset + 2 compared with row 15 offset
  INC A                   ;
  CP C                    ;
  JR C,$7B73              ;
  CP C                    ;
  JR NZ,$7B5E             ;
  LD E,(IX+$00)           ;
  BIT 7,E                 ;
  JR Z,$7B73              ;
  LD E,(IX+$02)           ;
  BIT 7,E                 ;
  JR NZ,$7B73             ;
  DEC A                   ; Row 13 offset + 1 compared with row 14 offset
  CP D                    ;
  JR C,$7B73              ;
  CP D                    ;
  JR NZ,$7B77             ;
  LD E,(IX+$01)           ;
  BIT 7,E                 ;
  JR Z,$7B73              ;
  LD E,(IX+$02)           ;
  BIT 7,E                 ;
  JR Z,$7B77              ;
  LD (IX+$02),$FF         ; Hide the row-13 shadow cell
  LD A,D                  ; Row 14 offset + 1 compared with row 15 offset
  INC A                   ;
  CP C                    ;
  JR C,$7B8D              ;
  CP C                    ;
  JR NZ,$7B91             ;
  LD E,(IX+$00)           ;
  BIT 7,E                 ;
  JR Z,$7B8D              ;
  LD E,(IX+$01)           ;
  BIT 7,E                 ;
  JR Z,$7B91              ;
  LD (IX+$01),$FF         ; Hide the row-14 shadow cell
  INC IX                  ;
  INC IX                  ;
  INC IX                  ;
  DJNZ $7B39              ;
  JP $7BB8                ; Draw the shadow

; Unused
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Zero bytes
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00                 ;

; Draw the helicopter's shadow into the sprite tiles
;
; The shadow sprite (3x3 cells, frame 7507, +8 mod 16 in south view; data at
; $EDB0+72*frame, cell order column-major bottom-up, first byte $FF = empty
; cell) is drawn into the graphics of the sprite tiles $5F-$7F (built by 7E10
; at $FCF8-$FDFF, attributes $FE5F-$FE7F). Each shadow cell (column 10+c, row
; 15-k) is raised by its ground offset h (7A95), i.e. drawn into the sprite
; tile h rows higher, so the shadow lies on the terrain. The tile already
; displayed there (from 7A9F) decides how: < $17 flat ground: the cell is
; replaced by the shadow and its INK set to black; $17-$26 objects: the shadow
; is masked by mask tiles $23-$26 ($FB18-$FB37) and may continue into the tile
; below; $27-$2F: shadow ORed in, INK black; >= $30: not drawn (hidden).
; Offsets >= 8 (aircraft) draw at the base cell with attribute $68.
  LD HL,$7A9F             ; Column list pointer
  LD ($7510),HL           ;
  LD HL,$FD48             ; Graphic of sprite tile $69 (column 10, row 15)
  LD ($7509),HL           ;
  LD HL,$FE69             ; Attribute of sprite tile $69
  LD ($750B),HL           ;
  LD HL,$ED68             ; Shadow frames base ($ED68 + 72*(frame+1))
  LD A,($7507)            ;
  LD B,A                  ;
  LD A,($7504)            ;
  CP $00                  ;
  JR Z,$7BDE              ;
  LD A,$08                ; South view: frame + 8 (mod 16)
  ADD A,B                 ;
  RES 4,A                 ;
  LD B,A                  ;
  INC B                   ;
  LD DE,$0048             ;
  ADD HL,DE               ;
  DJNZ $7BE2              ;
  LD ($750E),HL           ; Shadow cell pointer
  LD DE,$7A95             ; Shadow offsets of the 9 cells
  LD C,$03                ; 3 columns of 3 cells
  LD B,$03                ;
  PUSH BC                 ;
  PUSH DE                 ;
  LD HL,($750E)           ;
  LD A,(HL)               ; Empty shadow cell?
  CP $FF                  ;
  JR Z,$7C3F              ;
  LD A,(DE)               ; Hidden cell?
  CP $FF                  ;
  JR Z,$7C3F              ;
  RES 7,A                 ;
  CP $08                  ; Offset >= 8: plain OR at the base cell
  JP NC,$7C88             ;
  LD HL,($7510)           ; Tile displayed h rows above this cell
  ADD A,L                 ;
  LD L,A                  ;
  LD A,(HL)               ;
  RES 7,A                 ;
  CP $30                  ; >= $30: hidden behind it
  JR NC,$7C3F             ;
  CP $27                  ; $27-$2F: OR the shadow in
  JR NC,$7C93             ;
  CP $17                  ; $17-$26: masked (objects)
  JP NC,$7CBC             ;
  LD A,(DE)               ; Flat ground: attribute of the target tile, INK 0
  LD HL,($750B)           ;
  LD B,A                  ;
  LD A,L                  ;
  SUB B                   ;
  LD L,A                  ;
  LD A,(HL)               ;
  AND $F8                 ;
  LD (HL),A               ;
  LD A,(DE)               ; Target graphic = (7509) - 8*h
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  LD D,$00                ;
  LD E,A                  ;
  LD HL,($7509)           ;
  ADD A,$00               ;
  SBC HL,DE               ;
  EX DE,HL                ;
  LD HL,($750E)           ; Replace the tile graphic by the shadow cell
  LD BC,$0008             ;
  LDIR                    ;
  JR $7C46                ;
  LD HL,($750E)           ; Skip this cell
  LD BC,$0008             ;
  ADD HL,BC               ;
  LD ($750E),HL           ;
  LD HL,($750B)           ; Next cell up: attribute -1, graphic -8, list +1
  DEC HL                  ;
  LD ($750B),HL           ;
  LD HL,($7509)           ;
  LD BC,$FFF8             ;
  ADD HL,BC               ;
  LD ($7509),HL           ;
  LD HL,($7510)           ;
  INC HL                  ;
  LD ($7510),HL           ;
  POP DE                  ;
  INC DE                  ;
  POP BC                  ;
  DJNZ $7BEF              ;
  PUSH BC                 ; Next column: list +8, graphic +$70, attribute +$0E
  LD BC,$0008             ;
  ADD HL,BC               ;
  LD ($7510),HL           ;
  LD HL,($7509)           ;
  LD BC,$0070             ;
  ADD HL,BC               ;
  LD ($7509),HL           ;
  LD HL,($750B)           ;
  LD BC,$000E             ;
  ADD HL,BC               ;
  LD ($750B),HL           ;
  POP BC                  ;
  DEC C                   ;
  JP NZ,$7BED             ;
  RET                     ;
  LD HL,($750B)           ; Offset >= 8: attribute $68 (bright cyan paper,
  LD (HL),$68             ; black ink) at the base cell
  LD DE,($7509)           ;
  JR $7CAE                ;
  LD A,(DE)               ; OR-type tile: attribute INK 0, then OR the shadow
  LD HL,($750B)           ;
  LD B,A                  ;
  LD A,L                  ;
  SUB B                   ;
  LD L,A                  ;
  LD A,(HL)               ;
  AND $F8                 ;
  LD (HL),A               ;
  LD A,(DE)               ;
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  LD E,A                  ;
  LD D,$00                ;
  LD HL,($7509)           ;
  ADD A,$00               ;
  SBC HL,DE               ;
  EX DE,HL                ;
  LD HL,($750E)           ;
  LD B,$08                ;
  LD A,(DE)               ;
  OR (HL)                 ;
  LD (DE),A               ;
  INC HL                  ;
  INC DE                  ;
  DJNZ $7CB3              ;
  JR $7C46                ;
  PUSH HL                 ; Object tiles: choose the mask tile: $FB18 (tile
  LD HL,$FB18             ; $23) for codes $19, $1B, $21; $FB28 (tile $25) for
  LD BC,$0010             ; the others; +8 (tiles $24/$26) when the cell is
  CP $21                  ; flagged (bit 7), except for $21/$22
  JR Z,$7CCD              ;
  CP $22                  ;
  JP NZ,$7D4D             ;
  ADD HL,BC               ;
  LD A,(DE)               ;
  LD B,H                  ;
  LD C,L                  ;
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  LD E,A                  ;
  LD D,$00                ;
  LD HL,($7509)           ;
  ADD A,$00               ;
  SBC HL,DE               ;
  PUSH HL                 ;
  LD H,B                  ;
  LD L,C                  ;
  LD DE,($750E)           ;
  LD IX,$7DE5             ; Mask the shadow cell into the temporary buffer 7DE5
  LD B,$08                ;
  LD A,(DE)               ;
  AND (HL)                ;
  LD (IX+$00),A           ;
  INC HL                  ;
  INC DE                  ;
  INC IX                  ;
  DJNZ $7CEA              ;
  LD ($7512),HL           ; Remember the second mask tile
  LD HL,$7DE5             ;
  POP DE                  ;
  PUSH DE                 ;
  LD B,$08                ; OR it into the target
  LD A,(DE)               ;
  OR (HL)                 ;
  LD (DE),A               ;
  INC HL                  ;
  INC DE                  ;
  DJNZ $7CFF              ;
  POP HL                  ;
  POP DE                  ;
  LD BC,$0008             ;
  DEC DE                  ; Look at the tiles below for the rest of the shadow
  LD A,(DE)               ;
  RES 7,A                 ;
  ADD HL,BC               ;
  CP $1D                  ;
  JP C,$7C3F              ;
  CP $21                  ;
  JR C,$7D20              ;
  CP $5B                  ;
  JR NC,$7D0B             ;
  JP $7C3F                ;
  PUSH HL                 ; Continue the shadow into a trunk/base tile
  LD HL,($7512)           ; ($1D-$20) using the second mask
  LD DE,($750E)           ;
  LD IX,$7DE5             ;
  LD B,$08                ;
  LD A,(DE)               ;
  AND (HL)                ;
  LD (IX+$00),A           ;
  INC HL                  ;
  INC DE                  ;
  INC IX                  ;
  DJNZ $7D2E              ;
  LD ($750E),DE           ;
  POP DE                  ;
  LD HL,$7DE5             ;
  LD B,$08                ;
  LD A,(DE)               ;
  OR (HL)                 ;
  LD (DE),A               ;
  INC HL                  ;
  INC DE                  ;
  DJNZ $7D43              ;
  JP $7C49                ;
  CP $1B                  ; Tiles $17-$1A / $1B-$26
  JR NC,$7DBF             ;
  CP $19                  ;
  JR Z,$7D56              ;
  ADD HL,BC               ;
  LD A,(DE)               ;
  BIT 7,A                 ;
  JR Z,$7D5F              ;
  LD BC,$0008             ;
  ADD HL,BC               ;
  LD B,H                  ;
  LD C,L                  ;
  POP HL                  ;
  BIT 7,(HL)              ;
  JR NZ,$7DD0             ;
  PUSH HL                 ;
  RES 7,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  LD E,A                  ;
  LD D,$00                ;
  LD HL,($7509)           ;
  ADD A,$00               ;
  SBC HL,DE               ;
  PUSH HL                 ;
  LD H,B                  ;
  LD L,C                  ;
  LD DE,($750E)           ;
  LD IX,$7DE5             ;
  LD BC,$0800             ;
  LD A,(DE)               ;
  AND (HL)                ;
  LD (IX+$00),A           ;
  INC HL                  ;
  INC DE                  ;
  INC IX                  ;
  OR C                    ;
  LD C,A                  ;
  DJNZ $7D84              ;
  LD ($750E),DE           ;
  POP DE                  ;
  POP HL                  ;
  XOR A                   ;
  CP C                    ;
  JP Z,$7C49              ;
  SET 7,(HL)              ; Mark the list entry (bit 7) and replace the target
  LD HL,$7DE5             ; graphic by the masked shadow
  LD BC,$0008             ;
  LDIR                    ;
  POP DE                  ;
  PUSH DE                 ;
  LD HL,($750B)           ;
  LD A,(DE)               ;
  RES 7,A                 ;
  LD B,A                  ;
  LD A,L                  ;
  SUB B                   ;
  LD L,A                  ;
  LD (HL),$60             ; Attribute $60 (bright green paper, black ink)...
  LD A,(DE)               ;
  BIT 7,A                 ;
  JP Z,$7C49              ;
  LD (HL),$68             ; ...or $68 (bright cyan) for flagged cells
  JP $7C49                ;
  CP $1B                  ;
  JR Z,$7DC4              ;
  ADD HL,BC               ;
  LD A,(DE)               ;
  BIT 7,A                 ;
  JR Z,$7DCD              ;
  LD BC,$0008             ;
  ADD HL,BC               ;
  POP BC                  ;
  LD B,H                  ;
  LD C,L                  ;
  RES 7,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  LD E,A                  ;
  LD D,$00                ;
  LD HL,($7509)           ;
  ADD A,$00               ;
  SBC HL,DE               ;
  PUSH HL                 ;
  LD H,B                  ;
  LD L,C                  ;
  JP $7D24                ;

; Shadow mask buffer and survivor animation frames
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Temporary masked shadow cell (7BB8)
  DEFB $00                ; Unused
  DEFB $18,$00,$3C,$5A,$18,$24,$24 ; Survivor animation frame A (copied to tile
                                   ; $31 lines 0-6, $FB88, by F34A)
  DEFB $00                ; Unused
  DEFB $18,$42,$3C,$18,$18,$24,$24 ; Survivor animation frame B (tile $31)
  DEFB $00                ; Unused
  DEFB $00,$10,$00,$38,$54,$38,$7C,$28 ; Survivor animation frame C (copied to
                                       ; tile $32, $FB90)
  DEFB $10,$44,$38,$10,$38,$7C,$28,$00 ; Survivor animation frame D (tile $32)
  DEFB $00,$00            ; Unused

; Project the terrain and insert the sprite tiles
;
; Turns the flat map window built by 76D2 into the pseudo-3D view, in place in
; the 23x29 buffer at $F74E. Rows are processed from the top (far) to the
; bottom (near) - a painter's algorithm: each cell of code c becomes a
; 'pillar': pillar tile k (k=0,1,2...) is byte (P+k)*256+c and is written k
; rows above the cell; $FE = transparent (leave what is there), $FF = end of
; pillar. P = $63 in north view and $6C in south view (operands 7E35/7E41
; patched by 80F9). Nearer pillars overwrite farther ones.
;
; Row 0 only gets its base tile. Rows 1-23 get full pillars. After row 15 the
; helicopter sprite tiles are inserted (7F21). Rows 24-28 (below the screen)
; only contribute the parts of tall pillars that reach the visible area: row
; 24+j draws only for codes >= $54, $80, $B2, $D0, $E4 (j=0..4), starting with
; pillar tile 3+j at row 21.
;
; First the 9 raw codes of the 3x3 block under the helicopter are saved in
; 7A81.
  LD HL,$F8B1             ; Buffer column 10, row 15
  LD DE,$7A81             ;
  PUSH DE                 ;
  LD C,$03                ;
  LD B,$03                ;
  POP DE                  ;
  LD A,(HL)               ;
  LD (DE),A               ;
  INC DE                  ;
  PUSH DE                 ;
  LD DE,$FFE9             ; Up one row
  ADD HL,DE               ;
  DJNZ $7E1B              ;
  LD DE,$0046             ; Next column, back to row 15
  ADD HL,DE               ;
  DEC C                   ;
  JR NZ,$7E19             ;
  POP DE                  ;
  LD HL,Init              ; Row 0: base tile only
  LD B,$17                ;
  LD E,(HL)               ;
  LD D,$63                ; Pillar page (operand patched: $63 north / $6C
  LD A,(DE)               ; south)
  LD (HL),A               ;
  INC HL                  ;
  DJNZ $7E33              ;
  LD C,$17                ; Rows 1..23
  LD B,$17                ;
  LD E,(HL)               ;
  LD D,$63                ; Pillar page (operand patched)
  PUSH BC                 ;
  PUSH HL                 ;
  LD BC,$FFE9             ;
  LD A,(DE)               ; Base tile
  LD (HL),A               ; Write pillar tile
  ADD HL,BC               ; Up one row, next pillar level
  INC D                   ;
  LD A,(DE)               ;
  CP $FE                  ; $FE: transparent; $FF: end
  JR C,$7E48              ;
  CP $FE                  ;
  JR Z,$7E49              ;
  POP HL                  ;
  POP BC                  ;
  INC HL                  ;
  DJNZ $7E3F              ;
  LD A,C                  ; Row 15 finished: insert the sprite tiles
  CP $09                  ;
  JP Z,$7F21              ;
  DEC C                   ;
  JR NZ,$7E3D             ;
  LD B,$17                ; Row 24: codes >= $54, pillar page P+3 (operand at
  LD A,(HL)               ; 7E6D), from row 21
  CP $54                  ;
  JR C,$7E85              ;
  PUSH BC                 ;
  PUSH HL                 ;
  LD E,A                  ;
  LD D,$66                ;
  LD BC,$FFBB             ;
  ADD HL,BC               ;
  LD BC,$FFE9             ;
  JR $7E7A                ;
  LD (HL),A               ;
  INC D                   ;
  ADD HL,BC               ;
  LD A,(DE)               ;
  CP $FE                  ;
  JR C,$7E77              ;
  CP $FE                  ;
  JR Z,$7E78              ;
  POP HL                  ;
  POP BC                  ;
  INC HL                  ;
  DJNZ $7E64              ;
  LD B,$17                ; Row 25: codes >= $80, page P+4 (operand 7E93)
  LD A,(HL)               ;
  CP $80                  ;
  JR C,$7EAB              ;
  PUSH BC                 ;
  PUSH HL                 ;
  LD E,A                  ;
  LD D,$67                ;
  LD BC,$FFA4             ;
  ADD HL,BC               ;
  LD BC,$FFE9             ;
  JR $7EA0                ;
  LD (HL),A               ;
  INC D                   ;
  ADD HL,BC               ;
  LD A,(DE)               ;
  CP $FE                  ;
  JR C,$7E9D              ;
  CP $FE                  ;
  JR Z,$7E9E              ;
  POP HL                  ;
  POP BC                  ;
  INC HL                  ;
  DJNZ $7E8A              ;
  LD B,$17                ; Row 26: codes >= $B2, page P+5 (operand 7EB9)
  LD A,(HL)               ;
  CP $B2                  ;
  JR C,$7ED1              ;
  PUSH BC                 ;
  PUSH HL                 ;
  LD E,A                  ;
  LD D,$68                ;
  LD BC,$FF8D             ;
  ADD HL,BC               ;
  LD BC,$FFE9             ;
  JR $7EC6                ;
  LD (HL),A               ;
  INC D                   ;
  ADD HL,BC               ;
  LD A,(DE)               ;
  CP $FE                  ;
  JR C,$7EC3              ;
  CP $FE                  ;
  JR Z,$7EC4              ;
  POP HL                  ;
  POP BC                  ;
  INC HL                  ;
  DJNZ $7EB0              ;
  LD B,$17                ; Row 27: codes >= $D0, page P+6 (operand 7EDF)
  LD A,(HL)               ;
  CP $D0                  ;
  JR C,$7EF7              ;
  PUSH BC                 ;
  PUSH HL                 ;
  LD E,A                  ;
  LD D,$69                ;
  LD BC,$FF76             ;
  ADD HL,BC               ;
  LD BC,$FFE9             ;
  JR $7EEC                ;
  LD (HL),A               ;
  INC D                   ;
  ADD HL,BC               ;
  LD A,(DE)               ;
  CP $FE                  ;
  JR C,$7EE9              ;
  CP $FE                  ;
  JR Z,$7EEA              ;
  POP HL                  ;
  POP BC                  ;
  INC HL                  ;
  DJNZ $7ED6              ;
  LD B,$17                ; Row 28: codes >= $E4, page P+7 (operand 7F05)
  LD A,(HL)               ;
  CP $E4                  ;
  JR C,$7F1D              ;
  PUSH BC                 ;
  PUSH HL                 ;
  LD E,A                  ;
  LD D,$6A                ;
  LD BC,$FF5F             ;
  ADD HL,BC               ;
  LD BC,$FFE9             ;
  JR $7F12                ;
  LD (HL),A               ;
  INC D                   ;
  ADD HL,BC               ;
  LD A,(DE)               ;
  CP $FE                  ;
  JR C,$7F0F              ;
  CP $FE                  ;
  JR Z,$7F10              ;
  POP HL                  ;
  POP BC                  ;
  INC HL                  ;
  DJNZ $7EFC              ;
  RET                     ;
  DEC C                   ; Insert sprite tiles: account for this row
  PUSH BC                 ;
  PUSH HL                 ;
  LD HL,$FCF8             ; Destination: graphic of tile $5F ($FA00+8*$5F)
  LD ($7509),HL           ;
  LD HL,$FE5F             ; Destination: attribute of tile $5F
  LD ($750B),HL           ;
  LD HL,$F7CB             ; Buffer column 10, row 5
  LD C,$03                ; 3 columns x 11 rows (rows 5-15), top to bottom
  LD B,$0B                ;
  PUSH BC                 ;
  PUSH HL                 ;
  LD DE,($750B)           ;
  LD C,(HL)               ; Copy the cell's attribute
  LD B,$FE                ;
  LD A,(BC)               ;
  LD (DE),A               ;
  INC DE                  ;
  LD ($750B),DE           ;
  LD HL,$FA00             ; Copy the cell's graphic (tile 0's for solid tiles
  BIT 7,C                 ; >= $80)
  JR NZ,$7F56             ;
  LD E,C                  ;
  LD D,$00                ;
  EX DE,HL                ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,DE               ;
  LD DE,($7509)           ;
  LD BC,$0008             ;
  LDIR                    ;
  LD ($7509),DE           ;
  POP HL                  ;
  LD BC,$0017             ; Next row (+23)
  ADD HL,BC               ;
  POP BC                  ;
  DJNZ $7F37              ;
  LD DE,$FF04             ; Next column, back to row 5
  ADD HL,DE               ;
  DEC C                   ;
  JR NZ,$7F35             ;
  LD A,($7505)            ; Draw the shadow unless crashed
  CP $01                  ;
  CALL NZ,$7ADC           ;
  NOP                     ; Three NOPs (patched-out code)
  NOP                     ;
  NOP                     ;
  LD DE,$F7CB             ; Replace the 33 cells by the sprite tile codes 7F98
  LD HL,$7F98             ;
  LD A,$0B                ;
  LD BC,$0003             ;
  LDIR                    ;
  EX DE,HL                ;
  LD BC,$0014             ;
  ADD HL,BC               ;
  EX DE,HL                ;
  DEC A                   ;
  JR NZ,$7F85             ;
  POP HL                  ;
  POP BC                  ;
  JP $7E3D                ; Continue with row 16

; Sprite tile codes
;
; Codes written into buffer columns 10-12, rows 5-15 (3 per row). Tile
; $5F+r+11*c is column 10+c, row 5+r, so each column's graphics form a
; contiguous 88-line strip ($FCF8, $FD50, $FDA8) into which the shadow (7BB8)
; and the helicopter body (86AF) are drawn at pixel precision.
  DEFB $5F,$6A,$75
  DEFB $60,$6B,$76
  DEFB $61,$6C,$77
  DEFB $62,$6D,$78
  DEFB $63,$6E,$79
  DEFB $64,$6F,$7A
  DEFB $65,$70,$7B
  DEFB $66,$71,$7C
  DEFB $67,$72,$7D
  DEFB $68,$73,$7E
  DEFB $69,$74,$7F
  DEFB $FF                ; End marker (not used)
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Unused
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00                     ;

; Control method
;
; Set by the menu (E2BA: key - '2'): 0 = keyboard, 1 = Interface 2 (port $EFFE,
; keys 6-0), 2 = Kempston (port $1F), 3 = Protek/AGF (cursor keys 5-8 and 0).
; Read by 7FD6 to choose the input routine and by E299.
  DEFB $00

; Read the selected control device into the input bitmap 7522
;
; Called once per main-loop iteration (5B8C). Reads the device chosen on the
; main menu (7FD5 = menu key - "2": 0 keyboard, 1 Sinclair Interface 2, 2
; Kempston, 3 Protek/AGF cursor) and stores a 5-bit control word in 7522: bit 0
; = forward thrust, bit 1 = descend, bit 2 = climb, bit 3 = turn right
; (clockwise), bit 4 = turn left. The cyclone code at 7378 may later OR random
; bits into 7522 (wind buffeting).
;
; I:(7FD5) control method 0-3
; O:(7522) control bits (0 fwd, 1 down, 2 up, 3 right, 4 left)
;
; Keyboard (7FD5=0). Any key in a half-row counts, so the documented keys X / 1
; / Q are really whole half-rows.
  LD A,($7FD5)            ; Dispatch on the control method
  CP $01                  ;
  JP Z,$8023              ;
  CP $02                  ;
  JP Z,$8052              ;
  CP $03                  ;
  JP Z,$8079              ;
  LD B,$00                ; B accumulates the control bits
  LD A,$FE                ; Half-row SHIFT/Z/X/C/V: any key = forward (bit 0)
  IN A,($FE)              ;
  OR $E0                  ;
  CP $FF                  ;
  JR Z,$7FF6              ;
  SET 0,B                 ;
  LD A,$F7                ; Half-row 1-5: any key = climb (bit 2)
  IN A,($FE)              ;
  OR $E0                  ;
  CP $FF                  ;
  JR Z,$8002              ;
  SET 2,B                 ;
  LD A,$FB                ; Half-row Q-T: any key = descend (bit 1)
  IN A,($FE)              ;
  OR $E0                  ;
  CP $FF                  ;
  JR Z,$800E              ;
  SET 1,B                 ;
  LD A,$DF                ; Half-row P/O/I/U/Y: P = turn right (bit 3), O =
  IN A,($FE)              ; turn left (bit 4)
  BIT 0,A                 ;
  JR NZ,$8018             ;
  SET 3,B                 ;
  BIT 1,A                 ;
  JR NZ,$801E             ;
  SET 4,B                 ;
  LD A,B                  ; Store the control word
  LD ($7522),A            ;
  RET                     ;
; Sinclair Interface 2 (7FD5=1): both joystick ports are read and merged.
  LD A,$EF                ; Keys 0,9,8,7,6 (port 2: fire, up, down, right,
  IN A,($FE)              ; left) map directly onto bits 0-4
  OR $E0                  ;
  CPL                     ;
  LD B,A                  ;
  LD A,$F7                ; Keys 1-5 (port 1): 5 fire -> bit 0
  IN A,($FE)              ;
  BIT 4,A                 ;
  JR NZ,$8035             ;
  SET 0,B                 ;
  BIT 3,A                 ; 4 (up) -> bit 1 (descend)
  JR NZ,$803B             ;
  SET 1,B                 ;
  BIT 2,A                 ; 3 (down) -> bit 2 (climb)
  JR NZ,$8041             ;
  SET 2,B                 ;
  BIT 1,A                 ; 2 (right) -> bit 3
  JR NZ,$8047             ;
  SET 3,B                 ;
  BIT 0,A                 ; 1 (left) -> bit 4
  JR NZ,$804D             ;
  SET 4,B                 ;
  LD A,B                  ;
  LD ($7522),A            ;
  RET                     ;
; Kempston (7FD5=2): port 31, active-high bits 0 right, 1 left, 2 down, 3 up, 4
; fire. Joystick forward (up) descends, pulling back climbs, like an aircraft
; stick.
  LD B,$00
  IN A,($1F)              ; Fire -> forward (bit 0)
  BIT 4,A                 ;
  JR Z,$805C              ;
  SET 0,B                 ;
  BIT 3,A                 ; Up -> descend (bit 1)
  JR Z,$8062              ;
  SET 1,B                 ;
  BIT 2,A                 ; Down -> climb (bit 2)
  JR Z,$8068              ;
  SET 2,B                 ;
  BIT 0,A                 ; Right -> bit 3
  JR Z,$806E              ;
  SET 3,B                 ;
  BIT 1,A                 ; Left -> bit 4
  JR Z,$8074              ;
  SET 4,B                 ;
  LD A,B                  ;
  LD ($7522),A            ;
  RET                     ;
; Protek/AGF cursor joystick (7FD5=3): 5 left, 6 down, 7 up, 8 right, 0 fire.
  LD B,$00
  LD A,$F7                ; Key 5 -> left (bit 4)
  IN A,($FE)              ;
  BIT 4,A                 ;
  JR NZ,$8085             ;
  SET 4,B                 ;
  LD A,$EF                ; Half-row 0-6: 6 -> climb (bit 2)
  IN A,($FE)              ;
  BIT 4,A                 ;
  JR NZ,$808F             ;
  SET 2,B                 ;
  BIT 3,A                 ; 7 -> descend (bit 1)
  JR NZ,$8095             ;
  SET 1,B                 ;
  BIT 2,A                 ; 8 -> right (bit 3)
  JR NZ,$809B             ;
  SET 3,B                 ;
  BIT 0,A                 ; 0 -> forward (bit 0)
  JR NZ,$80A1             ;
  SET 0,B                 ;
  LD A,B                  ;
  LD ($7522),A            ;
  RET                     ;

; Unused
  DEFB $00,$00,$00,$00

; Check the M (map) and N (view) keys, then process the flight controls
;
; Called once per main-loop iteration (5BAC) except when the helicopter is
; landed away from the base with an empty tank. Reads half-row SPACE/SYM/M/N/B
; once. M toggles between the island view and the map; N toggles the view
; direction NORTH/SOUTH. Both are edge-triggered through latch bits in 7526 and
; each press beeps. Execution then falls through into the flight-control code
; at 8135.
;
; I:(7526) key latches / mode flags: bit0 M held, bit1 map mode, bit2 N held,
;          bit3 map just left, bit4 map just entered
; I:(7504) view direction 0=north 1=south
;
; 7526 bit 4 is consumed by the main loop (5B6F: redraw the map); bit 3 is set
; on leaving the map but nothing ever clears or tests it.
  LD HL,$7526             ; HL = mode flags
  LD A,$7F                ; Read half-row SPACE/SYM/M/N/B
  IN A,($FE)              ;
  BIT 2,A                 ; M (bit 2) not pressed: clear the M latch
  JR NZ,$80D8             ;
  BIT 0,(HL)              ; M still held from the previous iteration: ignore
  JR NZ,$80DA             ;
  PUSH AF                 ; Beep: BEEPER HL=$0361, DE=30 (about 489 Hz for 61
  PUSH HL                 ; ms)
  LD HL,$0361             ;
  LD DE,$001E             ;
  CALL $03B5              ;
  POP HL                  ;
  POP AF                  ;
  SET 0,(HL)              ; Set the M latch
  BIT 1,(HL)              ; In map mode?
  JR Z,$80D2              ;
  RES 1,(HL)              ; Yes: leave map mode, set bit 3 ("map just left")
  SET 3,(HL)              ;
  JR $80DA                ;
  SET 1,(HL)              ; No: enter map mode, set bit 4 ("map just entered":
  SET 4,(HL)              ; main loop draws the map)
  JR $80DA                ;
  RES 0,(HL)              ; M released: clear the latch
  BIT 3,A                 ; N (bit 3) not pressed: clear the N latch
  JR NZ,$8133             ;
  BIT 2,(HL)              ; N still held: ignore
  JR NZ,$8135             ;
  SET 2,(HL)              ; Set the N latch
  LD A,$7F                ; Blank the VIEW box (attribute $7F white on white)
  CALL $8582              ; while beeping
  LD HL,$0300             ; Beep: BEEPER HL=$0300, DE=40 (about 548 Hz for 73
  LD DE,$0028             ; ms)
  CALL $03B5              ;
  LD A,($7504)            ; Currently facing south? Then switch to north
  CP $00                  ; (80F9), else to south (8104)
  JR Z,$8104              ;

; Set the view direction to NORTH
;
; Also called directly at game start / after a death (5B36), so it then falls
; through into the flight controls once. Sets 7504=0, prints NORTH (attr $38),
; and patches the tile-page high bytes used by the renderer (7B18, 7E35, 7E41,
; 7E6D, 7E93, 7EB9, 7EDF, 7F05) to the north set
; $63,$63,$63,$66,$67,$68,$69,$6A. Entry 8104 does the same for SOUTH: 7504=1,
; attr $78, text SOUTH (827F), pages $6C,$6C,$6C,$6F,$70,$71,$72,$73. Each tile
; code has one byte per height level in page base+0, +1, +2...; the two sets
; hold the tile stacks as seen from the north and from the south.
  XOR A                   ; 7504 = 0 (north)
  LD ($7504),A            ;
  CALL $8580              ; Print NORTH with attribute $38
  LD A,$63                ; North page base = $63
  JR $8113                ;
; This entry point is used by the routine at 80AA.
  LD A,$01                ; 7504 = 1 (south)
  LD ($7504),A            ;
  LD A,$78                ; Print SOUTH (827F) with attribute $78 (bright)
  LD HL,$827F             ;
  CALL $8585              ;
  LD A,$6C                ; South page base = $6C
  LD ($7B18),A            ; Patch the page bases into the renderer: base...
  LD ($7E35),A            ;
  LD ($7E41),A            ;
  ADD A,$03               ; ...base+3...
  LD ($7E6D),A            ;
  INC A                   ; ...base+4 ... base+7
  LD ($7E93),A            ;
  INC A                   ;
  LD ($7EB9),A            ;
  INC A                   ;
  LD ($7EDF),A            ;
  INC A                   ;
  LD ($7F05),A            ;
  JR $8135                ;
; This entry point is used by the routine at 80AA.
  RES 2,(HL)              ; N released: clear the N latch

; Flight controls: turning, thrust/coasting, climbing, descending
;
; Reached by fall-through from 80AA/80F9 once per main-loop iteration. Applies
; the control word 7522 to the helicopter: (1) turning in steps of 2 (=45
; degrees) of the 16-step heading with a 3-iteration turn timer, (2) thrust:
; speed 7527 rises by 1 per iteration up to 7 while forward is held and decays
; by 1 when not, the helicopter moving one map unit along X and/or Y per
; iteration while speed>0 (direction 753B is latched while thrusting, so the
; craft coasts in the old direction after releasing), (3) climb/descent with an
; acceleration of 1,2,3 pixels per iteration, altitude 750D limited to 0..60.
;
; I:(7522) control bits
; I:(7515) 1 = landed (no turning or movement; climb = take off)
; I:(7516) 1 = fuel exhausted (no thrust, no climb, forced descent)
; O:(7500),(7502) map X and Y (16-bit)
; O:(7506) heading 0-15 (always even: 0 N, 2 NE, 4 E, 6 SE, 8 S, 10 SW, 12 W,
;          14 NW)
; O:(7507) heading shown by the sprite (odd during a turn)
; O:(750D) altitude 0-60 pixels
; O:(7514) set to 1 when trying to descend below altitude 0
  LD A,($7522)            ; C = control bits for the rest of the routine
  LD C,A                  ;
  LD HL,$7521             ; Turn timer 7521 running?
  XOR A                   ;
  CP (HL)                 ;
  JR Z,$8152              ;
  DEC (HL)                ; Count it down; when it reaches 1 the turn
  INC A                   ; completes: heading = 7507 = target 7508
  CP (HL)                 ;
  JP NZ,$81AB             ;
  LD A,($7508)            ;
  LD ($7506),A            ;
  LD ($7507),A            ;
  JP $81AB                ;
  LD A,($7515)            ; Landed: skip turning and movement, only the climb
  CP $01                  ; key matters
  JP Z,$81FA              ;
  BIT 4,C                 ; Turn left (bit 4)?
  JR Z,$817A              ;
  LD A,($7506)            ; 7507 = heading-1 (mod 16), the in-between sprite
  DEC A                   ; frame
  CP $FF                  ;
  JR NZ,$8168             ;
  LD A,$0F                ;
  LD ($7507),A            ;
  DEC A                   ; 7508 = heading-2 (mod 16), the target heading
  CP $FF                  ;
  JR NZ,$8172             ;
  LD A,$0F                ;
  LD ($7508),A            ;
  LD A,$03                ; Start the turn timer (3 iterations: the turn
  LD ($7521),A            ; completes 2 iterations later, the next turn can
                          ; start after 3)
  BIT 3,C                 ; Turn right (bit 3)?
  JR Z,$81AB              ;
  LD A,($7506)            ; 7507 = heading+1, 7508 = heading+2 (mod 16)
  INC A                   ;
  CP $10                  ;
  JR NZ,$8187             ;
  XOR A                   ;
  LD ($7507),A            ;
  INC A                   ;
  CP $10                  ;
  JR NZ,$8190             ;
  XOR A                   ;
  LD ($7508),A            ;
  LD A,($7521)            ; Left pressed as well (timer already started)? Then
  CP $00                  ; cancel: no turn, timer 0
  JR Z,$81A6              ;
  LD A,($7506)            ;
  LD ($7507),A            ;
  LD ($7508),A            ;
  XOR A                   ;
  JR $81A8                ;
  LD A,$03                ; Start the turn timer
  LD ($7521),A            ;
  LD A,($7516)            ; Out of fuel: no thrust
  CP $01                  ;
  JR Z,$81B6              ;
  BIT 0,C                 ; Forward (bit 0) held: accelerate
  JR NZ,$81CB             ;
  LD A,($7527)            ; Not thrusting: speed = max(speed-1, 0)
  DEC A                   ;
  CP $FF                  ;
  JR NZ,$81BF             ;
  XOR A                   ;
  LD ($7527),A            ;
  CP $00                  ;
  JR Z,$81FA              ; Stopped: no movement this iteration
  LD A,($753B)            ; Coasting: keep moving in the latched direction
  JR $81DC                ;
  LD A,($7527)            ; Thrusting: speed = min(speed+1, 7)
  CP $07                  ;
  JR Z,$81D6              ;
  INC A                   ;
  LD ($7527),A            ;
  LD A,($7506)            ; Latch the direction of travel = current heading
  LD ($753B),A            ;
  LD HL,$826F             ; Fetch the two movement opcodes for direction A from
  LD D,$00                ; the table at 826F (bytes A and A+1)
  LD E,A                  ;
  ADD HL,DE               ;
  LD A,(HL)               ;
  LD ($81EF),A            ; Patch the X opcode at 81EF...
  INC HL                  ;
  LD A,(HL)               ;
  LD ($81F6),A            ; ...and the Y opcode at 81F6
  LD HL,($7500)           ; X = X + dx (self-modified: NOP / DEC HL / INC HL)
  NOP                     ;
  LD ($7500),HL           ;
  LD HL,($7502)           ; Y = Y + dy (self-modified)
  NOP                     ;
  LD ($7502),HL           ;
  BIT 2,C                 ; Climb key (bit 2)?
  JR Z,$8232              ;
  LD A,($7516)            ; Out of fuel: cannot climb
  CP $01                  ;
  JR Z,$8232              ;
  LD A,($7515)            ; Landed? Then this press is the take-off:
  CP $00                  ;
  JR Z,$8214              ;
  XOR A                   ; clear 7515 (landed) and 752E (on base pad) and
  LD ($7515),A            ; return
  LD ($752E),A            ;
  RET                     ;
  LD A,($751A)            ; Climb rate 751A = min(rate+1, 3)
  CP $03                  ;
  JR Z,$821F              ;
  INC A                   ;
  LD ($751A),A            ;
  LD B,A                  ; Raise the altitude by the climb rate, one pixel at
  LD A,($750D)            ; a time, stopping at 60
  CP $3C                  ;
  JR NC,$8236             ;
  INC A                   ; Raise the altimeter bar by one pixel
  CALL $82D4              ;
  LD ($750D),A            ;
  DJNZ $8223              ;
  JR $8236                ;
  XOR A                   ; Climb key released: climb rate 0
  LD ($751A),A            ;
  LD A,($7515)            ; Landed: no descent
  CP $01                  ;
  RET Z                   ;
  LD A,($7516)            ; Out of fuel: forced descent
  CP $01                  ;
  JR Z,$824C              ;
  BIT 1,C                 ; Descend key (bit 1)?
  JR NZ,$824C             ;
  XOR A                   ; No: descent rate 0
  LD ($751B),A            ;
  RET                     ;
  LD A,($751B)            ; Descent rate 751B = min(rate+1, 3)
  CP $03                  ;
  JR Z,$8257              ;
  INC A                   ;
  LD ($751B),A            ;
  LD B,A                  ; Lower the altitude by the descent rate, one pixel
  LD A,($750D)            ; at a time
  DEC A                   ;
  BIT 7,A                 ; Would go below 0: stop
  JR NZ,$8269             ;
  CALL $82FB              ; Lower the altimeter bar by one pixel
  LD ($750D),A            ;
  DJNZ $825B              ;
  RET                     ;
  LD A,$01                ; 7514 = 1: tried to descend at altitude 0 (8A7A then
  LD ($7514),A            ; decides between landing and crashing)
  RET                     ;

; Movement opcode table
;
; Indexed by the direction of travel d (0-15): byte d is the opcode applied to
; X, byte d+1 the opcode applied to Y ($00 NOP, $23 INC HL, $2B DEC HL). Only
; even d are used (headings are always even), giving N (0,-1), NE (+1,-1), E
; (+1,0), SE (+1,+1), S (0,+1), SW (-1,+1), W (-1,0), NW (-1,-1). For d=15 the
; Y opcode would be the 'S' at 827F (LD D,E, harmless).
  DEFB $00,$2B
  DEFB $23,$2B
  DEFB $23,$00
  DEFB $23,$23
  DEFB $00,$23
  DEFB $2B,$23
  DEFB $2B,$00
  DEFB $2B,$2B

; View direction text
  DEFM "SOUTH"            ; "SOUTH" (printed by 8104)

; Count down the time-left bar (T)
;
; Called once per main-loop iteration (5BD7). Every (828C) iterations ($FF=255
; in round 1, 15 fewer each round) erases one pixel line from the top of the T
; bar (column 30, rows 1-5, 40 lines). When the pointer passes the bottom of
; the bar it becomes $40DE and the main loop (5BCC) jumps to 92C8: "NO TIME",
; game over.
;
; I:(7528) iteration counter
; I:(751C) screen address of the last erased line of the T bar, i.e. the line
;          just above the top lit one ($471E = full)
;
; The comparison operand at 828C is patched by 8372 (reset to $FF on a new
; game) and 83AD (minus 15 on each completed round).
  LD A,($7528)            ; Increment the time sub-counter
  INC A                   ;
  LD ($7528),A            ;
  CP $FF                  ; Not yet (828C) iterations: return (operand
  RET C                   ; self-modified)
  XOR A                   ; Reset the sub-counter
  LD ($7528),A            ;
  LD HL,($751C)           ; Move the pointer one pixel line down (next row of
  INC H                   ; cells when leaving a cell)
  LD A,H                  ;
  CP $48                  ;
  JR NZ,$82A1             ;
  LD H,$40                ;
  LD A,$20                ;
  ADD A,L                 ;
  LD L,A                  ;
  LD (HL),$00             ; Erase that line of the bar
  LD ($751C),HL           ;
  RET                     ;

; Burn fuel (F bar)
;
; Jumped to from 8470 when not on the base pad (and called by 92A9 to drain the
; tank during the death sequence). Every 49 iterations erases one pixel line
; from the top of the F bar (column 28, rows 1-5, 40 lines). After the last
; line, 7516 is set to 1 (tank empty).
;
; I:(7517) fuel sub-counter
; I:(7518) screen address of the last erased line of the F bar, i.e. just above
;          the top lit one ($471C = full, $47BC = empty)
; O:(7516) 1 when the tank runs dry
  LD HL,$7517             ; Sub-counter 0..48
  INC (HL)                ;
  LD A,$30                ;
  CP (HL)                 ;
  RET NC                  ;
  LD (HL),$00             ;
  LD HL,($7518)           ; Move the pointer down one pixel line
  INC H                   ;
  LD A,H                  ;
  CP $48                  ;
  JR NZ,$82CB             ;
  LD A,L                  ; Off the bottom of the bar (row 5)? Then the tank is
  CP $BC                  ; empty
  JR NZ,$82C5             ;
  LD A,$01                ;
  LD ($7516),A            ;
  RET                     ;
  LD H,$40                ; Next character row
  LD A,$20                ;
  ADD A,L                 ;
  LD L,A                  ;
  LD (HL),$00             ; Erase the line
  LD ($7518),HL           ;
  RET                     ;

; Unused
  DEFB $00,$00,$00

; Raise the altimeter bar by one pixel
;
; Moves the altimeter pointer 751E up one pixel line in column 24 and lights it
; ($FF). The bar runs from row 8 upwards (row 8 is lit at altitude 8; altitude
; 60 reaches row 1, line 4). Called by the climb code (8228) and by the landing
; code (8B16) when the altitude is rounded up.
;
; I:(751E) screen address of the top lit line of the A bar
  PUSH AF
  PUSH HL
  LD HL,($751E)           ; Up one pixel line
  DEC H                   ;
  LD A,H                  ;
  CP $47                  ; Crossing from the top line of row 8 into row 7
  JR Z,$82E7              ; (screen third boundary)?
  CP $3F                  ; Crossing a character row inside the top third?
  JR NZ,$82F3             ;
  LD H,$47                ; Previous character row: H=$47, L=L-32
  JR $82E9                ;
  LD H,$4F                ; Third boundary: row 7 line 7 is $47F8
  LD A,$E0                ;
  ADD A,L                 ;
  LD L,A                  ;
  CP $F8                  ;
  JR NZ,$82F3             ;
  LD H,$47                ;
  LD (HL),$FF             ; Light the line
  LD ($751E),HL           ;
  POP HL                  ;
  POP AF                  ;
  RET                     ;

; Lower the altimeter bar by one pixel
;
; Clears the top lit line of the altimeter bar and moves the pointer 751E down
; one line. Quirk: the test at 8307 uses $4F instead of $50, so below altitude
; 2 the pointer skips line 7 of row 8 and continues in row 9 (a stray line can
; then be drawn at $4838 when climbing back from altitude 0).
;
; I:(751E) screen address of the top lit line of the A bar
  PUSH AF
  LD HL,($751E)           ; Erase the current top line
  LD (HL),$00             ;
  INC H                   ; Down one pixel line
  LD A,H                  ;
  CP $48                  ; Leaving the bottom of the top third?
  JR Z,$830F              ;
  CP $4F                  ; Quirk: should be $50
  JR NZ,$831B             ;
  LD H,$48                ;
  JR $8311                ;
  LD H,$40                ; Next character row in the top third: H=$40, L=L+32
  LD A,$20                ;
  ADD A,L                 ;
  LD L,A                  ;
  CP $18                  ; Row 7 -> row 8: H=$48
  JR NZ,$831B             ;
  LD H,$48                ;
  LD ($751E),HL           ;
  POP AF                  ;
  RET                     ;
  NOP                     ;

; Start a round: crate boxes, round bonus, difficulty
;
; Called at 5B26 at the start of every round (new game, or after the 5th crate
; has been delivered to the base). Blanks the five crate boxes (attributes of
; rows 22-23, columns 0-9) and lights them one by one with a beep and a 0.19 s
; pause. On a new game (7554<>5) it resets the time-bar period to 255, sets the
; wind threshold 5B93 to 5 and picks a random cyclone starting corner
; (754B/754C). After a completed round (7554=5) it awards the round bonus,
; resets the crate counter, sets the wind threshold to 6 and shortens the
; time-bar period by 15. Finally clears the lives-lost counter 9245 and redraws
; the HUD.
;
; I:(7554) crates delivered (5 = round complete)
; I:(9245) lives lost this round (0-2)
; O:(5B93) wind threshold (operand of CP at 5B92: 7378 runs while 7550 < it)
; O:(828C) time-bar period in iterations
; O:(754B),(754C) cyclone start position (new game only)
  LD IX,$5AC0             ; Attributes of the five 2x2 crate boxes (rows 22-23,
  XOR A                   ; columns 0-9) = 0: invisible
  LD B,$0A                ;
  LD (IX+$00),A           ;
  LD (IX+$20),A           ;
  INC IX                  ;
  DJNZ $8328              ;
  LD IX,$5AC0             ; Light the boxes one by one (ink 6 yellow)
  LD B,$05                ;
  LD A,$06                ;
  LD (IX+$00),A           ;
  LD (IX+$01),A           ;
  LD (IX+$20),A           ;
  LD (IX+$21),A           ;
  INC IX                  ;
  INC IX                  ;
  PUSH BC                 ;
  PUSH IX                 ;
  LD HL,$03E8             ; Beep: BEEPER HL=$03E8, DE=44 (about 425 Hz for 104
  LD DE,$002C             ; ms)
  CALL $03B5              ;
  POP IX                  ;
  LD C,$C8                ; Delay: 200 x 255 DJNZ loops (about 666,000
  LD B,$FF                ; T-states, 0.19 s)
  DJNZ $835C              ;
  DEC C                   ;
  JR NZ,$835A             ;
  POP BC                  ;
  DJNZ $8338              ;
  LD A,($7554)            ; Round complete (5 crates delivered)?
  CP $05                  ;
  JR Z,$8390              ;
  LD A,$05                ; New game: wind threshold 5
  LD ($5B93),A            ;
  LD A,$FF                ; Time-bar period 255 iterations
  LD ($828C),A            ;
  CALL $8B74              ; Random cyclone corner: 754B = 2 or 20 (bit 0 of L),
  LD A,$02                ; 754C = 2 or 19 (bit 1 of L)
  BIT 0,L                 ;
  JR Z,$8380              ;
  LD A,$14                ;
  LD ($754B),A            ;
  LD A,$02                ;
  BIT 1,L                 ;
  JR Z,$838B              ;
  LD A,$13                ;
  LD ($754C),A            ;
  JR $83B6                ;
  XOR A                   ; Round complete: crates delivered = 0
  LD ($7554),A            ;
  LD A,($9245)            ; B = 250 - 64 * lives lost (mod 256): 250, 186 or
  ADD A,A                 ; 122
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  LD B,A                  ;
  LD A,$FA                ;
  SUB B                   ;
  LD B,A                  ;
  CALL AddScore           ; Add B points; the second call adds whatever B the
  CALL AddScore           ; score printer 6F00 leaves, which is always $66
                          ; (102)
  LD A,$06                ; Wind threshold 6 for every later round
  LD ($5B93),A            ;
  LD A,($828C)            ; Time-bar period 15 iterations shorter
  LD B,$0F                ;
  SUB B                   ;
  LD ($828C),A            ;
  XOR A                   ; Lives lost this round = 0 (all three helicopters
  LD ($9245),A            ; restored)
  CALL $84F4              ; Redraw the HUD
  RET                     ;

; Unused
  DEFB $00,$00,$44,$00

; Interrupt handler: rotor and winch sounds, crash noise
;
; Reached 50 times a second through the IM2 vector (FFFF->F3F3: JP 83C2).
; Silent when 752D=1 (menu, or after the crash sequence starts). When 7505=1
; (helicopter destroyed) jumps to the explosion noise at 5FDC, which returns
; through 842D. Otherwise, unless landed (7515) or out of fuel (7516), plays
; one rotor 'chop': a 4-interrupt cycle of one short high burst (10 cycles,
; half-periods 18 DJNZ loops) and three lower bursts (6 cycles, half-periods
; 36), both half-periods shortened by 2*speed. While 7555 is non-zero (winch
; line moving) a short BEEPER tone (HL=50, DE=8) precedes the chop.
;
; I:(752D) 1 = sound off
; I:(7505) 1 = helicopter destroyed
; I:(7515),(7516) landed / out of fuel: no rotor sound
; I:(7555) winch counter (non-zero = winch sound)
; I:(755D) rotor phase 0-3
; I:(7527) speed 0-7
  DI                      ; Save registers (IX too: the ROM BEEPER uses it)
  PUSH AF                 ;
  PUSH IX                 ;
  PUSH BC                 ;
  PUSH DE                 ;
  PUSH HL                 ;
  LD A,($752D)            ; Sound disabled?
  CP $01                  ;
  JP Z,$842D              ;
  LD A,($7505)            ; Helicopter destroyed: explosion noise (5FDC, ends
  CP $01                  ; with JP 842D)
  JP Z,CrashNoise         ;
  LD A,($7516)            ; Landed or tank empty: silence
  LD HL,$7515             ;
  OR (HL)                 ;
  CP $00                  ;
  JR NZ,$842D             ;
  LD A,($7555)            ; Winch running?
  CP $00                  ;
  JR Z,$83F4              ;
  LD DE,$0008             ; Winch beep: BEEPER HL=$0032, DE=8 (about 5.5 kHz
  LD HL,$0032             ; for 1.5 ms)
  CALL $03B5              ;
  LD A,($755D)            ; Advance the rotor phase
  INC A                   ;
  CP $02                  ;
  JR NC,$8404             ;
  LD C,$0A                ; Phase 0->1: high burst, C=10 cycles, half-periods
  LD E,$12                ; 18/18
  LD D,$12                ;
  JR $840F                ;
  CP $04                  ; Phases 1->2, 2->3, 3->0: low burst, C=6 cycles,
  JR C,$8409              ; half-periods 36/36
  XOR A                   ;
  LD C,$06                ;
  LD D,$24                ;
  LD E,$24                ;
  LD ($755D),A            ;
  LD A,($7527)            ; Both half-periods -= 2 * speed
  ADD A,A                 ;
  LD B,A                  ;
  LD A,D                  ;
  SUB B                   ;
  LD D,A                  ;
  LD A,E                  ;
  SUB B                   ;
  LD E,A                  ;
  LD A,$10                ; Speaker on (border black)
  OUT ($FE),A             ;
  LD B,E                  ;
  DJNZ $8422              ;
  XOR A                   ; Speaker off
  OUT ($FE),A             ;
  LD B,D                  ;
  DJNZ $8428              ;
  DEC C                   ;
  JR NZ,$841D             ;
; This entry point is used by the routine at CrashNoise.
  POP HL                  ; Restore registers and return
  POP DE                  ;
  POP BC                  ;
  POP IX                  ;
  POP AF                  ;
  EI                      ;
  RET                     ;

; Unused
  DEFB $00,$00,$00,$00,$00

; Fill the time-left bar, paying 40 points per line still lit
;
; Called at the start of every round (5B29). Walks the T bar (column 30) from
; row 5 line 7 up to row 1 line 0 (40 pixel lines). A line that is still lit
; from the previous round earns 40 points (6600) and a $FF-pitch beep; an unlit
; line is lit with a $D0-pitch beep. Leaves 751C = $471E (full bar) and resets
; the time sub-counter.
;
; O:(751C) $471E
; O:(7528) 0
  XOR A                   ; Time sub-counter = 0
  LD ($7528),A            ;
  LD HL,$47BE             ; Start at the bottom line of row 5, column 30
  LD A,(HL)               ; Line already lit?
  CP $FF                  ;
  JR Z,$844E              ;
  LD (HL),$FF             ; No: light it and beep with HL=$00D0 (about 1.84
  PUSH HL                 ; kHz)
  LD HL,$00D0             ;
  JR $8455                ;
  PUSH HL                 ; Yes: add 40 points, beep with HL=$00FF (about 1.53
  CALL AddScore40         ; kHz)
  LD HL,$00FF             ;
  LD DE,$0010             ; DE=16 cycles (about 9-10 ms)
  CALL $03B5              ;
  POP HL                  ;
  DEC H                   ; Up one pixel line; previous character row when
  LD A,H                  ; leaving a cell
  CP $3F                  ;
  JR NZ,$8441             ;
  LD H,$47                ;
  LD A,$E0                ;
  ADD A,L                 ;
  LD L,A                  ;
  CP $1E                  ; Stop after row 1
  JR NZ,$8441             ;
  LD ($751C),HL           ;
  RET                     ;

; Fuel: refuel on the base pad, otherwise burn
;
; Called once per main-loop iteration (5BD4). When not on the base helipad
; (752E=0) jumps to 82A7 to burn fuel. On the pad, adds one pixel line to the F
; bar per iteration (with a $D0-pitch beep) until the bar is full (pointer
; reaches row 0, $471C), and clears the empty-tank flag 7516. A full refuel
; from empty takes 40 iterations (about 4 seconds).
;
; I:(752E) 1 = landed on the base helipad
; I:(7518) F-bar pointer
; O:(7516) 0
  LD A,($752E)            ; Not on the pad: burn fuel
  CP $00                  ;
  JP Z,$82A7              ;
  LD A,($7517)            ; Sub-counter (always passes)
  INC A                   ;
  LD ($7517),A            ;
  CP $01                  ;
  RET C                   ;
  XOR A                   ;
  LD ($7517),A            ;
  LD HL,($7518)           ; Bar full (pointer in row 0)?
  LD A,L                  ;
  CP $1C                  ;
  RET Z                   ;
  PUSH HL                 ; Beep: BEEPER HL=$00D0, DE=16
  LD HL,$00D0             ;
  LD DE,$0010             ;
  CALL $03B5              ;
  POP HL                  ;
  LD (HL),$FF             ; Light one line and move the pointer up
  DEC H                   ;
  LD A,H                  ;
  CP $3F                  ;
  JR NZ,$84A6             ;
  LD H,$47                ;
  LD A,$E0                ;
  ADD A,L                 ;
  LD L,A                  ;
  LD ($7518),HL           ;
  XOR A                   ; Tank not empty any more
  LD ($7516),A            ;
  RET                     ;

; Initialise the altimeter bar
;
; Called at the start of a life (5B39). Clears column 24 in rows 1-7, lights
; all eight lines of row 8, and sets the altitude 750D to 8 with the pointer
; 751E = $4818 (top line of row 8).
;
; O:(750D) 8
; O:(751E) $4818
  LD HL,$4038             ; Clear rows 1-7 of column 24
  LD (HL),$00             ;
  INC H                   ;
  LD A,H                  ;
  CP $48                  ;
  JR NZ,$84B1             ;
  LD H,$40                ;
  LD A,$20                ;
  ADD A,L                 ;
  LD L,A                  ;
  CP $18                  ;
  JR NZ,$84B1             ;
  LD HL,$5018             ; Light row 8 of column 24
  LD B,$08                ;
  DEC H                   ;
  LD (HL),$FF             ;
  DJNZ $84C8              ;
  LD ($751E),HL           ;
  LD A,$08                ;
  LD ($750D),A            ;
  RET                     ;

; Clear the screen
;
; Bitmap to 0, all attributes to 7 (white ink on black). Called at game start
; (5B00) and by the menu/info screens (E293, E3B4).
  LD HL,$4000             ; 192 x 32 bitmap bytes
  LD C,$C0                ;
  LD B,$20                ;
  LD (HL),$00             ;
  INC HL                  ;
  DJNZ $84DD              ;
  DEC C                   ;
  JR NZ,$84DB             ;
  LD C,$18                ; 24 x 32 attribute bytes
  LD B,$20                ;
  LD (HL),$07             ;
  INC HL                  ;
  DJNZ $84E9              ;
  DEC C                   ;
  JR NZ,$84E7             ;
  RET                     ;

; Unused
  DEFB $00,$00

; Draw the HUD
;
; Draws the static instrument panel: attributes for columns 24-31 of rows 0-20
; (from 7200, 21 x 8 bytes) and for rows 22-23 (7148, 64 bytes); panel graphics
; for columns 24-31 of rows 0-14 from the tile map 7300 (15 x 8 codes, $FF =
; leave blank; tile n at 7400+8n): A S F T letters, bar scales, compass rose,
; three helicopter (lives) icons; the bottom two rows of text from 6848 (crate
; boxes, WIND FORCE, DANGER); BEWARE / AIRCRAFT (invisible until 91B4 colours
; them); the VIEW label; then falls into 8580 to print NORTH. Called at game
; start (5B06), every round start (83BA) and from E3C5.
  LD DE,$5818             ; Panel attributes, rows 0-20 (21 rows of 8)
  LD HL,$7200             ;
  LD A,$15                ;
  LD BC,$0008             ;
  LDIR                    ;
  EX DE,HL                ;
  LD BC,$0018             ;
  ADD HL,BC               ;
  EX DE,HL                ;
  DEC A                   ;
  JR NZ,$84FC             ;
  LD DE,$5AC0             ; Rows 22-23 attributes
  LD HL,$7148             ;
  LD BC,$0040             ;
  LDIR                    ;
  LD DE,$4018             ; Panel graphics: 15 rows x 8 cells of tile codes
  LD HL,$7300             ; from 7300
  LD C,$0F                ;
  LD B,$08                ;
  LD A,(HL)               ;
  INC HL                  ;
  CP $FF                  ;
  JR Z,$8539              ;
  PUSH HL                 ;
  LD H,$74                ; Tile bitmap at $7400 + 8 x code
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  LD L,A                  ;
  PUSH BC                 ;
  LD B,$08                ;
  PUSH DE                 ;
  LD A,(HL)               ;
  LD (DE),A               ;
  INC D                   ;
  INC HL                  ;
  DJNZ $8530              ;
  POP DE                  ;
  POP BC                  ;
  POP HL                  ;
  INC DE                  ;
  DJNZ $851F              ;
  DEC DE                  ; Next character row (convert to a linear row
  EX DE,HL                ; address, add 25 cells, convert back)
  PUSH BC                 ;
  RR H                    ;
  RR H                    ;
  RR H                    ;
  LD BC,$0019             ;
  ADD HL,BC               ;
  RL H                    ;
  RL H                    ;
  RL H                    ;
  POP BC                  ;
  EX DE,HL                ;
  DEC C                   ;
  JR NZ,$851D             ;
  LD DE,$50C0             ; Rows 22-23 text (64 characters from 6848)
  LD HL,$6848             ;
  LD C,$40                ;
  CALL $859A              ;
  LD DE,$5019             ; "BEWARE" at row 16, column 25
  LD HL,$85B9             ;
  LD C,$06                ;
  CALL $859A              ;
  LD DE,$5038             ; "AIRCRAFT" at row 17, column 24
  LD HL,$85BF             ;
  LD C,$08                ;
  CALL $859A              ;
  LD DE,$48BB             ; VIEW label (glyphs $3C-$40) at row 13, column 27
  LD HL,$85C7             ;
  LD C,$05                ;
  CALL $859A              ;

; Print the view direction box
;
; Entry 8580: NORTH with attribute $38. Entry 8582 (A preset): NORTH with
; attribute A. Entry 8585 (A, HL preset): the 5-character text at HL with
; attribute A. Sets the attributes of rows 13-14, columns 27-31 (the VIEW box)
; to A and prints the text at row 14, column 27, then falls into 859A.
;
; I:A attribute (entries 8582, 8585)
; I:HL text address (entry 8585)
  LD A,$38
; This entry point is used by the routine at 80AA.
  LD HL,$85CC             ; Text NORTH
; This entry point is used by the routine at 80F9.
  LD DE,$48DB             ; Row 14, column 27; 5 characters
  LD C,$05                ;
  LD IX,$59BB             ; Colour rows 13 and 14, columns 27-31
  LD B,$05                ;
  LD (IX+$00),A           ;
  LD (IX+$20),A           ;
  INC IX                  ;
  DJNZ $8590              ;

; Print a string in the main font
;
; Prints C characters from HL at screen address DE (left to right, character
; cells), using the 8x8 font at 6028 (character code n at 6028+8n). Used
; throughout the game, the map (8EC1...) and the menu/info screens.
;
; I:HL string
; I:DE screen address of the first cell
; I:C character count
; O:HL address after the string
  LD A,(HL)
  INC HL
  PUSH HL
  PUSH BC
  LD L,A                  ; Glyph address = $6028 + 8 x code
  LD H,$00                ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  LD BC,$6028             ;
  ADD HL,BC               ;
  LD B,$08                ; Copy 8 pixel lines
  PUSH DE                 ;
  LD A,(HL)               ;
  LD (DE),A               ;
  INC D                   ;
  INC HL                  ;
  DJNZ $85AB              ;
  POP DE                  ;
  POP BC                  ;
  POP HL                  ;
  INC DE                  ;
  DEC C                   ;
  JR NZ,$859A             ;
  RET                     ;

; HUD texts
  DEFM "BEWARE"           ; "BEWARE"
  DEFM "AIRCRAFT"         ; "AIRCRAFT"
  DEFB $3C,$3D,$3E,$3F,$40 ; Glyph codes $3C-$40 of the main font, which hold
                           ; the VIEW label
  DEFM "NORTH"            ; "NORTH"

; Unused
  DEFB $00,$00,$00

; Let foreground slope tiles cover the helicopter
;
; Called once per main-loop iteration (5B57), after the view has been built
; (7E10) and the helicopter drawn (86AF), before the view is copied to the
; screen (762C). Looks at the lower part of the helicopter's 3x11-cell window:
; view-buffer cells F86C + 23*i + j (i = 0-3 = window cells 7-10, j = 0-2 =
; window columns). Where such a cell holds a slope tile in front of the
; helicopter (codes $19-$1C) and the window cell's attribute has ink 0
; (helicopter pixels were drawn there by 86AF), the window cell's bitmap is
; ANDed with a triangular mask (tile $23 for odd codes, $25 for even) and ORed
; with the slope edge (tile $17 blank for $19/$1A, $1B or $1C), its attribute
; set to $60 (bright green paper), and the cell's code replaced by the window
; tile code so the merged picture is displayed. Aircraft tiles $3C-$44 in those
; cells (8689, never seen executed) are ORed in instead.
;
; I:(F86C) view buffer (23 cells per row)
; I:(FCF8) window tile bitmaps (tiles $5F-$7F: 3 columns x 11 cells,
;          column-major, 8 bytes each)
; I:(FE5F) window tile attributes (FE00+code)
  LD HL,$FD30             ; 7509 = bitmap of window tile $66 (column 0, cell 7)
  LD ($7509),HL           ;
  LD HL,$FE66             ; 750B = its attribute
  LD ($750B),HL           ;
  LD HL,$F86C             ; First view-buffer cell to test; 3 columns...
  LD C,$03                ;
  LD A,$66                ; A' = window tile code $66
  LD B,$04                ; ...of 4 cells
  EX AF,AF'               ;
  LD A,(HL)               ; A = view-buffer code
  PUSH HL                 ;
  LD HL,($750B)           ;
  LD DE,($7509)           ;
  CP $1D                  ; Codes $1D and up: only aircraft tiles $3C-$44 are
  JP NC,$8681             ; handled
  CP $19                  ; Codes below $19: nothing to do
  JR C,$864C              ;
  PUSH BC                 ;
  LD B,A                  ;
  LD A,(HL)               ; Slope tile: only where the helicopter has been
  AND $07                 ; drawn (ink 0)
  CP $00                  ;
  JR NZ,$864B             ;
  LD (HL),$60             ; Attribute $60
  INC HL                  ;
  LD ($750B),HL           ;
  LD HL,$FB18             ; Mask: tile $23 (codes $19/$1B) or tile $25 (codes
  LD A,B                  ; $1A/$1C)
  BIT 0,A                 ;
  JR NZ,$8617             ;
  LD BC,$0010             ;
  ADD HL,BC               ;
  LD IX,$FAB8             ; Edge: tile $17 (blank) for $19/$1A...
  CP $1B                  ;
  JR C,$862B              ;
  LD IX,$FAD8             ; ...tile $1B for $1B...
  CP $1B                  ;
  JR Z,$862B              ;
  LD IX,$FAE0             ; ...tile $1C for $1C
  LD BC,$0800             ; 8 lines: window = (window AND mask) OR edge; C = OR
  LD A,(DE)               ; of the results
  AND (HL)                ;
  OR (IX+$00)             ;
  LD (DE),A               ;
  INC IX                  ;
  INC HL                  ;
  INC DE                  ;
  OR C                    ;
  LD C,A                  ;
  DJNZ $862E              ;
  LD ($7509),DE           ;
  LD A,C                  ;
  POP BC                  ;
  POP HL                  ;
  CP $00                  ; Anything left? Then show the window tile in this
  JR Z,$8658              ; view cell
  EX AF,AF'               ;
  LD (HL),A               ;
  JR $8659                ;
  POP BC                  ;
  INC HL                  ; Skip the cell
  LD ($750B),HL           ;
  LD HL,$0008             ;
  ADD HL,DE               ;
  LD ($7509),HL           ;
  POP HL                  ;
  EX AF,AF'               ;
  INC A                   ; Next window tile code; next view-buffer row (+23)
  LD DE,$0017             ;
  ADD HL,DE               ;
  DJNZ $85E9              ;
  PUSH HL                 ; Next window column: skip window cells 0-6
  LD HL,($750B)           ;
  LD DE,$0007             ;
  ADD HL,DE               ;
  LD ($750B),HL           ;
  LD HL,($7509)           ;
  LD DE,$0038             ;
  ADD HL,DE               ;
  LD ($7509),HL           ;
  ADD A,$07               ;
  POP HL                  ;
  LD DE,$FFA5             ; Back 4 rows, one column right (-4*23+1)
  ADD HL,DE               ;
  DEC C                   ;
  JP NZ,$85E7             ;
  RET                     ;
  CP $45                  ; Aircraft tiles $3C-$44
  JR NC,$864C             ;
  CP $3C                  ;
  JR C,$864C              ;
  PUSH BC                 ;
  LD B,A                  ;
  LD A,(HL)               ; Only where the helicopter has been drawn
  AND $07                 ;
  CP $00                  ;
  JR NZ,$864B             ;
  INC HL                  ;
  LD ($750B),HL           ;
  LD L,B                  ; OR the aircraft tile bitmap (FA00+8*code) into the
  LD H,$00                ; window cell
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  LD A,$FA                ;
  ADD A,H                 ;
  LD H,A                  ;
  LD BC,$0801             ;
  LD A,(DE)               ;
  OR (HL)                 ;
  LD (DE),A               ;
  INC HL                  ;
  INC DE                  ;
  DJNZ $86A3              ;
  JR $863C                ;

; Unused
  DEFB $00,$00,$00

; Draw the helicopter sprite into its view window
;
; Called once per main-loop iteration (5B4E; also 9281 during the crash
; sequence). Draws the 24x24 sprite at 6950 (3 columns x 24 lines,
; column-major) into the helicopter window tiles $5F-$7F (3 columns of 11 cells
; = 88 pixel lines each, bitmaps at FCF8). The sprite's top line is at line
; 62-altitude of each 88-line column, so the helicopter rises one pixel per
; altitude unit above its shadow. Each cell-sized piece is drawn either solid
; (copied, rest of the cell cleared) when the cell's background code is below
; $1B and its attribute ink is non-zero (e.g. white wave dots on the sea), or
; ORed with a one-pixel 'cut' under every sprite pixel; the cell's ink is then
; set to 0 (black). Empty pieces leave the cell untouched.
;
; I:(750D) altitude
; I:(6950) helicopter sprite (built by 8CA0)
; I:(7AA2) per-cell background codes of the window (from the renderer)
;
; Variables: 7509/7529 = pointer into the background-code table (7AA2+C,
; stepping down per piece, +11 per column), 750B/752B = window attribute
; pointer (FE66-C, +11 per column), 7512 = column counter 0-2, where C =
; (altitude+1)>>3.
  XOR A                   ; Column counter = 0
  LD ($7512),A            ;
  LD A,($750D)            ; C = (altitude+1)>>3: number of cells the sprite is
  INC A                   ; lifted
  LD HL,$FE66             ; Attribute pointer = FE66 - C (window cell 7 - C of
  SRA A                   ; column 0)
  SRA A                   ;
  SRA A                   ;
  LD C,A                  ;
  LD B,$00                ;
  ADD A,$00               ;
  SBC HL,BC               ;
  LD ($750B),HL           ;
  LD ($752B),HL           ;
  LD HL,$7AA2             ; Background-code pointer = 7AA2 + C
  ADD HL,BC               ;
  LD ($7509),HL           ;
  LD ($7529),HL           ;
  LD A,($750D)            ; DE = window bitmap FD36 - altitude (column 0, line
  LD C,A                  ; 62-altitude)
  LD B,$00                ;
  LD HL,$FD36             ;
  ADD A,$00               ;
  SBC HL,BC               ;
  EX DE,HL                ;
  LD HL,$6950             ; HL = sprite; C = 24 lines per column
  LD C,$18                ;
; This entry point is used by the routine at Winch.
  PUSH HL                 ; Count in B the lines up to the next cell boundary,
  PUSH DE                 ; ORing the sprite bytes to see whether the piece is
  XOR A                   ; empty
  PUSH AF                 ;
  LD B,$00                ;
  INC B                   ;
  POP AF                  ;
  OR (HL)                 ;
  PUSH AF                 ;
  INC HL                  ;
  INC DE                  ;
  DEC C                   ;
  JR Z,$8700              ;
  LD A,E                  ;
  AND $07                 ;
  CP $00                  ;
  JR NZ,$86F0             ;
  LD HL,($7529)           ; Empty piece: skip it (8741)
  POP AF                  ;
  CP $00                  ;
  JP Z,$8741              ;
  LD A,(HL)               ; Background code (bit 7 ignored)
  RES 7,A                 ;
  DEC HL                  ;
  LD ($7529),HL           ;
  CP $1B                  ; Code $1B or more: OR-draw
  JR NC,$8770             ;
  LD HL,($752B)           ; Attribute ink 0: OR-draw
  LD A,(HL)               ;
  AND $07                 ;
  CP $00                  ;
  JR Z,$8770              ;
  POP DE                  ; Solid draw: whole cell?
  POP HL                  ;
  LD A,B                  ;
  CP $08                  ;
  JR Z,$8739              ;
  LD A,C                  ; Last piece (C=0): copy, then clear the rest of the
  CP $00                  ; cell (875A)
  JR Z,$875A              ;
  LD A,E                  ; First piece: clear the cell from its first line,
  AND $F8                 ; then copy
  LD E,A                  ;
  LD A,$08                ;
  SUB B                   ;
  PUSH BC                 ;
  LD B,A                  ;
  XOR A                   ;
  LD (DE),A               ;
  INC DE                  ;
  DJNZ $8734              ;
  POP BC                  ;
  LD A,(HL)               ;
  LD (DE),A               ;
  INC HL                  ;
  INC DE                  ;
  DJNZ $8739              ;
  JR $877E                ;
  DEC HL                  ; Empty piece: advance all pointers
  LD ($7529),HL           ;
  LD HL,($752B)           ;
  INC HL                  ;
  LD ($752B),HL           ;
  POP DE                  ;
  POP HL                  ;
  INC DE                  ;
  INC HL                  ;
  DJNZ $874E              ;
  LD A,C                  ; More lines in this column?
  CP $00                  ;
  JP NZ,$86EA             ;
  JR $878D                ;
  LD A,$08                ; Copy B lines then clear the remaining 8-B lines
  SUB B                   ;
  LD C,A                  ;
  LD A,(HL)               ;
  LD (DE),A               ;
  INC HL                  ;
  INC DE                  ;
  DJNZ $875E              ;
  LD B,C                  ;
  XOR A                   ;
  PUSH DE                 ;
  LD (DE),A               ;
  INC DE                  ;
  DJNZ $8767              ;
  POP DE                  ;
  LD C,$00                ;
  JR $877E                ;
  POP HL                  ; OR-draw: line |= sprite, next line &= NOT sprite
  POP DE                  ;
  LD A,(DE)               ;
  OR (HL)                 ;
  LD (HL),A               ;
  INC HL                  ;
  LD A,(DE)               ;
  CPL                     ;
  AND (HL)                ;
  LD (HL),A               ;
  INC DE                  ;
  DJNZ $8772              ;
  EX DE,HL                ;
  PUSH HL                 ; Ink of this window cell := 0 (black)
  LD HL,($752B)           ;
  LD A,(HL)               ;
  AND $F8                 ;
  LD (HL),A               ;
  INC HL                  ;
  LD ($752B),HL           ;
  POP HL                  ;
  JR $8752                ;
  PUSH HL                 ; Next column: pointers + 11, DE + 64 (88 lines per
  LD HL,($750B)           ; column)
  LD BC,$000B             ;
  ADD HL,BC               ;
  LD ($750B),HL           ;
  LD ($752B),HL           ;
  LD HL,($7509)           ;
  ADD HL,BC               ;
  LD ($7509),HL           ;
  LD ($7529),HL           ;
  EX DE,HL                ;
  LD BC,$0040             ;
  ADD HL,BC               ;
  EX DE,HL                ;
  POP HL                  ;
  LD A,($7512)            ;
  INC A                   ;
  LD ($7512),A            ;
  CP $03                  ;
  JP NZ,$86E8             ;
  RET                     ;

; Unused (leftover LD ($7509),HL)
  DEFB $22,$09,$75

; Update and print the high score
;
; Compares the 7-character score at 661E with the high score at 6627 (ASCII
; digits, leading '.' which sorts below '0'). If the score is higher it is
; copied over the high score. Then prints the high score right-to-left on the H
; line (row 20, ending at column 31) via 6F06. Called at the start of each game
; (5B09, before the score is cleared) and from E3EA.
  LD HL,$661E             ; Compare digit by digit from the left
  LD DE,$6627             ;
  LD B,$07                ;
  PUSH BC                 ;
  LD A,(DE)               ;
  LD B,A                  ;
  INC DE                  ;
  LD A,(HL)               ;
  INC HL                  ;
  CP B                    ;
  JR NZ,$87D2             ;
  POP BC                  ;
  DJNZ $87C4              ;
  JR $87E4                ;
  CP B                    ; First different digit: score lower? Then keep the
  JR NC,$87D8             ; old high score
  POP BC                  ;
  JR $87E4                ;
  POP BC                  ;
  LD HL,$661E             ; Score higher: high score = score
  LD DE,$6627             ;
  LD BC,$0007             ;
  LDIR                    ;
  LD DE,$509F             ; Print the high score at $509F (row 20, column 31)
  LD BC,$662D             ; leftwards from 662D
  JP PrintBackwards       ;

; Unused
  DEFB $00,$00

; Aircraft height level
;
; Current height level (1-7) at which the aircraft sprite tiles are placed in
; the tile-stack pages; 89CA moves it one step per drawn frame towards the
; helicopter's level 7533. Initial value 1.
  DEFB $01

; Aircraft: move, steer by schedule, warn, place in view
;
; Called once per main-loop iteration (5B3F). (1) Every 28 iterations advances
; the schedule pointer 8A69 by 20 through 15 records at E740-E858 and applies
; the record to the 19 aircraft of the live table E86C (5 bytes each: direction
; code, X, Y): a byte with bit 7 set also respawns that aircraft at its start
; position (E8CD+5n). (2) Moves every aircraft by its direction code d
; (multiple of 4): the 4 bytes at E700+d are opcodes (NOP/INC BC/DEC BC)
; patched into 8867/8868 (X) and 8871/8872 (Y): 16 directions, 2 units per
; iteration on the main axis. (3) Proximity: |dx|<=22 and |dy|<=25 sets 7530=3
; (BEWARE AIRCRAFT flashes, 91B4). (4) An aircraft within |dx|<=12, |dy|<=15 is
; placed in the view buffer as a 3x3 block of codes $F6-$FE at F71E + (dx+12) +
; 23*(dy+15) (mirrored for the south view); for the first such aircraft the
; sprite for its direction (DDB8+72*(n+1)) is copied to the aircraft tiles
; $3C-$44 (FBE0) and a dithered copy to the shadow tiles $33-$3B (FB98), and
; the tile-stack pages are updated so the shadow sits on the ground and the
; aircraft at height level 87EF.
;
; I:(7500),(7502) helicopter X, Y
; I:(7504) view direction
; I:(7533) helicopter height level
; O:(7530) bit 0 = aircraft near in X, bit 1 = near in X and Y (value 3 =
;          warning)
; O:(7524),(7525) view cell column/row of the aircraft block
; O:(752F) 1 once an aircraft sprite has been set up this iteration
  XOR A                   ; Clear the drawn flag and the warning bits
  LD ($752F),A            ;
  LD ($7530),A            ;
  LD A,($8A6B)            ; Schedule step counter 8A6B (0-27)
  INC A                   ;
  CP $1C                  ;
  JR NZ,$8844             ;
  XOR A                   ; 28th iteration: next schedule record
  LD ($8A6B),A            ;
  LD HL,($8A69)           ;
  LD DE,$0014             ;
  ADD HL,DE               ;
  LD A,H                  ; Past E858? Wrap to E740 (15 records)
  CP $E8                  ;
  JR NZ,$8817             ;
  LD A,L                  ;
  CP $5A                  ;
  JR C,$8817              ;
  LD HL,$E740             ;
  LD ($8A69),HL           ;
  LD C,L                  ; BC = record, HL = live table
  LD B,H                  ;
  LD HL,$E86C             ;
  LD A,(BC)               ; Next byte of the record ($FF = end)
  INC BC                  ;
  CP $FF                  ;
  JR Z,$8847              ;
  BIT 7,A                 ; Bit 7 set: new direction and respawn
  JR Z,$883D              ;
  RES 7,A                 ; Store the direction
  LD (HL),A               ;
  PUSH BC                 ;
  LD BC,$0060             ; Copy the 4-byte start position from 96 bytes
  INC HL                  ; further on
  LD D,H                  ;
  LD E,L                  ;
  ADD HL,BC               ;
  LD BC,$0004             ;
  LDIR                    ;
  EX DE,HL                ;
  POP BC                  ;
  JR $881F                ;
  LD (HL),A               ; Bit 7 clear: just the new direction
  LD DE,$0005             ;
  ADD HL,DE               ;
  JR $881F                ;
  LD ($8A6B),A            ;
  LD HL,$E86C             ; Move every aircraft
  LD A,(HL)               ; Direction code d
  LD E,A                  ;
  LD D,$E7                ; Opcode quartet at E700+d
  EX DE,HL                ;
  LD A,(HL)               ; First two opcodes for X...
  LD ($8867),A            ;
  INC HL                  ;
  LD A,(HL)               ;
  LD ($8868),A            ;
  INC HL                  ;
  LD A,(HL)               ; ...last two for Y
  LD ($8871),A            ;
  INC HL                  ;
  LD A,(HL)               ;
  LD ($8872),A            ;
  EX DE,HL                ;
  INC HL                  ; BC = X
  LD C,(HL)               ;
  INC HL                  ;
  LD B,(HL)               ;
  NOP                     ; X += dx (two self-modified opcodes)
  NOP                     ;
  DEC HL                  ;
  LD (HL),C               ;
  INC HL                  ;
  LD (HL),B               ;
  INC HL                  ;
  LD C,(HL)               ; BC = Y
  INC HL                  ;
  LD B,(HL)               ;
  NOP                     ; Y += dy (two self-modified opcodes)
  NOP                     ;
  DEC HL                  ;
  LD (HL),C               ;
  INC HL                  ;
  LD (HL),B               ;
  INC HL                  ;
  LD A,(HL)               ; Until the $FF terminator
  CP $FF                  ;
  JR NZ,$884B             ;
  LD IX,$E86C             ; Proximity / visibility test for each aircraft
  LD B,$0A                ;
  LD L,(IX+$01)           ; HL = aircraft X - helicopter X + 22
  LD H,(IX+$02)           ;
  LD DE,($7500)           ;
  ADD A,$00               ;
  SBC HL,DE               ;
  LD DE,$0016             ;
  ADD HL,DE               ;
  XOR A                   ;
  CP H                    ; Outside 0..44: not near
  JR NZ,$88D0             ;
  LD A,L                  ;
  CP $2D                  ;
  JR NC,$88D0             ;
  LD HL,$7530             ; Near in X: set bit 0
  SET 0,(HL)              ;
  SUB B                   ; X inside the view window (dx = -12..12)? 7524 =
  CP $19                  ; dx+12
  JR NC,$88DD             ;
  LD ($7524),A            ;
  LD L,(IX+$03)           ; HL = aircraft Y - helicopter Y + 25
  LD H,(IX+$04)           ;
  LD DE,($7502)           ;
  ADD A,$00               ;
  SBC HL,DE               ;
  LD DE,$0019             ;
  ADD HL,DE               ;
  XOR A                   ; Outside 0..50: not near
  CP H                    ;
  JR NZ,$88D0             ;
  LD A,L                  ;
  CP $33                  ;
  JR NC,$88D0             ;
  LD HL,$7530             ; Near in X and Y: set bit 1
  SET 1,(HL)              ;
  SUB B                   ; Y inside the view window (dy = -15..15)? Place it
  CP $1F                  ; (88FF)
  JR C,$88FF              ;
  LD DE,$0005             ; Next aircraft
  ADD IX,DE               ;
  LD A,(IX+$00)           ;
  CP $FF                  ;
  JR NZ,$8881             ;
  RET                     ;
  LD L,(IX+$03)           ; X near but outside the window: Y nearness test only
  LD H,(IX+$04)           ;
  LD DE,($7502)           ;
  ADD A,$00               ;
  SBC HL,DE               ;
  LD DE,$0019             ;
  ADD HL,DE               ;
  XOR A                   ;
  CP H                    ;
  JR NZ,$88D0             ;
  LD A,L                  ;
  CP $33                  ;
  JR NC,$88D0             ;
  LD HL,$7530             ;
  SET 1,(HL)              ;
  JR $88D0                ;
  LD ($7525),A            ; 7525 = dy+15
  LD B,A                  ;
  LD A,($7504)            ; Facing south: mirror (7525 = 30-7525, 7524 =
  CP $00                  ; 24-7524)
  JR Z,$891D              ;
  LD A,$1E                ;
  SUB B                   ;
  LD ($7525),A            ;
  LD B,A                  ;
  LD A,($7524)            ;
  LD C,A                  ;
  LD A,$18                ;
  SUB C                   ;
  LD ($7524),A            ;
  JR $8920                ;
  LD A,($7524)            ;
  LD L,A                  ; HL = F71E + 7524 + 23*7525
  LD H,$00                ;
  INC B                   ;
  LD DE,$0017             ;
  JR $892A                ;
  ADD HL,DE               ;
  DJNZ $8929              ;
  LD DE,$F71E             ;
  ADD HL,DE               ;
  LD A,($7525)            ; Bottom row (7525=30): only the top row of the block
  CP $1E                  ;
  JR C,$894C              ;
  LD A,($7524)            ;
  CP $02                  ;
  JR C,$8940              ;
  LD (HL),$F6             ;
  INC HL                  ;
  CP $00                  ;
  JR Z,$8947              ;
  LD (HL),$F9             ;
  INC HL                  ;
  LD (HL),$FC             ;
  JR $8984                ;
  LD DE,$0017             ; Full 3x3 block; columns clipped to 7524+c = 2..24
  LD C,L                  ;
  LD B,H                  ;
  LD A,($7524)            ;
  CP $02                  ;
  JR C,$8962              ;
  LD (HL),$F6             ; Column 0: codes F6, F7, F8 downwards
  ADD HL,DE               ;
  LD (HL),$F7             ;
  ADD HL,DE               ;
  LD (HL),$F8             ;
  LD L,C                  ;
  LD H,B                  ;
  INC HL                  ;
  LD C,L                  ;
  LD B,H                  ;
  CP $00                  ;
  JR Z,$8977              ;
  CP $18                  ;
  JR Z,$8977              ;
  LD (HL),$F9             ; Column 1: F9, FA, FB
  ADD HL,DE               ;
  LD (HL),$FA             ;
  ADD HL,DE               ;
  LD (HL),$FB             ;
  LD L,C                  ;
  LD H,B                  ;
  CP $17                  ;
  JR NC,$8984             ;
  INC HL                  ; Column 2: FC, FD, FE
  LD (HL),$FC             ;
  ADD HL,DE               ;
  LD (HL),$FD             ;
  ADD HL,DE               ;
  LD (HL),$FE             ;
  LD HL,$752F             ; Sprite already set up this iteration? (Then later
  XOR A                   ; aircraft re-use it)
  CP (HL)                 ;
  JP NZ,$88D0             ;
  INC (HL)                ;
  LD A,(IX+$00)           ; B = direction code / 4 = sprite number 0-15
  SRA A                   ;
  SRA A                   ;
  LD B,A                  ;
  LD HL,$DDB8             ;
  LD A,($7504)            ;
  CP $00                  ;
  JR Z,$89A5              ;
  LD A,$08                ; Facing south: sprite (n+8) mod 16
  ADD A,B                 ;
  RES 4,A                 ;
  LD B,A                  ;
  INC B                   ; Sprite address DDB8 + 72*(n+1)
  LD DE,$0048             ;
  ADD HL,DE               ;
  DJNZ $89A9              ;
  LD DE,$FBE0             ; Copy it to the aircraft tiles $3C-$44 (FBE0)
  LD BC,$0048             ;
  LDIR                    ;
  LD HL,$FBE0             ; Dithered copy (AND $AA/$55) to the shadow tiles
  LD DE,$FB98             ; $33-$3B (FB98)
  LD B,$24                ;
  LD A,$AA                ;
  AND (HL)                ;
  LD (DE),A               ;
  INC HL                  ;
  INC DE                  ;
  LD A,$55                ;
  AND (HL)                ;
  LD (DE),A               ;
  INC HL                  ;
  INC DE                  ;
  DJNZ $89BC              ;
  LD A,($7533)            ; Step the aircraft level 87EF one towards the
  LD B,A                  ; helicopter level 7533
  LD A,($87EF)            ;
  CP B                    ;
  JR Z,$8A20              ;
  CP B                    ;
  JR C,$89D9              ;
  DEC A                   ;
  DEC A                   ;
  INC A                   ;
  LD ($87EF),A            ;
  LD DE,$6DF6             ; Rewrite the tile stacks of codes F6-FE in both page
  LD HL,$64F6             ; sets ($64.. north, $6D.. south): level L-1 = $FE
  LD C,$01                ; (empty, continue), level L = tiles $3C-$44, level
                          ; L+1 = $FF (end)
  CP C                    ; Level 1: tiles at page +1, end at +2
  JR Z,$8A02              ;
  INC C                   ;
  CP C                    ;
  JR Z,$89F2              ;
  INC C                   ;
  INC H                   ;
  INC D                   ;
  CP C                    ;
  JR NZ,$89EC             ;
  LD B,$09                ; Level >= 2: empty marker $FE at page L-1
  LD A,$FE                ;
  LD (HL),A               ;
  INC HL                  ;
  LD (DE),A               ;
  INC DE                  ;
  DJNZ $89F6              ;
  INC D                   ;
  LD E,$F6                ;
  INC H                   ;
  LD L,$F6                ;
  LD B,$09                ; Aircraft tiles $3C-$44
  LD A,$3C                ;
  LD (HL),A               ;
  INC HL                  ;
  LD (DE),A               ;
  INC DE                  ;
  INC A                   ;
  DJNZ $8A06              ;
  INC D                   ;
  LD E,$F6                ;
  INC H                   ;
  LD L,$F6                ;
  LD B,$09                ; End marker $FF
  LD A,$FF                ;
  LD (HL),A               ;
  INC HL                  ;
  LD (DE),A               ;
  INC DE                  ;
  DJNZ $8A17              ;
  LD A,($87EF)            ; Level 2: the shadow row 0 overlaps aircraft row 2;
  CP $01                  ; level 1: shadow rows 0-1 overlap aircraft rows 1-2
  JR Z,$8A49              ;
  CP $02                  ;
  JP NZ,$88D0             ;
  LD HL,$FB98             ; Level 2: OR shadow row 0 into aircraft row 2 of
  LD DE,$FBF0             ; each column
  LD A,$03                ;
  EX AF,AF'               ;
  LD B,$08                ;
  LD A,(DE)               ;
  OR (HL)                 ;
  LD (DE),A               ;
  INC HL                  ;
  INC DE                  ;
  DJNZ $8A34              ;
  LD BC,$0010             ;
  ADD HL,BC               ;
  EX DE,HL                ;
  ADD HL,BC               ;
  EX DE,HL                ;
  EX AF,AF'               ;
  DEC A                   ;
  JR NZ,$8A31             ;
  JP $88D0                ;
  LD HL,$FB98             ; Level 1: OR shadow rows 0-1 into aircraft rows 1-2
  LD DE,$FBE8             ;
  LD A,$03                ;
  EX AF,AF'               ;
  LD B,$10                ;
  LD A,(DE)               ;
  OR (HL)                 ;
  LD (DE),A               ;
  INC HL                  ;
  INC DE                  ;
  DJNZ $8A54              ;
  LD BC,$0008             ;
  ADD HL,BC               ;
  EX DE,HL                ;
  ADD HL,BC               ;
  EX DE,HL                ;
  EX AF,AF'               ;
  DEC A                   ;
  JR NZ,$8A51             ;
  JP $88D0                ;

; Aircraft schedule variables and NO TIME message
;
; 8A69 = pointer to the current schedule record (E740-E858, initial E740), 8A6B
; = iteration counter 0-27 within the record, 8A6C-8A6D unused, 8A6E = " NO
; TIME " (printed at 4067 by 92CD).
  DEFW $E740
  DEFB $00
  DEFB $C8,$FE
  DEFM " NO TIME "        ; " NO TIME "

; Unused
  DEFB $09,$1A,$6F

; Landing / terrain-collision check
;
; Called once per main-loop iteration (5B54). Does nothing while landed
; (7515=1). Otherwise (a) every other group of 4 calls updates 7533, the target
; height level (0-7) of the helicopter's own tile column, from the altitude;
; (b) compares altitude/4 with the height class of each of the 9 footprint
; cells (7A8B, filled by 7ADC) and decides between "still flying", "touch-down"
; and "crash". Touch-down then requires every footprint cell's top tile to be
; landable; landing on 9 helipad tiles sets 752E=1. A crash is signalled by
; 7505=1 (main loop then jumps to the death sequence at 9246).
;
; I:(7515) 1 = landed (routine returns at once)
; I:(750D) altitude in pixels (0..60)
; I:(7514) 1 = helicopter tried to descend below altitude 0 (set by 8269)
; I:(751B) descent speed 0..3 (pixels per iteration while 'down' held)
; I:(7A81) 9 raw terrain codes under the helicopter (3x3, filled by 7E10)
; I:(7A8B) 9 height classes of those cells, in units of 4 altitude pixels
;          (filled by 7ADC)
;
; Footprint order in 7A81/7A8B: view-buffer cells
; (row15,col10),(14,10),(13,10),(15,11),(14,11),(13,11),(15,12),(14,12),(13,12).
  LD A,($7515)            ; Landed? Then nothing to do.
  CP $01                  ;
  RET Z                   ;
  LD A,($750D)            ; B = altitude/4 (arithmetic shifts)
  SRA A                   ;
  SRA A                   ;
  LD B,A                  ;
  LD HL,$7534             ; 7534 = free-running call counter
  INC (HL)                ;
  BIT 2,(HL)              ; Only when bit 2 of the counter is set (4 calls in
  JR Z,$8A9B              ; every 8)...
  SRA A                   ; ...7533 = min((altitude>>3)+1, 7): helicopter
  INC A                   ; tile-column level that 89CA steps 87EF towards
  CP $08                  ;
  JR NZ,$8A98             ;
  DEC A                   ;
  LD ($7533),A            ;
  LD HL,$7A8B             ; Count in C the footprint cells whose height class
  LD A,B                  ; is <= altitude/4 (clear cells)
  LD BC,$0900             ;
  CP (HL)                 ; altitude/4 < height class? Then this cell is
  JP C,$8B30              ; touching/above the helicopter: go to 8B30
  INC C                   ;
  INC HL                  ;
  DJNZ $8AA2              ;
  LD A,($7514)            ; Flag 7514 set (pressing down at altitude 0)?
  CP $00                  ;
  JR Z,$8AC1              ;
  LD A,C                  ; With 7514 set: anything less than 9 clear cells is
  CP $09                  ; a crash...
  JP NZ,$8B5D             ;
  LD A,($751B)            ; ...and so is a descent speed of 3; otherwise try to
  CP $03                  ; touch down
  JP NC,$8B5D             ;
  JR $8ACA                ;
  LD A,C                  ; 7514 clear: 9 clear cells = still flying, return
  CP $09                  ;
  RET Z                   ;
  CP $00                  ; 0 clear cells = all 9 cells reached: try to touch
  JP NZ,$8B5D             ; down; 1..8 = partly over an obstacle/edge: crash
  LD DE,$7A81             ; Touch-down: examine the top tile of each footprint
  LD BC,$0900             ; cell's tile stack. C counts helipad tiles.
  LD A,(DE)               ; L = raw terrain code; the stack for code L is the
  LD L,A                  ; bytes at $6300+L, $6400+L, ... terminated by $FF
  LD H,$63                ;
  LD A,$FF                ; Find the first page (from $64) holding $FF for this
  INC H                   ; code...
  CP (HL)                 ;
  JR NZ,$8AD6             ;
  DEC H                   ; ...and step back to the topmost tile of the stack
  LD A,(HL)               ;
  BIT 7,A                 ; Tiles $80-$FF are special (8B1D)
  JR NZ,$8B1D             ;
  CP $2D                  ; Ordinary tiles $2D-$7F cannot be landed on: crash
  JR NC,$8B5D             ;
  CP $03                  ; Tiles $00-$02 (sea) cannot be landed on: crash
  JR C,$8B5D              ;
  INC DE                  ; Next footprint cell
  DJNZ $8AD0              ;
  LD A,$09                ; All 9 cells were helipad tiles ($83/$89)?
  CP C                    ;
  JR NZ,$8AF5             ;
  LD A,$01                ; Then 752E=1: landed on the base helipad (refuelling
  LD ($752E),A            ; allowed; required to finish a round)
  LD A,$01                ; 7515=1: landed
  LD ($7515),A            ;
  XOR A                   ; Clear 7514
  LD ($7514),A            ;
  LD A,($750D)            ; Round the altitude UP to a multiple of 8: new =
  LD D,A                  ; ((alt+7)>>3)*8
  ADD A,$07               ;
  SRA A                   ;
  SRA A                   ;
  SRA A                   ;
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  LD ($750D),A            ;
  SUB D                   ; B = (new-old)+1
  LD B,A                  ;
  INC B                   ;
  JR $8B1A                ; Raise the altimeter bar by new-old pixels (82D4
  PUSH BC                 ; once per pixel)
  CALL $82D4              ;
  POP BC                  ;
  DJNZ $8B15              ;
  RET                     ;
  CP $80                  ; Special top tile: $80 or $86 = crash
  JR Z,$8B5D              ;
  CP $86                  ;
  JR Z,$8B5D              ;
  CP $83                  ; $83 or $89 = helipad tile: count it (C=C+1); any
  JR Z,$8B2D              ; other $80-$FF tile is landable
  CP $89                  ;
  JR NZ,$8AE8             ;
  INC C                   ;
  JR $8AE8                ;
  LD E,A                  ; Cell height class (HL) is above altitude/4. E =
  LD A,(HL)               ; altitude/4
  CP $0F                  ; Height class < 15: low obstacle (ground). Go to
  JR C,$8B4E              ; 8B4E
  LD A,($87EF)            ; Height class >= 15 (very tall object). Not seen
  SRA E                   ; executed. A = 87EF (current helicopter tile level),
                          ; E = altitude/8
  DEC A                   ; 87EF-1 = altitude/8: crash
  CP E                    ;
  JR Z,$8B5D              ;
  INC A                   ;
  CP $07                  ; 87EF=7: crash only if altitude/8 = 7 (8B49)
  JR Z,$8B49              ;
  LD A,E                  ; Otherwise count the cell as clear and continue the
  INC C                   ; loop
  JP $8AA7                ;
  CP E                    ;
  JR NZ,$8B44             ;
  JR $8B5D                ;
  LD A,($751B)            ; Low obstacle reached: a descent speed of 3 is a
  CP $03                  ; hard landing = crash
  JR NC,$8B5D             ;
  XOR A                   ; Otherwise kill the descent speed (soft contact) and
  LD ($751B),A            ; continue the loop WITHOUT counting the cell as
  LD A,E                  ; clear
  JP $8AA7                ;
  LD A,$01                ; 7505=1: helicopter destroyed
  LD ($7505),A            ;
  RET                     ;

; Unused code fragment (never called)
;
; Disassembles as LD A,$F3 / LD A,$3E / LD I,A / IM 1 / EI / RET: a leftover
; interrupt-mode-1 restore. Followed by 7 zero bytes.
  DEFB $3E,$F3,$3E,$3E,$ED,$47,$ED,$56,$FB,$C9
  DEFB $00,$00,$00,$00,$00,$00,$00

; Random number generator
;
; Advances the 16-bit seed held in the ROM system variable SEED (5C76) and
; returns it in HL. The arithmetic is the classic Spectrum Lehmer step done
; without multiplication: new = ((254*(seed+1)) mod 65537) - 1 (verified for
; 3,206 seeds by emulation, including 0 and 65535). The sequence visits all
; 65,536 values (period 65536). Callers use L or H of the result.
;
; I:(5C76) seed
; O:HL new seed (also stored at 5C76)
; O:A,D,E corrupted
  LD DE,($5C76)           ; DE = seed
  LD H,E                  ; Form the 24-bit number A:H:L = seed*256 + $FD
  LD L,$FD                ;
  LD A,D                  ;
  OR A                    ; Subtract the seed twice (with borrow into A): A:HL
  SBC HL,DE               ; = 254*seed + 253 = 254*(seed+1) - 1
  SBC A,$00               ;
  SBC HL,DE               ;
  SBC A,$00               ;
  LD E,A                  ; Reduce modulo 65537 (65536 = -1): HL = HL - A
  LD D,$00                ;
  SBC HL,DE               ;
  JR NC,$8B8D             ; On borrow add 65537 back (i.e. +1 in 16 bits)
  INC HL                  ;
  LD ($5C76),HL           ; Store new seed
  RET                     ;

; Animate sea waves in the view buffer
;
; Called every main-loop iteration (5B45) and every step of the death sequence
; (925A), after 76D2 has rebuilt the view buffer (F74E, 23 columns x 22 rows of
; terrain codes) and before 7E10 converts codes to tile stacks. Puts random
; wave codes 0-3 into the empty (code 0 = open sea) cells of a sparse sheared
; lattice (7 rows x 4-5 columns, lattice vectors +5 cells across and +4 rows/+3
; columns down). The lattice phase (7535 column 0..8, 7536 row 0..6) is shifted
; against the heading whenever the helicopter is moving, so the waves scroll
; with the motion; the random bytes are taken from ROM $0100+n, n re-randomised
; every 3rd call, so the wave pattern changes every 3 iterations.
;
; I:(7527) speed (0 = hovering: phase unchanged)
; I:(7506) heading 0,2,..14 (0=N, clockwise)
; I:(7504) view: 0 = north, 1 = south (180 degree rotated)
;
; Cell written = F705 + 7535 + 23*B + 5*i + 95*j (j=0..6 rows, i=0..3 or 4),
; where B = 7536 (view north) or, view south, B = 7536+2 if that is < 7 else
; 7536-2; F705 = F74E - 73 (3 rows and 4 columns before the buffer start). If
; 7535 < 4 the first lattice column is skipped (+5). Columns per row: 5 if 7535
; in 0,1,4,5,6; 4 if 7535 in 2,3,7,8 (the row stride is always 95). Only cells
; containing 0 are changed, to (ROM byte AND 3).
  LD A,($7537)            ; 7537 counts 0,1,2
  INC A                   ;
  CP $03                  ;
  JR Z,$8BA2              ;
  LD ($7537),A            ;
  LD DE,($7538)           ; Not the 3rd call: reuse the ROM pointer in 7538
  JR $8BB0                ;
  XOR A                   ; Every 3rd call: DE = $0100 + (L of a new random
  LD ($7537),A            ; number) = pointer to "random" ROM bytes
  CALL $8B74              ;
  LD D,$01                ;
  LD E,L                  ;
  LD ($7538),DE           ;
  PUSH DE                 ; Keep the ROM pointer on the stack
  LD A,($7527)            ; Speed 0: lattice phase unchanged
  CP $00                  ;
  JR NZ,$8BC6             ;
  LD HL,$F705             ;
  LD A,($7535)            ;
  LD C,A                  ;
  ADD A,L                 ;
  LD L,A                  ;
  LD A,($7536)            ;
  JR $8C00                ;
  LD A,($7504)            ; Moving: choose the phase-step table for the current
  CP $00                  ; view
  JR Z,$8BD2              ;
  LD HL,$8C77             ;
  JR $8BD5                ;
  LD HL,$8C66             ;
  LD A,($7506)            ; Index it by heading (2 bytes per heading)
  LD D,$00                ;
  LD E,A                  ;
  ADD HL,DE               ;
  LD DE,$F705             ;
  LD B,(HL)               ; 7535 += dx; values outside 0..8 reset to 4
  LD A,($7535)            ;
  ADD A,B                 ;
  CP $09                  ;
  JR C,$8BEA              ;
  LD A,$04                ;
  LD ($7535),A            ; C = new column phase; E = $05+7535 (DE =
  INC HL                  ; F705+column phase)
  LD C,A                  ;
  ADD A,E                 ;
  LD E,A                  ;
  LD B,(HL)               ; 7536 += dy; values outside 0..6 reset to 3
  LD A,($7536)            ;
  ADD A,B                 ;
  CP $07                  ;
  JR C,$8BFC              ;
  LD A,$03                ;
  LD ($7536),A            ;
  EX DE,HL                ;
  LD B,A                  ; B = row phase; adjusted by 2 rows for the south
  LD A,($7504)            ; view
  CP $00                  ;
  JR Z,$8C13              ;
  INC B                   ;
  INC B                   ;
  LD A,B                  ;
  CP $07                  ;
  JR C,$8C13              ;
  LD B,$04                ;
  SUB B                   ;
  LD B,A                  ;
  LD DE,$0017             ; HL = F705 + column phase + 23*row phase
  INC B                   ;
  JR $8C1A                ;
  ADD HL,DE               ;
  DJNZ $8C19              ;
  LD A,$04                ; Default: 4 lattice columns per row, row skip 75
  LD ($8C47),A            ; (self-modified operands at 8C47 and 8C5E)
  LD A,$4B                ;
  LD ($8C5E),A            ;
  LD A,C                  ; Column phase < 4: start one lattice column (5
  CP $04                  ; cells) further on
  JR NC,$8C35             ;
  LD DE,$0005             ;
  ADD HL,DE               ;
  CP $02                  ;
  JR C,$8C39              ;
  JR $8C43                ;
  CP $07                  ;
  JR NC,$8C43             ;
  LD A,$05                ; 5 lattice columns per row, row skip 70
  LD ($8C47),A            ;
  LD A,$46                ;
  LD ($8C5E),A            ;
  LD C,$07                ; 7 lattice rows
  XOR A                   ;
  LD B,$05                ; B = lattice columns (operand at 8C47 modified
  LD DE,$0005             ; above)
  CP (HL)                 ; Cell empty (open sea)?
  JR NZ,$8C5A             ;
  EX AF,AF'               ; Then set it to the next ROM byte AND 3 (wave code
  POP DE                  ; 0-3)
  LD A,(DE)               ;
  AND $03                 ;
  LD (HL),A               ;
  INC E                   ;
  PUSH DE                 ;
  EX AF,AF'               ;
  LD DE,$0005             ; Next lattice column (+5 cells)
  ADD HL,DE               ;
  DJNZ $8C4B              ;
  LD DE,$0046             ; Next lattice row (operand at 8C5E modified above:
  ADD HL,DE               ; 95 bytes per row in total)
  DEC C                   ;
  JR NZ,$8C46             ;
  POP DE                  ; Drop the ROM pointer
  RET                     ;

; Wave phase steps, view north
;
; (dx,dy) added to 7535/7536 per moving iteration, indexed by heading 7506
; (0=N,2=NE,4=E,...,14=NW). The step is opposite to the direction of travel.
; Byte 8C76 is padding.
  DEFB $00,$01
  DEFB $FF,$01
  DEFB $FF,$00
  DEFB $FF,$FF
  DEFB $00,$FF
  DEFB $01,$FF
  DEFB $01,$00
  DEFB $01,$01
  DEFB $00

; Wave phase steps, view south
;
; As 8C66 but negated (view rotated 180 degrees).
  DEFB $00,$FF
  DEFB $01,$FF
  DEFB $01,$00
  DEFB $01,$01
  DEFB $00,$01
  DEFB $FF,$01
  DEFB $FF,$00
  DEFB $FF,$FF

; Unused code fragment (never called)
;
; Disassembles as an old interrupt set-up: LD HL,$FFFF / LD (HL),$18 / LD
; HL,$FFF4 / LD (HL),$C3 / INC HL / LD (HL),$C2 / INC HL / LD (HL),$83 (JR at
; FFFF + JP $83C2 at FFF4) / LD A,$3A / LD I,A / IM 2 / JP $E280. Superseded by
; the F74E init.
  DEFB $21,$FF,$FF,$36,$18,$21,$F4,$FF,$36
  DEFB $C3,$23,$36,$C2,$23,$36,$83,$3E,$3A
  DEFB $ED,$47,$ED,$5E,$C3,$80,$E2

; Build the helicopter sprite (with rotor) in 6950
;
; Called every main-loop iteration (5B48) and for the first 3 steps of the
; death sequence. Copies the 72-byte (9 character, 3x3) helicopter graphic for
; sprite frame 7507 from E930+72*frame to the sprite buffer 6950-6997, then
; XORs one of the rotor overlays onto it. 86AF later draws 6950 into the view.
;
; I:(7507) displayed sprite heading frame 0-15 (moves one step at a time
;          towards 7508)
; I:(7504) view 0 north / 1 south
; I:(7515) landed flag; (7516) fuel-empty flag
; I:(753A) rotor animation frame
;
; Frame used = 7507 (view north) or (7507+8) mod 16 (view south). For frames
; 10-15 the instruction at 8D02 becomes ADD A,A so the rotor overlay is shifted
; one pixel left (mirror-side frames). Rotor overlays (72 bytes each, XORed):
; flying: $7000+256*f, f = 753A cycling 0,1 (2-frame fast rotor); landed or out
; of fuel: $6700+256*f, f cycling 0,1,2,3 (4-frame slow rotor). (OBSERVED: 753A
; cycles 1,2,3,0 while landed, 0,1 in flight.)
  LD A,($7507)            ; B = sprite frame
  LD B,A                  ;
  LD A,($7504)            ; South view: frame = (frame+8) AND 15 (RES 4)
  CP $00                  ;
  JR Z,$8CB1              ;
  LD A,$08                ;
  ADD A,B                 ;
  RES 4,A                 ;
  LD B,A                  ;
  LD HL,$8D02             ; Frames 0-9: NOP at 8D02; frames 10-15: ADD A,A
  LD (HL),$00             ; ($87) at 8D02
  LD A,$09                ;
  CP B                    ;
  JR NC,$8CBD             ;
  LD (HL),$87             ;
  LD HL,$E8E8             ; HL = E8E8 + 72*(frame+1) = E930 + 72*frame
  INC B                   ;
  LD DE,$0048             ;
  ADD HL,DE               ;
  DJNZ $8CC4              ;
  LD DE,$6950             ; Copy the 72-byte graphic to 6950
  LD BC,$0048             ;
  LDIR                    ;
  LD DE,$7000             ; Rotor overlay page: $70 (flying)...
  LD A,($7515)            ; ...or $67 if landed or out of fuel, with a 4-frame
  CP $01                  ; cycle
  JR Z,$8CE0              ;
  LD A,($7516)            ;
  CP $00                  ;
  JR Z,$8CEE              ;
  LD DE,$6700             ;
  LD A,($753A)            ;
  INC A                   ;
  CP $04                  ;
  JR C,$8CF7              ;
  XOR A                   ;
  JR $8CF7                ;
  LD A,($753A)            ; Flying: 2-frame cycle
  INC A                   ;
  CP $02                  ;
  JR C,$8CF7              ;
  XOR A                   ;
  LD ($753A),A            ;
  ADD A,D                 ; DE = (page+frame)*256
  LD D,A                  ;
  LD HL,$6950             ;
  LD B,$48                ;
  LD A,(DE)               ; XOR 72 overlay bytes onto the sprite buffer
  NOP                     ; Self-modified: NOP, or ADD A,A (shift overlay left)
  XOR (HL)                ; for frames 10-15
  LD (HL),A               ;
  INC HL                  ;
  INC DE                  ;
  DJNZ $8D01              ;
  RET                     ;

; Unused
  DEFB $00,$00,$00,$00

; Clear the view window
;
; Used at game start (5B03) and when the map screen is entered (5B78). Sets the
; 23x22-cell view window (columns 0-22, rows 0-21) to attribute $3F (white on
; white), clears its bitmap, then sets the inner 21x20 cells (columns 1-21,
; rows 1-20) to $7C (bright white paper, green ink: map land colour).
  LD HL,$5800             ; 22 rows x 23 attributes = $3F
  LD C,$16                ;
  LD DE,$0009             ;
  LD B,$17                ;
  LD (HL),$3F             ;
  INC HL                  ;
  DJNZ $8D18              ;
  ADD HL,DE               ;
  DEC C                   ;
  JR NZ,$8D16             ;
  LD HL,$4000             ; Clear 22 rows x 23 columns x 8 pixel lines of
  LD C,$16                ; bitmap
  LD B,$17                ;
  PUSH BC                 ;
  PUSH HL                 ;
  LD B,$08                ;
  LD (HL),$00             ;
  INC H                   ;
  DJNZ $8D2C              ;
  POP HL                  ;
  POP BC                  ;
  INC HL                  ;
  DJNZ $8D28              ;
  RR H                    ; Next character row (screen address arithmetic via
  RR H                    ; rotation of H)
  RR H                    ;
  LD DE,$0009             ;
  ADD HL,DE               ;
  RL H                    ;
  RL H                    ;
  RL H                    ;
  DEC C                   ;
  JR NZ,$8D26             ;
  LD HL,$5821             ; Inner 20 rows x 21 columns = $7C
  LD C,$14                ;
  LD DE,$000B             ;
  LD B,$15                ;
  LD (HL),$7C             ;
  INC HL                  ;
  DJNZ $8D53              ;
  ADD HL,DE               ;
  DEC C                   ;
  JR NZ,$8D51             ;
  RET                     ;

; Map screen: draw the island shapes
;
; Used when the map screen is entered (5B7B), after 8D0E. For each of the 14
; island records at F230 (20 bytes each, list ends with $FF) it renders the
; island's heightmap at 1/4 scale: one map pixel per 4x4 world units, pixel set
; if the sampled height byte is >= $0F. Falls through into 8DE2 to print the
; names.
;
; I:F230 island table: +0A/+0B heightmap base, +0C/+0D map bitmap address
;        (top-left), +0E width in pixels, +0F height in pixel rows
;
; Heightmap format expected (same as the view builder 775E/7789): one byte per
; world unit, 128 bytes per world row, i.e. byte for (x,y) = base + 128*(y-y0)
; + (x-x0). The map samples pixel (px,py) at base + $102 + 4*px + $200*py, i.e.
; world offset (2+4*px, 2+4*py). Only the low byte is stepped (INC L x4), so a
; row must not cross a 256-byte page. Pixels are packed MSB first, 8 per screen
; byte; a final partial byte is padded with zero bits. 753C = start of current
; pixel row on screen, 753E = write pointer.
  LD IX,$F230             ; IX = first island record
  LD L,(IX+$0C)           ; 753C = 753E = bitmap address of the island's
  LD H,(IX+$0D)           ; top-left pixel
  LD ($753C),HL           ;
  LD ($753E),HL           ;
  LD L,(IX+$0A)           ; HL = heightmap base + $102 (2 world units in from
  LD H,(IX+$0B)           ; the top-left corner)
  INC H                   ;
  INC HL                  ;
  INC HL                  ;
  LD D,(IX+$0F)           ; D = pixel rows, E = pixels per row
  LD E,(IX+$0E)           ;
  PUSH HL                 ;
  LD B,$08                ; Build one screen byte from up to 8 samples
  LD C,$00                ;
  SLA C                   ;
  LD A,(HL)               ; Height >= $0F: land pixel
  CP $0F                  ;
  JR C,$8D8A              ;
  SET 0,C                 ;
  INC L                   ; Next sample 4 bytes (4 world units) to the right
  INC L                   ;
  INC L                   ;
  INC L                   ;
  XOR A                   ; Row finished? Then pad the byte with zero bits
  CP E                    ;
  JR Z,$8D99              ;
  DEC E                   ;
  DJNZ $8D81              ;
  JR $8D9B                ;
  SLA C                   ;
  DJNZ $8D97              ;
  PUSH HL                 ; Store the byte and advance the screen pointer
  LD HL,($753E)           ;
  LD (HL),C               ;
  INC HL                  ;
  LD ($753E),HL           ;
  POP HL                  ;
  XOR A                   ; Loop until the row is complete
  CP E                    ;
  JR NZ,$8D7D             ;
  LD HL,($753C)           ; Move 753C down one pixel line (handling
  LD A,H                  ; character-row boundaries)
  AND $07                 ;
  CP $07                  ;
  JR NZ,$8DC8             ;
  LD A,H                  ;
  AND $F8                 ;
  LD H,A                  ;
  RR H                    ;
  RR H                    ;
  RR H                    ;
  LD BC,$0020             ;
  ADD HL,BC               ;
  RL H                    ;
  RL H                    ;
  RL H                    ;
  DEC H                   ;
  INC H                   ;
  LD ($753C),HL           ;
  LD ($753E),HL           ;
  POP HL                  ; Next sample row: 4 world rows down (2 pages)
  INC H                   ;
  INC H                   ;
  DEC D                   ;
  JR NZ,$8D79             ;
  LD BC,$0014             ; Next island record
  ADD IX,BC               ;
  LD A,(IX+$00)           ;
  CP $FF                  ;
  JR NZ,$8D61             ;
  NOP                     ; Fall through to print the names

; Print island names (4-pixel-wide font)
;
; Prints the island names on the map in a half-width font, two characters per
; screen cell, black on bright white. Entry 8DE2 sets IX=F230, record stride 20
; and the text pointer 6A4F; entry 8DEE is also used by the info screen (E446)
; with its own IX table (E68C), stride 3 (written to 8E0A) and text (E517).
;
; I:(IX+$10/$11) screen address one cell left of where the text starts;
;                (IX+$12) attribute-file high byte ($58/$59/$5A) for that row
;
; Text format (6A50-6AC9 for the map): ASCII bytes, with '?' ($3F) used as the
; space character. $FE = end of this name, move to the next record; $FD =
; append the shared suffix at 6AC2 ("?ISLAND", i.e. " ISLAND") which itself
; ends with $FC = return from suffix and move to the next record; $FF = end of
; all text. Glyphs: 8 bytes per character at 6908+8*code (only the left 4
; pixels are used); even-numbered characters are copied into the next cell (and
; its attribute set to $78), odd-numbered characters are shifted right 4 pixels
; and ORed into the same cell. Map name order follows F230: BANANA, ORTE ROCKS,
; KOKOLA, LAGOON, PEAK, BASE, GILLIGANS, RED, SKEG, BONE, GIANTS GATEWAY, CLAW,
; LUKELAND ISLES, ENTERPRISE (ISLAND appended except for ORTE ROCKS, GIANTS
; GATEWAY, LUKELAND ISLES).
  LD IX,$F230             ; Map: island records at F230, stride 20 (operand at
  LD A,$14                ; 8E0A), text at 6A50
  LD ($8E0A),A            ;
  LD HL,$6A4F             ;
; This entry point is used by the routine at DrawInfoTexts.
  LD E,(IX+$10)           ; DE = name position (one cell to the left), C =
  LD D,(IX+$11)           ; character counter
  DEC E                   ;
  LD C,$00                ;
  INC HL                  ; Next text byte
  LD A,(HL)               ;
  CP $FC                  ;
  JR C,$8E15              ;
  CP $FF                  ; $FF: finished
  RET Z                   ;
  CP $FE                  ; $FE: next record
  JR Z,$8E09              ;
  CP $FD                  ; $FD: switch to the suffix text at 6AC2
  JR Z,$8E10              ;
  POP HL                  ; $FC: end of suffix: restore the main text pointer
                          ; and go to the next record
  LD BC,$0014             ; IX += stride (operand at 8E0A is self-modified: 20
  ADD IX,BC               ; for the map, 3 for the info screen)
  JR $8DEE                ;
  PUSH HL                 ; Push the main text pointer and read the suffix from
  LD HL,$6AC2             ; 6AC2 onwards
  LD A,(HL)               ;
  PUSH HL                 ; HL = 6908 + 8*code (glyph)
  PUSH BC                 ;
  LD BC,$6908             ;
  LD L,A                  ;
  LD H,$00                ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,BC               ;
  POP BC                  ;
  PUSH BC                 ;
  BIT 0,C                 ; Odd character: OR the glyph shifted right 4 pixels
  JR Z,$8E3D              ; into the current cell
  PUSH DE                 ;
  LD B,$08                ;
  EX DE,HL                ;
  LD A,(DE)               ;
  SRL A                   ;
  SRL A                   ;
  SRL A                   ;
  SRL A                   ;
  OR (HL)                 ;
  LD (HL),A               ;
  INC DE                  ;
  INC H                   ;
  DJNZ $8E2B              ;
  EX DE,HL                ;
  JR $8E4D                ;
  INC DE                  ; Even character: move to the next cell and copy the
  PUSH DE                 ; glyph
  LD B,$08                ;
  LD A,(HL)               ;
  LD (DE),A               ;
  INC HL                  ;
  INC D                   ;
  DJNZ $8E41              ;
  LD D,(IX+$12)           ; Set the cell's attribute to $78
  LD A,$78                ;
  LD (DE),A               ;
  POP DE                  ;
  POP BC                  ;
  POP HL                  ;
  INC C                   ; Next character
  JR $8DF7                ;

; Unused
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00

; Map screen: draw frame and north indicator
;
; Used when the map screen is entered (5B7E). Draws the frame around the 23x22
; map using 8-byte characters from the HUD graphics at 7438-7497, then a
; 3-character north arrow at column 20, rows 17-19 (codes $4E 'N', $29, $2A
; from 8F0C in the main font at 6028) with attributes $78.
;
; Frame pieces: 7438 top-left (row 0,col 0), 7440 x21 top edge, 7448 top-right
; (col 22); 7480 bottom-left (row 21), 7488 x21 bottom edge, 7490 bottom-right;
; 7460 x20 left edge (rows 1-20, col 0); 7470 x20 right edge (col 22).
  LD IX,$7438
  LD DE,$4000
  LD HL,$0001
  LD C,$01
  CALL $8EE8
  LD IX,$7440
  LD C,$15
  CALL $8EE8
  LD IX,$7448
  LD C,$01
  CALL $8EE8
  LD IX,$7480
  LD DE,$50A0
  LD C,$01
  CALL $8EE8
  LD IX,$7488
  LD C,$15
  CALL $8EE8
  LD IX,$7490
  LD C,$01
  CALL $8EE8
  LD IX,$7460
  LD DE,$4020
  LD HL,$0020
  LD C,$14
  CALL $8EE8
  LD IX,$7470
  LD DE,$4036
  LD HL,$0020
  LD C,$14
  CALL $8EE8
  LD DE,$5034
  LD HL,$8F0C
  LD C,$01
  CALL $859A
  LD DE,$5054
  LD HL,$8F0D
  LD C,$01
  CALL $859A
  LD DE,$5074
  LD HL,$8F0E
  LD C,$01
  CALL $859A
  LD HL,$5A34
  LD A,$78
  LD BC,$0020
  LD (HL),A
  ADD HL,BC
  LD (HL),A
  ADD HL,BC
  LD (HL),A
  RET

; Draw a character C times
;
; Copies the 8-byte character at IX to screen address DE, C times, advancing DE
; by HL each time (HL=1: next column, HL=$20: next character row; also $40 from
; the info screen). Used by 8E5C and the info screen (E4C2-E4D2).
;
; I:IX 8-byte character
; I:DE screen address
; I:HL step (in character cells; 32 = one row down)
; I:C repeat count
; O:DE address after the last character
  PUSH IX
  PUSH DE
  LD B,$08
  LD A,(IX+$00)
  LD (DE),A
  INC D
  INC IX
  DJNZ $8EED
  POP DE
  EX DE,HL                ; DE += HL using the 'linear' form of the screen
  RR H                    ; address (H rotated right 3 times) so that +32
  RR H                    ; crosses character rows and thirds correctly
  RR H                    ;
  ADD HL,DE               ;
  RL H                    ;
  RL H                    ;
  RL H                    ;
  EX DE,HL                ;
  POP IX                  ;
  DEC C                   ;
  JR NZ,$8EE8             ;
  RET                     ;

; Map north-indicator characters
;
; Font codes printed by 8E5C at rows 17, 18 and 19 of column 20: 'N', arrow
; shaft/head ($29), arrow tail ($2A). 8F0F-8F11 unused.
  DEFB $4E,$29,$2A
  DEFB $00,$00,$00

; Map screen: per-iteration update (blinking markers)
;
; Called by the main loop instead of 762C/9034 while the map screen is shown
; (7526 bit 1). Wastes about 132,000 T-states (about 1.9 frames), then blinks
; the helicopter and cyclone markers with a 7-call cycle using counter 7542:
; calls 1-3 just update positions (9034), calls 4-6 remove the markers, call 7
; resets the counter, updates positions and redraws the markers at their new
; cells (8F6A). OBSERVED: one map-mode iteration takes about 5.7 frames, so a
; blink cycle lasts about 40 frames.
  LD C,$28                ; Delay loop: 40 x 255 DJNZ
  LD B,$FF                ;
  DJNZ $8F16              ;
  DEC C                   ;
  JR NZ,$8F14             ;
  LD HL,$7542             ; 7542 = 7542+1; 1..3: positions only
  INC (HL)                ;
  LD A,$03                ;
  CP (HL)                 ;
  JP NC,$9034             ;
  LD A,($9027)            ; Remove the helicopter marker: restore its attribute
  LD HL,($7543)           ; (a saved $3F frame attribute is restored as $3A
  CP $3F                  ; instead; never seen)
  JR NZ,$8F31             ;
  LD A,$3A                ;
  LD (HL),A               ;
  LD A,($9030)            ; Restore the cyclone marker's attribute
  LD HL,($7547)           ;
  LD (HL),A               ;
  LD DE,$901F             ; Restore the 8 bitmap bytes under the helicopter
  LD HL,($7545)           ; marker
  LD B,$08                ;
  LD A,(DE)               ;
  LD (HL),A               ;
  INC DE                  ;
  INC H                   ;
  DJNZ $8F41              ;
  LD DE,$9028             ; Restore the 8 bitmap bytes under the cyclone marker
  LD HL,($7549)           ;
  LD B,$08                ;
  LD A,(DE)               ;
  LD (HL),A               ;
  INC DE                  ;
  INC H                   ;
  DJNZ $8F4F              ;
  LD HL,$7542             ; Counter 4..6: done
  LD A,$06                ;
  CP (HL)                 ;
  JP NC,$9034             ;
  LD (HL),$00             ; Counter 7: reset to 0, restore helicopter attribute
  LD A,($9027)            ;
  LD HL,($7543)           ;
  LD (HL),A               ;
  CALL $9034              ; Update positions, then fall through to redraw the
                          ; markers

; Map screen: draw helicopter and cyclone markers
;
; Saves the attribute and the 8 bitmap bytes of the character cell (column
; 7540, row 7541) and prints the helicopter marker there (main-font code $28
; 'H'-like glyph) with attribute $7A (bright, white paper, red ink); then does
; the same for the cyclone at (754B, 754C) with code $27 (swirl). Called on map
; entry (5B81) and by 8F12.
;
; I:(7540),(7541) helicopter map cell (column 0-22, row 0-21), from 9034
; I:(754B),(754C) cyclone map cell
; O:(7543) helicopter cell attribute address, (7545) its bitmap address, (9027)
;          saved attribute, 901F-9026 saved bitmap
; O:(7547) cyclone cell attribute address, (7549) its bitmap address, (9030)
;          saved attribute, 9028-902F saved bitmap
  LD HL,$5800             ; Attribute address = 5800 + 32*row + column
  LD A,($7541)            ;
  LD B,A                  ;
  LD DE,$0020             ;
  INC B                   ;
  JR $8F78                ;
  ADD HL,DE               ;
  DJNZ $8F77              ;
  LD A,($7540)            ;
  ADD A,L                 ;
  LD L,A                  ;
  LD ($7543),HL           ;
  LD A,(HL)               ; Save it and set $7A
  LD ($9027),A            ;
  LD (HL),$7A             ;
  LD HL,$4000             ; Bitmap address of the cell
  LD A,($7541)            ;
  LD B,A                  ;
  LD DE,$0020             ;
  INC B                   ;
  JR $8FA2                ;
  RR H                    ;
  RR H                    ;
  RR H                    ;
  ADD HL,DE               ;
  RL H                    ;
  RL H                    ;
  RL H                    ;
  DJNZ $8F95              ;
  LD A,($7540)            ;
  ADD A,L                 ;
  LD L,A                  ;
  LD ($7545),HL           ;
  LD DE,$901F             ; Save the 8 pixel bytes
  LD B,$08                ;
  LD A,(HL)               ;
  LD (DE),A               ;
  INC H                   ;
  INC DE                  ;
  DJNZ $8FB1              ;
  LD DE,($7545)           ; Print the helicopter marker (code at 901D)
  LD HL,$901D             ;
  LD C,$01                ;
  CALL $859A              ;
  LD HL,$5800             ; Same for the cyclone
  LD A,($754C)            ;
  LD B,A                  ;
  LD DE,$0020             ;
  INC B                   ;
  JR $8FD1                ;
  ADD HL,DE               ;
  DJNZ $8FD0              ;
  LD A,($754B)            ;
  ADD A,L                 ;
  LD L,A                  ;
  LD ($7547),HL           ;
  LD A,(HL)               ;
  LD ($9030),A            ;
  LD (HL),$7A             ;
  LD HL,$4000             ;
  LD A,($754C)            ;
  LD B,A                  ;
  LD DE,$0020             ;
  INC B                   ;
  JR $8FFB                ;
  RR H                    ;
  RR H                    ;
  RR H                    ;
  ADD HL,DE               ;
  RL H                    ;
  RL H                    ;
  RL H                    ;
  DJNZ $8FEE              ;
  LD A,($754B)            ;
  ADD A,L                 ;
  LD L,A                  ;
  LD ($7549),HL           ;
  LD DE,$9028             ;
  LD B,$08                ;
  LD A,(HL)               ;
  LD (DE),A               ;
  INC H                   ;
  INC DE                  ;
  DJNZ $900A              ;
  LD DE,($7549)           ;
  LD HL,$901E             ; Print the cyclone marker (code at 901E)
  LD C,$01                ;
  CALL $859A              ;
  RET                     ;

; Map marker codes and save areas
  DEFB $28                ; Helicopter marker character code ($28)
  DEFB $27                ; Cyclone marker character code ($27)
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Saved bitmap under the helicopter
                                       ; marker
  DEFB $00                ; Saved attribute under the helicopter marker
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Saved bitmap under the cyclone marker
  DEFB $00                ; Saved attribute under the cyclone marker
  DEFB $00,$00,$00        ; Unused

; Map positions, cyclone movement and wind-force/danger gauges
;
; Called every main-loop iteration in the normal view (5B89) and on calls 1-3
; and 7 of the map blink cycle. (1) Converts the helicopter's world position to
; a map cell. (2) Every 25 calls moves the cyclone one map cell in a random
; direction chosen from the current 'regime', picking a new regime every 9
; moves or when the cyclone hits the map edge. (3) Sets 7550 = Chebyshev
; distance helicopter-cyclone (max 15) and draws the WIND FORCE bar and DANGER
; warning.
;
; I:(7500) helicopter X (16-bit world units), (7502) helicopter Y (Y grows
;          southwards)
; O:(7540) map column = X/32 clamped to 0..22; (7541) map row = Y/32 clamped to
;          0..21
; O:(754D) number of axes on which the helicopter is off the map (0-2)
; O:(754B),(754C) cyclone map column 1..21 / row 1..20
; O:(7550) distance to cyclone 0..15
;
; Off-map test: if X/32 >= 256 (only possible for 'negative' X >= $2000) the
; column is 0; if 23 <= X/32 < 256 it is 22; rows likewise use 21. (The checks
; of H against $80 at 9054/9087 can never succeed, as H <= 7 after the shifts;
; dead code.)
;
; Cyclone timing (OBSERVED, helicopter idling at base: 5.16 frames per
; main-loop iteration): one step every 25 iterations = about 129 frames (2.6
; s); a regime lasts 9 steps (about 23 s) unless cut short at an edge.
  XOR A                   ; 754D = 0
  LD ($754D),A            ;
  LD HL,($7500)           ; HL = X >> 5
  SRL H                   ;
  RR L                    ;
  SRL H                   ;
  RR L                    ;
  SRL H                   ;
  RR L                    ;
  SRL H                   ;
  RR L                    ;
  SRL H                   ;
  RR L                    ;
  LD A,H                  ; X/32 < 256?
  CP $00                  ;
  JR Z,$9063              ;
  CP $80                  ;
  JR NC,$905B             ;
  XOR A                   ;
  JR $905D                ;
  LD A,$16                ;
  LD HL,$754D             ;
  INC (HL)                ;
  JR $9068                ;
  LD A,L                  ; X/32 >= 23: column 22 and flag off-map
  CP $17                  ;
  JR NC,$905B             ;
  LD ($7540),A            ; 7540 = column
  LD HL,($7502)           ; HL = Y >> 5
  SRL H                   ;
  RR L                    ;
  SRL H                   ;
  RR L                    ;
  SRL H                   ;
  RR L                    ;
  SRL H                   ;
  RR L                    ;
  SRL H                   ;
  RR L                    ;
  LD A,H                  ;
  CP $00                  ;
  JR Z,$9096              ;
  CP $80                  ;
  JR NC,$9090             ;
  XOR A                   ;
  JR $9090                ;
  LD A,$15                ;
  LD HL,$754D             ;
  INC (HL)                ;
  JR $909B                ;
  LD A,L                  ; Y/32 >= 22: row 21 and flag off-map
  CP $16                  ;
  JR NC,$908E             ;
  LD ($7541),A            ; 7541 = row
  LD HL,$754E             ; 754E counts calls 0..24; the cyclone moves when it
  INC (HL)                ; reaches 25
  LD A,$18                ;
  CP (HL)                 ;
  JR NC,$9111             ;
  LD (HL),$00             ; 754F counts moves 0..8
  LD HL,$754F             ;
  INC (HL)                ;
  LD A,$08                ;
  CP (HL)                 ;
  JR NC,$90CB             ;
  LD (HL),$00             ; 9th move: new regime = random entry of 9178 (L AND
  CALL $8B74              ; 15), stored into the AND/OR operands at 90D0/90D2
  LD A,L                  ;
  AND $0F                 ;
  LD HL,$9178             ;
  LD D,$00                ;
  ADD A,A                 ;
  LD E,A                  ;
  ADD HL,DE               ;
  LD A,(HL)               ;
  LD ($90D0),A            ;
  INC HL                  ;
  LD A,(HL)               ;
  LD ($90D2),A            ;
  CALL $8B74              ; Direction index = (H of a new random number AND
  LD A,H                  ; mask) OR bits (operands at 90D0, 90D2): an even
  AND $0E                 ; offset into 9198
  OR $06                  ;
  LD HL,$9198             ;
  ADD A,L                 ;
  LD L,A                  ;
  LD A,($754B)            ; New column must be 1..21...
  LD B,(HL)               ;
  ADD A,B                 ;
  CP $01                  ;
  JR C,$90EA              ;
  CP $16                  ;
  JR NC,$90EA             ;
  LD ($754B),A            ;
  JR $90F4                ;
  LD A,$08                ; ...else stay and force a new regime next call
  LD ($754F),A            ; (754F=8, 754E=24)
  LD A,$18                ;
  LD ($754E),A            ;
  INC HL                  ; New row must be 1..20, else likewise force a new
  LD A,($754C)            ; regime
  LD B,(HL)               ;
  ADD A,B                 ;
  CP $01                  ;
  JR C,$9107              ;
  CP $15                  ;
  JR NC,$9107             ;
  LD ($754C),A            ;
  JR $9111                ;
  LD A,$08                ;
  LD ($754F),A            ;
  LD A,$18                ;
  LD ($754E),A            ;
  LD A,($7540)            ; C = |cyclone column - helicopter column|
  LD B,A                  ;
  LD A,($754B)            ;
  SUB B                   ;
  CP $80                  ;
  JR C,$911F              ;
  NEG                     ;
  LD C,A                  ;
  LD A,($7541)            ; A = |cyclone row - helicopter row|
  LD B,A                  ;
  LD A,($754C)            ;
  SUB B                   ;
  CP $80                  ;
  JR C,$912E              ;
  NEG                     ;
  CP C                    ; 7550 = min(15, max of the two)
  JR NC,$9132             ;
  LD A,C                  ;
  CP $10                  ;
  JR C,$9138              ;
  LD A,$0F                ;
  LD ($7550),A            ;
  LD E,A                  ; WIND FORCE bar at row 23, columns 16-31:
  LD A,$10                ; (16-distance) cells of $52 (red) then distance
  SUB E                   ; cells of $7F (white); one fewer red cell if the
  LD B,A                  ; helicopter is off the map
  LD A,($754D)            ;
  CP $00                  ;
  JR Z,$9149              ;
  DEC B                   ;
  INC E                   ;
  LD HL,$5AF0             ; Note the bar is drawn at 5AF0 = row 23 column 16
  INC B                   ;
  JR $9152                ;
  LD (HL),$52             ;
  INC L                   ;
  DJNZ $914F              ;
  LD B,E                  ;
  INC B                   ;
  JR $915B                ;
  LD (HL),$7F             ;
  INC L                   ;
  DJNZ $9158              ;
  NOP                     ; DANGER label (row 22, columns 26-31): $FA (flashing
  LD A,($7550)            ; red on white) if distance < 6, else $38 (black on
  CP $06                  ; white)
  JR C,$9169              ;
  LD A,$38                ;
  JR $916B                ;
  LD A,$FA                ;
  LD B,(HL)               ; Already that colour? Then return without rewriting
  CP B                    ;
  RET Z                   ;
  LD B,$06                ;
  LD HL,$5ADA             ;
  LD (HL),A               ;
  INC HL                  ;
  DJNZ $9173              ;
  RET                     ;

; Cyclone direction regimes
;
; 16 (mask, bits) pairs, one chosen at random (L AND 15) every 9 cyclone moves;
; each step's direction offset is (random H AND mask) OR bits, indexing the
; (dx,dy) pairs at 9198, so each regime allows 2 or 4 equally likely
; directions: 0 W/NW; 1 SW/S; 2 NE/E; 3 SE/E; 4 W/SW; 5 W/NW/N/NE; 6 W/NW/SW/S;
; 7 N/NE/SE/E; 8 SW/S/SE/E; 9 N/NE; 10 W/NW; 11 SW/S; 12 SE/E; 13 W/NW/N/NE; 14
; SW/S/SE/E; 15 N/NE. The current regime lives in the operands at 90D0/90D2
; (never reset; $0E/$06 = NE/E in the loaded image).
  DEFB $02,$00
  DEFB $0A,$08
  DEFB $0E,$06
  DEFB $0E,$0C
  DEFB $08,$00
  DEFB $06,$00
  DEFB $0A,$00
  DEFB $0E,$04
  DEFB $0E,$08
  DEFB $06,$04
  DEFB $02,$00
  DEFB $0A,$08
  DEFB $0E,$0C
  DEFB $06,$00
  DEFB $0E,$08
  DEFB $06,$04

; Cyclone step directions
;
; (dx,dy) map-cell steps at even offsets 0-14: 0 W(-1,0), 2 NW(-1,-1), 4
; N(0,-1), 6 NE(+1,-1), 8 SW(-1,+1), 10 S(0,+1), 12 SE(+1,+1), 14 E(+1,0). The
; bytes from 91A8 are never indexed.
  DEFB $FF,$00
  DEFB $FF,$FF
  DEFB $00,$FF
  DEFB $01,$FF
  DEFB $FF,$01
  DEFB $00,$01
  DEFB $01,$01
  DEFB $01,$00
  DEFB $00,$FF,$01,$00,$01,$01,$01,$01,$00,$00,$00,$00 ; Unused

; HUD: compass, speed bar, aircraft warning
;
; Called every main-loop iteration (5B42) and by the info screen (E3E4).
; Redraws the compass direction dot, the S (speed) bar and the BEWARE AIRCRAFT
; warning colours.
;
; I:(7527) speed 0..6
; I:(7506) heading (used while hovering), (753B) direction of travel (used
;          while moving); both 0,2,..14
; I:(7530) aircraft warning state (3 = flash)
  LD HL,$591C             ; Clear the 8 compass ring cells around the centre at
  XOR A                   ; 593D (row 9, column 29) to attribute 0
  LD (HL),A               ;
  INC HL                  ;
  LD (HL),A               ;
  INC HL                  ;
  LD (HL),A               ;
  LD HL,$595C             ;
  LD (HL),A               ;
  INC HL                  ;
  LD (HL),A               ;
  INC HL                  ;
  LD (HL),A               ;
  LD HL,$593C             ;
  LD (HL),A               ;
  INC HL                  ;
  INC HL                  ;
  LD (HL),A               ;
  DEC HL                  ;
  EX DE,HL                ;
  LD A,($7527)            ; Direction = heading 7506 if hovering, else travel
  CP $00                  ; direction 753B
  JR NZ,$91DA             ;
  LD A,($7506)            ;
  JR $91DD                ;
  LD A,($753B)            ;
  LD C,A                  ;
  LD B,$00                ;
  LD HL,$9232             ; Offset of the ring cell for this direction from the
  ADD HL,BC               ; table at 9232
  LD C,(HL)               ;
  INC HL                  ;
  LD B,(HL)               ;
  EX DE,HL                ;
  ADD HL,BC               ;
  LD (HL),$47             ; Light it: $47 (bright white on black)
  LD HL,$58BA             ; Speed bar: column 26 from row 5 upwards, 5 cells:
  LD A,($7527)            ; min(speed,5) cells of $52 (red) then the rest $7F
  INC A                   ; (white)
  CP $07                  ;
  JR C,$91F8              ;
  LD A,$06                ;
  LD B,A                  ;
  LD A,$06                ;
  SUB B                   ;
  LD DE,$FFE0             ;
  JR $9204                ;
  LD (HL),$52             ;
  ADD HL,DE               ;
  DJNZ $9201              ;
  LD B,A                  ;
  INC B                   ;
  JR $920D                ;
  LD (HL),$7F             ;
  ADD HL,DE               ;
  DJNZ $920A              ;
  LD HL,$5A18             ; BEWARE AIRCRAFT panel (rows 16-17, columns 24-31):
  LD A,($7530)            ; $FA (flashing) if 7530 = 3, else $3F
  CP $03                  ;
  JR Z,$921D              ;
  LD A,$3F                ;
  JR $921F                ;
  LD A,$FA                ;
  LD B,(HL)               ; Already that colour? Return
  CP B                    ;
  RET Z                   ;
  LD B,$08                ;
  LD (HL),A               ;
  INC HL                  ;
  DJNZ $9224              ;
  LD HL,$5A38             ;
  LD B,$08                ;
  LD (HL),A               ;
  INC HL                  ;
  DJNZ $922D              ;
  RET                     ;

; Compass ring offsets and death-sequence variables
;
; Attribute offsets from the compass centre (593D) for directions
; 0=N,2=NE,4=E,6=SE,8=S,10=SW,12=W,14=NW.
  DEFW $FFE0
  DEFW $FFE1
  DEFW $0001
  DEFW $0021
  DEFW $0020
  DEFW $001F
  DEFW $FFFF
  DEFW $FFDF
  DEFB $00                ; Unused
  DEFW $0000              ; Death sequence: pointer to the next 72-byte
                          ; explosion overlay (F550, F598, ...)
  DEFB $00                ; Lives lost this round (0-3; reset to 0 by 8321 at
                          ; the start of each round)

; Death sequence (helicopter destroyed)
;
; Entered from the main loop when 7505=1. Plays a 24-step explosion animation
; in the view, marks a life as lost (helicopter icon turned red), and either
; returns to the menu (3 lives lost) or resets the per-life variables and
; resumes the main loop at 5B36. OBSERVED: the 24 steps take about 132 frames
; (2.6 s).
;
; Per step (counter n = 24 down to 1): 76D2 rebuild view buffer, 8B91 waves;
; 6950 = 72 zero bytes (copied from 9300); n >= 22: 8CA0 rebuilds the normal
; helicopter sprite; n = 18: 752D+1 (explosion sound request for the interrupt
; handler); n >= 20: XOR the next explosion overlay (F550+72*k, k=0..4) onto
; 6950; then 7E10 (tile stacks), 86AF (draw sprite), 762C (render view). So the
; explosion overlays are shown over the helicopter for steps 24-22, alone for
; steps 21-20, and the sprite is blank from step 19.
;
; Life lost: attributes (row 10+2*k, columns 24-25), k = lives lost so far, are
; set to $02 (red ink); lives lost +1; 3 = game over (JP E280). Otherwise 82A7
; (fuel-gauge tick) is called until 7516=1 (fuel gauge emptied), then every
; byte of the reset table 75C8-762B that is not $FF is copied over 7500-7563
; (position $0139,$0170 on the base pad, landed, altitude 8, speed 0 ...; $FF
; entries such as the time bar pointer 751C/751D, 7543-754C markers/cyclone,
; 754E/754F, 7554 crates are kept) and play resumes at 5B36.
  CALL $762C              ; Render the view once
  LD HL,$F550             ; First explosion overlay at F550
  LD ($9243),HL           ;
  LD HL,$750D             ; Altitude +2 for the animation
  INC (HL)                ;
  INC (HL)                ;
  LD B,$18                ; 24 steps
  PUSH BC                 ;
  CALL $76D2              ;
  CALL $8B91              ;
  LD DE,$6950             ; Blank sprite: copy 72 zero bytes from 9300 to 6950
  LD HL,$9300             ;
  LD BC,$0048             ;
  LDIR                    ;
  POP AF                  ; Steps 24-22: normal helicopter sprite
  PUSH AF                 ;
  CP $16                  ;
  CALL NC,$8CA0           ;
  POP AF                  ;
  PUSH AF                 ;
  CP $12                  ; Step 18: explosion sound
  JR NZ,$9279             ;
  LD HL,$752D             ;
  INC (HL)                ;
  CP $14                  ; Steps 24-20: XOR an explosion overlay
  CALL NC,$92ED           ;
  CALL $7E10              ;
  CALL $86AF              ;
  CALL $762C              ;
  POP BC                  ;
  DJNZ $9256              ;
  LD A,($9245)            ; Turn the next helicopter (life) icon red: 5958 +
  ADD A,A                 ; 64*lives lost
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  LD HL,$5958             ;
  ADD A,L                 ;
  LD L,A                  ;
  LD (HL),$02             ;
  INC HL                  ;
  LD (HL),$02             ;
  LD A,($9245)            ; Lives lost +1; 3 = game over, back to the menu
  INC A                   ;
  LD ($9245),A            ;
  CP $03                  ;
  JP Z,MainMenu           ;
  CALL $82A7              ; Empty the fuel gauge
  LD A,($7516)            ;
  CP $01                  ;
  JR NZ,$92A9             ;
  LD HL,$7500             ; Copy the reset table 75C8 to 7500 (100 bytes),
  LD DE,$75C8             ; skipping $FF bytes
  LD B,$64                ;
  LD A,(DE)               ;
  CP $FF                  ;
  JR Z,$92C1              ;
  LD (HL),A               ;
  INC HL                  ;
  INC DE                  ;
  DJNZ $92BB              ;
  JP LifeStart            ; Resume the main loop
; This entry point is used by the routine at GameStart.
  LD A,$02                ; Time ran out (from 5BD1, 751C=$DE): set 2 lives
  LD ($9245),A            ; lost so that the next one ends the game, message "
  LD HL,$8A6E             ; NO TIME "
; This entry point is used by the routine at GameStart.
  LD DE,$4067             ; Entry from 5BEF with HL=5BF2 (" NO FUEL ", landed
  LD C,$09                ; off the helipad with an empty tank: costs one
  CALL $859A              ; life). Print the 9-character message at row 3,
  LD HL,$5867             ; column 7, attributes $47
  LD B,$09                ;
  LD (HL),$47             ;
  INC HL                  ;
  DJNZ $92DD              ;
  LD HL,$0466             ; Beep: ROM BEEPER, DE=$0300 cycles, HL=$0466 pitch
  LD DE,$0300             ;
  CALL $03B5              ;
  JR $928A                ; Join the life-lost code

; XOR the next explosion overlay onto the sprite
;
; XORs 72 bytes from (9243) onto the sprite buffer 6950 and advances 9243 by
; 72.
;
; I:(9243) overlay pointer
  LD HL,($9243)
  LD DE,$6950
  LD B,$48
  LD A,(DE)
  XOR (HL)
  LD (DE),A
  INC HL
  INC DE
  DJNZ $92F5
  LD ($9243),HL
  RET

; Island tile store
;
; The terrain of all 14 islands, one byte (tile ID) per map cell, stored as 150
; rows of 128 bytes (stride 128). Each island is a rectangular block somewhere
; in this store, located by the island table at F230 (record bytes 10-11 =
; address of the block's top-left cell, block width = rec[3]-rec[6]+1, height =
; rec[5]-rec[8]+1); blocks are packed side by side and may share sea rows. The
; window builder 76D2 copies a 23x29 part of the active island into the window
; buffer F74E (row stride 128 -> 23), the renderer 7E10 turns every tile into a
; column of character codes via the tables at 6300+level*256+tile, and 762C
; draws it.
;
; Tile IDs: 00 sea; 01-03 wave sparkles (only placed at run time by 8B91);
; 04-0E sea-level beach/rocks; 10-2C height 1; 30-54 height 2; 58-88 height 3;
; 8C-A4 height 4; B2-C1 height 5; D0-D8 height 6; E4-EB height 7 (class = count
; of 7AC2 entries <= tile, height = class/2). Odd classes are objects on that
; height: crates 0F/2F/57/8B (placed by ShuffleCrates), survivors
; 2D-2E/55-56/89-8A (placed by PlaceSurvivors), houses and trees (A5-B1, C2-CF,
; D9-E3, EC-EF), aircraft F6-FE (written into the window only). See
; re/notes/data.md and re/assets/terrain/tiles.json.
;
; Row 0 (9300-937F) is all zeros; 9246 also uses its first 72 bytes as a blank
; sprite to clear the helicopter buffer 6950.
;
; Island blocks (index: name, block address, width x height, world position of
; the block's top-left cell):
;
; 0: BANANA ISLAND at 9300 (store row 0, col 0), 55x29, world (626,412) =
; sector (2,1) local (114,156).
;
; 1: ORTE ROCKS at 9D00 (store row 20, col 0), 54x30, world (414,540) = sector
; (1,2) local (158,28).
;
; 2: KOKOLA ISLAND at A900 (store row 44, col 0), 53x29, world (365,176) =
; sector (1,0) local (109,176).
;
; 3: LAGOON ISLAND at B600 (store row 70, col 0), 66x29, world (138,212) =
; sector (0,0) local (138,212).
;
; 4: PEAK ISLAND at C300 (store row 96, col 0), 40x29, world (574,116) = sector
; (2,0) local (62,116).
;
; 5: BASE ISLAND at CF80 (store row 121, col 0), 81x29, world (306,364) =
; sector (1,1) local (50,108).
;
; 6: GILLIGANS ISLAND at $9354 (store row 0, col 84), 45x30, world (306,116) =
; sector (1,0) local (50,116).
;
; 7: RED ISLAND at 9FD8 (store row 25, col 88), 41x29, world (398,604) = sector
; (1,2) local (142,92).
;
; 8: SKEG ISLAND at ADD8 (store row 53, col 88), 40x29, world (134,540) =
; sector (0,2) local (134,28).
;
; 9: BONE ISLAND at $B843 (store row 74, col 67), 62x29, world (450,152) =
; sector (1,0) local (194,152).
;
; 10: GIANTS GATEWAY at $9337 (store row 0, col 55), 30x41, world (430,296) =
; sector (1,1) local (174,40).
;
; 11: CLAW ISLAND at $A735 (store row 40, col 53), 36x35, world (474,476) =
; sector (1,1) local (218,220).
;
; 12: LUKELAND ISLES at C628 (store row 102, col 40), 40x33, world (70,588) =
; sector (0,2) local (70,76).
;
; 13: ENTERPRISE ISLAND at $C64F (store row 102, col 79), 50x48, world (90,460)
; = sector (0,1) local (90,204).
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Row 0:
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; 0:Banana
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-54;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; 6:Gilligans
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; 84-128;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; 10:Giants
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 1: 0:Banana cols 0-54; 6:Gilligans
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 84-128; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$94,$8D,$8D ;
  DEFB $8E,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$3C,$31 ;
  DEFB $31,$31,$39,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$3C,$31,$32 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$38,$31,$31,$31,$39,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 2: 0:Banana cols 0-54; 6:Gilligans
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 84-128; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$93,$8C,$DE ;
  DEFB $8F,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$38,$31,$31,$30,$30 ;
  DEFB $30,$30,$33,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$37,$AD,$30 ;
  DEFB $32,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$38,$30,$30,$30,$30,$30,$31 ;
  DEFB $31,$31,$31,$31,$31,$32,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 3: 0:Banana cols 0-54; 6:Gilligans
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 84-128; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$97,$8C,$8C ;
  DEFB $8C,$8D,$8D,$8D,$8D,$8D,$8D,$8D ;
  DEFB $8D,$8D,$95,$59,$59,$59,$59,$5A ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $18,$11,$44,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$32,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$37,$30,$30 ;
  DEFB $33,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$32,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 4: 0:Banana cols 0-54; 6:Gilligans
  DEFB $00,$00,$00,$00,$38,$31,$31,$31 ; cols 84-128; 10:Giants cols 55-84
  DEFB $31,$31,$31,$31,$31,$30,$93,$8C ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$DE,$8C ;
  DEFB $8C,$8C,$8F,$58,$58,$58,$58,$58 ;
  DEFB $59,$59,$59,$59,$5A,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$18 ;
  DEFB $10,$10,$37,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$32,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$38,$31,$31,$31,$30,$30,$35 ;
  DEFB $3A,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$64,$59,$59,$59,$59,$59,$59 ;
  DEFB $59,$61,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 5: 0:Banana cols 0-54; 6:Gilligans
  DEFB $00,$38,$31,$31,$30,$30,$30,$30 ; cols 84-128; 10:Giants cols 55-84
  DEFB $30,$30,$30,$30,$30,$30,$93,$8C ;
  DEFB $E1,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8C,$8C,$8F,$CE,$CE,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$5B,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$17 ;
  DEFB $10,$10,$64,$59,$59,$59,$59,$59 ;
  DEFB $59,$65,$30,$30,$30,$32,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$B1,$30,$30,$30,$33,$10 ;
  DEFB $13,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$5B,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 6: 0:Banana cols 0-54; 6:Gilligans
  DEFB $00,$37,$30,$30,$68,$59,$59,$59 ; cols 84-128; 10:Giants cols 55-84
  DEFB $59,$59,$61,$30,$30,$30,$93,$8C ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8C,$8C,$8F,$58,$58,$58,$58,$CD ;
  DEFB $58,$58,$58,$58,$58,$59,$61,$31 ;
  DEFB $31,$32,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$17 ;
  DEFB $10,$10,$5F,$58,$B5,$B5,$B5,$58 ;
  DEFB $58,$5B,$30,$30,$30,$30,$32,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$86 ;
  DEFB $86,$86,$86,$4B,$30,$30,$33,$10 ;
  DEFB $13,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$5B,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 7: 0:Banana cols 0-54; 6:Gilligans
  DEFB $00,$37,$30,$30,$5F,$58,$58,$58 ; cols 84-128; 10:Giants cols 55-84
  DEFB $5D,$5D,$62,$30,$30,$30,$97,$91 ;
  DEFB $91,$91,$91,$91,$91,$91,$91,$91 ;
  DEFB $8C,$8C,$8F,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$5B,$30 ;
  DEFB $30,$30,$32,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$17 ;
  DEFB $64,$59,$58,$58,$B4,$B4,$B8,$58 ;
  DEFB $58,$5B,$30,$30,$30,$30,$30,$32 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$86 ;
  DEFB $86,$86,$86,$4B,$4D,$30,$33,$10 ;
  DEFB $13,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$58,$58,$58,$58,$58 ;
  DEFB $CF,$58,$59,$61,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 8: 0:Banana cols 0-54; 6:Gilligans
  DEFB $00,$37,$30,$30,$63,$5D,$5D,$62 ; cols 84-128; 10:Giants cols 55-84
  DEFB $30,$30,$30,$30,$30,$33,$04,$04 ;
  DEFB $04,$04,$04,$04,$04,$04,$04,$04 ;
  DEFB $93,$8C,$8F,$5D,$5D,$5D,$5D,$5D ;
  DEFB $5D,$5D,$5D,$5D,$58,$58,$58,$65 ;
  DEFB $30,$30,$33,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$17 ;
  DEFB $5F,$58,$58,$58,$7A,$7A,$7A,$7A ;
  DEFB $7A,$5B,$30,$30,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$86 ;
  DEFB $86,$86,$86,$4F,$4B,$4D,$30,$3D ;
  DEFB $13,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$58,$58,$5D,$5D,$5D ;
  DEFB $5D,$5D,$5D,$62,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$38,$31,$31,$31 ; Row 9: 0:Banana cols 0-54; 6:Gilligans
  DEFB $31,$30,$30,$30,$30,$30,$30,$30 ; cols 84-128; 10:Giants cols 55-84
  DEFB $30,$30,$35,$35,$35,$34,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$06 ;
  DEFB $93,$8C,$8F,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$5F,$58,$CF,$58 ;
  DEFB $65,$30,$33,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$70 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$7A ;
  DEFB $7A,$5B,$30,$30,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$30,$4F,$4B,$4D,$30 ;
  DEFB $31,$31,$31,$32,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$58,$5B,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$34,$00 ;
  DEFB $00,$00,$00,$38,$30,$30,$30,$30 ; Row 10: 0:Banana cols 0-54;
  DEFB $30,$30,$30,$30,$35,$35,$35,$35 ; 6:Gilligans cols 84-128; 10:Giants
  DEFB $35,$34,$00,$00,$00,$00,$00,$00 ; cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $92,$91,$96,$35,$35,$35,$35,$35 ;
  DEFB $35,$35,$30,$30,$5F,$58,$58,$CF ;
  DEFB $5B,$30,$30,$31,$32,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$60,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$7A ;
  DEFB $7A,$58,$65,$30,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$30,$30,$4F,$4B,$4D ;
  DEFB $30,$30,$30,$30,$32,$00,$00,$00 ;
  DEFB $00,$5F,$58,$58,$5B,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$35,$34,$00,$00 ;
  DEFB $00,$00,$38,$30,$68,$59,$61,$30 ; Row 11: 0:Banana cols 0-54;
  DEFB $30,$35,$35,$3E,$10,$10,$10,$10 ; 6:Gilligans cols 84-128; 10:Giants
  DEFB $14,$00,$00,$00,$00,$00,$00,$00 ; cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$06,$37,$30,$5F,$CC,$58,$58 ;
  DEFB $5B,$30,$30,$30,$33,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5F,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$7E ;
  DEFB $7A,$7C,$58,$65,$30,$30,$30,$30 ;
  DEFB $32,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $38,$30,$30,$30,$30,$30,$4F,$4B ;
  DEFB $4D,$30,$30,$30,$30,$31,$31,$31 ;
  DEFB $31,$5F,$58,$58,$5B,$30,$30,$30 ;
  DEFB $30,$30,$35,$3A,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$5F,$58,$5B,$30 ; Row 12: 0:Banana cols 0-54;
  DEFB $33,$15,$15,$15,$15,$15,$15,$14 ; 6:Gilligans cols 84-128; 10:Giants
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$5F,$58,$5D,$5D ;
  DEFB $62,$30,$35,$35,$3A,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5F,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $7E,$7A,$7C,$58,$65,$30,$30,$30 ;
  DEFB $30,$32,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$38 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$4B ;
  DEFB $4B,$4B,$4B,$30,$30,$30,$30,$30 ;
  DEFB $30,$5F,$58,$58,$5B,$30,$30,$30 ;
  DEFB $30,$33,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$63,$5D,$62,$30 ; Row 13: 0:Banana cols 0-54;
  DEFB $33,$00,$00,$00,$00,$00,$00,$00 ; 6:Gilligans cols 84-128; 10:Giants
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$5F,$5B,$30,$30 ;
  DEFB $30,$33,$10,$10,$13,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5F,$58 ;
  DEFB $58,$58,$58,$9C,$8D,$8D,$8D,$95 ;
  DEFB $58,$7E,$7A,$7C,$58,$59,$59,$59 ;
  DEFB $59,$61,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$38,$31,$31,$31,$31,$30 ;
  DEFB $30,$30,$98,$8D,$95,$30,$30,$9E ;
  DEFB $9E,$9E,$9E,$30,$30,$30,$30,$30 ;
  DEFB $30,$5F,$58,$58,$5B,$30,$30,$30 ;
  DEFB $30,$33,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$30,$30,$30,$30 ; Row 14: 0:Banana cols 0-54;
  DEFB $34,$00,$00,$00,$00,$00,$00,$00 ; 6:Gilligans cols 84-128; 10:Giants
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$63,$62,$30,$30 ;
  DEFB $30,$33,$10,$10,$1A,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5F,$58 ;
  DEFB $58,$58,$9C,$8C,$8C,$E3,$8C,$8F ;
  DEFB $58,$58,$7E,$7A,$7A,$7A,$B5,$B5 ;
  DEFB $58,$5B,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$30,$68,$59,$59 ;
  DEFB $59,$59,$93,$8C,$8F,$30,$30,$9D ;
  DEFB $9D,$A1,$9D,$30,$30,$30,$30,$30 ;
  DEFB $30,$67,$58,$58,$5B,$30,$30,$30 ;
  DEFB $30,$33,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$3B,$35,$35,$35,$35,$34 ; Row 15: 0:Banana cols 0-54;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 6:Gilligans cols 84-128; 10:Giants
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$36,$30,$30,$30,$30,$30 ;
  DEFB $30,$3E,$10,$13,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5E,$58 ;
  DEFB $98,$8D,$8C,$E3,$8C,$8C,$E3,$8F ;
  DEFB $58,$58,$58,$58,$B5,$B5,$B4,$B4 ;
  DEFB $58,$5B,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$68,$9C,$8D,$8D ;
  DEFB $8D,$8D,$8C,$E2,$8F,$30,$30,$30 ;
  DEFB $35,$35,$35,$35,$35,$35,$35,$35 ;
  DEFB $30,$30,$67,$5D,$62,$30,$30,$30 ;
  DEFB $30,$33,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 16: 0:Banana cols 0-54;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 6:Gilligans cols 84-128; 10:Giants
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$36,$35,$35,$35,$35 ;
  DEFB $3E,$10,$10,$13,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$5E ;
  DEFB $93,$8C,$8C,$8C,$91,$91,$91,$9A ;
  DEFB $58,$58,$58,$58,$B4,$B4,$58,$58 ;
  DEFB $58,$5B,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$64,$59,$9C,$8C,$8C,$8C ;
  DEFB $8C,$E2,$E2,$8C,$8F,$30,$30,$33 ;
  DEFB $15,$15,$15,$15,$15,$15,$15,$15 ;
  DEFB $37,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$33,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 17: 0:Banana cols 0-54;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 6:Gilligans cols 84-128; 10:Giants
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $16,$15,$15,$14,$00,$00,$00,$38 ;
  DEFB $31,$64,$59,$5A,$00,$00,$00,$00 ;
  DEFB $97,$91,$8C,$8F,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$5B,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$5F,$CF,$93,$8C,$8C,$8C ;
  DEFB $E8,$8C,$8C,$8C,$8F,$61,$30,$33 ;
  DEFB $04,$04,$04,$04,$04,$04,$04,$04 ;
  DEFB $37,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$33,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 18: 0:Banana cols 0-54;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 6:Gilligans cols 84-128; 10:Giants
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$37 ;
  DEFB $30,$5F,$CF,$58,$5A,$00,$00,$00 ;
  DEFB $00,$00,$92,$96,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$62,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$63,$5D,$97,$91,$8C,$E1 ;
  DEFB $8C,$8C,$8C,$91,$9A,$66,$30,$33 ;
  DEFB $04,$04,$04,$04,$04,$04,$04,$04 ;
  DEFB $37,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$3D,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 19: 0:Banana cols 0-54;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 6:Gilligans cols 84-128; 10:Giants
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$3B ;
  DEFB $35,$63,$5D,$CF,$58,$5A,$00,$00 ;
  DEFB $00,$00,$00,$63,$5D,$58,$58,$58 ;
  DEFB $58,$5D,$5D,$5D,$5D,$5D,$5D,$5D ;
  DEFB $62,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$30,$30,$97,$91 ;
  DEFB $91,$91,$96,$5D,$66,$30,$30,$33 ;
  DEFB $09,$0D,$09,$0D,$09,$0D,$09,$0D ;
  DEFB $37,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$32,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 20: 0:Banana cols 0-54; 1:Orte
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-53; 6:Gilligans cols 84-128;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$04,$04,$5F,$58,$9C,$8D,$8F ;
  DEFB $00,$00,$00,$00,$00,$5F,$58,$58 ;
  DEFB $66,$30,$30,$30,$30,$30,$34,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$3B,$35,$35,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$35,$35,$3A ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $36,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$31,$31,$39,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 21: 0:Banana cols 0-54; 1:Orte
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-53; 6:Gilligans cols 84-128;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$04,$04,$5F,$58,$93,$8C,$8F ;
  DEFB $00,$00,$00,$00,$00,$63,$5D,$66 ;
  DEFB $30,$30,$30,$30,$30,$34,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$37,$30,$30 ;
  DEFB $30,$30,$30,$30,$34,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$36,$35,$35,$35,$35,$35,$35 ;
  DEFB $35,$30,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 22: 0:Banana cols 0-54; 1:Orte
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-53; 6:Gilligans cols 84-128;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$04,$04,$5F,$58,$93,$8C,$9A ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$36 ;
  DEFB $35,$35,$35,$35,$34,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$3B,$35,$35 ;
  DEFB $35,$35,$35,$34,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$3B,$35,$35,$35,$35,$3A,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 23: 0:Banana cols 0-54; 1:Orte
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-53; 6:Gilligans cols 84-128;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$04,$04,$5F,$58,$93,$8F,$5B ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 24: 0:Banana cols 0-54; 1:Orte
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-53; 6:Gilligans cols 84-128;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$04,$04,$5F,$58,$97,$96,$58 ;
  DEFB $59,$59,$59,$59,$5A,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 25: 0:Banana cols 0-54; 1:Orte
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-53; 6:Gilligans cols 84-128;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 7:Red cols 88-128; 10:Giants cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $38,$31,$64,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$CB,$58,$58,$5A,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 26: 0:Banana cols 0-54; 1:Orte
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-53; 6:Gilligans cols 84-128;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 7:Red cols 88-128; 10:Giants cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$5F,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$61,$31 ;
  DEFB $39,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 27: 0:Banana cols 0-54; 1:Orte
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-53; 6:Gilligans cols 84-128;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 7:Red cols 88-128; 10:Giants cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$63,$5D,$5D,$5D,$5D,$5D ;
  DEFB $5D,$5D,$58,$58,$58,$58,$5B,$30 ;
  DEFB $33,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 28: 0:Banana cols 0-54; 1:Orte
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-53; 6:Gilligans cols 84-128;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 7:Red cols 88-128; 10:Giants cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$5F,$58,$58,$58,$5B,$30 ;
  DEFB $33,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$3C,$39 ; Row 29: 1:Orte cols 0-53; 6:Gilligans
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 84-128; 7:Red cols 88-128;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $36,$35,$35,$35,$35,$35,$35,$35 ;
  DEFB $30,$30,$5F,$A2,$B7,$B7,$5B,$30 ;
  DEFB $33,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ; Row 30: 1:Orte cols 0-53; 7:Red cols
  DEFB $32,$00,$00,$00,$00,$00,$00,$00 ; 88-128; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$5F,$A2,$B4,$B4,$5B,$30 ;
  DEFB $33,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ; Row 31: 1:Orte cols 0-53; 7:Red cols
  DEFB $30,$32,$00,$00,$00,$00,$00,$00 ; 88-128; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$1C,$11,$11 ;
  DEFB $19,$00,$00,$00,$00,$1C,$11,$11 ;
  DEFB $11,$19,$00,$00,$00,$00,$00,$00 ;
  DEFB $1C,$3C,$31,$31,$39,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$63,$5D,$5D,$5D,$62,$30 ;
  DEFB $30,$31,$39,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$3C,$31,$31,$31,$30,$30 ; Row 32: 1:Orte cols 0-53; 7:Red cols
  DEFB $30,$33,$00,$00,$00,$00,$00,$00 ; 88-128; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$17,$10,$10 ;
  DEFB $13,$00,$00,$00,$00,$17,$10,$10 ;
  DEFB $10,$13,$00,$00,$00,$00,$00,$00 ;
  DEFB $17,$37,$30,$30,$33,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $36,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$33,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$AD,$30,$30,$30 ; Row 33: 1:Orte cols 0-53; 7:Red cols
  DEFB $30,$3A,$00,$00,$00,$00,$00,$00 ; 88-128; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$18,$10,$10,$10 ;
  DEFB $10,$11,$11,$11,$11,$10,$10,$10 ;
  DEFB $10,$13,$00,$00,$00,$00,$00,$00 ;
  DEFB $17,$37,$AF,$30,$34,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$36,$B1,$B1,$30,$A0,$9E,$9E ;
  DEFB $30,$30,$34,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $1C,$11,$11,$12,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$30,$30,$30,$30 ; Row 34: 1:Orte cols 0-53; 7:Red cols
  DEFB $64,$59,$61,$00,$00,$00,$00,$00 ; 88-128; 10:Giants cols 55-84
  DEFB $00,$00,$00,$18,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$13,$00,$00,$00,$00,$00,$00 ;
  DEFB $17,$37,$30,$34,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$36,$35,$30,$9D,$A1,$9D ;
  DEFB $30,$33,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $17,$10,$10,$10,$11,$11,$12,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$36,$30,$30,$30,$30,$30 ; Row 35: 1:Orte cols 0-53; 7:Red cols
  DEFB $5F,$58,$5B,$00,$00,$00,$00,$00 ; 88-128; 10:Giants cols 55-84
  DEFB $00,$00,$00,$17,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$15,$15 ;
  DEFB $15,$1A,$00,$00,$00,$00,$00,$00 ;
  DEFB $1B,$3B,$3A,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$37,$30,$30,$30 ;
  DEFB $30,$33,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$38,$31,$31,$31 ;
  DEFB $31,$31,$31,$31,$31,$31,$39,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$38,$31 ;
  DEFB $31,$31,$31,$31,$31,$31,$31,$31 ;
  DEFB $32,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$36,$35,$35,$30,$30 ; Row 36: 1:Orte cols 0-53; 7:Red cols
  DEFB $5F,$58,$5B,$00,$00,$00,$00,$00 ; 88-128; 10:Giants cols 55-84
  DEFB $00,$00,$00,$3C,$31,$31,$39,$10 ;
  DEFB $10,$10,$10,$15,$15,$1A,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$37,$30,$30,$30 ;
  DEFB $30,$33,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$37,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$33,$0E ;
  DEFB $0A,$0E,$0A,$0E,$0A,$0E,$37,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$32,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ; Row 37: 1:Orte cols 0-53; 7:Red cols
  DEFB $5F,$CF,$5B,$00,$00,$00,$00,$00 ; 88-128; 10:Giants cols 55-84
  DEFB $00,$00,$00,$3B,$B1,$35,$3A,$15 ;
  DEFB $15,$15,$1A,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$36,$30,$30,$30 ;
  DEFB $30,$34,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$38,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$33,$04 ;
  DEFB $04,$04,$04,$04,$04,$04,$37,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$AF ;
  DEFB $30,$30,$31,$39,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ; Row 38: 1:Orte cols 0-53; 7:Red cols
  DEFB $63,$5D,$5C,$00,$00,$00,$00,$00 ; 88-128; 10:Giants cols 55-84
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$36,$30,$AC ;
  DEFB $33,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$38,$30,$30,$68,$59,$61 ;
  DEFB $30,$30,$30,$30,$30,$30,$33,$04 ;
  DEFB $04,$04,$04,$04,$04,$04,$37,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$33,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$3B,$3A ; Row 39: 1:Orte cols 0-53; 7:Red cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 88-128; 10:Giants cols 55-84
  DEFB $00,$00,$64,$59,$59,$59,$59,$59 ;
  DEFB $59,$61,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$36,$35 ;
  DEFB $3A,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$38,$30,$30,$68,$58,$58,$58 ;
  DEFB $59,$59,$61,$30,$30,$30,$30,$31 ;
  DEFB $31,$31,$31,$31,$31,$31,$30,$30 ;
  DEFB $30,$30,$30,$9E,$9E,$9E,$30,$30 ;
  DEFB $30,$30,$30,$33,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 40: 1:Orte cols 0-53; 7:Red cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 88-128; 10:Giants cols 55-84; 11:Claw
  DEFB $00,$00,$5F,$58,$58,$58,$58,$CF ; cols 53-88
  DEFB $CF,$5B,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$68,$58,$58,$CF,$58 ;
  DEFB $58,$58,$5B,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$9D,$9D,$A1,$30,$30 ;
  DEFB $30,$30,$30,$33,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 41: 1:Orte cols 0-53; 7:Red cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 88-128; 11:Claw cols 53-88
  DEFB $3C,$31,$63,$5D,$5D,$5D,$5D,$5D ;
  DEFB $5D,$5C,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$38,$31,$31,$31,$31,$31,$31 ;
  DEFB $31,$31,$39,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$5F,$58,$CF,$58,$58 ;
  DEFB $58,$58,$58,$59,$59,$59,$59,$59 ;
  DEFB $59,$59,$59,$59,$59,$59,$59,$59 ;
  DEFB $59,$59,$59,$61,$30,$30,$30,$30 ;
  DEFB $30,$AE,$30,$33,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 42: 1:Orte cols 0-53; 7:Red cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 88-128; 11:Claw cols 53-88
  DEFB $37,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $33,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $38,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$33,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$5F,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$5D,$5D,$5D,$5D ;
  DEFB $5D,$5D,$5D,$62,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$34,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 43: 1:Orte cols 0-53; 7:Red cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 88-128; 11:Claw cols 53-88
  DEFB $3B,$35,$35,$35,$35,$35,$35,$35 ;
  DEFB $3A,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$64,$59,$59,$61 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$AA ;
  DEFB $30,$30,$33,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$36,$30,$5F,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$5B,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$34,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 44: 1:Orte cols 0-53; 2:Kokola
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-52; 7:Red cols 88-128; 11:Claw
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $60,$59,$59,$59,$58,$58,$58,$5B ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$83,$83,$85,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$36,$5F,$58,$58,$58,$5D ;
  DEFB $5D,$58,$CF,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$5B,$30,$30,$30,$35 ;
  DEFB $35,$35,$35,$35,$30,$30,$30,$30 ;
  DEFB $30,$33,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 45: 1:Orte cols 0-53; 2:Kokola
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-52; 7:Red cols 88-128; 11:Claw
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$60 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $59,$59,$59,$65,$30,$30,$30,$B5 ;
  DEFB $B5,$B5,$82,$82,$32,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$5F,$58,$58,$5B,$30 ;
  DEFB $30,$63,$5D,$5D,$5D,$5D,$5D,$5D ;
  DEFB $5D,$5D,$5D,$66,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$36,$35,$35,$35 ;
  DEFB $35,$34,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 46: 1:Orte cols 0-53; 2:Kokola
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-52; 7:Red cols 88-128; 11:Claw
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$60,$58 ;
  DEFB $58,$9C,$8D,$8D,$8D,$8D,$8D,$95 ;
  DEFB $58,$58,$58,$58,$65,$30,$30,$B4 ;
  DEFB $B4,$B4,$30,$30,$30,$31,$31,$31 ;
  DEFB $31,$31,$31,$31,$31,$31,$32,$00 ;
  DEFB $00,$00,$00,$67,$5D,$5D,$62,$30 ;
  DEFB $35,$35,$35,$35,$35,$35,$35,$35 ;
  DEFB $35,$30,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 47: 1:Orte cols 0-53; 2:Kokola
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-52; 7:Red cols 88-128; 11:Claw
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5F,$58 ;
  DEFB $9C,$8C,$8C,$8C,$8C,$8C,$8C,$8F ;
  DEFB $58,$58,$58,$58,$5B,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$32 ;
  DEFB $00,$00,$00,$37,$30,$30,$30,$33 ;
  DEFB $1F,$1F,$1F,$1F,$00,$00,$00,$00 ;
  DEFB $00,$36,$30,$30,$30,$30,$30,$31 ;
  DEFB $39,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 48: 1:Orte cols 0-53; 2:Kokola
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-52; 7:Red cols 88-128; 11:Claw
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5F,$58 ;
  DEFB $93,$8C,$8C,$8C,$8C,$91,$91,$96 ;
  DEFB $58,$58,$5D,$5D,$62,$30,$30,$30 ;
  DEFB $30,$AB,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$68,$59,$59,$59,$59,$61 ;
  DEFB $00,$00,$00,$37,$30,$B1,$30,$33 ;
  DEFB $1F,$1F,$1F,$1F,$00,$00,$00,$00 ;
  DEFB $00,$00,$36,$35,$35,$35,$35,$35 ;
  DEFB $34,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 49: 1:Orte cols 0-53; 2:Kokola
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-52; 7:Red cols 88-128; 11:Claw
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5F,$58 ;
  DEFB $93,$8C,$8C,$8C,$8F,$58,$58,$58 ;
  DEFB $58,$66,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$68,$58,$58,$58,$CD,$58,$5B ;
  DEFB $00,$00,$00,$37,$30,$30,$30,$33 ;
  DEFB $1F,$1F,$1F,$1F,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 50: 2:Kokola cols 0-52; 7:Red cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 88-128; 11:Claw cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5F,$58 ;
  DEFB $93,$8C,$8C,$8C,$8F,$58,$C7,$58 ;
  DEFB $66,$30,$30,$30,$30,$35,$35,$35 ;
  DEFB $35,$35,$35,$35,$35,$30,$30,$30 ;
  DEFB $30,$63,$5D,$5D,$5D,$5D,$5D,$62 ;
  DEFB $00,$00,$00,$36,$35,$35,$35,$3A ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 51: 2:Kokola cols 0-52; 7:Red cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 88-128; 11:Claw cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5F,$58 ;
  DEFB $93,$8C,$8C,$8C,$8C,$99,$58,$5B ;
  DEFB $30,$30,$30,$30,$33,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$36,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 52: 2:Kokola cols 0-52; 7:Red cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 88-128; 11:Claw cols 53-88
  DEFB $00,$00,$00,$00,$00,$38,$31,$31 ;
  DEFB $98,$8D,$8D,$8D,$8D,$8D,$8D,$8D ;
  DEFB $8D,$8D,$8D,$8D,$8D,$8D,$8D,$8D ;
  DEFB $8E,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5F,$58 ;
  DEFB $9B,$8C,$8C,$8C,$8C,$8F,$58,$5B ;
  DEFB $30,$30,$30,$30,$33,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$36,$35 ;
  DEFB $35,$35,$30,$30,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 53: 2:Kokola cols 0-52; 7:Red cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 88-128; 8:Skeg cols 88-127; 11:Claw
  DEFB $00,$00,$00,$00,$38,$30,$AD,$30 ; cols 53-88
  DEFB $93,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8C,$8E,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5E,$58 ;
  DEFB $58,$9B,$91,$91,$8C,$8F,$58,$5B ;
  DEFB $30,$30,$30,$30,$33,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$3B,$35,$35,$35,$35,$3A ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 54: 2:Kokola cols 0-52; 8:Skeg
  DEFB $00,$00,$00,$00,$38,$31,$31,$31 ; cols 88-127; 11:Claw cols 53-88
  DEFB $31,$31,$31,$31,$30,$30,$30,$30 ;
  DEFB $97,$91,$91,$91,$91,$8C,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8C,$8C,$8D,$8D,$8D,$8D,$8D,$8D ;
  DEFB $E0,$E0,$8E,$00,$00,$00,$00,$5E ;
  DEFB $58,$58,$58,$58,$93,$8F,$58,$5B ;
  DEFB $30,$30,$30,$30,$33,$00,$00,$00 ;
  DEFB $18,$11,$11,$19,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$18,$11,$11 ;
  DEFB $11,$11,$11,$11,$11,$11,$11,$11 ;
  DEFB $11,$11,$11,$11,$11,$11,$11,$12 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 55: 2:Kokola cols 0-52; 8:Skeg
  DEFB $00,$00,$00,$38,$30,$30,$30,$30 ; cols 88-127; 11:Claw cols 53-88
  DEFB $30,$30,$30,$30,$30,$AF,$30,$30 ;
  DEFB $30,$30,$30,$30,$67,$9B,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $E2,$8C,$8C,$8C,$DE,$DE,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8E,$00,$00,$00,$00 ;
  DEFB $5F,$58,$58,$58,$97,$96,$58,$5B ;
  DEFB $30,$30,$30,$30,$33,$00,$00,$18 ;
  DEFB $10,$10,$10,$13,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$17,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$13 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$18,$11,$11 ; Row 56: 2:Kokola cols 0-52; 8:Skeg
  DEFB $11,$11,$11,$37,$30,$30,$30,$30 ; cols 88-127; 11:Claw cols 53-88
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$67,$9B,$91 ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8F,$00,$00,$00,$00 ;
  DEFB $5F,$58,$58,$58,$58,$58,$58,$66 ;
  DEFB $30,$30,$30,$30,$34,$00,$00,$17 ;
  DEFB $10,$10,$10,$10,$11,$19,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$17,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $11,$11,$11,$11,$11,$11,$12,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$18,$10,$10,$10 ; Row 57: 2:Kokola cols 0-52; 8:Skeg
  DEFB $10,$10,$10,$3B,$35,$30,$B1,$30 ; cols 88-127; 11:Claw cols 53-88
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $93,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8C,$8C,$E2,$8C,$8C,$8C,$8C,$DA ;
  DEFB $8C,$8C,$8C,$90,$00,$00,$00,$00 ;
  DEFB $5F,$58,$58,$58,$5D,$5D,$66,$30 ;
  DEFB $30,$30,$30,$34,$00,$00,$00,$17 ;
  DEFB $10,$10,$10,$10,$10,$13,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$1B,$15,$15 ;
  DEFB $15,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$12 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$17,$10,$10,$10 ; Row 58: 2:Kokola cols 0-52; 8:Skeg
  DEFB $10,$10,$10,$10,$10,$37,$30,$30 ; cols 88-127; 11:Claw cols 53-88
  DEFB $30,$30,$30,$35,$35,$35,$35,$64 ;
  DEFB $59,$61,$30,$30,$30,$30,$30,$30 ;
  DEFB $97,$91,$91,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8C,$8C,$8C,$E2,$E2,$8C,$8C,$8C ;
  DEFB $DA,$91,$96,$00,$00,$00,$00,$00 ;
  DEFB $5F,$58,$58,$5B,$30,$30,$30,$30 ;
  DEFB $30,$30,$34,$00,$00,$1C,$11,$10 ;
  DEFB $10,$10,$10,$15,$15,$1A,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$0C,$04 ;
  DEFB $04,$17,$10,$10,$10,$10,$10,$10 ;
  DEFB $70,$59,$59,$59,$59,$59,$59,$59 ;
  DEFB $59,$59,$6D,$10,$10,$10,$10,$13 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$17,$10,$10,$10 ; Row 59: 2:Kokola cols 0-52; 8:Skeg
  DEFB $10,$10,$10,$10,$10,$37,$30,$30 ; cols 88-127; 11:Claw cols 53-88
  DEFB $30,$30,$33,$04,$04,$04,$04,$5F ;
  DEFB $58,$5B,$30,$30,$30,$30,$30,$68 ;
  DEFB $58,$58,$58,$93,$8C,$8C,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8F,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $5E,$58,$58,$5B,$30,$30,$30,$30 ;
  DEFB $30,$33,$00,$00,$00,$1B,$15,$10 ;
  DEFB $10,$10,$14,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$0C,$04 ;
  DEFB $04,$17,$10,$10,$10,$10,$10,$70 ;
  DEFB $58,$58,$58,$75,$75,$75,$75,$58 ;
  DEFB $58,$58,$58,$6D,$10,$10,$10,$13 ;
  DEFB $08,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$1C,$11,$11,$10,$10,$10,$10 ; Row 60: 2:Kokola cols 0-52; 8:Skeg
  DEFB $10,$10,$10,$10,$3C,$30,$30,$30 ; cols 88-127; 11:Claw cols 53-88
  DEFB $30,$30,$33,$04,$04,$04,$04,$5F ;
  DEFB $58,$5B,$30,$30,$30,$30,$68,$58 ;
  DEFB $58,$58,$58,$93,$8C,$8C,$8C,$E1 ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8F,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$5B,$30,$30,$30,$30 ;
  DEFB $30,$33,$00,$00,$00,$00,$00,$1B ;
  DEFB $15,$14,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$0C,$04 ;
  DEFB $04,$17,$10,$10,$10,$10,$10,$5F ;
  DEFB $58,$58,$58,$75,$75,$75,$75,$58 ;
  DEFB $58,$58,$58,$58,$59,$59,$59,$59 ;
  DEFB $59,$59,$59,$59,$5A,$00,$00,$00 ;
  DEFB $00,$17,$10,$10,$10,$10,$10,$10 ; Row 61: 2:Kokola cols 0-52; 8:Skeg
  DEFB $10,$10,$10,$10,$3B,$35,$30,$30 ; cols 88-127; 11:Claw cols 53-88
  DEFB $30,$30,$34,$00,$00,$06,$64,$58 ;
  DEFB $58,$58,$59,$59,$59,$59,$58,$58 ;
  DEFB $58,$58,$58,$93,$8C,$8C,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$91 ;
  DEFB $96,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$5B,$30,$30,$30,$30 ;
  DEFB $30,$34,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$0C,$04 ;
  DEFB $04,$17,$10,$10,$40,$31,$31,$5F ;
  DEFB $58,$58,$58,$75,$75,$75,$75,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$5B,$00,$00,$00 ;
  DEFB $00,$1B,$15,$10,$10,$10,$10,$10 ; Row 62: 2:Kokola cols 0-52; 8:Skeg
  DEFB $10,$10,$10,$10,$10,$10,$3F,$35 ; cols 88-127; 11:Claw cols 53-88
  DEFB $35,$34,$00,$00,$00,$00,$63,$5D ;
  DEFB $5D,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$93,$8C,$8C,$8C,$8C ;
  DEFB $8C,$8C,$91,$91,$91,$91,$96,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$5B,$30,$30,$30,$30 ;
  DEFB $34,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$18,$11,$11 ;
  DEFB $11,$10,$10,$10,$37,$B1,$30,$5F ;
  DEFB $58,$CE,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$5B,$00,$00,$00 ;
  DEFB $00,$00,$00,$17,$10,$10,$10,$10 ; Row 63: 2:Kokola cols 0-52; 8:Skeg
  DEFB $10,$10,$10,$10,$10,$10,$10,$13 ; cols 88-127; 11:Claw cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$5E,$58,$58,$58,$58,$58,$58 ;
  DEFB $98,$8D,$8D,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8C,$9A,$58,$58,$5B,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$5B,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$18,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$37,$30,$30,$5F ;
  DEFB $58,$58,$58,$5D,$5D,$5D,$5D,$5D ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$CC ;
  DEFB $58,$58,$58,$58,$5B,$00,$00,$00 ;
  DEFB $00,$00,$00,$1B,$15,$15,$15,$15 ; Row 64: 2:Kokola cols 0-52; 8:Skeg
  DEFB $15,$15,$15,$15,$15,$15,$15,$14 ; cols 88-127; 11:Claw cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$5E,$58,$58,$58,$58,$58 ;
  DEFB $93,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $9A,$58,$58,$C7,$5B,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$5B,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$38,$31,$31,$31,$31 ;
  DEFB $32,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$17,$10,$10,$40 ;
  DEFB $31,$31,$31,$31,$30,$30,$30,$67 ;
  DEFB $5D,$5D,$62,$9E,$9E,$9E,$30,$30 ;
  DEFB $5F,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $98,$8D,$8D,$95,$5B,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 65: 2:Kokola cols 0-52; 8:Skeg
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 88-127; 11:Claw cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$5E,$5D,$5D,$5D,$5D ;
  DEFB $97,$91,$91,$91,$91,$91,$91,$9A ;
  DEFB $58,$58,$58,$58,$58,$59,$59,$59 ;
  DEFB $59,$61,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$5B,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$30,$30,$30 ;
  DEFB $30,$31,$31,$31,$32,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$17,$10,$10,$37 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$9D,$9D,$9D,$30,$30 ;
  DEFB $5F,$58,$58,$58,$58,$58,$CF,$58 ;
  DEFB $93,$8C,$8C,$8F,$5B,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 66: 2:Kokola cols 0-52; 8:Skeg
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 88-127; 11:Claw cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$5F,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$75,$75,$75,$75 ;
  DEFB $58,$58,$5A,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$5B,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$31,$39,$00 ;
  DEFB $00,$00,$00,$00,$17,$10,$10,$3B ;
  DEFB $35,$35,$35,$35,$35,$35,$35,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $5F,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $93,$8C,$8C,$8C,$8D,$95,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 67: 2:Kokola cols 0-52; 8:Skeg
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 88-127; 11:Claw cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$5E,$5D,$5D,$5D ;
  DEFB $58,$58,$58,$58,$75,$75,$75,$75 ;
  DEFB $58,$58,$5B,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$58,$65,$30,$30,$30 ;
  DEFB $31,$31,$31,$31,$31,$31,$31,$31 ;
  DEFB $31,$31,$31,$30,$30,$64,$59,$59 ;
  DEFB $65,$30,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$17,$10,$10,$10 ;
  DEFB $13,$00,$00,$00,$00,$00,$06,$37 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $67,$58,$58,$58,$58,$58,$9C,$8D ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8F,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 68: 2:Kokola cols 0-52; 8:Skeg
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 88-127; 11:Claw cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $5F,$58,$58,$58,$75,$75,$75,$75 ;
  DEFB $58,$58,$5B,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$58,$58,$65,$30,$30 ;
  DEFB $30,$30,$30,$30,$B1,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$5F,$58,$58 ;
  DEFB $58,$59,$59,$59,$59,$61,$33,$00 ;
  DEFB $00,$00,$00,$00,$16,$15,$15,$15 ;
  DEFB $1A,$00,$00,$00,$00,$00,$00,$37 ;
  DEFB $30,$AE,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$67,$5D,$5D,$5D,$9C,$8C,$8C ;
  DEFB $8C,$E1,$8C,$E3,$8C,$8F,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 69: 2:Kokola cols 0-52; 8:Skeg
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 88-127; 11:Claw cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $5E,$5D,$5D,$5D,$5D,$5D,$5D,$5D ;
  DEFB $5D,$5D,$5C,$00,$00,$00,$00,$00 ;
  DEFB $00,$5E,$5D,$5D,$5D,$62,$35,$35 ;
  DEFB $35,$35,$30,$30,$30,$B1,$30,$30 ;
  DEFB $30,$30,$30,$30,$68,$58,$CD,$58 ;
  DEFB $5D,$5D,$5D,$5D,$5D,$62,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$36 ;
  DEFB $30,$30,$AF,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$93,$8C,$8C ;
  DEFB $E1,$8C,$8C,$8C,$8C,$90,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 70: 2:Kokola cols 0-52; 3:Lagoon
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-65; 8:Skeg cols 88-127; 11:Claw
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$30,$30,$30,$30 ;
  DEFB $30,$64,$59,$59,$58,$58,$5D,$62 ;
  DEFB $30,$30,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $36,$30,$30,$30,$30,$30,$30,$35 ;
  DEFB $35,$35,$35,$35,$35,$93,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8C,$8F,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 71: 2:Kokola cols 0-52; 3:Lagoon
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-65; 8:Skeg cols 88-127; 11:Claw
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$3B,$35,$35,$35,$30,$30 ;
  DEFB $30,$63,$5D,$5D,$5D,$62,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$92,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8C,$8F,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 72: 2:Kokola cols 0-52; 3:Lagoon
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-65; 8:Skeg cols 88-127; 11:Claw
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$36,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $35,$35,$35,$35,$35,$35,$34,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$3B,$35,$35,$35,$35,$3A,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$92,$91 ;
  DEFB $91,$8C,$8C,$8C,$8F,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$98,$8D ; Row 73: 3:Lagoon cols 0-65; 8:Skeg
  DEFB $8D,$8D,$8D,$8D,$8D,$8E,$00,$00 ; cols 88-127; 11:Claw cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$38 ;
  DEFB $31,$31,$64,$59,$59,$59,$59,$59 ;
  DEFB $59,$59,$5A,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$36 ;
  DEFB $35,$35,$35,$35,$35,$35,$35,$34 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$97,$91,$91,$96,$00,$00,$00 ;
  DEFB $00,$00,$00,$94,$8D,$8D,$8C,$8C ; Row 74: 3:Lagoon cols 0-65; 8:Skeg
  DEFB $8C,$8C,$8C,$8C,$E3,$8F,$00,$00 ; cols 88-127; 9:Bone cols 67-128;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 11:Claw cols 53-88
  DEFB $00,$00,$00,$00,$00,$00,$38,$30 ;
  DEFB $30,$30,$5F,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$5B,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$94,$8C,$8C,$8C,$8C,$8C ; Row 75: 3:Lagoon cols 0-65; 8:Skeg
  DEFB $8C,$8C,$8C,$8C,$8C,$8F,$00,$00 ; cols 88-127; 9:Bone cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$3C,$31,$31,$30,$30 ;
  DEFB $30,$30,$5F,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$59,$59,$59,$59,$59 ;
  DEFB $59,$61,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$93,$8C,$8C,$8C,$8C,$8C ; Row 76: 3:Lagoon cols 0-65; 8:Skeg
  DEFB $8C,$8C,$8C,$91,$91,$96,$00,$00 ; cols 88-127; 9:Bone cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$30,$30,$30 ;
  DEFB $30,$30,$5F,$58,$58,$58,$5D,$5D ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$5B,$08,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$93,$8C,$8C,$8C,$8C,$8C ; Row 77: 3:Lagoon cols 0-65; 8:Skeg
  DEFB $8C,$90,$00,$00,$00,$00,$00,$00 ; cols 88-127; 9:Bone cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$30,$68,$59 ;
  DEFB $59,$59,$58,$58,$5D,$62,$30,$30 ;
  DEFB $63,$5D,$5D,$5D,$58,$58,$58,$58 ;
  DEFB $58,$58,$59,$59,$59,$59,$61,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$97,$8C,$8C,$8C,$8C,$8C ; Row 78: 3:Lagoon cols 0-65; 8:Skeg
  DEFB $8C,$00,$00,$00,$00,$00,$00,$00 ; cols 88-127; 9:Bone cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$30,$5F,$58 ;
  DEFB $58,$5D,$5D,$66,$33,$10,$10,$10 ;
  DEFB $10,$10,$37,$30,$63,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$5B,$08 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$5F,$93,$8C,$8C,$8C,$8C ; Row 79: 3:Lagoon cols 0-65; 8:Skeg
  DEFB $8F,$00,$00,$00,$00,$00,$00,$00 ; cols 88-127; 9:Bone cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$30,$5F,$58 ;
  DEFB $5B,$30,$30,$30,$33,$10,$10,$10 ;
  DEFB $10,$10,$37,$30,$30,$5F,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$5B,$31 ;
  DEFB $31,$31,$31,$31,$31,$32,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$5F,$93,$8C,$8C,$8C,$8C ; Row 80: 3:Lagoon cols 0-65; 8:Skeg
  DEFB $8F,$00,$00,$00,$00,$00,$00,$00 ; cols 88-127; 9:Bone cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$30,$5F,$58 ;
  DEFB $5B,$30,$30,$30,$33,$10,$10,$10 ;
  DEFB $10,$10,$37,$30,$30,$5F,$58,$5D ;
  DEFB $5D,$5D,$5D,$5D,$5D,$5D,$62,$30 ;
  DEFB $30,$9E,$9E,$9E,$30,$30,$32,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$5F,$93,$8C,$8C,$8C,$91 ; Row 81: 3:Lagoon cols 0-65; 8:Skeg
  DEFB $96,$00,$00,$00,$00,$00,$00,$00 ; cols 88-127; 9:Bone cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$38,$30,$30,$30,$5F,$58 ;
  DEFB $5B,$30,$30,$30,$30,$31,$31,$64 ;
  DEFB $59,$59,$59,$59,$59,$58,$5B,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$A1,$9D,$9D,$30,$30,$30,$32 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$5F,$93,$8C,$8C,$8F,$58 ; Row 82: 3:Lagoon cols 0-65; 9:Bone
  DEFB $58,$59,$59,$59,$61,$00,$00,$00 ; cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$38,$30,$30,$30,$30,$63,$5D ;
  DEFB $58,$59,$59,$61,$30,$30,$30,$5F ;
  DEFB $58,$58,$58,$58,$58,$5D,$62,$35 ;
  DEFB $35,$35,$35,$35,$35,$35,$35,$30 ;
  DEFB $30,$30,$30,$30,$30,$AF,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$60,$59,$59,$59,$5A,$00 ;
  DEFB $00,$00,$5F,$93,$8C,$8C,$9A,$58 ; Row 83: 3:Lagoon cols 0-65; 9:Bone
  DEFB $58,$58,$58,$58,$5B,$00,$00,$00 ; cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $38,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $67,$58,$58,$5B,$30,$30,$30,$5F ;
  DEFB $58,$58,$58,$58,$5C,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$3B ;
  DEFB $35,$35,$35,$30,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$38,$31 ;
  DEFB $31,$31,$31,$31,$31,$31,$32,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$18 ;
  DEFB $11,$11,$11,$11,$11,$64,$59,$59 ;
  DEFB $59,$59,$58,$58,$58,$58,$5B,$00 ;
  DEFB $00,$00,$5F,$97,$91,$9A,$58,$58 ; Row 84: 3:Lagoon cols 0-65; 9:Bone
  DEFB $58,$58,$58,$58,$5B,$00,$00,$00 ; cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$5F,$58,$58,$59,$59,$59,$58 ;
  DEFB $5D,$5D,$5D,$5C,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$32 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$17 ;
  DEFB $10,$10,$10,$10,$10,$5F,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$5B,$00 ;
  DEFB $00,$00,$5F,$58,$58,$58,$58,$58 ; Row 85: 3:Lagoon cols 0-65; 9:Bone
  DEFB $58,$58,$58,$58,$5B,$08,$00,$00 ; cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$30,$30,$35,$35,$35,$35 ;
  DEFB $35,$63,$5D,$58,$58,$58,$58,$5B ;
  DEFB $10,$10,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$3C,$30,$B0,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ;
  DEFB $64,$59,$59,$59,$65,$30,$30,$30 ;
  DEFB $31,$31,$39,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$07,$17 ;
  DEFB $10,$10,$70,$59,$59,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$5B,$00 ;
  DEFB $00,$00,$5E,$58,$58,$58,$CF,$58 ; Row 86: 3:Lagoon cols 0-65; 9:Bone
  DEFB $B9,$B5,$B5,$58,$5B,$31,$39,$08 ; cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$3C ;
  DEFB $30,$30,$30,$33,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$5E,$58,$58,$58,$5B ;
  DEFB $10,$10,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$38,$30,$30,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ;
  DEFB $5F,$58,$58,$58,$58,$65,$30,$30 ;
  DEFB $30,$30,$33,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$1C,$11,$11,$10 ;
  DEFB $10,$70,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$5B,$00 ;
  DEFB $00,$00,$00,$5E,$58,$58,$58,$58 ; Row 87: 3:Lagoon cols 0-65; 9:Bone
  DEFB $B4,$B4,$B4,$58,$5B,$30,$30,$31 ; cols 67-128
  DEFB $31,$31,$39,$00,$00,$00,$00,$37 ;
  DEFB $30,$30,$30,$33,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$5E,$5D,$5D,$62 ;
  DEFB $10,$10,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$38,$31 ;
  DEFB $31,$30,$30,$30,$30,$30,$98,$95 ;
  DEFB $00,$00,$00,$00,$00,$60,$59,$59 ;
  DEFB $58,$58,$58,$58,$58,$58,$59,$61 ;
  DEFB $30,$30,$30,$39,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$07,$17,$10,$10,$10 ;
  DEFB $70,$58,$58,$58,$9C,$8D,$8D,$8D ;
  DEFB $8D,$95,$58,$58,$58,$58,$5B,$00 ;
  DEFB $00,$00,$00,$00,$5E,$5D,$5D,$5D ; Row 88: 3:Lagoon cols 0-65; 9:Bone
  DEFB $5D,$5D,$5D,$5D,$62,$35,$35,$35 ; cols 67-128
  DEFB $35,$30,$33,$00,$00,$3C,$31,$30 ;
  DEFB $30,$30,$30,$33,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$17,$10,$10 ;
  DEFB $10,$10,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$93,$8F ;
  DEFB $00,$00,$00,$00,$60,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $59,$59,$59,$59,$5A,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$1C ;
  DEFB $11,$11,$11,$11,$10,$10,$10,$10 ;
  DEFB $5F,$58,$58,$9C,$8C,$8C,$8C,$E3 ;
  DEFB $8C,$8F,$58,$58,$58,$5D,$62,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 89: 3:Lagoon cols 0-65; 9:Bone
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 67-128
  DEFB $06,$37,$33,$00,$00,$3B,$35,$30 ;
  DEFB $30,$B0,$30,$30,$32,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$17,$10,$10 ;
  DEFB $10,$10,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ;
  DEFB $9C,$8D,$8D,$8D,$8D,$8D,$8C,$8F ;
  DEFB $00,$00,$00,$00,$5F,$58,$58,$98 ;
  DEFB $8D,$95,$58,$58,$58,$58,$98,$8D ;
  DEFB $95,$58,$58,$58,$58,$5A,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$17 ;
  DEFB $10,$10,$10,$10,$64,$59,$59,$59 ;
  DEFB $58,$58,$58,$93,$8C,$8C,$E3,$8C ;
  DEFB $8C,$8F,$58,$58,$5B,$33,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 90: 3:Lagoon cols 0-65; 9:Bone
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 67-128
  DEFB $00,$37,$33,$00,$00,$00,$00,$37 ;
  DEFB $30,$30,$30,$30,$33,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$17,$10,$10 ;
  DEFB $10,$10,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ;
  DEFB $93,$8C,$8C,$8C,$8C,$8C,$8C,$8F ;
  DEFB $00,$00,$00,$00,$5F,$58,$58,$93 ;
  DEFB $8C,$8F,$58,$58,$58,$58,$93,$8C ;
  DEFB $8F,$58,$58,$58,$58,$58,$59,$59 ;
  DEFB $59,$59,$59,$59,$59,$59,$59,$59 ;
  DEFB $59,$59,$59,$59,$59,$59,$59,$6D ;
  DEFB $10,$10,$10,$10,$5F,$58,$58,$58 ;
  DEFB $58,$58,$98,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8C,$9A,$58,$58,$5B,$33,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 91: 3:Lagoon cols 0-65; 9:Bone
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 67-128
  DEFB $00,$3B,$3A,$00,$00,$00,$00,$3B ;
  DEFB $35,$35,$35,$35,$3A,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$17,$10,$10 ;
  DEFB $10,$10,$10,$12,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ;
  DEFB $93,$8C,$8C,$8C,$8C,$8C,$8C,$90 ;
  DEFB $00,$00,$00,$00,$5F,$58,$58,$93 ;
  DEFB $8C,$8C,$8D,$8D,$8D,$8D,$8C,$8C ;
  DEFB $8C,$95,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$CF,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $59,$59,$59,$59,$58,$58,$58,$58 ;
  DEFB $58,$58,$93,$8C,$8C,$8C,$91,$91 ;
  DEFB $9A,$58,$58,$5D,$62,$33,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 92: 3:Lagoon cols 0-65; 9:Bone
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$18,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$12,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$3C,$31,$30,$30 ;
  DEFB $93,$8C,$8C,$8C,$8C,$8C,$90,$00 ;
  DEFB $00,$00,$00,$00,$5F,$58,$58,$93 ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$E2 ;
  DEFB $8C,$8F,$58,$58,$58,$58,$5D,$5D ;
  DEFB $5D,$5D,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$9B,$8C,$8C,$8F,$58,$58 ;
  DEFB $58,$58,$66,$30,$30,$30,$32,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 93: 3:Lagoon cols 0-65; 9:Bone
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$3C,$31,$31,$39,$00 ;
  DEFB $00,$00,$00,$18,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$12,$00,$00 ;
  DEFB $00,$00,$00,$00,$3B,$35,$35,$35 ;
  DEFB $97,$91,$91,$91,$91,$90,$00,$00 ;
  DEFB $00,$00,$00,$00,$5F,$58,$58,$93 ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$8C ;
  DEFB $8C,$9A,$58,$58,$58,$5B,$30,$30 ;
  DEFB $30,$30,$67,$5D,$5D,$5D,$5D,$5D ;
  DEFB $5D,$5D,$5D,$5D,$5D,$5D,$5D,$5D ;
  DEFB $5D,$5D,$5D,$5D,$5D,$5D,$5D,$5D ;
  DEFB $5D,$58,$58,$9B,$91,$96,$58,$58 ;
  DEFB $58,$66,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 94: 3:Lagoon cols 0-65; 9:Bone
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$3B,$35,$35,$3A,$11 ;
  DEFB $11,$11,$11,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$11,$11 ;
  DEFB $19,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$5F,$58,$58,$93 ;
  DEFB $8C,$E3,$8C,$D3,$D3,$D3,$8C,$8C ;
  DEFB $9A,$58,$58,$58,$58,$5B,$30,$30 ;
  DEFB $A9,$30,$35,$35,$35,$35,$35,$35 ;
  DEFB $35,$35,$35,$35,$35,$35,$35,$35 ;
  DEFB $35,$35,$35,$35,$35,$35,$35,$35 ;
  DEFB $35,$6B,$58,$58,$58,$58,$58,$58 ;
  DEFB $5B,$30,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 95: 3:Lagoon cols 0-65; 9:Bone
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$1B,$15,$15,$15,$15 ;
  DEFB $15,$15,$15,$15,$15,$15,$15,$15 ;
  DEFB $15,$15,$15,$15,$15,$15,$15,$15 ;
  DEFB $1A,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$5E,$58,$58,$9B ;
  DEFB $8C,$8C,$8C,$D2,$D2,$D2,$8C,$9A ;
  DEFB $58,$58,$58,$58,$58,$5B,$30,$30 ;
  DEFB $30,$34,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$5E,$58,$58,$58,$58,$58 ;
  DEFB $5B,$30,$30,$30,$AF,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 96: 3:Lagoon cols 0-65; 4:Peak
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-39; 9:Bone cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$5E,$58,$58 ;
  DEFB $9B,$8C,$8C,$8C,$8C,$8C,$8F,$58 ;
  DEFB $58,$58,$58,$58,$58,$5B,$35,$35 ;
  DEFB $34,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$5F,$58,$58,$58,$58 ;
  DEFB $5B,$30,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 97: 3:Lagoon cols 0-65; 4:Peak
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-39; 9:Bone cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5F,$58 ;
  DEFB $58,$97,$91,$91,$91,$91,$96,$58 ;
  DEFB $58,$58,$58,$58,$58,$5C,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$63,$5D,$5D,$5D,$5D ;
  DEFB $62,$30,$30,$B0,$30,$30,$34,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 98: 3:Lagoon cols 0-65; 4:Peak
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; cols 0-39; 9:Bone cols 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5F,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$5D,$5D,$5C,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$37,$30,$B1,$30 ;
  DEFB $30,$30,$30,$30,$30,$34,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 99: 4:Peak cols 0-39; 9:Bone cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 67-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$5E,$58 ;
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$5C,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$3B,$35,$35,$35 ;
  DEFB $30,$30,$30,$30,$33,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 100: 4:Peak cols 0-39; 9:Bone cols
  DEFB $1C,$11,$11,$11,$11,$11,$11,$11 ; 67-128
  DEFB $11,$11,$11,$19,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$1C,$11 ;
  DEFB $11,$11,$11,$11,$11,$12,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$5E ;
  DEFB $5D,$5D,$5D,$5D,$5D,$5D,$5D,$5D ;
  DEFB $5C,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $3B,$35,$35,$35,$3A,$00,$00,$00 ;
  DEFB $00,$00,$00,$18,$10,$10,$10,$10 ; Row 101: 4:Peak cols 0-39; 9:Bone cols
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ; 67-128
  DEFB $10,$10,$10,$13,$0E,$0A,$0E,$0A ;
  DEFB $0E,$0A,$0E,$0A,$0E,$0A,$17,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$12,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$3B,$35,$35,$35,$35,$3A,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$17,$10,$10,$10,$10 ; Row 102: 4:Peak cols 0-39; 9:Bone cols
  DEFB $10,$10,$40,$31,$31,$31,$39,$10 ; 67-128; 12:Lukeland cols 40-79;
  DEFB $10,$10,$10,$10,$11,$11,$11,$11 ; 13:Enterprise cols 79-128
  DEFB $11,$11,$11,$11,$11,$11,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$13,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$17,$10,$10,$10,$10 ; Row 103: 4:Peak cols 0-39; 12:Lukeland
  DEFB $10,$40,$30,$30,$30,$30,$33,$10 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$3C ;
  DEFB $31,$3D,$10,$10,$10,$15,$1A,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$38,$31,$31,$39,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$17,$10,$10,$10,$10 ; Row 104: 4:Peak cols 0-39; 12:Lukeland
  DEFB $40,$30,$30,$30,$30,$30,$33,$10 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$3C,$30 ;
  DEFB $30,$30,$3D,$10,$13,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$3C,$31,$31,$31 ;
  DEFB $31,$31,$31,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$17,$10,$10,$10,$40 ; Row 105: 4:Peak cols 0-39; 12:Lukeland
  DEFB $30,$30,$30,$30,$30,$30,$30,$31 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $31,$31,$31,$31,$31,$31,$31,$31 ;
  DEFB $31,$31,$31,$31,$31,$31,$30,$30 ;
  DEFB $30,$30,$33,$10,$13,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $18,$11,$19,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$38,$31 ;
  DEFB $31,$31,$31,$31,$31,$31,$39,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$37,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$17,$10,$10,$10,$37 ; Row 106: 4:Peak cols 0-39; 12:Lukeland
  DEFB $30,$30,$30,$68,$59,$59,$59,$59 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $59,$59,$59,$59,$9C,$8D,$8D,$8D ;
  DEFB $95,$59,$59,$65,$30,$30,$30,$30 ;
  DEFB $30,$30,$33,$10,$13,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$18 ;
  DEFB $10,$10,$13,$08,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$38,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$35,$3A,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$37,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$AF,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$17,$10,$10,$10,$37 ; Row 107: 4:Peak cols 0-39; 12:Lukeland
  DEFB $30,$30,$68,$58,$58,$58,$9C,$8D ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $8D,$8D,$8D,$8D,$8C,$8C,$8C,$91 ;
  DEFB $96,$58,$58,$58,$65,$30,$30,$30 ;
  DEFB $30,$30,$33,$10,$13,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$18,$10 ;
  DEFB $10,$10,$10,$11,$11,$11,$19,$00 ;
  DEFB $00,$00,$00,$00,$00,$37,$30,$30 ;
  DEFB $B1,$30,$30,$30,$33,$0B,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$37,$30,$68,$59 ;
  DEFB $61,$30,$30,$30,$30,$30,$30,$31 ;
  DEFB $31,$31,$31,$31,$32,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$17,$10,$10,$10,$37 ; Row 108: 4:Peak cols 0-39; 12:Lukeland
  DEFB $30,$30,$5F,$58,$58,$9C,$8C,$E8 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $8C,$8C,$91,$91,$91,$91,$96,$58 ;
  DEFB $58,$58,$58,$58,$5B,$30,$30,$30 ;
  DEFB $30,$30,$33,$10,$10,$11,$19,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$17,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$13,$00 ;
  DEFB $00,$00,$00,$00,$00,$37,$30,$30 ;
  DEFB $30,$30,$30,$30,$33,$0B,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$38,$31,$31,$30,$68,$58,$58 ;
  DEFB $98,$8D,$95,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$32,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$18,$10,$10,$10,$40,$30 ; Row 109: 4:Peak cols 0-39; 12:Lukeland
  DEFB $30,$30,$5F,$58,$58,$93,$8C,$91 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $91,$96,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$5D,$5D,$62,$30,$30,$30 ;
  DEFB $30,$30,$33,$10,$10,$10,$13,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$3C,$31 ;
  DEFB $31,$31,$31,$31,$39,$1B,$1A,$00 ;
  DEFB $00,$00,$00,$00,$00,$3B,$35,$35 ;
  DEFB $35,$30,$30,$30,$33,$0B,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $38,$30,$30,$30,$68,$58,$58,$58 ;
  DEFB $93,$8C,$8F,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$33,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$18,$10,$10,$10,$40,$30,$30 ; Row 110: 4:Peak cols 0-39; 12:Lukeland
  DEFB $30,$68,$58,$58,$58,$97,$96,$58 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $58,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$5B,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$33,$10,$10,$10,$13,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$B1 ;
  DEFB $30,$30,$30,$30,$33,$05,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$16,$10 ;
  DEFB $10,$37,$30,$30,$30,$31,$39,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$30,$68,$58,$58,$58,$58 ;
  DEFB $93,$8C,$8C,$8D,$8D,$8D,$8D,$95 ;
  DEFB $65,$30,$30,$30,$30,$33,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$17,$10,$10,$10,$37,$30,$30 ; Row 111: 4:Peak cols 0-39; 12:Lukeland
  DEFB $68,$58,$58,$58,$58,$58,$58,$58 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $5D,$5D,$5D,$5D,$5D,$5D,$5D,$5D ;
  DEFB $5D,$62,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$33,$10,$45,$45,$45,$45 ;
  DEFB $00,$00,$00,$00,$00,$00,$3B,$35 ;
  DEFB $35,$35,$35,$35,$3A,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$16 ;
  DEFB $10,$37,$30,$35,$35,$35,$3A,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$30,$5F,$98,$8D,$8D,$8D ;
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$96 ;
  DEFB $58,$65,$30,$30,$30,$33,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$17,$10,$10,$10,$37,$30,$30 ; Row 112: 4:Peak cols 0-39; 12:Lukeland
  DEFB $5F,$58,$58,$58,$58,$58,$58,$5B ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$B1,$30,$30,$30 ;
  DEFB $AE,$30,$33,$10,$45,$45,$45,$45 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $16,$37,$33,$05,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$30,$5F,$93,$8C,$8C,$8C ;
  DEFB $8C,$8C,$91,$91,$91,$91,$96,$58 ;
  DEFB $58,$5B,$30,$30,$30,$33,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$17,$10,$10,$10,$37,$30,$30 ; Row 113: 4:Peak cols 0-39; 12:Lukeland
  DEFB $63,$5D,$5D,$5D,$5D,$5D,$5D,$62 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $30,$30,$30,$35,$35,$35,$35,$35 ;
  DEFB $35,$30,$30,$30,$30,$30,$30,$B1 ;
  DEFB $30,$30,$33,$10,$45,$45,$45,$45 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$33,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$30,$5F,$93,$8C,$8C,$8C ;
  DEFB $8C,$9A,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$5B,$30,$30,$30,$33,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$17,$10,$10,$10,$37,$30,$30 ; Row 114: 4:Peak cols 0-39; 12:Lukeland
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $30,$30,$3E,$10,$10,$10,$10,$10 ;
  DEFB $10,$37,$B1,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$33,$10,$10,$10,$13,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$3B,$3A,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$30,$5F,$97,$91,$91,$91 ;
  DEFB $9A,$58,$58,$CF,$58,$58,$58,$58 ;
  DEFB $58,$66,$30,$30,$30,$33,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$17,$10,$10,$10,$3B,$35,$35 ; Row 115: 4:Peak cols 0-39; 12:Lukeland
  DEFB $35,$35,$35,$35,$35,$35,$35,$35 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $35,$3E,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$37,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$3E,$10,$10,$10,$13,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $60,$59,$61,$00,$00,$00,$00,$00 ;
  DEFB $36,$30,$30,$5F,$58,$58,$58,$58 ;
  DEFB $58,$58,$5D,$5D,$5D,$5D,$CF,$5D ;
  DEFB $66,$30,$30,$30,$30,$33,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$17,$10,$10,$10,$10,$10,$10 ; Row 116: 4:Peak cols 0-39; 12:Lukeland
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$3B,$35,$35,$35,$35,$35,$35 ;
  DEFB $35,$3E,$10,$10,$10,$10,$13,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $5F,$CF,$5B,$00,$00,$00,$00,$00 ;
  DEFB $00,$36,$30,$5F,$58,$58,$58,$CF ;
  DEFB $58,$5B,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$33,$00,$00 ;
  DEFB $00,$00,$00,$3C,$31,$31,$32,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$16,$10,$10,$10,$10,$10,$10 ; Row 117: 4:Peak cols 0-39; 12:Lukeland
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$13,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $63,$5D,$62,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$5F,$58,$58,$58,$58 ;
  DEFB $5D,$66,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$34,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$16,$10,$10,$10,$10,$10 ; Row 118: 4:Peak cols 0-39; 12:Lukeland
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $10,$10,$15,$15,$15,$15,$15,$15 ;
  DEFB $15,$15,$15,$15,$15,$15,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$14,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$5F,$58,$58,$58,$5B ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$34,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$16,$10,$10,$10,$10 ; Row 119: 4:Peak cols 0-39; 12:Lukeland
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $10,$14,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$16,$10 ;
  DEFB $10,$10,$10,$10,$10,$14,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$63,$5D,$58,$58,$5B ;
  DEFB $30,$30,$35,$35,$35,$35,$35,$35 ;
  DEFB $35,$35,$35,$34,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$30,$30,$31 ;
  DEFB $31,$31,$31,$31,$31,$39,$00,$00 ;
  DEFB $00,$00,$3C,$31,$31,$31,$32,$00 ;
  DEFB $00,$00,$00,$00,$16,$15,$15,$15 ; Row 120: 4:Peak cols 0-39; 12:Lukeland
  DEFB $15,$15,$15,$15,$15,$15,$15,$15 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $14,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$16 ;
  DEFB $15,$15,$15,$15,$14,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$30,$67,$5D,$62 ;
  DEFB $30,$33,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$13,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$3B,$35,$35,$30,$30 ;
  DEFB $9E,$9E,$9E,$30,$30,$30,$31,$31 ;
  DEFB $31,$31,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 121: 4:Peak cols 0-39; 5:Base cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 0-80; 12:Lukeland cols 40-79;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 13:Enterprise cols 79-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$3B,$35,$30,$30,$30,$30 ;
  DEFB $30,$33,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$13,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ;
  DEFB $9D,$9D,$A1,$30,$30,$64,$59,$59 ;
  DEFB $59,$59,$59,$61,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 122: 4:Peak cols 0-39; 5:Base cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 0-80; 12:Lukeland cols 40-79;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 13:Enterprise cols 79-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$38 ;
  DEFB $31,$31,$31,$39,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$37,$30,$30,$30 ;
  DEFB $83,$83,$83,$83,$10,$10,$10,$10 ;
  DEFB $10,$13,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ;
  DEFB $30,$30,$30,$30,$30,$63,$5D,$5D ;
  DEFB $58,$58,$58,$5B,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 123: 4:Peak cols 0-39; 5:Base cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 0-80; 12:Lukeland cols 40-79;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 13:Enterprise cols 79-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$38,$31,$39,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$38,$B1 ;
  DEFB $30,$30,$35,$3A,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$37,$30,$30,$30 ;
  DEFB $82,$82,$82,$82,$45,$45,$10,$10 ;
  DEFB $10,$13,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$3B,$35 ;
  DEFB $35,$35,$35,$35,$35,$35,$30,$30 ;
  DEFB $5F,$58,$58,$66,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 124: 4:Peak cols 0-39; 5:Base cols
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 0-80; 12:Lukeland cols 40-79;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 13:Enterprise cols 79-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $38,$30,$30,$33,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$37,$30 ;
  DEFB $30,$33,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$3B,$85,$85,$35 ;
  DEFB $35,$3A,$10,$10,$10,$45,$10,$10 ;
  DEFB $10,$13,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$17,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$37,$30 ;
  DEFB $63,$5D,$66,$30,$30,$30,$34,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 125: 5:Base cols 0-80; 12:Lukeland
  DEFB $00,$00,$00,$00,$00,$98,$8D,$8D ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $8D,$8D,$8D,$95,$31,$31,$32,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$30,$30,$31,$31,$31,$31 ;
  DEFB $31,$31,$31,$31,$31,$31,$31,$31 ;
  DEFB $31,$31,$31,$32,$00,$00,$3B,$30 ;
  DEFB $AF,$33,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$17,$84,$84,$10 ;
  DEFB $10,$10,$10,$10,$10,$45,$10,$10 ;
  DEFB $10,$14,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$17,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$37,$30 ;
  DEFB $30,$30,$30,$30,$30,$34,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$98,$8D ; Row 126: 5:Base cols 0-80; 12:Lukeland
  DEFB $8D,$8D,$8D,$8D,$8D,$8C,$8C,$8C ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $8C,$8C,$8C,$8F,$30,$30,$30,$32 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $3B,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$33,$00,$00,$00,$37 ;
  DEFB $30,$33,$00,$00,$00,$00,$3C,$31 ;
  DEFB $31,$31,$31,$31,$32,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$17,$10,$45,$10 ;
  DEFB $10,$10,$10,$10,$10,$45,$10,$10 ;
  DEFB $14,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$17,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$37,$30 ;
  DEFB $30,$30,$30,$B1,$33,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$93,$8C ; Row 127: 5:Base cols 0-80; 12:Lukeland
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$8C ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $8C,$8C,$8C,$8F,$30,$30,$30,$30 ;
  DEFB $31,$31,$32,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$64,$59,$59,$59,$59,$59,$61 ;
  DEFB $30,$9E,$9E,$9E,$30,$30,$30,$30 ;
  DEFB $35,$35,$35,$3A,$00,$00,$00,$37 ;
  DEFB $30,$33,$00,$00,$00,$00,$37,$30 ;
  DEFB $30,$30,$30,$30,$30,$32,$00,$00 ;
  DEFB $00,$00,$00,$00,$17,$10,$45,$10 ;
  DEFB $10,$10,$10,$10,$85,$85,$10,$14 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$17,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$3B,$35 ;
  DEFB $35,$35,$35,$35,$3A,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$94,$8C,$8C ; Row 128: 5:Base cols 0-80; 12:Lukeland
  DEFB $8C,$8C,$8C,$8C,$8C,$8C,$8C,$8C ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $8C,$8C,$8C,$8F,$59,$59,$61,$30 ;
  DEFB $30,$30,$30,$41,$11,$11,$11,$11 ;
  DEFB $11,$12,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$58,$58,$58,$58,$5B ;
  DEFB $30,$9D,$9D,$9D,$30,$30,$30,$33 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$36 ;
  DEFB $35,$34,$00,$38,$31,$31,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$33,$00,$00 ;
  DEFB $00,$00,$00,$00,$17,$10,$45,$45 ;
  DEFB $45,$45,$45,$45,$84,$84,$13,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$17,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$94,$8C,$8C,$8C ; Row 129: 5:Base cols 0-80; 12:Lukeland
  DEFB $8C,$8C,$8C,$91,$91,$91,$91,$91 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $91,$91,$91,$9A,$58,$58,$5B,$30 ;
  DEFB $30,$30,$30,$33,$10,$10,$10,$10 ;
  DEFB $10,$10,$12,$00,$00,$00,$00,$00 ;
  DEFB $00,$5F,$58,$CD,$58,$5D,$5D,$62 ;
  DEFB $35,$35,$35,$35,$35,$35,$35,$3A ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$38,$30,$30,$30,$30,$30 ;
  DEFB $83,$83,$83,$30,$30,$33,$00,$00 ;
  DEFB $00,$00,$00,$00,$16,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$13,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$17,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$13,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$93,$8C,$8C,$8C ; Row 130: 5:Base cols 0-80; 12:Lukeland
  DEFB $91,$91,$9A,$58,$58,$58,$58,$58 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $58,$58,$58,$58,$58,$58,$58,$59 ;
  DEFB $59,$59,$59,$61,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$11,$11,$19,$00,$00 ;
  DEFB $00,$5F,$58,$58,$5B,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$B1,$30,$30,$82 ;
  DEFB $82,$82,$82,$30,$30,$34,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$16,$15,$15 ;
  DEFB $10,$10,$10,$10,$10,$10,$13,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$18,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$14,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$97,$91,$91,$96 ; Row 131: 5:Base cols 0-80; 12:Lukeland
  DEFB $58,$58,$58,$5D,$5D,$5D,$5D,$5D ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $5D,$5D,$5D,$5D,$5D,$5D,$5D,$58 ;
  DEFB $58,$58,$58,$5B,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$13,$00,$00 ;
  DEFB $00,$5F,$58,$58,$5B,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$30,$30,$35,$35 ;
  DEFB $35,$35,$35,$35,$34,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $16,$10,$10,$10,$10,$10,$13,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$18,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$14,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$3C,$31,$31,$30,$30,$5F,$58 ; Row 132: 5:Base cols 0-80; 12:Lukeland
  DEFB $58,$58,$66,$30,$30,$30,$30,$35 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $35,$35,$35,$35,$35,$30,$30,$5F ;
  DEFB $58,$58,$CF,$58,$59,$59,$6D,$10 ;
  DEFB $10,$10,$10,$10,$10,$13,$00,$00 ;
  DEFB $00,$63,$5D,$5D,$62,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$3B,$35,$35,$3A,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$16,$10,$10,$10,$10,$10,$11 ;
  DEFB $11,$11,$12,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$18,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$15,$15,$15,$15 ;
  DEFB $14,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$30,$30,$30,$5F,$58 ; Row 133: 5:Base cols 0-80; 12:Lukeland
  DEFB $58,$5B,$30,$A9,$30,$B1,$33,$10 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $10,$10,$10,$10,$10,$37,$30,$5F ;
  DEFB $58,$58,$58,$58,$CF,$58,$58,$6D ;
  DEFB $10,$10,$10,$10,$10,$13,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$17,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$12,$00,$00,$00,$00 ;
  DEFB $38,$31,$31,$31,$31,$31,$31,$39 ;
  DEFB $10,$10,$10,$13,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$30,$30,$30,$5F,$58 ; Row 134: 5:Base cols 0-80; 12:Lukeland
  DEFB $58,$5B,$30,$30,$AE,$30,$33,$10 ; cols 40-79; 13:Enterprise cols 79-128
  DEFB $10,$10,$10,$10,$10,$3B,$35,$63 ;
  DEFB $5D,$5D,$5D,$58,$58,$58,$58,$5B ;
  DEFB $10,$10,$10,$10,$10,$13,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$17,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$12,$00,$00,$38 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$33 ;
  DEFB $10,$10,$10,$13,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$30,$30,$30,$5F,$58 ; Row 135: 5:Base cols 0-80;
  DEFB $58,$5B,$30,$30,$30,$30,$33,$10 ; 13:Enterprise cols 79-128
  DEFB $83,$83,$83,$10,$10,$10,$10,$10 ;
  DEFB $3B,$35,$30,$5F,$58,$58,$58,$5B ;
  DEFB $10,$10,$10,$10,$10,$13,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$3C ;
  DEFB $31,$31,$31,$31,$31,$32,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$17,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$11,$11,$37 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $31,$31,$31,$31,$31,$32,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$30,$30,$30,$5F,$58 ; Row 136: 5:Base cols 0-80;
  DEFB $58,$58,$61,$30,$30,$30,$33,$10 ; 13:Enterprise cols 79-128
  DEFB $82,$82,$82,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$37,$5F,$58,$58,$CF,$5B ;
  DEFB $10,$10,$10,$10,$10,$13,$00,$00 ;
  DEFB $00,$00,$1C,$11,$11,$19,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$3C,$31,$31,$31,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$32,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$17,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$37 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$32,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$3B,$35,$30,$30,$64,$58,$58 ; Row 137: 5:Base cols 0-80;
  DEFB $58,$58,$5B,$30,$30,$35,$3A,$10 ; 13:Enterprise cols 79-128
  DEFB $10,$24,$24,$24,$24,$24,$24,$24 ;
  DEFB $10,$10,$37,$5F,$58,$58,$58,$5B ;
  DEFB $10,$10,$10,$10,$10,$14,$00,$00 ;
  DEFB $00,$18,$10,$10,$10,$10,$11,$11 ;
  DEFB $11,$11,$11,$11,$11,$11,$11,$11 ;
  DEFB $11,$11,$11,$11,$11,$11,$11,$11 ;
  DEFB $11,$11,$11,$37,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$17,$10,$10,$10,$10,$40 ;
  DEFB $31,$31,$31,$31,$31,$31,$31,$30 ;
  DEFB $30,$64,$59,$59,$59,$59,$59,$59 ;
  DEFB $65,$30,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$5F,$58,$58 ; Row 138: 5:Base cols 0-80;
  DEFB $58,$58,$5B,$30,$33,$10,$10,$10 ; 13:Enterprise cols 79-128
  DEFB $1F,$1F,$1F,$1F,$10,$10,$24,$24 ;
  DEFB $10,$10,$37,$5F,$58,$58,$58,$5B ;
  DEFB $10,$10,$10,$15,$14,$00,$00,$00 ;
  DEFB $18,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$3C ;
  DEFB $31,$31,$31,$30,$64,$59,$59,$8D ;
  DEFB $8D,$8D,$8D,$95,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$17,$10,$10,$10,$10,$37 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$5F,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$65,$30,$30,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$5F,$58,$CE ; Row 139: 5:Base cols 0-80;
  DEFB $58,$58,$5B,$30,$33,$10,$10,$10 ; 13:Enterprise cols 79-128
  DEFB $1F,$1F,$1F,$1F,$10,$10,$24,$24 ;
  DEFB $10,$10,$37,$5F,$58,$58,$58,$66 ;
  DEFB $31,$31,$39,$00,$00,$00,$00,$00 ;
  DEFB $3C,$31,$31,$39,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$40,$30 ;
  DEFB $30,$30,$68,$59,$58,$58,$58,$93 ;
  DEFB $8C,$8C,$E3,$8F,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$3C,$31,$31,$31,$31,$30 ;
  DEFB $30,$30,$30,$30,$64,$59,$59,$59 ;
  DEFB $59,$58,$58,$58,$58,$58,$58,$58 ;
  DEFB $58,$58,$59,$61,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$5F,$58,$58 ; Row 140: 5:Base cols 0-80;
  DEFB $58,$58,$5B,$30,$33,$10,$10,$10 ; 13:Enterprise cols 79-128
  DEFB $1F,$1F,$1F,$1F,$10,$10,$83,$83 ;
  DEFB $83,$83,$37,$5F,$58,$58,$66,$30 ;
  DEFB $30,$30,$33,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$30,$33,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$40,$30,$30 ;
  DEFB $30,$98,$8D,$8D,$8D,$8D,$8D,$8C ;
  DEFB $8C,$8C,$8C,$8F,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$5F,$58,$58,$58 ;
  DEFB $58,$9C,$8D,$8D,$8D,$8D,$8D,$8D ;
  DEFB $8D,$8D,$8D,$95,$30,$30,$30,$31 ;
  DEFB $31,$39,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$37,$30,$63,$58,$58 ; Row 141: 5:Base cols 0-80;
  DEFB $58,$58,$5B,$30,$33,$10,$10,$10 ; 13:Enterprise cols 79-128
  DEFB $10,$10,$10,$10,$10,$10,$84,$84 ;
  DEFB $82,$82,$37,$5F,$58,$5B,$30,$30 ;
  DEFB $30,$30,$33,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$30,$30,$3D,$10,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$83,$83 ;
  DEFB $83,$3C,$31,$31,$31,$30,$30,$30 ;
  DEFB $30,$93,$8C,$8C,$E8,$8C,$B5,$B5 ;
  DEFB $B5,$B5,$8C,$8F,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$3B,$35,$35,$35,$35,$35 ;
  DEFB $35,$35,$30,$30,$5F,$58,$CC,$58 ;
  DEFB $9C,$8C,$8C,$D3,$D3,$D3,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8F,$30,$30,$30,$30 ;
  DEFB $30,$33,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$3C,$31,$30,$30,$30,$5F,$58 ; Row 142: 5:Base cols 0-80;
  DEFB $CF,$58,$5B,$30,$33,$10,$10,$10 ; 13:Enterprise cols 79-128
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$37,$5F,$58,$5B,$30,$30 ;
  DEFB $30,$30,$3A,$00,$00,$00,$00,$60 ;
  DEFB $59,$65,$30,$B1,$30,$3D,$10,$10 ;
  DEFB $10,$10,$10,$10,$10,$10,$82,$82 ;
  DEFB $82,$37,$30,$9E,$9E,$9E,$30,$64 ;
  DEFB $59,$97,$91,$91,$8C,$8C,$B4,$B4 ;
  DEFB $B4,$B4,$8C,$8F,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$5F,$58,$58,$58 ;
  DEFB $93,$8C,$8C,$D2,$D2,$D2,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8C,$95,$30,$30,$30 ;
  DEFB $30,$33,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$30,$30,$30,$5F,$58 ; Row 143: 5:Base cols 0-80;
  DEFB $58,$58,$5B,$30,$33,$10,$10,$10 ; 13:Enterprise cols 79-128
  DEFB $10,$10,$10,$10,$10,$10,$10,$10 ;
  DEFB $10,$10,$37,$5F,$58,$5B,$30,$30 ;
  DEFB $30,$33,$00,$00,$00,$00,$60,$58 ;
  DEFB $58,$5B,$30,$30,$30,$30,$31,$31 ;
  DEFB $31,$31,$31,$31,$31,$31,$31,$31 ;
  DEFB $31,$30,$30,$A1,$9D,$9D,$30,$5F ;
  DEFB $58,$58,$58,$58,$9B,$8C,$8C,$8C ;
  DEFB $8C,$8C,$8C,$8F,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$67,$58,$58,$58 ;
  DEFB $97,$91,$91,$91,$91,$91,$8C,$8C ;
  DEFB $8C,$E3,$8C,$8C,$8F,$30,$30,$30 ;
  DEFB $30,$33,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$37,$30,$30,$64,$59,$58,$58 ; Row 144: 5:Base cols 0-80;
  DEFB $58,$58,$62,$30,$30,$31,$31,$31 ; 13:Enterprise cols 79-128
  DEFB $31,$31,$31,$39,$10,$10,$10,$10 ;
  DEFB $10,$10,$37,$5F,$58,$5B,$30,$30 ;
  DEFB $30,$33,$00,$00,$00,$00,$5F,$58 ;
  DEFB $CD,$58,$59,$59,$59,$59,$59,$59 ;
  DEFB $59,$59,$59,$61,$30,$30,$30,$30 ;
  DEFB $30,$B1,$30,$30,$30,$30,$30,$67 ;
  DEFB $58,$58,$58,$58,$58,$9B,$91,$91 ;
  DEFB $91,$91,$91,$96,$30,$30,$33,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$37,$30,$30,$67,$5D,$5D ;
  DEFB $5D,$5D,$5D,$5D,$5D,$5D,$93,$8C ;
  DEFB $8C,$8C,$8C,$8C,$8F,$30,$30,$AF ;
  DEFB $30,$33,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$36,$30,$30,$63,$5D,$5D,$5D ; Row 145: 5:Base cols 0-80;
  DEFB $5D,$66,$30,$30,$30,$30,$AF,$30 ; 13:Enterprise cols 79-128
  DEFB $30,$30,$30,$30,$31,$31,$64,$59 ;
  DEFB $59,$59,$59,$58,$58,$5B,$30,$64 ;
  DEFB $59,$61,$00,$00,$00,$00,$5F,$58 ;
  DEFB $58,$58,$58,$58,$58,$5D,$5D,$5D ;
  DEFB $5D,$5D,$5D,$62,$30,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $67,$5D,$5D,$5D,$5D,$5D,$5D,$62 ;
  DEFB $30,$30,$30,$30,$30,$30,$34,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$3B,$35,$35,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$93,$8C ;
  DEFB $8C,$8C,$8C,$8C,$8F,$30,$30,$30 ;
  DEFB $30,$33,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$36,$30,$30,$30,$30,$30 ; Row 146: 5:Base cols 0-80;
  DEFB $30,$30,$30,$AF,$30,$30,$30,$30 ; 13:Enterprise cols 79-128
  DEFB $30,$30,$30,$30,$30,$30,$63,$5D ;
  DEFB $5D,$5D,$5D,$5D,$5D,$62,$30,$63 ;
  DEFB $5D,$62,$00,$00,$00,$00,$63,$5D ;
  DEFB $5D,$5D,$5D,$5D,$66,$30,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$35 ;
  DEFB $35,$35,$35,$35,$35,$35,$30,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$30,$35,$35,$35,$34,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$36,$35,$35 ;
  DEFB $30,$30,$30,$30,$30,$30,$97,$91 ;
  DEFB $91,$91,$91,$91,$96,$30,$30,$30 ;
  DEFB $30,$34,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$36,$30,$30,$30,$30 ; Row 147: 5:Base cols 0-80;
  DEFB $30,$30,$30,$30,$35,$35,$35,$35 ; 13:Enterprise cols 79-128
  DEFB $35,$35,$35,$35,$35,$35,$35,$35 ;
  DEFB $35,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$34,$00,$00,$00,$00,$00,$3B ;
  DEFB $30,$30,$30,$30,$30,$30,$35,$35 ;
  DEFB $35,$35,$35,$35,$35,$35,$34,$00 ;
  DEFB $00,$00,$00,$00,$00,$06,$37,$30 ;
  DEFB $30,$30,$30,$30,$30,$30,$30,$30 ;
  DEFB $30,$33,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $37,$30,$30,$35,$35,$35,$35,$35 ;
  DEFB $35,$35,$35,$35,$35,$35,$35,$35 ;
  DEFB $34,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$36,$35,$35,$35 ; Row 148: 5:Base cols 0-80;
  DEFB $35,$35,$35,$3A,$00,$00,$00,$00 ; 13:Enterprise cols 79-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$3B,$35,$35,$35,$35,$35,$35 ;
  DEFB $35,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $36,$35,$35,$35,$35,$34,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$36,$35 ;
  DEFB $35,$35,$35,$35,$35,$35,$35,$35 ;
  DEFB $35,$34,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $3B,$35,$3A,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Row 149: 5:Base cols 0-80;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; 13:Enterprise cols 79-128
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;

; Aircraft sprite frames
;
; 16 frames of 72 bytes, one per direction (frame n = n*22.5 degrees clockwise
; from north/up; the code adds 8 modulo 16 in the south view). Each frame is a
; 24x24 image stored column-major: bytes 0-23 are the left 8-pixel column (top
; to bottom), 24-47 the middle column, 48-71 the right column; equivalently 9
; characters in column order. 8995 copies the current frame (DDB8+72*(index+1))
; to FBE0 (terrain chars 3C-44) and an AND AA/55 dithered copy to FB98 (chars
; 33-3B, the shadow); the plane is then drawn as window tiles F6-FE.
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$1F,$1F,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Frame 0 (0
  DEFB $00,$1C,$1C,$3E,$3E,$3E,$3E,$3E,$3E,$FF,$FF,$FF,$FF,$1C,$1C,$14,$77,$F7,$08,$08,$00,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$F0,$FC,$FC,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$1E,$1F,$0F,$03,$05,$07,$07,$1F,$0F,$07,$06,$00,$00,$00,$00,$00 ; Frame 1
  DEFB $00,$00,$03,$0F,$1F,$1F,$3F,$3F,$7E,$FA,$FC,$F7,$FF,$FF,$F1,$E0,$C0,$E0,$E0,$00,$00,$00,$00,$00 ; (22.5
  DEFB $00,$00,$00,$80,$80,$80,$00,$00,$00,$00,$00,$00,$C0,$F0,$F0,$20,$00,$00,$00,$00,$00,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$00,$00,$00,$07,$07,$03,$01,$00,$09,$1F,$1F,$0F,$0F,$03,$00,$00,$00,$00,$00,$00,$00 ; Frame 2
  DEFB $00,$00,$00,$00,$01,$03,$07,$EF,$FF,$FE,$FD,$FB,$FF,$FF,$F7,$83,$C1,$C0,$00,$00,$00,$00,$00,$00 ; (45
  DEFB $00,$00,$00,$C0,$F0,$F0,$F0,$E0,$C0,$80,$00,$00,$00,$80,$C0,$C0,$E0,$E0,$40,$00,$00,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$00,$00,$01,$01,$00,$00,$2E,$7F,$3F,$1F,$1F,$0F,$07,$07,$00,$00,$00,$00,$00,$00,$00 ; Frame 3
  DEFB $00,$00,$00,$00,$00,$C0,$E0,$F3,$FF,$FF,$FE,$FB,$FE,$FE,$1E,$0F,$0F,$07,$06,$00,$00,$00,$00,$00 ; (67.5
  DEFB $00,$00,$00,$00,$00,$00,$78,$F4,$F8,$F8,$E0,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$00,$00,$00,$60,$70,$78,$7F,$7F,$7F,$7F,$31,$30,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Frame 4
  DEFB $00,$00,$00,$00,$00,$60,$70,$70,$70,$FF,$FF,$FF,$EA,$FF,$78,$78,$70,$70,$70,$60,$00,$00,$00,$00 ; (90
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$E0,$E8,$FE,$FE,$FC,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$00,$20,$30,$38,$38,$3E,$3F,$1F,$3F,$33,$01,$00,$00,$01,$03,$03,$01,$00,$00,$00,$00 ; Frame 5
  DEFB $00,$00,$00,$00,$00,$00,$03,$07,$07,$8E,$FE,$FE,$FF,$DF,$F7,$FF,$F3,$E0,$C0,$00,$00,$00,$00,$00 ; (112.5
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$E0,$E8,$D8,$FC,$78,$00,$00,$00,$00,$00,$00 ; degrees)
  DEFB $00,$04,$06,$06,$07,$07,$0F,$1F,$1F,$01,$01,$00,$00,$01,$07,$0F,$1F,$1C,$00,$00,$00,$00,$00,$00 ; Frame 6
  DEFB $00,$00,$00,$00,$80,$80,$80,$E1,$F3,$FF,$FF,$FF,$FF,$EF,$F7,$FB,$87,$03,$01,$00,$00,$00,$00,$00 ; (135
  DEFB $00,$00,$00,$00,$00,$00,$C0,$E0,$C0,$80,$80,$00,$00,$80,$C0,$E0,$E0,$D0,$F0,$F8,$70,$00,$00,$00 ; degrees)
  DEFB $00,$01,$01,$01,$01,$0F,$0F,$01,$01,$00,$00,$00,$03,$1F,$3F,$38,$00,$00,$00,$00,$00,$00,$00,$00 ; Frame 7
  DEFB $00,$00,$00,$00,$E0,$F0,$C0,$C0,$E0,$F1,$FF,$FF,$FF,$DE,$FE,$2F,$1F,$1C,$0F,$07,$03,$00,$00,$00 ; (157.5
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$60,$F0,$E0,$80,$00,$00,$00,$00,$00,$80,$80,$80,$80,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$1F,$1F,$07,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Frame 8
  DEFB $08,$08,$08,$08,$FF,$7F,$1C,$14,$1C,$FF,$FF,$FF,$FF,$3E,$3E,$3E,$3E,$22,$3E,$1C,$1C,$00,$00,$00 ; (180
  DEFB $00,$00,$00,$00,$80,$00,$00,$00,$00,$FC,$FC,$F0,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$06,$0F,$07,$01,$00,$00,$00,$00,$00,$01,$01,$01,$01,$00,$00,$00 ; Frame 9
  DEFB $00,$00,$00,$00,$07,$0F,$03,$03,$07,$8F,$FF,$FF,$FF,$7B,$7F,$F4,$F8,$38,$F0,$E0,$C0,$00,$00,$00 ; (202.5
  DEFB $00,$80,$80,$80,$80,$F0,$F0,$80,$80,$00,$00,$00,$C0,$F8,$FC,$1C,$00,$00,$00,$00,$00,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$00,$00,$00,$03,$07,$03,$01,$01,$00,$00,$01,$03,$07,$07,$0B,$0F,$1F,$0E,$00,$00,$00 ; Frame 10
  DEFB $00,$00,$00,$00,$01,$01,$01,$87,$CF,$FF,$FF,$FF,$FF,$F7,$EF,$DF,$E1,$C0,$80,$00,$00,$00,$00,$00 ; (225
  DEFB $00,$20,$60,$60,$E0,$E0,$F0,$F8,$F8,$80,$80,$00,$00,$80,$E0,$F0,$F8,$38,$00,$00,$00,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$07,$17,$1B,$3F,$1E,$00,$00,$00,$00,$00,$00 ; Frame 11
  DEFB $00,$00,$00,$00,$00,$00,$C0,$E0,$E0,$71,$7F,$7F,$FF,$FB,$EF,$FF,$CF,$07,$03,$00,$00,$00,$00,$00 ; (247.5
  DEFB $00,$00,$00,$00,$04,$0C,$1C,$1C,$7C,$FC,$F8,$FC,$CC,$80,$00,$00,$80,$C0,$C0,$80,$00,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$17,$7F,$7F,$3F,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Frame 12
  DEFB $00,$00,$00,$00,$00,$06,$0E,$0E,$0E,$FF,$FF,$FF,$57,$FF,$1E,$1E,$0E,$0E,$0E,$06,$00,$00,$00,$00 ; (270
  DEFB $00,$00,$00,$00,$00,$00,$06,$0E,$1E,$FE,$FE,$FE,$FE,$8C,$0C,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$00,$00,$00,$1E,$2F,$1F,$1F,$07,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Frame 13
  DEFB $00,$00,$00,$00,$00,$03,$07,$CF,$FF,$FF,$7F,$DF,$7F,$7F,$78,$F0,$F0,$E0,$60,$00,$00,$00,$00,$00 ; (292.5
  DEFB $00,$00,$00,$00,$00,$80,$80,$00,$00,$74,$FE,$FC,$F8,$F8,$F0,$E0,$E0,$00,$00,$00,$00,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$03,$0F,$0F,$0F,$07,$03,$01,$00,$00,$00,$01,$03,$03,$07,$07,$02,$00,$00,$00,$00,$00 ; Frame 14
  DEFB $00,$00,$00,$00,$80,$C0,$E0,$F7,$FF,$7F,$BF,$DF,$FF,$FF,$EF,$C1,$83,$03,$00,$00,$00,$00,$00,$00 ; (315
  DEFB $00,$00,$00,$00,$00,$00,$E0,$E0,$C0,$80,$00,$90,$F8,$F8,$F0,$F0,$C0,$00,$00,$00,$00,$00,$00,$00 ; degrees)
  DEFB $00,$00,$00,$01,$01,$01,$00,$00,$00,$00,$00,$00,$03,$0F,$0F,$04,$00,$00,$00,$00,$00,$00,$00,$00 ; Frame 15
  DEFB $00,$00,$C0,$F0,$F8,$F8,$FC,$FC,$7E,$5F,$3F,$EF,$FF,$FF,$8F,$07,$03,$07,$07,$00,$00,$00,$00,$00 ; (337.5
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$78,$F8,$F0,$C0,$A0,$E0,$E0,$F8,$F0,$E0,$60,$00,$00,$00,$00,$00 ; degrees)

; Main menu
;
; Entered after initialisation (Init), at game over ($92A6), from the info
; screen and when A+G abandons a game (5BE9). Silences the engine sound, beeps,
; waits for all keys to be released, draws the menu and highlights the selected
; controller. While waiting for a key it calls the crate shuffle
; (ShuffleVector) continuously. Keys: 1 = information screen (InfoScreen); 2 =
; keyboard, 3 = Interface 2, 4 = Kempston, 5 = Protek/AGF (cursor) joystick:
; stored as 0-3 in the control method $7FD5 (initially 0); 6 = start the game
; (GameStart). Other keys are ignored.
MainMenu:
  LD A,$01                ; $752D=1: interrupt handler makes no engine sound
  LD ($752D),A            ;
  LD HL,$0666             ; Beep (pitch $0666, $55 cycles)
  LD DE,$0055             ;
  CALL $03B5              ;
MainMenu_0:
  CALL GetKey             ; Wait until no key is pressed
  JR NC,MainMenu_0        ;
  CALL $84D6              ; Clear the screen
  CALL DrawMenu           ; Draw the menu
  LD A,($7FD5)            ; Current control method (0-3)
  JR MainMenu_1           ;
MenuLoop:
  CALL ShuffleVector      ; Shuffle the crates again (randomises the layout
                          ; while waiting)
  CALL GetKey             ; Read a key (carry set: none)
  JR C,MenuLoop           ;
  CP $31                  ; Ignore anything but "1".."6"
  JR C,MenuLoop           ;
  CP $37                  ;
  JR NC,MenuLoop          ;
  CP $31                  ;
  JP Z,InfoScreen         ; "1": information screen
  CP $36                  ;
  JP Z,GameStart          ; "6": start the game
  SUB $32                 ; "2".."5": control method 0..3
  LD ($7FD5),A            ;
MainMenu_1:
  LD HL,$5960             ; Rows 11-14, all columns: bright cyan on black...
  LD B,$80                ;
MainMenu_2:
  LD (HL),$45             ;
  INC HL                  ;
  DJNZ MainMenu_2         ;
  LD HL,$5969             ; ...except the selected row (11+method), columns
  ADD A,A                 ; 9-21: flashing bright cyan
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,L                 ;
  LD L,A                  ;
  LD B,$0D                ;
MainMenu_3:
  LD (HL),$C5             ;
  INC HL                  ;
  DJNZ MainMenu_3         ;
  LD HL,$0300             ; Click
  LD DE,$0060             ;
  CALL $03B5              ;
MainMenu_4:
  CALL GetKey             ; Wait for the key to be released
  JR NC,MainMenu_4        ;
  JR MenuLoop             ;

; Draw the main menu
;
; Colours rows 5-17, columns 9-21 from the list at E3A6 (one attribute per
; row), draws a horizontal line (pixel line 3) across the same 13 columns of
; each of those rows (visible only on the red rows that carry no text: rows 8,
; 10, 15, 17), then prints the strings at E325.
DrawMenu:
  LD DE,$E3A6             ; One attribute per row
  LD HL,$58A9             ;
DrawMenu_0:
  LD B,$0D                ;
  LD A,(DE)               ;
DrawMenu_1:
  LD (HL),A               ;
  INC HL                  ;
  DJNZ DrawMenu_1         ;
  INC DE                  ;
  LD BC,$0013             ;
  ADD HL,BC               ;
  LD A,(DE)               ;
  CP $FF                  ;
  JR NZ,DrawMenu_0        ;
  LD HL,$43A9             ; Pixel line 3 of row 5, column 9
  LD A,$FF                ;
  LD C,$0D                ;
DrawMenu_2:
  LD B,$0D                ;
DrawMenu_3:
  LD (HL),A               ;
  INC HL                  ;
  DJNZ DrawMenu_3         ;
  RR H                    ; Move to the same pixel line of the next character
  RR H                    ; row (bit-rotation trick)
  RR H                    ;
  LD DE,$0013             ;
  ADD HL,DE               ;
  RL H                    ;
  RL H                    ;
  RL H                    ;
  DEC C                   ;
  JR NZ,DrawMenu_2        ;
  LD HL,$E325             ; Print the menu strings
  JP PrintStrings         ;

; Main menu strings
;
; Format for PrintStrings: screen address (2 bytes), character codes (font
; 6028), $FF; the list ends with another $FF.
  DEFW $40A9              ; Screen address $40A9 (row 5, column 9)
  DEFB $20,$20,$17,$18,$19,$1A,$1B,$1C ; Character codes (font at $6028;
  DEFB $1D,$1E,$1F,$20,$20             ; $17-$1F = CYCLONE logo glyphs)
  DEFB $FF                ; End of string
  DEFW $40E9              ; Screen address $40E9 (row 7, column 9)
  DEFM "SELECT OPTION"
  DEFB $FF                ; End of string
  DEFW $4829              ; Screen address $4829 (row 9, column 9)
  DEFM "1 INFORMATION"
  DEFB $FF                ; End of string
  DEFW $4869              ; Screen address $4869 (row 11, column 9)
  DEFM "2 KEYBOARD   "
  DEFB $FF                ; End of string
  DEFW $4889              ; Screen address $4889 (row 12, column 9)
  DEFM "3 INTERFACE 2"
  DEFB $FF                ; End of string
  DEFW $48A9              ; Screen address $48A9 (row 13, column 9)
  DEFM "4 KEMPSTON   "
  DEFB $FF                ; End of string
  DEFW $48C9              ; Screen address $48C9 (row 14, column 9)
  DEFM "5 PROTEK/AGF "
  DEFB $FF                ; End of string
  DEFW $5009              ; Screen address $5009 (row 16, column 9)
  DEFM "6 START GAME "
  DEFB $FF                ; End of string
  DEFB $FF                ; End of list

; Main menu row attributes
;
; One attribute for 13 cells (columns 9-21) of each of rows 5-17 (DrawMenu):
; logo row bright white; SELECT OPTION white; red rule rows; options white
; (rows 11-14 are recoloured by the highlight code).
  DEFB $47,$00,$07,$42,$47,$42,$07,$07,$07,$07,$42,$47,$42
  DEFB $FF                ; End of list

; Information screen
;
; Menu option 1. Draws the HUD panel and labels every HUD element, the key
; controls and the map symbols, then waits for any key and returns to the menu.
; Also updates the high score (87BC).
InfoScreen:
  CALL $84D6              ; Clear the screen
  LD HL,$0400             ; Beep (pitch $0400, $70 cycles)
  LD DE,$0070             ;
  CALL $03B5              ;
InfoScreen_0:
  CALL GetKey             ; Wait until no key is pressed
  JR NC,InfoScreen_0      ;
  CALL $84F4              ; Draw the HUD panel
  LD DE,$0009             ; Play area (23 x 22 cells): bright red ink on white
  LD HL,$5800             ; paper
  LD C,$16                ;
InfoScreen_1:
  LD B,$17                ;
InfoScreen_2:
  LD (HL),$7A             ;
  INC HL                  ;
  DJNZ InfoScreen_2       ;
  ADD HL,DE               ;
  DEC C                   ;
  JR NZ,InfoScreen_1      ;
  LD A,$03                ; $7530=3: aircraft collision warning lit
  LD ($7530),A            ;
  XOR A                   ; Speed $7527=0
  LD ($7527),A            ;
  CALL $91B4              ; Draw compass/speedometer/warning
  CALL PrintScore         ; Print the score
  CALL $87BC              ; Update and print the high score
  CALL DrawInfoTexts      ; Print all the information texts
InfoScreen_3:
  CALL GetKey             ; Wait for a key
  JR C,InfoScreen_3       ;
  JP MainMenu             ;

; Read the keyboard (ROM)
;
; Uses ROM KEY-SCAN ($028E), K-TEST ($031E) and K-DECODE ($0333, L mode).
;
; O:A ASCII code of the key pressed (0 if none)
; O:F Carry clear if a single valid key is pressed, set if none
GetKey:
  CALL $028E
  JR NZ,GetKey_0
  CALL $031E
  JR NC,GetKey_0
  LD E,A
  LD C,$00
  LD D,$08
  CALL $0333
  AND A
  RET
GetKey_0:
  XOR A
  SCF
  RET

; Print a list of strings (8x8 font)
;
; Each string: screen address (2 bytes), character codes, $FF; a second $FF
; ends the list. Characters are copied from the font at 6028 (8 pixel lines
; each).
;
; HL String list
PrintStrings:
  LD A,(HL)
  CP $FF
  RET Z
  LD E,A
  INC HL
  LD D,(HL)
  INC HL
PrintStrings_0:
  LD A,(HL)
  INC HL
  CP $FF
  JR Z,PrintStrings
  PUSH DE
  PUSH HL
  LD L,A
  LD H,$00
  LD BC,$6028
  ADD HL,HL
  ADD HL,HL
  ADD HL,HL
  ADD HL,BC
  LD B,$08
PrintStrings_1:
  LD A,(HL)
  LD (DE),A
  INC D
  INC HL
  DJNZ PrintStrings_1
  POP HL
  POP DE
  INC DE
  JR PrintStrings_0

; Unused
  DEFB $E1,$00,$0A,$15

; Print the information screen texts
;
; Prints the 29 lines of 4x8-font text at E517 (positions from E69C; the stride
; operand at $8E0A is set to 3 here, the map labels use 20), the two headings
; and the highlighted key letters/map symbols in the 8x8 font, horizontal rules
; (E504), the leaving-map arrow (HUD glyph at $7460), crate glyph ($FB80, char
; $30) and survivor glyph ($FB90, char $32), and makes "PRESS ANY KEY" flash.
DrawInfoTexts:
  LD IX,$E68C             ; Line position table base (IX+$10 = E69C)
  LD A,$03                ; Line-record stride 3 for $8DEE
  LD ($8E0A),A            ;
  LD HL,$E517             ; Print the small-font texts
  CALL $8DEE              ;
  LD HL,$E4E0             ; "KEY CONTROLS" at row 1, column 1
  LD DE,$4021             ;
  LD C,$0C                ;
  CALL $859A              ;
  LD HL,$E4EC             ; "MAP INDICATORS" at row 8, column 1
  LD DE,$4801             ;
  LD C,$0E                ;
  CALL $859A              ;
  LD HL,$E504             ; Draw horizontal rules (list at E504)
DrawInfoTexts_0:
  LD A,$FF                ;
  LD B,(HL)               ;
  CP B                    ;
  JR Z,DrawInfoTexts_2    ;
  INC HL                  ;
  LD E,(HL)               ;
  INC HL                  ;
  LD D,(HL)               ;
  INC HL                  ;
DrawInfoTexts_1:
  LD (DE),A               ;
  INC DE                  ;
  DJNZ DrawInfoTexts_1    ;
  JR DrawInfoTexts_0      ;
DrawInfoTexts_2:
  LD HL,$E4FA             ; Single characters: "1" row 3 col 1, "O" row 3 col
  LD C,$01                ; 7, "Q" row 4 col 1, "P" row 4 col 7, "X" row 5 col
  LD DE,$4061             ; 1, "N" row 5 col 7, "M" row 6 col 1, "N" row 14 col
  CALL $859A              ; 21, helicopter symbol row 10 col 1, cyclone symbol
  INC C                   ; row 11 col 1
  LD E,$67                ;
  CALL $859A              ;
  INC C                   ;
  LD E,$81                ;
  CALL $859A              ;
  INC C                   ;
  LD E,$87                ;
  CALL $859A              ;
  INC C                   ;
  LD E,$A1                ;
  CALL $859A              ;
  INC C                   ;
  LD E,$A7                ;
  CALL $859A              ;
  INC C                   ;
  LD E,$C1                ;
  CALL $859A              ;
  INC C                   ;
  LD DE,$48D5             ;
  CALL $859A              ;
  INC C                   ;
  LD E,$41                ;
  CALL $859A              ;
  INC C                   ;
  LD E,$61                ;
  CALL $859A              ;
  INC C                   ;
  LD IX,$7460             ; Leaving-map arrow at row 12, column 1
  LD DE,$4881             ;
  LD C,$01                ;
  LD HL,$0040             ;
  CALL $8EE8              ;
  LD IX,$FB80             ; Crate glyph at row 14, column 1
  INC C                   ;
  CALL $8EE8              ;
  LD IX,$FB90             ; Survivor glyph at row 16, column 1
  INC C                   ;
  CALL $8EE8              ;
  LD HL,$5A41             ; "PRESS ANY KEY" (row 18, columns 1-7) flashing
  LD B,$07                ;
DrawInfoTexts_3:
  LD (HL),$FA             ;
  INC HL                  ;
  DJNZ DrawInfoTexts_3    ;
  RET                     ;

; Information screen headings and key letters
  DEFM "KEY CONTROLS"     ; "KEY CONTROLS"
  DEFM "MAP INDICATORS"   ; "MAP INDICATORS"
  DEFM "1OQPXNMN"         ; Key letters 1 O Q P X N M N
  DEFB $28,$27            ; Map symbols: $28 helicopter position, $27 cyclone
                          ; location

; Information screen horizontal rules
;
; Entries: length, screen address (2 bytes); all bytes are set to $FF. List
; ends with $FF.
  DEFB $0E,$01,$44
  DEFB $0E,$41,$44
  DEFB $0E,$E1,$44
  DEFB $0E,$21,$4C
  DEFB $0E,$A1,$4C
  DEFB $07,$48,$54
  DEFB $FF                ; End of list

; Information screen texts (4x8 font)
;
; Printed by 8DEE from E518 (first byte skipped): lines separated by $FE, '?' =
; space, $FF = end. Line n is printed at the screen position in entry n of
; E69C.
  DEFB $3F                ; Skipped
  DEFM "?UP"
  DEFB $FE                ; next line
  DEFM "?LEFT"
  DEFB $FE                ; next line
  DEFM "?DOWN"
  DEFB $FE                ; next line
  DEFM "?RIGHT"
  DEFB $FE                ; next line
  DEFM "?FORWARD"
  DEFB $FE                ; next line
  DEFM "?VIEW?CHANGE"
  DEFB $FE                ; next line
  DEFM "?MAP?OR?MAIN?SCREEN"
  DEFB $FE                ; next line
  DEFM "?HELICOPTER?POSITION"
  DEFB $FE                ; next line
  DEFM "?CYCLONE?LOCATION"
  DEFB $FE                ; next line
  DEFM "?LEAVING?MAP?AREA"
  DEFB $FE                ; next line
  DEFM "?COLLECT?FIVE?CRATES"
  DEFB $FE                ; next line
  DEFM "?AND?RETURN?TO?BASE"
  DEFB $FE                ; next line
  DEFM "?RESCUE?SURVIVORS?FOR"
  DEFB $FE                ; next line
  DEFM "?EXTRA?POINTS"
  DEFB $FE                ; next line
  DEFM "PRESS?ANY?KEY"
  DEFB $FE                ; next line
  DEFM "CRATES?LEFT"
  DEFB $FE                ; next line
  DEFM "?ALTIMETER"
  DEFB $FE                ; next line
  DEFM "?SPEEDOMETER"
  DEFB $FE                ; next line
  DEFM "FUEL?GAUGE"
  DEFB $FE                ; next line
  DEFM "?TIME?LEFT"
  DEFB $FE                ; next line
  DEFM "?COMPASS"
  DEFB $FE                ; next line
  DEFM "?HEADING"
  DEFB $FE                ; next line
  DEFM "?LIVES"
  DEFB $FE                ; next line
  DEFM "?VIEW?SELECTED"
  DEFB $FE                ; next line
  DEFM "?WITH?KEY"
  DEFB $FE                ; next line
  DEFM "?COLLISION"
  DEFB $FE                ; next line
  DEFM "?WARNING"
  DEFB $FE                ; next line
  DEFM "WIND?SPEED?INCREASES"
  DEFB $FE                ; next line
  DEFM "WHEN?APPROACHING?CYCLONE"
  DEFB $FF                ; end of text
  DEFB $FF                ; end of text

; Information screen text line positions
;
; 29 entries: screen address (2 bytes), attribute page ($58/$59/$5A; the
; attribute of each cell written gets $78). Accessed as IX+$10..IX+$12 with
; IX=$E68C+3n.
  DEFB $62,$40,$58
  DEFB $68,$40,$58
  DEFB $82,$40,$58
  DEFB $88,$40,$58
  DEFB $A2,$40,$58
  DEFB $A8,$40,$58
  DEFB $C2,$40,$58
  DEFB $42,$48,$59
  DEFB $62,$48,$59
  DEFB $82,$48,$59
  DEFB $C2,$48,$59
  DEFB $E2,$48,$59
  DEFB $02,$50,$5A
  DEFB $22,$50,$5A
  DEFB $41,$50,$5A
  DEFB $81,$50,$5A
  DEFB $31,$40,$58
  DEFB $50,$40,$58
  DEFB $71,$40,$58
  DEFB $91,$40,$58
  DEFB $F2,$40,$58
  DEFB $12,$48,$59
  DEFB $53,$48,$59
  DEFB $AF,$48,$59
  DEFB $D0,$48,$59
  DEFB $11,$50,$5A
  DEFB $32,$50,$5A
  DEFB $6C,$50,$5A
  DEFB $8A,$50,$5A

; Unused
  DEFB $00,$00,$00,$80,$00,$A8,$50,$A0
  DEFB $40,$00,$00,$00,$00

; Aircraft movement opcodes
;
; 16 directions x 4 bytes, patched into the aircraft mover at $8867/$8868 (X)
; and $8871/$8872 (Y) by $87F0: $03 = INC BC, $0B = DEC BC, $00 = NOP, so each
; axis moves -2..+2 per iteration.
  DEFB $00,$00,$0B,$0B
  DEFB $03,$00,$0B,$0B
  DEFB $03,$03,$0B,$0B
  DEFB $03,$03,$0B,$00
  DEFB $03,$03,$00,$00
  DEFB $03,$03,$03,$00
  DEFB $03,$03,$03,$03
  DEFB $00,$03,$03,$03
  DEFB $00,$00,$03,$03
  DEFB $0B,$00,$03,$03
  DEFB $0B,$0B,$03,$03
  DEFB $0B,$0B,$03,$00
  DEFB $0B,$0B,$00,$00
  DEFB $0B,$0B,$0B,$00
  DEFB $0B,$0B,$0B,$0B
  DEFB $0B,$00,$0B,$0B

; Aircraft course script
;
; 15 records of 20 bytes; $87F0 advances to the next record every 28 iterations
; (wrapping at $E85A to $E740). Each record is a list of new directions for the
; aircraft table (E86C); a byte with bit 7 set also resets that aircraft's
; position from E8CC; $FF ends a record.
  DEFB $20,$20,$34,$34,$88,$88,$88,$20,$20,$00,$00,$10,$90,$04,$10,$00,$30,$B0,$00,$FF
  DEFB $1C,$20,$30,$30,$08,$08,$08,$A0,$A0,$80,$00,$90,$10,$08,$10,$00,$34,$30,$00,$FF
  DEFB $20,$20,$AC,$AC,$04,$04,$04,$20,$20,$00,$80,$10,$10,$08,$10,$3C,$30,$30,$00,$FF
  DEFB $20,$20,$28,$28,$08,$08,$08,$1C,$1C,$00,$00,$10,$10,$08,$0C,$3C,$2C,$30,$3C,$FF
  DEFB $20,$20,$2C,$2C,$08,$08,$08,$20,$20,$00,$00,$10,$10,$0C,$10,$38,$30,$34,$38,$FF
  DEFB $A0,$20,$28,$28,$08,$08,$08,$24,$24,$00,$00,$10,$10,$08,$10,$3C,$30,$38,$3C,$FF
  DEFB $20,$20,$28,$28,$0C,$0C,$0C,$20,$20,$00,$00,$10,$10,$08,$0C,$00,$34,$38,$00,$FF
  DEFB $20,$20,$2C,$2C,$08,$08,$08,$24,$24,$00,$00,$10,$10,$0C,$0C,$00,$30,$38,$3C,$FF
  DEFB $20,$20,$30,$30,$04,$04,$04,$28,$28,$00,$00,$10,$10,$10,$0C,$00,$30,$38,$00,$FF
  DEFB $20,$A0,$30,$30,$08,$08,$08,$24,$24,$00,$00,$10,$10,$10,$10,$00,$30,$38,$00,$FF
  DEFB $20,$20,$2C,$2C,$08,$08,$08,$20,$20,$00,$00,$10,$0C,$10,$0C,$80,$30,$38,$00,$FF
  DEFB $20,$20,$30,$30,$08,$08,$08,$1C,$1C,$00,$00,$10,$08,$80,$10,$00,$B0,$38,$00,$FF
  DEFB $24,$20,$34,$34,$04,$04,$04,$20,$20,$04,$00,$10,$0C,$00,$10,$00,$30,$34,$80,$FF
  DEFB $20,$20,$38,$38,$00,$00,$00,$20,$20,$04,$00,$10,$10,$00,$10,$00,$30,$34,$00,$FF
  DEFB $20,$20,$38,$38,$00,$00,$00,$20,$20,$00,$00,$10,$10,$00,$90,$00,$30,$30,$00,$FF

; Aircraft table
;
; 19 aircraft x 5 bytes: direction (0-15, index into E700), X (word), Y (word);
; $FF ends the table. Updated by $87F0, which also sets the collision warning
; bits in $7530 when one is near the helicopter.
  DEFB $20,$A8,$00,$EC,$01
  DEFB $20,$04,$02,$0C,$01
  DEFB $34,$3C,$00,$14,$02
  DEFB $34,$3C,$00,$0C,$02
  DEFB $08,$24,$00,$E0,$02
  DEFB $08,$24,$00,$EC,$02
  DEFB $08,$24,$00,$FC,$02
  DEFB $20,$F8,$00,$CC,$02
  DEFB $20,$EC,$00,$CC,$02
  DEFB $00,$D4,$02,$F4,$FF
  DEFB $00,$34,$00,$64,$00
  DEFB $10,$DC,$02,$F8,$00
  DEFB $10,$CC,$FF,$B8,$01
  DEFB $04,$60,$01,$24,$02
  DEFB $10,$04,$00,$AC,$00
  DEFB $00,$B8,$02,$EC,$01
  DEFB $30,$34,$02,$1C,$02
  DEFB $30,$2C,$03,$EC,$01
  DEFB $00,$3C,$02,$5C,$02
  DEFB $FF                ; End of table

; Aircraft start positions
;
; Same layout as E86C; copied into it (4 bytes per aircraft) when the course
; script says so.
  DEFB $20,$C4,$00,$BC,$FF
  DEFB $20,$04,$02,$BC,$FF
  DEFB $34,$1C,$03,$84,$01
  DEFB $34,$1C,$03,$7C,$01
  DEFB $08,$24,$00,$00,$03
  DEFB $08,$24,$00,$F0,$02
  DEFB $08,$24,$00,$E0,$02
  DEFB $20,$4C,$01,$BC,$FF
  DEFB $20,$40,$01,$BC,$FF
  DEFB $00,$9E,$02,$04,$03
  DEFB $00,$34,$00,$04,$03
  DEFB $10,$CC,$FF,$F8,$00
  DEFB $10,$CC,$FF,$B5,$01
  DEFB $04,$60,$01,$04,$03
  DEFB $10,$CC,$FF,$AC,$00
  DEFB $00,$B8,$02,$04,$03
  DEFB $30,$14,$03,$1C,$02
  DEFB $30,$2C,$03,$EC,$01
  DEFB $00,$3C,$02,$04,$03
  DEFB $FF                ; End of table
  DEFB $00,$00,$00,$00    ; Unused

; Helicopter frames (16 headings)
;
; 16 frames x 72 bytes (24x24 pixels, 3 bytes x 24 lines), frame h at
; $E8E8+72*(h+1), h = heading $7507 (or heading+8 AND 15 in the south view).
; Used by $8CA0. The graphics agent decodes these.
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$03,$03
  DEFB $03,$03,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$3E
  DEFB $7F,$7F,$7F
  DEFB $7F,$77,$77
  DEFB $F7,$FF,$FF
  DEFB $FF,$FF,$7F
  DEFB $7F,$7F,$1C
  DEFB $1F,$1F,$1C
  DEFB $08,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $80,$E0,$E0
  DEFB $E0,$E0,$00
  DEFB $00,$00,$00
  DEFB $80,$80,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$01
  DEFB $00,$00,$00
  DEFB $00,$01,$03
  DEFB $01,$01,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $07,$0F,$0F
  DEFB $1F,$17,$17
  DEFB $F7,$FF,$FF
  DEFB $FF,$7F,$7F
  DEFB $7E,$F8,$E0
  DEFB $F8,$FC,$C8
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $80,$C0,$C0
  DEFB $C0,$C0,$C0
  DEFB $80,$40,$E0
  DEFB $E0,$E0,$C0
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$01,$0B
  DEFB $1F,$1F,$0F
  DEFB $0F,$01,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$01,$03
  DEFB $07,$1F,$17
  DEFB $37,$7F,$7E
  DEFB $FD,$FF,$FF
  DEFB $FD,$80,$00
  DEFB $C0,$80,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$40,$E0
  DEFB $F0,$F0,$F0
  DEFB $E0,$40,$C0
  DEFB $E0,$E0,$C0
  DEFB $80,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$01
  DEFB $77,$7F,$7F
  DEFB $38,$1C,$18
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $01,$0F,$17
  DEFB $77,$7F,$FF
  DEFB $FE,$FB,$FF
  DEFB $FF,$33,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $C0,$F0,$F8
  DEFB $F8,$FC,$78
  DEFB $E0,$C0,$E0
  DEFB $E0,$80,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $E0,$FF,$FF
  DEFB $FF,$C7,$C3
  DEFB $01,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$08,$77
  DEFB $F7,$FF,$FF
  DEFB $FF,$FF,$EA
  DEFB $FF,$1F,$1F
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $E0,$E8,$E8
  DEFB $F8,$F8,$F0
  DEFB $FC,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$20,$30
  DEFB $78,$7C,$EF
  DEFB $CF,$03,$03
  DEFB $03,$01,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$68,$F0
  DEFB $F6,$FF,$FF
  DEFB $FF,$DF,$EF
  DEFB $3B,$7F,$7F
  DEFB $1C,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$80,$E0
  DEFB $E0,$D0,$B8
  DEFB $F8,$F8,$F0
  DEFB $F0,$08,$00
  DEFB $00,$00,$00
  DEFB $00,$02,$06
  DEFB $0F,$3F,$3B
  DEFB $03,$01,$00
  DEFB $01,$01,$01
  DEFB $01,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$80
  DEFB $C0,$F8,$F4
  DEFB $F6,$FF,$FF
  DEFB $FF,$DF,$6F
  DEFB $77,$FF,$FF
  DEFB $7F,$33,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $80,$C0,$E0
  DEFB $A0,$60,$F0
  DEFB $F0,$E0,$80
  DEFB $40,$00,$00
  DEFB $00,$03,$0F
  DEFB $0E,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$03
  DEFB $01,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $C0,$C0,$C0
  DEFB $C0,$E0,$60
  DEFB $70,$74,$F4
  DEFB $F6,$FE,$FF
  DEFB $7F,$DF,$FF
  DEFB $FF,$FF,$FC
  DEFB $5F,$1F,$0F
  DEFB $03,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$80
  DEFB $C0,$C0,$E0
  DEFB $C0,$80,$80
  DEFB $80,$80,$80
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$03,$03
  DEFB $03,$03,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $F8,$FE,$08
  DEFB $08,$1C,$1C
  DEFB $1C,$36,$77
  DEFB $77,$7F,$7F
  DEFB $FF,$FF,$FF
  DEFB $FF,$FF,$63
  DEFB $7F,$7F,$3E
  DEFB $3E,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $80,$E0,$E0
  DEFB $E0,$E0,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$01
  DEFB $03,$03,$07
  DEFB $03,$01,$03
  DEFB $03,$03,$01
  DEFB $02,$00,$00
  DEFB $1E,$0F,$03
  DEFB $03,$07,$07
  DEFB $0E,$2E,$2F
  DEFB $6F,$7F,$FE
  DEFB $FE,$FB,$FF
  DEFB $FF,$FF,$3B
  DEFB $F8,$F0,$E0
  DEFB $80,$00,$00
  DEFB $00,$80,$80
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$80,$C0
  DEFB $80,$80,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$01
  DEFB $01,$03,$07
  DEFB $07,$05,$0E
  DEFB $0F,$17,$03
  DEFB $00,$00,$00
  DEFB $03,$03,$00
  DEFB $00,$00,$01
  DEFB $03,$1F,$0F
  DEFB $6F,$FF,$FF
  DEFB $FF,$FD,$FA
  DEFB $F6,$FF,$FF
  DEFB $FE,$CC,$00
  DEFB $00,$00,$00
  DEFB $00,$C0,$E0
  DEFB $E0,$E0,$C0
  DEFB $C0,$80,$00
  DEFB $80,$80,$80
  DEFB $80,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$01,$07
  DEFB $07,$0B,$0D
  DEFB $1F,$1F,$2F
  DEFB $06,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$10,$0D
  DEFB $EF,$FF,$FF
  DEFB $FF,$FB,$F7
  DEFB $DC,$FE,$FE
  DEFB $38,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$08
  DEFB $1C,$0C,$06
  DEFB $06,$3E,$FE
  DEFB $F8,$E0,$C0
  DEFB $C0,$C0,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $07,$17,$17
  DEFB $7F,$1F,$1F
  DEFB $0F,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$10,$EE
  DEFB $EF,$FF,$FF
  DEFB $FF,$FF,$57
  DEFB $FF,$F8,$F8
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $03,$03,$03
  DEFB $07,$FF,$FF
  DEFB $FE,$FE,$C0
  DEFB $80,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $03,$0F,$1F
  DEFB $1F,$1F,$1F
  DEFB $0E,$03,$01
  DEFB $03,$01,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $C0,$F0,$E8
  DEFB $EE,$FE,$FF
  DEFB $FF,$7F,$DF
  DEFB $FF,$EE,$40
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $02,$07,$86
  DEFB $EE,$FE,$FC
  DEFB $FC,$18,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$02
  DEFB $07,$0F,$0F
  DEFB $0F,$07,$02
  DEFB $03,$07,$07
  DEFB $03,$01,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$80
  DEFB $E0,$F0,$E8
  DEFB $EC,$FE,$FE
  DEFB $7E,$BF,$FF
  DEFB $FF,$3F,$08
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$0C,$9C
  DEFB $F8,$F0,$F0
  DEFB $60,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $01,$03,$03
  DEFB $03,$03,$03
  DEFB $01,$01,$07
  DEFB $07,$07,$03
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $E0,$F0,$F0
  DEFB $F8,$E8,$EC
  DEFB $EF,$7F,$FF
  DEFB $FF,$FE,$FE
  DEFB $7E,$7F,$3F
  DEFB $07,$03,$03
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$80
  DEFB $00,$00,$00
  DEFB $30,$F8,$F0
  DEFB $80,$00,$00
  DEFB $00,$00,$00

; Helicopter mask/shadow frames (16 headings)
;
; 16 frames x 72 bytes, frame h at $ED68+72*(h+1) (used by $7BB8; $FF bytes are
; transparent).
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$01
  DEFB $02,$01,$02
  DEFB $00,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $2A,$55,$08
  DEFB $14,$0A,$15
  DEFB $0A,$00,$2A
  DEFB $55,$2A,$55
  DEFB $AA,$55,$AA
  DEFB $55,$00,$00
  DEFB $00,$14,$2A
  DEFB $55,$2A,$55
  DEFB $00,$00,$00
  DEFB $00,$80,$00
  DEFB $80,$00,$00
  DEFB $00,$00,$40
  DEFB $A0,$40,$A0
  DEFB $00,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$01,$02
  DEFB $01,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$01
  DEFB $00,$00,$00
  DEFB $00,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $AA,$40,$A0
  DEFB $50,$A8,$14
  DEFB $00,$00,$0A
  DEFB $55,$AA,$55
  DEFB $AA,$55,$2A
  DEFB $55,$00,$00
  DEFB $00,$00,$02
  DEFB $05,$0A,$05
  DEFB $80,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$80
  DEFB $40,$80,$40
  DEFB $A0,$40,$80
  DEFB $00,$00,$00
  DEFB $00,$00,$80
  DEFB $40,$80,$40
  DEFB $02,$05,$02
  DEFB $01,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $01,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $A0,$00,$80
  DEFB $50,$A0,$40
  DEFB $00,$00,$2A
  DEFB $15,$2A,$55
  DEFB $2A,$55,$AA
  DEFB $55,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$01
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$A0
  DEFB $40,$80,$40
  DEFB $A0,$40,$80
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $40,$A0,$50
  DEFB $0A,$14,$0A
  DEFB $05,$02,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$02
  DEFB $05,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $A2,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$08
  DEFB $15,$0A,$55
  DEFB $AA,$55,$AA
  DEFB $55,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $80,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$A8
  DEFB $50,$A8,$50
  DEFB $A0,$40,$A0
  DEFB $40,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$50
  DEFB $80,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$55
  DEFB $AA,$55,$AA
  DEFB $41,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $0A,$15,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$0A
  DEFB $15,$AA,$55
  DEFB $AA,$55,$AA
  DEFB $55,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$A0,$50
  DEFB $A8,$50,$A8
  DEFB $50,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$2A
  DEFB $55,$AA,$41
  DEFB $02,$01,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$10
  DEFB $2A,$55,$08
  DEFB $00,$00,$00
  DEFB $00,$00,$80
  DEFB $54,$AA,$55
  DEFB $AA,$55,$AA
  DEFB $15,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $A8,$50,$A0
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $80,$40,$A0
  DEFB $50,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$22
  DEFB $01,$00,$01
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$08
  DEFB $14,$2A,$15
  DEFB $AA,$55,$2A
  DEFB $11,$00,$00
  DEFB $00,$00,$A8
  DEFB $50,$A8,$55
  DEFB $AA,$55,$2A
  DEFB $55,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$40
  DEFB $A0,$50,$A0
  DEFB $40,$80,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $80,$40,$80
  DEFB $40,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$02
  DEFB $01,$00,$00
  DEFB $00,$05,$0A
  DEFB $05,$00,$00
  DEFB $AA,$55,$0A
  DEFB $15,$0A,$05
  DEFB $00,$00,$A0
  DEFB $54,$AA,$55
  DEFB $2A,$55,$AA
  DEFB $55,$00,$00
  DEFB $80,$40,$80
  DEFB $40,$A0,$40
  DEFB $00,$00,$80
  DEFB $00,$80,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $80,$40,$80
  DEFB $40,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $02,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$01,$02
  DEFB $01,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $AA,$55,$2A
  DEFB $55,$2A,$14
  DEFB $00,$00,$2A
  DEFB $55,$2A,$55
  DEFB $AA,$55,$AA
  DEFB $55,$00,$54
  DEFB $A8,$14,$08
  DEFB $14,$08,$14
  DEFB $A0,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $80,$40,$A0
  DEFB $40,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$01,$02
  DEFB $01,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$01
  DEFB $02,$05,$02
  DEFB $01,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $AA,$51,$A8
  DEFB $50,$A0,$00
  DEFB $00,$00,$2A
  DEFB $55,$2A,$54
  DEFB $AA,$55,$AA
  DEFB $55,$08,$05
  DEFB $0A,$01,$02
  DEFB $05,$0A,$05
  DEFB $80,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$80
  DEFB $00,$00,$00
  DEFB $80,$40,$80
  DEFB $00,$00,$00
  DEFB $02,$05,$0A
  DEFB $05,$02,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$01
  DEFB $00,$01,$00
  DEFB $01,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $AA,$55,$AA
  DEFB $44,$00,$00
  DEFB $00,$00,$00
  DEFB $05,$AA,$55
  DEFB $AA,$55,$AA
  DEFB $54,$00,$00
  DEFB $02,$01,$00
  DEFB $00,$00,$00
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$A0
  DEFB $40,$80,$00
  DEFB $80,$00,$00
  DEFB $00,$00,$00
  DEFB $80,$40,$A0
  DEFB $50,$20,$50
  DEFB $0A,$05,$02
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$01
  DEFB $00,$05,$0A
  DEFB $15,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $AA,$54,$28
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $45,$AA,$55
  DEFB $AA,$55,$AA
  DEFB $54,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$2A
  DEFB $54,$A8,$40
  DEFB $80,$40,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $10,$28,$14
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$0A,$15
  DEFB $0A,$15,$0A
  DEFB $05,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $A8,$50,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$A8
  DEFB $54,$AA,$55
  DEFB $AA,$55,$AA
  DEFB $55,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $01,$82,$55
  DEFB $AA,$55,$AA
  DEFB $00,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$0A
  DEFB $15,$0A,$15
  DEFB $0A,$01,$00
  DEFB $01,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$05
  DEFB $AA,$40,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$A8
  DEFB $54,$AA,$55
  DEFB $AA,$55,$AA
  DEFB $55,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$10
  DEFB $A8,$54,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $82,$04,$8A
  DEFB $54,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$0A
  DEFB $05,$02,$01
  DEFB $02,$05,$02
  DEFB $01,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$02,$05
  DEFB $2A,$01,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$A8
  DEFB $54,$AA,$54
  DEFB $A8,$54,$AA
  DEFB $55,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$40
  DEFB $A8,$50,$A0
  DEFB $40,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$08
  DEFB $14,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $FF,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$02
  DEFB $01,$02,$05
  DEFB $02,$05,$02
  DEFB $01,$00,$00
  DEFB $00,$00,$02
  DEFB $05,$02,$05
  DEFB $2A,$05,$0A
  DEFB $05,$02,$00
  DEFB $00,$00,$A8
  DEFB $55,$AA,$55
  DEFB $AA,$54,$AA
  DEFB $54,$00,$00
  DEFB $00,$00,$A0
  DEFB $40,$A0,$50
  DEFB $28,$50,$A8
  DEFB $40,$80,$00
  DEFB $00,$00,$FF
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$FF,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00

; Island records
;
; 14 records of 20 bytes, terminated by $FF, in the order of the names at 6A4F:
; BANANA, ORTE ROCKS, KOKOLA, LAGOON, PEAK, BASE (F294, the home island: level
; complete needs $7552=$F294), GILLIGANS, RED, SKEG, BONE, GIANTS GATEWAY,
; CLAW, LUKELAND ISLES, ENTERPRISE. +0/+1: world X and Y high bytes; +2/+3: X
; low range [min,max); +4/+5: Y low range [min,max) (bounding box tested by
; $76D2 to set $7552); +6..+9: X/Y origin bytes used to convert world
; coordinates to map cells (cell = base + (Y+$0E-[+8])*128 + (X+$0B-[+6]),
; F444); +$0A/+$0B: address of the island's origin in the 128-byte-wide world
; map; +$0C/+$0D: screen address of the island bitmap on the map screen;
; +$0E/+$0F: its width/height; +$10/+$11: label screen address; +$12: label
; attribute page; +$13: 0.
  DEFB $02,$01,$5C,$A8,$80,$B8,$72,$92,$9C,$9C,$00,$93,$94,$48,$0D,$06,$6F,$48,$59,$00
  DEFB $01,$02,$88,$D3,$00,$39,$9E,$BD,$1C,$1D,$00,$9D,$0D,$53,$0C,$07,$2E,$50,$5A,$00
  DEFB $01,$00,$57,$A1,$94,$CC,$6D,$8B,$B0,$AF,$00,$A9,$AB,$40,$0C,$07,$C8,$40,$58,$00
  DEFB $00,$00,$74,$CB,$B8,$F0,$8A,$B5,$D4,$D4,$00,$B6,$C4,$40,$10,$07,$E2,$40,$58,$00
  DEFB $02,$00,$28,$65,$58,$90,$3E,$4F,$74,$74,$00,$C3,$72,$40,$0A,$07,$50,$40,$58,$00
  DEFB $01,$01,$1C,$82,$50,$88,$32,$6C,$6C,$6C,$80,$CF,$69,$48,$14,$07,$86,$48,$59,$00
  DEFB $01,$00,$1C,$5E,$58,$91,$32,$48,$74,$75,$54,$93,$69,$40,$0A,$07,$42,$40,$58,$00
  DEFB $01,$02,$78,$B6,$40,$78,$8E,$A0,$5C,$5C,$D8,$9F,$4C,$53,$09,$07,$6D,$50,$5A,$00
  DEFB $00,$02,$70,$AD,$00,$38,$86,$97,$1C,$1C,$D8,$AD,$04,$55,$09,$07,$25,$50,$5A,$00
  DEFB $01,$00,$AC,$FF,$7C,$B4,$C2,$E9,$98,$98,$43,$B8,$8E,$40,$0F,$07,$AF,$40,$58,$00
  DEFB $01,$01,$98,$CB,$0C,$50,$AE,$B5,$28,$34,$37,$93,$2D,$48,$07,$0A,$2E,$48,$59,$00
  DEFB $01,$01,$C4,$FD,$C0,$FE,$DA,$E7,$DC,$E2,$35,$A7,$CF,$4B,$08,$08,$F0,$48,$59,$00
  DEFB $00,$02,$30,$6D,$30,$6C,$46,$57,$4C,$50,$28,$C6,$42,$50,$09,$08,$62,$50,$5A,$00
  DEFB $00,$01,$44,$8B,$B0,$FB,$5A,$75,$CC,$DF,$4F,$C6,$C2,$48,$0B,$0C,$C4,$48,$59,$00
  DEFB $FF                ; End of records
  DEFB $00                ; Unused

; Animate the survivor glyphs
;
; Called every main-loop iteration. Character $31 (glyph $FB88, 7 lines)
; alternates between the frames at $7DEE and $7DF6 every 4 iterations (counter
; $755B, 0-7); character $32 (glyph $FB90, 8 lines) alternates between $7DFE
; and $7E06 every 3 iterations (counter $755C, 0-5).
AnimateSurvivors:
  LD DE,$FB88             ; Glyph of character $31
  LD A,($755B)            ;
  INC A                    ; Counter 1 reaches 4: frame 1
  CP $04                   ;
  JR NZ,AnimateSurvivors_0 ;
  LD HL,$7DEE              ;
  JR AnimateSurvivors_1    ;
AnimateSurvivors_0:
  CP $08                   ; Counter 1 reaches 8: frame 0, counter := 0
  JR NZ,AnimateSurvivors_2 ;
  XOR A                    ;
  LD HL,$7DF6              ;
AnimateSurvivors_1:
  LD BC,$0007              ;
  LDIR                     ;
AnimateSurvivors_2:
  LD ($755B),A             ;
  LD DE,$FB90             ; Glyph of character $32
  LD A,($755C)            ;
  INC A                    ; Counter 2 reaches 3: frame 1
  CP $03                   ;
  JR NZ,AnimateSurvivors_3 ;
  LD HL,$7DFE              ;
  JR AnimateSurvivors_4    ;
AnimateSurvivors_3:
  CP $06                   ; Counter 2 reaches 6: frame 0, counter := 0
  JR NZ,AnimateSurvivors_5 ;
  XOR A                    ;
  LD HL,$7E06              ;
AnimateSurvivors_4:
  LD BC,$0008              ;
  LDIR                     ;
AnimateSurvivors_5:
  LD ($755C),A             ;
  RET                      ;

; Unused
  DEFS $0F

; Winch: pick up crates and survivors
;
; Called every main-loop iteration. $7A85 is the tile under the helicopter
; (centre of the 3x3 tiles saved by $7E10). If it is a crate (F511) or survivor
; (F515) tile, a rope is lowered: E = vertical gap in pixel lines between the
; helicopter and the object (from the view-buffer addresses; RET if negative or
; >255). If E>=17 the rope just dangles (12 lines, then 16 lines max) and
; nothing happens. If E<17 the rope takes two iterations to reach the object
; (winch state $7556: 0 -> 1 -> 2, the step is skipped if E>=13), then the
; object is hooked: the map cell is overwritten with the plain tile (F51B) so
; the object disappears from the world, and a crate increments $7554 and turns
; its HUD box red (attribute 2, boxes from the right). $7555 is then set to
; max(E,2)-1 and the object is reeled in by 1+$751B lines per iteration (faster
; while descending); when $7555 reaches 0 the points are scored: crate 250,
; survivor 50. When the helicopter moves off the object the rope is drawn
; retracted once (12 lines) and $7556 reset. While $7555<>0 the interrupt
; handler plays a winch beep.
Winch:
  LD A,($7555)            ; Object being reeled in ($7555=1-16)?
  DEC A                   ;
  CP $10                  ;
  JP C,WinchReel          ;
  LD A,($7A85)            ; Tile under the helicopter
  LD DE,$F51B             ; Crate tile?
  LD HL,$F511             ;
  LD B,$04                ;
Winch_0:
  CP (HL)                 ;
  JR Z,Winch_3            ;
  INC HL                  ;
  INC DE                  ;
  DJNZ Winch_0            ;
  LD DE,$F51B             ; Survivor tile (either variant)?
  LD HL,$F515             ;
  LD B,$03                ;
Winch_1:
  CP (HL)                 ;
  JR Z,Winch_2            ;
  INC HL                  ;
  CP (HL)                 ;
  JR Z,Winch_2            ;
  INC HL                  ;
  INC DE                  ;
  DJNZ Winch_1            ;
  LD A,($7556)            ; Nothing under the helicopter: retract a lowered
  CP $00                  ; rope
  RET Z                   ;
  LD E,$0C                ;
  XOR A                   ;
  LD ($7556),A            ;
  JR Winch_8              ;
Winch_2:
  INC B                   ; Survivor: B = 1-3 (pair index from the end); sprite
  LD HL,$F548             ; F548
  JR Winch_4              ;
Winch_3:
  LD HL,$F52F             ; Crate: B = 1-4; sprite F52F
Winch_4:
  LD ($7557),HL           ; $7557 = rope+object graphic
  LD A,(DE)               ; $7551 = plain tile that replaces the object in the
  LD ($7551),A            ; map
  LD HL,$FDA1             ; Object position in the view buffer area
  LD A,B                  ;
  ADD A,A                 ;
  ADD A,A                 ;
  ADD A,A                 ;
  LD B,$00                ;
  LD C,A                  ;
  AND A                   ;
  JR Winch_5              ;
IM2Vector:
  JP $83C2                ; IM2 interrupt vector target (I=$FF, table at $FF00
                          ; is all $F3): JP to the interrupt handler $83C2.
                          ; Skipped over by the JR above.
Winch_5:
  SBC HL,BC               ; DE = $FDA1-8*B
  EX DE,HL                ;
  LD A,($750D)            ; Helicopter altitude
  LD C,A                  ;
  LD HL,$FD96             ;
  AND A                   ;
  SBC HL,BC               ;
  EX DE,HL                ; DE = gap between helicopter and object
  AND A                   ;
  SBC HL,DE               ;
  EX DE,HL                ;
  LD A,D                  ; Not in reach (gap < 0 or > 255)
  CP $00                  ;
  RET NZ                  ;
  LD HL,$7556             ;
  LD A,E                  ; Gap >= 17: rope cannot reach
  CP $11                  ;
  JR C,Winch_9            ;
  LD E,$10                ; Rope length 16...
Winch_6:
  INC (HL)                ;
  LD A,$01                ;
  CP (HL)                 ;
  JR NZ,Winch_7           ;
  LD A,E                  ; ...or 12 on the first iteration
  CP $0D                  ;
  JR C,Winch_7            ;
  LD E,$0C                ;
  JR Winch_8              ;
Winch_7:
  LD (HL),$02             ; Winch state 2
Winch_8:
  LD A,E                  ; Draw the rope only (F51F)
  PUSH AF                 ;
  LD DE,$F51F             ;
  JP Winch_16             ;
Winch_9:
  CP $0D                  ; Gap < 13: advance the winch state
  JR NC,Winch_10          ;
  INC (HL)                ;
Winch_10:
  LD A,$01                ; Not yet extended twice: keep extending
  CP (HL)                 ;
  JR NC,Winch_6           ;
  LD A,E                  ; Hooked: rope length = max(gap,2)-1
  CP $02                  ;
  JR NC,Winch_11          ;
  LD A,$02                ;
Winch_11:
  DEC A                   ;
  LD ($7555),A            ;
  LD IX,($7552)           ; IX = island record under the helicopter
  LD B,(IX+$0B)           ; Island's map origin
  LD C,(IX+$0A)           ;
  LD A,($7502)            ; Map row = Y + 14 - origin Y ...
  ADD A,$0E               ;
  LD L,(IX+$08)           ;
  SUB L                   ;
  LD L,A                  ;
  LD H,$00                ;
  ADD HL,HL               ; ... * 128
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,BC               ;
  LD B,$00                ;
  LD A,($7500)            ; Map column = X + 11 - origin X
  ADD A,$0B               ;
  LD C,(IX+$06)           ;
  SUB C                   ;
  LD C,A                  ;
  ADD HL,BC               ;
  LD A,($7551)            ; Replace the object by the plain tile
  LD (HL),A               ;
  XOR A                   ; Winch state 0
  LD ($7556),A            ;
  LD A,($7557)            ; Survivor? Skip the crate count
  LD HL,$F548             ;
  CP L                    ;
  JR Z,Winch_12           ;
  LD A,($7554)            ; Crates collected + 1 (max 5)
  INC A                   ;
  CP $06                  ;
  JR Z,Winch_12           ;
  LD H,$5A                ; HUD crate box n (attributes $5ACA-2n, 2x2 cells) :=
  LD ($7554),A            ; red
  ADD A,A                 ;
  LD L,A                  ;
  LD A,$CA                ;
  SUB L                   ;
  LD L,A                  ;
  PUSH HL                 ;
  POP IX                  ;
  LD (IX+$00),$02         ;
  LD (IX+$01),$02         ;
  LD (IX+$20),$02         ;
  LD (IX+$21),$02         ;
Winch_12:
  LD A,($7555)            ; Draw rope + object
  JR Winch_15             ;
WinchReel:
  LD HL,$751B             ; Reeling in: rope length - 1 - descent rate ($751B),
  LD B,(HL)               ; not below 0
  CP B                    ;
  JR NC,Winch_13          ;
  LD B,A                  ;
Winch_13:
  SUB B                   ;
  LD ($7555),A            ;
  CP $00                  ; Still on the rope?
  JR NZ,Winch_15          ;
  LD A,($7557)            ; Arrived: 50 points for a survivor...
  LD HL,$F548             ;
  LD B,$32                ;
  CP L                    ;
  JR Z,Winch_14           ;
  LD B,$FA                ; ...250 for a crate
Winch_14:
  CALL AddScore           ;
  RET                     ;
Winch_15:
  LD HL,($7557)           ; Draw rope (A lines) + object (8 lines) below the
  LD B,$00                ; helicopter
  LD C,A                  ;
  ADD A,$08               ;
  SBC HL,BC               ;
  EX DE,HL                ;
  PUSH AF                 ;
Winch_16:
  LD A,$02                ; $7512 := 2
  LD ($7512),A            ;
  LD A,($750D)            ;
  INC A                   ;
  LD HL,$FE72             ;
  SRA A                   ;
  SRA A                   ;
  SRA A                   ;
  LD C,A                  ;
  LD B,$00                ;
  ADD A,$00               ;
  SBC HL,BC               ;
  LD ($752B),HL           ;
  LD HL,$7AAC             ;
  ADD HL,BC               ;
  LD ($7529),HL           ;
  LD A,($750D)            ;
  LD C,A                  ;
  LD B,$00                ;
  LD HL,$FD96             ;
  ADD A,$00               ;
  SBC HL,BC               ;
  EX DE,HL                ;
  POP AF                  ;
  CP $19                  ; Too long? Don't draw
  RET NC                  ;
  LD C,A                  ;
  JP $86EA                ; Draw C lines of graphic DE at HL ($86EA)

; Winch tables and graphics
  DEFB $8B,$57,$2F,$0F    ; Crate tiles $8B, $57, $2F, $0F
  DEFB $89,$8A,$55,$56,$2D,$2E ; Survivor tiles (pairs) $89/$8A, $55/$56,
                               ; $2D/$2E
  DEFB $58,$30,$10,$04    ; Plain tiles that replace them: $58, $30, $10, $04
  DEFB $08,$08,$08,$08,$08,$08,$08,$08 ; Rope (16 lines) above the crate
  DEFB $08,$08,$08,$08,$08,$08,$10,$08 ;
  DEFB $08,$34,$4A,$66,$7A,$72,$34,$18 ; Hook and crate (Winch pointer $7557)
  DEFB $00
  DEFB $08,$08,$08,$08,$08,$08,$08,$08 ; Rope (16 lines) above the survivor
  DEFB $08,$08,$08,$08,$08,$08,$08,$08 ;
  DEFB $18,$00,$3C,$5A,$18,$18,$18,$00 ; Survivor (Winch pointer $7557)

; Crash debris overlays
;
; 5 frames x 72 bytes (24x24 pixels), XORed one after another onto the wreck
; sprite in 6950 during the first 5 iterations of the crash sequence
; ($9246/$92ED, pointer $9243).
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$01,$01
  DEFB $00,$01,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $09,$09,$2E
  DEFB $4E,$2F,$71
  DEFB $E3,$AB,$E3
  DEFB $DD,$BF,$6A
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $80,$00,$00
  DEFB $80,$00,$80
  DEFB $00,$80,$80
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$02
  DEFB $00,$00,$04
  DEFB $00,$00,$03
  DEFB $05,$04,$07
  DEFB $0A,$01,$00
  DEFB $11,$02,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$09,$2F
  DEFB $3E,$4A,$2B
  DEFB $71,$C4,$98
  DEFB $AC,$80,$5E
  DEFB $CA,$DF,$1B
  DEFB $1D,$08,$44
  DEFB $80,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$20
  DEFB $10,$80,$00
  DEFB $10,$E0,$60
  DEFB $40,$E8,$60
  DEFB $F0,$C0,$40
  DEFB $20,$48,$00
  DEFB $20,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$02
  DEFB $00,$08,$04
  DEFB $01,$03,$15
  DEFB $06,$08,$06
  DEFB $02,$01,$08
  DEFB $00,$02,$04
  DEFB $08,$01,$00
  DEFB $00,$00,$00
  DEFB $00,$09,$2B
  DEFB $3B,$42,$AB
  DEFB $51,$C0,$80
  DEFB $20,$00,$42
  DEFB $82,$CB,$35
  DEFB $4F,$29,$04
  DEFB $80,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$24
  DEFB $10,$A0,$58
  DEFB $30,$B0,$28
  DEFB $2C,$9C,$3A
  DEFB $B0,$34,$00
  DEFB $80,$88,$44
  DEFB $20,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$10,$04
  DEFB $01,$02,$15
  DEFB $06,$10,$06
  DEFB $04,$01,$01
  DEFB $22,$00,$08
  DEFB $00,$01,$00
  DEFB $00,$00,$00
  DEFB $02,$0A,$31
  DEFB $80,$42,$88
  DEFB $40,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$90,$04
  DEFB $20,$01,$04
  DEFB $80,$08,$00
  DEFB $00,$00,$00
  DEFB $00,$10,$02
  DEFB $10,$20,$18
  DEFB $80,$10,$04
  DEFB $00,$0C,$1A
  DEFB $00,$04,$02
  DEFB $00,$80,$04
  DEFB $42,$20,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$02
  DEFB $00,$00,$04
  DEFB $00,$02,$10
  DEFB $00,$10,$00
  DEFB $00,$05,$00
  DEFB $01,$00,$08
  DEFB $00,$00,$10
  DEFB $20,$00,$00
  DEFB $00,$00,$20
  DEFB $10,$40,$80
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$00,$00
  DEFB $00,$10,$44
  DEFB $00,$80,$00
  DEFB $08,$00,$00
  DEFB $04,$00,$29
  DEFB $10,$04,$08
  DEFB $00,$00,$04
  DEFB $00,$06,$10
  DEFB $00,$00,$00
  DEFB $01,$80,$40
  DEFB $01,$00,$10
  DEFB $08,$00,$00

; Unused at load; overflow rows above the view buffer at run time
;
; Tall terrain columns are drawn upwards past the top row of the view buffer at
; Init, so this area is overwritten every iteration during play (observed
; $F6CD-$F74D).
  DEFB $02,$20,$10,$04,$00,$02,$00,$08,$00,$00,$02,$01,$C3,$87,$8C,$00
  DEFB $08,$00,$01,$00,$00,$20,$40,$00,$08,$00,$00,$80,$40,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$04,$00,$00,$00,$01,$00,$02,$00,$00,$00,$04
  DEFB $00,$10,$08,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00

; Initialisation
;
; Jumped to from the loader entry Entry after the tape has loaded. Copies the
; main-loop code to the printer buffer (F78A -> GameStart, 255 bytes) and the
; crate shuffle to ShuffleCrates (F88A, 232 bytes), writes JP $5EEC at
; ShuffleVector, fills the IM2 vector table $FF00-$FFFF with $F3 (vector $F3F3
; for any data bus value, incl. $FFFF/$0000 = $F3 $F3 from the ROM), sets I=$FF
; and IM 2 and enters the main menu. After this runs, the area from here to
; $F9FF is reused as the view buffer, so this code and the two source copies
; are overwritten during play.
Init:
  DI
  LD HL,$F78A
  LD DE,GameStart
  LD BC,$00FF
  LDIR
  LD HL,$F88A
  LD DE,ShuffleCrates
  LD BC,$00E8
  LDIR
  LD HL,ShuffleVector     ; FE92: JP $5EEC
  LD (HL),$C3             ;
  INC HL                  ;
  LD (HL),$EC             ;
  INC HL                  ;
  LD (HL),$5E             ;
  LD HL,$FF00             ; 256 bytes of $F3 (B=0)
  LD BC,$00F3             ;
Init_0:
  LD (HL),C               ;
  INC HL                  ;
  DJNZ Init_0             ;
  LD A,$FF                ;
  LD I,A                  ;
  IM 2                    ;
  EI                      ;
  JP MainMenu             ;

; Unused
  DEFS $06

; Source copy of the routine at $5B00 (duplicate)
;
; Identical to GameStart-$5BFE (255 bytes) after Init has copied it.
; Overwritten at run time (view buffer). See GameStart for the disassembly.
  DEFB $CD,$D6,$84,$CD,$0E,$8D,$CD,$F4,$84,$CD,$BC,$87,$06,$06,$21,$1E
  DEFB $66,$36,$2E,$23,$10,$FB,$36,$30,$CD,$00,$6F,$21,$64,$75,$11,$00
  DEFB $75,$01,$64,$00,$ED,$B0,$CD,$21,$83,$CD,$3A,$84,$CD,$92,$FE,$CD
  DEFB $72,$60,$00,$00,$00,$00,$CD,$F9,$80,$CD,$AE,$84,$CD,$D2,$76,$CD
  DEFB $F0,$87,$CD,$B4,$91,$CD,$91,$8B,$CD,$A0,$8C,$CD,$10,$7E,$CD,$AF
  DEFB $86,$CD,$9A,$F3,$CD,$7A,$8A,$CD,$D4,$85,$3A,$05,$75,$FE,$01,$CA
  DEFB $46,$92,$3A,$26,$75,$CB,$4F,$28,$1D,$CD,$12,$8F,$3A,$26,$75,$CB
  DEFB $67,$28,$19,$CB,$A7,$32,$26,$75,$CD,$0E,$8D,$CD,$5D,$8D,$CD,$5C
  DEFB $8E,$CD,$6A,$8F,$18,$06,$CD,$2C,$76,$CD,$34,$90,$CD,$D6,$7F,$3A
  DEFB $50,$75,$FE,$05,$DC,$78,$73,$3A,$15,$75,$FE,$01,$20,$0E,$3A,$16
  DEFB $75,$FE,$01,$20,$07,$3A,$2E,$75,$FE,$00,$28,$40,$CD,$AA,$80,$3A
  DEFB $54,$75,$FE,$05,$20,$16,$3A,$2E,$75,$FE,$01,$20,$0F,$3A,$52,$75
  DEFB $FE,$94,$20,$08,$3A,$53,$75,$FE,$F2,$CA,$26,$5B,$3A,$1C,$75,$FE
  DEFB $DE,$CA,$C8,$92,$CD,$70,$84,$CD,$84,$82,$CD,$4A,$F3,$3E,$FD,$DB
  DEFB $FE,$E6,$11,$C2,$3C,$5B,$00,$00,$00,$C3,$80,$E2,$21,$F2,$5B,$C3
  DEFB $D0,$92,$20,$4E,$4F,$20,$46,$55,$45,$4C,$20,$00,$00,$00,$00
  DEFB $00                ; Unused

; Source copy of the routine at $5EEC (duplicate)
;
; Identical to ShuffleCrates-$5FD3 (232 bytes). Overwritten at run time (view
; buffer). See ShuffleCrates.
  DEFB $21,$61,$5F,$06,$26,$C5,$7E,$FE,$FF,$20,$20,$36,$00,$E5,$23,$5E
  DEFB $23,$56,$1A,$D5,$11,$5D,$5F,$21,$59,$5F,$06,$04,$BE,$28,$08,$23
  DEFB $13,$10,$F9,$D1,$E1,$18,$04,$1A,$D1,$E1,$12,$23,$23,$23,$C1,$10
  DEFB $D4,$06,$05,$C5,$CD,$74,$8B,$7D,$FE,$4C,$30,$F8,$00,$00,$CB,$2F
  DEFB $47,$87,$80,$21,$61,$5F,$5F,$16,$00,$19,$7E,$FE,$FF,$28,$E5,$36
  DEFB $FF,$23,$5E,$23,$56,$1A,$D5,$11,$59,$5F,$21,$5D,$5F,$06,$03,$BE
  DEFB $28,$04,$23,$13,$10,$F9,$1A,$D1,$12,$C1,$10,$C7,$C9,$8B,$57,$2F
  DEFB $0F,$58,$30,$10,$04,$00,$05,$99,$00,$A5,$96,$00,$2F,$9A,$00,$18
  DEFB $A5,$00,$89,$A4,$00,$86,$B0,$00,$91,$AE,$00,$9B,$AF,$00,$14,$B1
  DEFB $00,$A6,$BA,$00,$09,$BD,$00,$BA,$BE,$00,$23,$C6,$00,$97,$C6,$00
  DEFB $87,$CE,$00,$1D,$D4,$00,$F3,$95,$00,$6B,$9C,$00,$E9,$A5,$00,$F7
  DEFB $A8,$00,$60,$AF,$00,$6C,$AF,$00,$6C,$B6,$00,$4B,$BF,$00,$FB,$BD
  DEFB $00,$D3,$C2,$00,$C0,$95,$00,$CA,$9D,$00,$39,$9E,$00,$3C,$A0,$00
  DEFB $49,$A8,$00,$43,$AE,$00,$D4,$B6,$00,$31,$CA,$00,$43,$C9,$00,$5E
  DEFB $C9,$00,$EC,$CD,$00,$E9,$DB,$00

; View buffer (rest)
;
; The view buffer occupies $F74E-$F9E8 (29 rows x 23 character cells; cleared
; every iteration by $76D2, row 0 at the top; $F8B1 = row 15 column 10 is the
; cell under the helicopter), $F9E9-$F9FF is a spare row used by $77F8/$7870.
  DEFS $8E

; Terrain character glyphs ($00-$7F)
;
; Glyph of character c (0-$7F) at $FA00+8*c, used by the view blitter $762C.
; $00-$5E are static terrain graphics ($30 = crate at $FB80; $31/$32 = the two
; survivors, animated by AnimateSurvivors; $33-$3E are rebuilt by $89AC-$8A66
; for the helicopter shadow). $5F-$7F ($FCF8-$FDFF) are dynamic glyphs rebuilt
; every iteration for the helicopter, rope and objects ($7F24, $85D4, $86AF,
; $7BB8). Codes $80+ have no glyph (solid colour).
  DEFB $00,$00,$00,$20,$54,$00,$00,$00
  DEFB $00,$00,$08,$52,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$14,$00,$00
  DEFB $FE,$FC,$F0,$C0,$91,$80,$00,$20
  DEFB $7F,$3F,$0F,$03,$89,$01,$00,$04
  DEFB $04,$00,$01,$89,$03,$0F,$3F,$7F
  DEFB $20,$00,$80,$91,$C0,$F0,$FC,$FE
  DEFB $FE,$FC,$F0,$E0,$E0,$E0,$80,$00
  DEFB $7F,$3F,$0F,$07,$07,$01,$01,$00
  DEFB $00,$01,$03,$03,$07,$1F,$1F,$7F
  DEFB $00,$80,$C0,$C0,$E0,$F8,$F8,$FE
  DEFB $FE,$FC,$F0,$E0,$E0,$E0,$80,$00
  DEFB $7F,$3F,$0F,$07,$07,$01,$01,$00
  DEFB $00,$01,$03,$03,$07,$1F,$1F,$7F
  DEFB $00,$80,$C0,$C0,$E0,$F8,$F8,$FE
  DEFB $01,$02,$0B,$15,$03,$57,$9F,$6F
  DEFB $00,$00,$00,$00,$00,$00,$3C,$FF
  DEFB $FF,$3C,$00,$00,$00,$00,$00,$00
  DEFB $03,$01,$01,$00,$00,$01,$01,$03
  DEFB $C0,$80,$80,$00,$00,$80,$80,$C0
  DEFB $00,$00,$00,$00,$00,$00,$00,$81
  DEFB $81,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$C0,$E0,$F0,$F0,$F8,$FC,$FF
  DEFB $00,$03,$07,$0F,$0F,$1F,$3F,$FF
  DEFB $80,$40,$00,$30,$08,$00,$06,$01
  DEFB $01,$02,$00,$0C,$10,$00,$60,$80
  DEFB $2A,$2A,$2A,$0A,$02,$02,$02,$00
  DEFB $BE,$B4,$A8,$F0,$E0,$E0,$40,$80
  DEFB $2A,$2A,$2A,$0A,$02,$02,$02,$00
  DEFB $54,$54,$54,$50,$40,$40,$40,$00
  DEFB $40,$80,$A0,$88,$B2,$A4,$A9,$AA
  DEFB $02,$01,$05,$11,$4D,$25,$95,$55
  DEFB $3F,$0F,$07,$07,$03,$03,$01,$00
  DEFB $00,$C0,$E0,$F0,$F0,$F8,$FC,$FF
  DEFB $FC,$F0,$E0,$E0,$C0,$C0,$80,$00
  DEFB $00,$03,$07,$0F,$0F,$1F,$3F,$FF
  DEFB $AE,$00,$00,$00,$00,$00,$00,$00
  DEFB $01,$06,$01,$00,$06,$01,$00,$02
  DEFB $80,$60,$80,$00,$60,$80,$00,$40
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $76,$01,$02,$01,$06,$01,$00,$02
  DEFB $6E,$80,$40,$80,$60,$80,$00,$40
  DEFB $55,$AA,$55,$AA,$55,$88,$11,$22
  DEFB $44,$88,$11,$22,$44,$88,$11,$22
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $08,$34,$4A,$66,$7A,$72,$34,$18
  DEFB $10,$44,$38,$10,$38,$7C,$28,$00
  DEFB $18,$42,$3C,$18,$18,$24,$24,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$00,$00,$00,$00,$00,$00
  DEFB $5A,$39,$5E,$9A,$77,$7C,$9B,$76
  DEFB $5A,$39,$5E,$9A,$77,$7C,$9B,$76
  DEFB $10,$28,$0C,$18,$36,$1A,$3A,$6C
  DEFB $10,$28,$0C,$18,$36,$1A,$3A,$6C
  DEFB $10,$28,$0C,$18,$36,$1A,$3A,$6C
  DEFB $10,$28,$0C,$18,$36,$1A,$3A,$6C
  DEFB $5A,$39,$5E,$9A,$77,$7C,$9B,$76
  DEFB $59,$3A,$38,$38,$10,$00,$00,$00
  DEFB $28,$36,$99,$6E,$3C,$4A,$6C,$B8
  DEFB $6A,$5C,$3A,$5C,$5C,$3A,$3C,$70
  DEFB $70,$38,$38,$38,$38,$10,$00,$00
  DEFB $28,$7C,$5E,$5A,$77,$7C,$9B,$76
  DEFB $5A,$39,$5E,$3A,$76,$FC,$E6,$74
  DEFB $3E,$38,$38,$38,$10,$00,$00,$00
  DEFB $52,$81,$40,$B2,$5D,$A0,$C0,$A9
  DEFB $43,$21,$50,$A1,$41,$A1,$C5,$62
  DEFB $3C,$1C,$1C,$1C,$1C,$08,$00,$00
  DEFB $08,$34,$4A,$66,$7A,$72,$34,$18
  DEFB $FF,$00,$00,$00,$00,$00,$00,$00
  DEFB $00,$00,$3C,$3C,$3C,$3C,$3C,$3C
  DEFB $FF,$00,$7C,$7C,$74,$7C,$00,$00
  DEFB $00,$00,$7C,$7C,$74,$7C,$00,$00
  DEFB $55,$55,$55,$55,$55,$55,$55,$55
  DEFB $56,$5A,$5A,$5A,$6A,$6B,$6F,$AD
  DEFB $AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA
  DEFB $AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ; Dynamic glyphs $5F-$7F
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;
  DEFB $00,$00,$00,$00,$00,$00,$00,$00 ;

; Terrain character attributes
;
; Attribute of character code c at $FE00+c (view blitter $762C: LD H,$FE / LD
; L,code). $FE5F-$FE7F hold the attributes of the dynamic glyphs (rebuilt at
; run time, 0 at load); $FE80-$FE91 the colours of the solid blocks $80-$91
; (e.g. $87 green, $89/$83 landing pad).
  DEFB $6F,$6F,$6F,$6E,$6E,$6E,$6E,$74,$74,$74,$74,$7C,$7C,$7C,$7C,$66
  DEFB $75,$75,$75,$75,$75,$75,$00,$24,$24,$6C,$6C,$60,$60,$68,$68,$60
  DEFB $60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$50,$50,$50
  DEFB $70,$60,$60,$68,$68,$68,$68,$68,$68,$68,$68,$68,$68,$68,$68,$68
  DEFB $68,$68,$68,$68,$68,$20,$68,$20,$38,$68,$60,$60,$60,$60,$60,$60
  DEFB $60,$60,$60,$30,$30,$62,$60,$38,$38,$38,$38,$60,$60,$60,$60
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Dynamic
  DEFB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; glyph
  DEFB $00                                                             ; attributes
  DEFB $6D,$64,$76,$7F,$52,$5B,$6D,$24,$36,$3F,$12,$1B,$49,$09,$40,$00 ; Solid
  DEFB $00,$00                                                         ; block
                                                                       ; colours
                                                                       ; ($80-$91)

; Jump to the crate shuffle
;
; Written by Init over the loader's LD DE,$9EB6. Called by 5B2C and the menu
; loop MenuLoop.
ShuffleVector:
  JP ShuffleCrates

; Unused remnant of the tape loader
;
; Part of the original turbo loader (Entry is the old continuation). Never
; executed.
  CALL $FE9F

; Program entry point (RANDOMIZE USR 65176)
;
; The BASIC loader loads the screen ("Cyclone2"), this 512-byte block at $FE00
; ("Cyclone4") and the main block at $5FDC-$FE91 ("Cyclone3", which overwrites
; $FE00-$FE91) with the ROM, then calls here. In the original loader block
; $FE00 decrypted $FE80-$FFFF (XOR with R) and $FE80 loaded the screen and the
; main block with its own LD-BYTES at $FE9F before falling into this code; that
; path is not used by this version.
Entry:
  LD SP,$FEFF
  EI
  JP Init

; Unused remnant of the tape loader's LD-BYTES routine
;
; A copy of the ROM's LD-BYTES ($0556) used by the original turbo loader; its
; second half ($FF00+) has been overwritten by the IM2 table. Never executed.
; The stack (SP=$FEFF) grows down into its last bytes (observed $FEE5-$FEFE in
; use).
  XOR A
  SCF
  INC D
  EX AF,AF'
  DEC D
  DI
  LD A,$08
  OUT ($FE),A
  LD HL,$FF49
  PUSH HL
  IN A,($FE)
  RRA
  AND $20
  OR $00
  LD C,A
  CP A
  RET NZ
  CALL $FF2B
  JR NC,$FEB6
  LD HL,$0415
  DJNZ $FEBF
  DEC HL
  LD A,H
  OR L
  JR NZ,$FEBF
  CALL $FF27
  JR NC,$FEB6
  LD B,$9C
  CALL $FF27
  JR NC,$FEB6
  LD A,$C6
  CP B
  JR NC,$FEB7
  INC H
  JR NZ,$FECB
  LD B,$C9
  CALL $FF2B
  JR NC,$FEB6
  LD A,B
  CP $D4
  JR NC,$FEDA
  CALL $FF2B
  RET NC
  LD A,C
  XOR $00
  LD C,A
  LD H,$00
  LD B,$75
  JR $FF0C
  EX AF,AF'
  JR NZ,$FEFC
  LD (IX+$00),L
  JR $FF06
  RL C
  XOR L
  RET NZ

; IM2 vector table
;
; 256 bytes of $F3 (written by Init). With I=$FF the CPU reads the vector from
; $FFxx/$FFxx+1, always $F3F3 (for bus value $FF the second byte is $0000 in
; ROM, also $F3), which holds JP $83C2 (IM2Vector).
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3
  DEFB $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3

