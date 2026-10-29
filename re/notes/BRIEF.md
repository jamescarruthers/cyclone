# Cyclone (Vortex Software, 1985, ZX Spectrum 48K) — shared RE brief

## Goal
Produce an annotated disassembly and a technical description of the game precise enough
to build a faithful remake: game rules, physics, AI, rendering, data formats, timings.

## Environment
- Python with SkoolKit 9.x + Pillow: `$PY` = /private/tmp/claude-501/-Users-james-Library-CloudStorage-Dropbox-Apps-GitHub-cyclone/050e6649-2128-42d6-b209-13f7f501be4f/scratchpad/venv/bin/python  (always run with `-I`)
  SkoolKit CLIs live next to it in the same venv bin/ (sna2skool.py, trace.py, snapinfo.py, skool2asm.py ...).
- Project dir: /Users/james/Library/CloudStorage/Dropbox/Apps/GitHub/cyclone/re
  - snapshots/init.z80   — CANONICAL image: tape loaded + init code at F74E run, PC=E280 (main menu entry). Use this for disassembly.
  - snapshots/cyclone.z80 — straight after tape load (PC=FE98).  info.z80 = info screen; play1.z80 = mid-game.
  - build/exec_map.txt   — every address executed during ~15 min of emulated menu + gameplay (runtime evidence).
  - ctl/base.ctl         — automatic code/data split (recursive descent seeded by exec map). build/base.skool = its disassembly.
  - tools/dis.py SNAP START END  — quick linear disassembly (hex addresses).
  - tools/drive.py CONFIG.json — runs a snapshot with scripted key presses, writes code map + PNG screenshots per frame.
      config: {"sna":..., "frames":N, "map":"out_map.txt", "prefix":"shot", "script":[[startFrame,endFrame,"KEYS"],...], "shots":[frame,...], "out":"final.z80"}
      keys: SHIFT Z X C V A S D F G Q W E R T 1-0 P O I U Y ENTER L K J H SPACE SYM M N B. Run from your own working dir (outputs are relative).
      From info.z80: frame 10 SPACE (back to menu), 100 "2" (keyboard), 200 "6" (start game) → gameplay from ~frame 300. See tools/c2.json.
  - tools/bitmap.py SNAP START END COLHEIGHT BYTESWIDE SCALE OUT.png — render memory as 1bpp bitmap columns.
  - `trace.py` supports -S stop addr, -p pokes, -v verbose instruction trace, --map, -M max tstates; output PNG/z80.
  You may write your own Python helpers (e.g. a tracer that logs writes to a variable, or that stops on a breakpoint
  and dumps registers) using skoolkit.simulator / skoolkit.trace.Tracer (see tools/drive.py for how to construct one).
- Do your scratch work in /private/tmp/claude-501/-Users-james-Library-CloudStorage-Dropbox-Apps-GitHub-cyclone/050e6649-2128-42d6-b209-13f7f501be4f/scratchpad/agents/<your-area>/ . Do NOT modify existing files in re/; only create your own output files.

## What is already known
- Tape: BASIC CLEAR 24539; SCREEN$ to 4000; 512-byte loader at FE00; main block 40630 bytes at 5FDC (24540–65169). USR 65176 → LD SP,FEFF; EI; JP F74E.
- F74E init: copies F78A→5B00 (255 bytes) and F88A→5EEC (232 bytes); writes JP 5EEC at FE92; fills FF00–FFFF with F3 (IM2 table); I=FF; IM 2; JP E280.
- IM2 interrupt vector → F3F3: JP 83C2 (interrupt handler; beeper sounds via ROM BEEPER 03B5; checks 752D, 7505, 7515/7516, 7555, 755D, 7527).
- E280: main menu (1 info, 2 keyboard, 3 Interface 2, 4 Kempston, 5 Protek/AGF, 6 start). 7FD5 = control method. Menu loop calls FE92 (→5EEC: crate placement shuffle using RNG 8B74) while waiting. E3B4 = info screen. "6" → JP 5B00.
- 5B00 = game start / main game loop: 84D6, 8D0E, 84F4, 87BC init; copies 100 bytes 7564→7500 (initial variable values → live variables 7500–7563); then per-frame loop at 5B36 calls 80F9, 84AE, 76D2, 87F0, 91B4, 8B91, 8CA0, 7E10, 86AF, F39A, 8A7A, 85D4, ... and checks 7505 (=1 → JP 9246), 7526 flags, 7550, 7515/7516, 752E, 7554, 7552/7553.
- Keys (info screen): 1 up, Q down, O left, P right, X forward, N view change (N/S/E/W view), M map/main screen.
  HUD: A S F T bars (altimeter, speedometer, fuel, time left), compass/heading, lives (helicopter icons), "VIEW NORTH", "BEWARE AIRCRAFT" collision warning,
  S/H counters (survivors?/ ...), crates-left boxes, WIND FORCE bar, DANGER (approaching cyclone).
  Objective: collect five crates and return to base; rescue survivors for extra points. Islands named on map (Gilligans, Peak, Bone, Kokola, Lagoon, Giants Gateway, Banana, Base, Enterprise, Claw, Skeg, Orte Rocks, Lukeland Isles, Red Island).
  View is an isometric 3D island landscape, rotatable in 4 directions.
- ROM calls: 03B5 = BEEPER (DE=cycles, HL=pitch). Indirect jumps JP (HL)/(IX) found at 775D and 791C — check for jump tables.

## Output requirements (for your assigned address range)
1. `re/ctl/<area>.ctl` — a SkoolKit control file covering EXACTLY your range (first line a block directive at your range start;
   blocks must tile the range with no gaps/overlap). Use: `c/b/t/w/s/u $ADDR Title`, `D $ADDR description`, `R $ADDR A Meaning`
   for inputs/outputs, `N $ADDR note`, instruction comments as ` $ADDR comment` (leading space). Use sub-block directives
   (`B $ADDR,len`, `T`, `W`, `S`) for data layout. Fix wrong code/data splits from base.ctl (missing code, data mistaken for code).
   Validate with: `$VENV/sna2skool.py -c your.ctl -s START -e END re/snapshots/init.z80 > /dev/null` (must run without errors).
2. `re/notes/<area>.md` — routine-by-routine explanation (address, name, purpose, inputs/outputs, callers, side effects), every
   variable/table address touched with its inferred meaning, units, ranges and initial value, and all game mechanics you uncover,
   with exact constants (speeds, thresholds, timers, scoring, probabilities, frame counts). Mark each claim as
   OBSERVED (seen in emulation), CODE (read directly from the disassembly) or INFERRED (your interpretation). List open questions.
Be thorough and concrete: numbers and formulas over vague prose. Remake-relevant detail is the priority.
