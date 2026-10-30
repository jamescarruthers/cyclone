# Cyclone 3D — a Rust + wgpu remake of Cyclone (Vortex Software, 1985)

A recreation of the ZX Spectrum game *Cyclone* (Costa Panayi) in true 3D. It keeps the original's
look, rules and timing. The reverse engineering it is built on is in [`../re`](../re/README.md).

## Build and run

```sh
cargo run --release
```

Requires a Rust toolchain (tested with 1.98) and a GPU supported by wgpu (Metal, Vulkan or DX12).

### Browser version

```sh
rustup target add wasm32-unknown-unknown
cargo install wasm-bindgen-cli --version 0.2.129   # must match wasm-bindgen in Cargo.lock
web/build.sh                                       # builds web/dist
python3 -m http.server -d web/dist 8080            # then open http://localhost:8080
```

`web/dist` is a static site (`index.html`, `cyclone.js`, `cyclone_bg.wasm`: 4.3 MB, 1.2 MB
gzipped) that any web server can host. It uses WebGPU where the browser has it and falls back
to WebGL 2. Click the game (or press a key) to give it the keyboard; sound starts with the first
key press, as browsers require. The Wireframe button does the same as F2; the Fullscreen button
replaces F11.

### GitHub Pages

The `Deploy to GitHub Pages` workflow builds and deploys this browser version on pushes to `main`.
In the repository settings, set **Pages → Build and deployment → Source** to **GitHub Actions**.
The site URL is shown in the workflow deployment environment after the first successful run.

## Controls

The game reads the keyboard exactly as the original did.

| Key | Action |
|---|---|
| `1`–`5` | up (climb; first press takes off) |
| `Q`–`T` | down |
| `O` / `P` | turn left / right (45° steps) |
| `Shift`, `Z`, `X`, `C`, `V` | forward (thrust) |
| `N` | view north ↔ south (the camera swings round) |
| `[` / `]` | rotate the view 45° anticlockwise / clockwise (the camera swings round, as for `N`) |
| `M` | map ↔ main screen |
| `A` + `G` | abandon the game |
| Menu `1`–`6` | information, keyboard, Interface 2, Kempston, Protek/AGF, start |
| Arrows + right Ctrl | Kempston joystick (choose option 4) |
| `F1` | orthographic "classic" camera ↔ perspective |
| `F2` | textured ↔ wireframe 3D view (a diagonal wipe moves between them) |
| `F11` | fullscreen |

Objective (from the original information screen): collect five crates, then return to base and land
on the helipad. Rescue survivors for extra points. Watch the fuel (F) and time (T) bars, avoid the
aircraft, and stay away from the cyclone: you can't see it, but the WIND FORCE bar and DANGER warning
show how close it is.

## How it works

* **Game logic: a port of the original code** (`src/game.rs`). Each routine of the Z80 program is
  translated one to one, and its doc comment gives the original address. The port keeps the
  original 64 KB memory layout: variables at `$7500`, the self-modified operands, the tile store,
  the view buffer and the screen all live at their original addresses, in an image of the game
  after loading (`data/mem.bin`). Quirks are kept, for example the round-bonus bug, the altimeter's
  `$4F` comparison and the aircraft-collision comparison.
* **Timing**: the original main loop free-runs at about 9–10 iterations per second, and every game
  timer counts iterations. The port is straight-line code: beeps block, the same as ROM BEEPER, and
  a virtual clock drives the 50 Hz interrupt (rotor chop, winch click and crash noise) and paces
  the game against the wall clock (`src/sys.rs`). The routines that pass time are `async`. On the
  desktop the game runs on its own thread and the pacing point sleeps. In the browser the game
  is a future polled once per animation frame, and the pacing point waits until the clock catches
  up.
