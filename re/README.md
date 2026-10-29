# Cyclone (Vortex Software, 1985) — reverse engineering

Complete reverse engineering of the ZX Spectrum 48K game *Cyclone* (Costa Panayi / Vortex), from the
TAP image in `../original/`. All 4,300 executed instructions and every data region in $5B00–$FFFF are
identified and annotated.

The 3D remake built from this work is in [`../remake`](../remake/README.md).

## Contents

| Path | What |
|---|---|
| `ctl/cyclone.ctl` | Master SkoolKit control file (merged from `frontend`, `core1`, `core2`, `core3`, `data`) |
| `build/cyclone.skool`, `build/cyclone.asm` | Annotated disassembly (skool + assembler listing) |
| `build/html/cyclone/index.html` | Browsable HTML disassembly with cross-references |
| `notes/frontend.md` | Boot, loader, menu, controls, main loop, game flow, crates/survivors/winch |
| `notes/core1.md` | Variable glossary ($7500–$7563), view-window builder, terrain projection, shadow |
| `notes/core2.md` | Input, flight model, fuel/time/altimeter bars, HUD, aircraft, interrupt sound |
| `notes/core3.md` | Collision/landing, RNG, sea waves, helicopter sprite, map screen, cyclone, death |
| `notes/data.md` | World/island data format, tile column tables, charset, sprites, fonts, asset files |
| `assets/` | Extracted graphics, world grid (768×768), fonts, HUD, verification renders |
| `snapshots/` | `cyclone.tap`, `init.z80` (canonical post-init image), plus menu/info/in-game states |
| `tools/` | Emulation driver (scripted keys), disassembly helpers, asset extractors, render verifier, `reftrace.py` (original-vs-remake state comparison and autopilot), `export_remake_data.py` |

Rebuild: `sna2skool.py -H -c ctl/cyclone.ctl snapshots/init.z80 > build/cyclone.skool`, then
`skool2html.py -H -d build/html build/cyclone.skool` / `skool2asm.py -H build/cyclone.skool`.

Evidence tags used in the notes: **CODE** (read from disassembly), **OBSERVED** (seen in emulation under
SkoolKit's simulator with scripted input and breakpoints), **INFERRED** (interpretation).

## Summary of the machine

* **Loading**: BASIC → SCREEN$ → 512-byte loader at $FE00 → 40,630-byte block at $5FDC. `USR 65176` →
  $FE98 → init $F74E: relocates the main loop to $5B00 (printer buffer) and the crate shuffler to $5EEC,
  fills an IM2 table at $FF00 with $F3 (vector $F3F3 = `JP $83C2`, hidden inside the winch routine),
  `IM 2`, menu at $E280. The 16 Z80 snapshot variants are the same program in different saved states.
* **Timing**: no HALT; the main loop free-runs at ~4–5.6 TV frames per iteration (≈ 9–11 Hz). Every game
  timer counts *iterations*. The 50 Hz interrupt only makes sound (rotor chop, winch click, crash noise).
* **RNG** ($8B74): `seed' = (254·(seed+1) mod 65537) − 1`, seed in ROM SYSVAR SEED $5C76.

## Game rules (reconciled across all notes)

* **World**: 768×768 tile cells (3×3 sectors of 256), 14 islands stored as rectangular blocks in
  $9300–$DDFF (128-byte rows), placed by the 20-byte records at $F230. Everything else is sea. The view
  is a 23×22 window of the 23×29 buffer whose origin is (X,Y) = ($7500,$7502); the helicopter's ground
  cell is (X+11, Y+14). The map grid used by the cyclone/map screen is 23×22 cells of 32×32 tiles.
* **Projection**: each tile code expands into a *column* of 8×8 chars (pages $63+k north, $6C+k
  south; $FE skip, $FF end). Level k is drawn k rows above the tile; nearer rows overwrite. This is
  exactly an orthographic view at 45° from the south: level-k chars are south-facing cube faces, the
  last char is the top face. The south view is the window rotated 180° using the second page set
  (north faces). Only two views exist (N key toggles).
* **Helicopter**: 8 headings (45° steps; a turn takes 4 iterations and shows an odd in-between frame);
  while speed ($7527, 0–7) > 0 it moves exactly 1 tile per iteration per axis (diagonals √2 faster).
  Speed is only momentum: 6 iterations of coasting after releasing thrust. Climb/descent ramps
  1→2→3 px per iteration; altitude 0–60 px (8 px = one level). Landed state snaps altitude to ×8.
* **Collision/landing** ($8A7A): footprint = 3×3 cells; terrain class = number of thresholds
  `0F 10 2E 30 56 58 89 8C A5 B2 C2 D0 D9 E4 EC F0 F6 FF` ≤ tile (2 classes per level, odd = object on
  top). `alt>>2 ≥ class` clears a cell. Partial clearance = crash; touching at descent rate 3 = crash;
  touchdown requires every top char to be landable; all 9 helipad chars ($83/$89) = on pad.
* **Fuel**: 40 bar lines, −1 per 49 iterations whenever not on the base pad; +1 per iteration on the
  pad. Empty: forced descent, no thrust/climb; landing empty away from the pad = "NO FUEL" (lose a life).
  Each life starts on the pad with an empty tank.
* **Time**: 40 lines (+1 tick), one per 255 iterations in round 1, 15 fewer per later round. Running out
  = "NO TIME" = game over. Time bonus at round start: 40 points per remaining line.
* **Crates/survivors**: 5 crates on random sites of 38 (shuffled continuously while the menu waits);
  survivors on all 45 survivor sites each round. Hover low over one: the rope drops, the object is
  hooked (map tile replaced) and reeled in; +250 per crate, +50 per survivor on arrival. Five crates and
  landing on the Base island pad completes the round: bonus 2-step add = 352/288/224 for 0/1/2 lives
  lost (an original bug passes 102 to the second add instead of 250−64n).
* **Lives**: 3 per round (restored every round). Death: 24-iteration explosion, icon turns red, respawn
  on base pad; 3 lost = straight back to the menu. A+G abandons.
* **Cyclone**: invisible except through effects. Map-grid position (1..21, 1..20), starts in a random
  corner; one grid step every 25 iterations using 16 equiprobable direction regimes (re-picked every 9
  steps or at edges). Chebyshev distance d (≤15) sets WIND FORCE = 16−d, DANGER flashes at d<6, and at
  d<5 (round 1; d<6 later) the controls get random bits ORed in (`RND & $1A` at d≥4, `& $1B` at 2–3,
  forced down+left at d<2).
* **Aircraft**: 19 planes, 2 tiles per iteration in 16 directions, steered by a 15-step script (one
  step per 28 iterations, some steps respawn a plane at its entry point). Only the first plane within
  ±12/±15 tiles is drawn; its height level ($87EF) creeps one level per iteration towards the
  helicopter's level, and touching it at the same level is a crash. BEWARE AIRCRAFT flashes within
  ±22/±25.

## Reconciliation notes
* $87EF is the **aircraft's** height level (core2, verified by an emulated collision through the
  $8B36 "very tall" branch); core3's notes call it the helicopter's level — that is superseded.
* Cyclone "cells" (core3) are map-grid cells of 32×32 tiles; the world itself is 768×768 tiles (data).
* There is no cyclone sprite anywhere: traced reads during flight, map and crash never touch one.
