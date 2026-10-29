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
D $75C8 After a lost life 92B3 copies these 100 bytes over #R$7500, except that a byte of $FF leaves the variable unchanged (time bar #R$751C, map marker pointers #R$7543-#R$754A, cyclone state #R$754B/#R$754C/#R$754E/#R$754F and crates #R$7554 survive a death). The values otherwise equal #R$7564.
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