* **Sound**: 1-bit beeper tones rendered through cpal (`src/audio.rs`).
* **3D world** (`src/world.rs`, `src/render.rs`, `src/shader.wgsl`). The original draws each map
  tile as a column of 8×8 characters (pages `$63+k` for the north view, `$6C+k` for the south view).
  Geometrically that is an oblique view of a stack of cubes, so each column becomes real cubes:
  * the char at level k textures that cube's south face, the south-view char its north face, and the
    last char the top face;
  * trees, crates and survivors are upright cards that turn to face the camera;
  * all textures are the original glyphs in their attribute colours, and cyan "sky" pixels are cut
    out. So is the paper of the object cards: it is the background the original drew behind the
    object, which the 3D view now shows for real (so shadows pass behind trees). Back faces are
    culled, so you see the sea through a cut-out pixel, not the inside of the cube;
  * the red-roofed houses (two tiles deep: striped roof char on the front row, checked on the
    back) get gable roofs, with the ridge between the rows; the original draws the roof flat.
    Their end walls always show windows (the original swaps window and plain chars between the
    north and south views);
  * a terrace's corner on the coast, which the original rounds off with a diagonally cut top
    char, is cut through its whole height: a triangular prism with a diagonal cliff wall, so no
    square wall sticks up past the cut when the camera turns;
  * shadows are cut along the tile edges, so each piece lies on its own tile's surface (and on
    the slope of a roof, and along a cut corner's diagonal).

  With the orthographic camera (F1) the 45° view reproduces the original screen almost pixel for
  pixel. The perspective camera is the default.
* **Sprites** (`src/scene.rs`): the helicopter, aircraft, shadows, rope and crash debris use the
  original frames. The frame is picked from the heading relative to the camera, so the helicopter
  and aircraft turn properly as the camera swings round. Positions are interpolated between game
  iterations.
* **HUD, menus and map** are drawn by the ported routines into the emulated Spectrum screen memory,
  then shown on top of the 3D view (`src/zx.rs`).

## Verification against the original

`../re/tools/reftrace.py` runs the original program under SkoolKit's Z80 simulator. It feeds the
same per-iteration keyboard input to the original and to the port (`cyclone --trace`) and compares
the full game state at every main-loop iteration: all variables, score, aircraft table, the tile
store, the HUD screen memory and the footprint under the helicopter.

```sh
python -I ../re/tools/reftrace.py gen 1 3000 s.txt                     # random flight
python -I ../re/tools/reftrace.py run ../re/snapshots/info.z80 s.txt start.bin rs.txt > ref.trace
python -I ../re/tools/reftrace.py auto ../re/snapshots/info.z80 6000 a.txt start.bin rs.txt > ref.trace   # autopilot
cargo run --release -- --trace start.bin rs.txt > rust.trace
python -I ../re/tools/reftrace.py diff ref.trace rust.trace
```

Results:

* Three random flights: identical.
* An autopilot run of 4,845 iterations: identical. It collects crates with the winch, completes a
  round with its bonus, plays the next round and ends in game over.

The only difference is the RNG seed at the start of a new life. The original's crash noise calls the
RNG from the interrupt handler a timing-dependent number of times, so the harness re-syncs the seed
there.

## Other modes

* `cyclone --video START.bin SCRIPT OUT.mp4 [ITERATIONS] [N-presses] [W-toggles]`: renders a
  gameplay MP4 with sound (needs ffmpeg; set `CYCLONE_FFMPEG` to point at the binary).
  `N-presses` and `W-toggles` are comma-separated iterations: at each N press the camera swings
  round, and at each W toggle the 3D view wipes between textured and wireframe. The showcase is
  the autopilot run (`reftrace.py auto`, see above) with
  `1700 260,340 515,690,1520,1620`.
* `cyclone --orbit ISLAND DIR [FRAMES] [PITCH] [STRETCH]`: orbit renders of an island (0–13).
* `cyclone --wipe ISLAND OUT.mp4 [SECONDS]`: an orbit of an island that starts textured, then
  wipes to the wireframe view (needs ffmpeg, as `--video`).
* `cyclone --shot X Y SOUTH ORTHO OUT.ppm`: the in-game camera at a given window origin.
* `cyclone --demo SCRIPT DIR [EVERY]`: composed screenshots from a scripted game.
* `CYCLONE_SNAPSHOT=SECONDS:FILE.ppm cyclone`: save one frame from the live window, then quit.

## Data

`data/` holds the original game's memory after loading (with the 256 ROM bytes the sea-wave code
reads as random data) and screens captured from the original: menu, information, map and the
loading screen. They are regenerated by `../re/tools/export_remake_data.py`. These are the
original copyrighted assets, for personal and preservation use.
