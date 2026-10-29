mod app;
mod audio;
mod game;
mod render;
mod scene;
mod sys;
#[cfg(not(target_arch = "wasm32"))]
mod offline;
#[cfg(not(target_arch = "wasm32"))]
mod trace;
mod world;
mod zx;

#[cfg(not(target_arch = "wasm32"))]
use offline::*;

/// The browser build: just the game (see `web/`).
#[cfg(target_arch = "wasm32")]
fn main() {
    console_error_panic_hook::set_once();
    console_log::init_with_level(log::Level::Info).ok();
    app::run();
}

#[cfg(not(target_arch = "wasm32"))]
fn main() {
    env_logger::init();
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(|s| s.as_str()) {
        Some("--trace") => trace::run(&args[2], &args[3]),
        Some("--orbit") => {
            let island = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(5);
            let dir = args.get(3).cloned().unwrap_or_else(|| "orbit".into());
            let frames = args.get(4).and_then(|s| s.parse().ok()).unwrap_or(12);
            let pitch = args.get(5).and_then(|s| s.parse().ok()).unwrap_or(40.0);
            let stretch = args.get(6).and_then(|s| s.parse().ok()).unwrap_or(1.0);
            orbit(island, &dir, frames, pitch, stretch);
        }
        Some("--wipe") => {
            let island = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(5);
            let out = args.get(3).cloned().unwrap_or_else(|| "wipe.mp4".into());
            let secs = args.get(4).and_then(|s| s.parse().ok()).unwrap_or(12.0);
            wipe(island, &out, secs);
        }
        Some("--wire-stills") => {
            let wipes: Vec<f32> = args[5].split(',').filter_map(|x| x.parse().ok()).collect();
            wire_stills(args[2].parse().unwrap(), &args[3], args[4].parse().unwrap(), &wipes);
        }
        Some("--shot") => {
            let x: f32 = args[2].parse().unwrap();
            let y: f32 = args[3].parse().unwrap();
            shot(x, y, args[4] == "1", args[5] == "1", &args[6]);
        }
        Some("--demo") => {
            let every = args.get(4).and_then(|s| s.parse().ok()).unwrap_or(10);
            demo(&args[2], &args[3], every, args.get(5).map(|s| s == "ortho").unwrap_or(false));
        }
        Some("--video") => {
            let max = args.get(5).and_then(|s| s.parse().ok()).unwrap_or(usize::MAX);
            let extra: Vec<usize> = args.get(6).map(|s| s.split(',').filter_map(|x| x.parse().ok()).collect()).unwrap_or_default();
            let wire: Vec<usize> = args.get(7).map(|s| s.split(',').filter_map(|x| x.parse().ok()).collect()).unwrap_or_default();
            video(&args[2], &args[3], &args[4], max, extra, wire);
        }
        _ => app::run(),
    }
}
