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
N $9300 6: GILLIGANS ISLAND at #R$9354 (store row 0, col 84), 45x30, world (306,116) = sector (1,0) local (50,116).
N $9300 7: RED ISLAND at #R$9FD8 (store row 25, col 88), 41x29, world (398,604) = sector (1,2) local (142,92).
N $9300 8: SKEG ISLAND at #R$ADD8 (store row 53, col 88), 40x29, world (134,540) = sector (0,2) local (134,28).
N $9300 9: BONE ISLAND at #R$B843 (store row 74, col 67), 62x29, world (450,152) = sector (1,0) local (194,152).
N $9300 10: GIANTS GATEWAY at #R$9337 (store row 0, col 55), 30x41, world (430,296) = sector (1,1) local (174,40).
N $9300 11: CLAW ISLAND at #R$A735 (store row 40, col 53), 36x35, world (474,476) = sector (1,1) local (218,220).
N $9300 12: LUKELAND ISLES at #R$C628 (store row 102, col 40), 40x33, world (70,588) = sector (0,2) local (70,76).
N $9300 13: ENTERPRISE ISLAND at #R$C64F (store row 102, col 79), 50x48, world (90,460) = sector (0,1) local (90,204).
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
i $E280
