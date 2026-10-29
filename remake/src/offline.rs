//! Offline modes of the desktop build: showcase renders, scripted demos and gameplay video.

use crate::{app, audio, game, render, sys, world, zx};
use glam::Vec3;

pub fn write_ppm(path: &str, w: u32, h: u32, rgba: &[u8]) {
    let mut out = format!("P6\n{w} {h}\n255\n").into_bytes();
    for p in rgba.chunks(4) {
        out.extend_from_slice(&p[..3]);
    }
    std::fs::write(path, out).expect("write");
}

/// A renderer holding the populated world, and the centre, size and name of an island.
fn island_view(island: usize) -> (render::Renderer, Vec3, f32, String, f64) {
    let mut mem = zx::Mem::original();
    {
        let sys = sys::Sys::new(sys::Shared::new(), None, false);
        let mut g = game::Game::new(mem.clone(), sys);
        g.populate();
        mem = g.m.clone();
    }
    let mut r = render::headless();
    r.rebuild_world(&mem.0, None);
    let isl = world::islands(&mem.0);
    let grid = world::world_grid(&mem.0, &isl);
    let i = &isl[island];
    let (mut sx, mut sy, mut n) = (0f64, 0f64, 0f64);
    let (mut minx, mut maxx, mut miny, mut maxy) = (i32::MAX, i32::MIN, i32::MAX, i32::MIN);
    for y in i.y0..i.y0 + i.h {
        for x in i.x0..i.x0 + i.w {
            if grid[y as usize * world::WORLD + x as usize] != 0 {
                sx += x as f64;
                sy += y as f64;
                n += 1.0;
                minx = minx.min(x);
                maxx = maxx.max(x);
                miny = miny.min(y);
                maxy = maxy.max(y);
            }
        }
    }
    let c = Vec3::new((sx / n) as f32 + 0.5, 1.5, (sy / n) as f32 + 0.5);
    let ext = ((maxx - minx).max(maxy - miny)) as f32;
    (r, c, ext, i.name.clone(), n)
}

fn orbit_camera(c: Vec3, ext: f32, yaw: f32, pitch_deg: f32, stretch: f32) -> render::Camera {
    render::Camera {
        target: c,
        yaw,
        pitch: pitch_deg.to_radians(),
        dist: ext * 0.9 + 20.0,
        half_h: ext * 0.22 + 3.0,
        stretch,
        ortho: false,
    }
}

/// Showcase: orbit the camera around an island and write frames as PPM files.
pub fn orbit(island: usize, dir: &str, frames: usize, pitch_deg: f32, stretch: f32) {
    let (mut r, c, ext, name, n) = island_view(island);
    std::fs::create_dir_all(dir).unwrap();
    let (w, h) = (960u32, 720u32);
    for f in 0..frames {
        let cam = orbit_camera(c, ext, f as f32 / frames as f32 * std::f32::consts::TAU, pitch_deg, stretch);
        let px = r.capture(w, h, Some((&cam, [0.0, 0.0, w as f32, h as f32])), None, [0.0, 0.0, 0.0]);
        write_ppm(&format!("{dir}/orbit_{f:03}.ppm"), w, h, &px);
    }
    println!("{name} ({n} cells): {frames} frames in {dir}");
}

/// Showcase video: orbit an island, textured at first, then a wipe reveals the wireframe.
/// `secs`: length; the wipe runs from 30% to 55% of it.
pub fn wipe(island: usize, out: &str, secs: f32) {
    use std::io::Write;
    const FPS: f32 = 40.0;
    let (w, h) = (1280u32, 720u32);
    let (mut r, c, ext, name, _) = island_view(island);
    let ffmpeg = std::env::var("CYCLONE_FFMPEG").unwrap_or_else(|_| "ffmpeg".into());
    let mut child = std::process::Command::new(&ffmpeg)
        .args(["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", &format!("{w}x{h}"), "-r", "40", "-i", "-",
               "-c:v", "libx264", "-preset", "slow", "-crf", "21", "-pix_fmt", "yuv420p", "-movflags", "+faststart", out])
        .stdin(std::process::Stdio::piped())
        .spawn()
        .expect("ffmpeg");
    let frames = (secs * FPS) as usize;
    let stdin = child.stdin.as_mut().unwrap();
    for f in 0..frames {
        let t = f as f32 / frames as f32;
        let k = ((t - 0.3) / 0.25).clamp(0.0, 1.0);
        r.wire = k * k * (3.0 - 2.0 * k);
        let mut cam = orbit_camera(c, ext, 0.4 + t * std::f32::consts::TAU * 0.6, 34.0, 1.0);
        cam.half_h *= 1.2;
        let px = r.capture(w, h, Some((&cam, [0.0, 0.0, w as f32, h as f32])), None, [0.0, 0.0, 0.0]);
        stdin.write_all(&px).expect("ffmpeg pipe");
    }
    drop(child.stdin.take());
    child.wait().ok();
    println!("{out}: {name}, {frames} frames");
}

/// Stills of an island at given wipe positions (testing the wireframe look).
pub fn wire_stills(island: usize, dir: &str, yaw: f32, wipes: &[f32]) {
    let (mut r, c, ext, _, _) = island_view(island);
    std::fs::create_dir_all(dir).unwrap();
    let (w, h) = (1280u32, 720u32);
    for &k in wipes {
        r.wire = k;
        let cam = orbit_camera(c, ext, yaw, 32.0, 1.0);
        let px = r.capture(w, h, Some((&cam, [0.0, 0.0, w as f32, h as f32])), None, [0.0, 0.0, 0.0]);
        write_ppm(&format!("{dir}/wire_{:03}.ppm", (k * 100.0) as i32), w, h, &px);
    }
}

/// The in-game camera framing at window origin (X, Y): the 23x22 view of the original.
pub fn shot(x: f32, y: f32, south: bool, ortho: bool, out: &str) {
    let mut mem = zx::Mem::original();
    {
        let sys = sys::Sys::new(sys::Shared::new(), None, false);
        let mut g = game::Game::new(mem.clone(), sys);
        g.populate();
        mem = g.m.clone();
    }
    let mut r = render::headless();
    r.rebuild_world(&mem.0, None);
    let heli = Vec3::new(x + 11.5, 0.0, y + 14.5);
    let yaw = if south { std::f32::consts::PI } else { 0.0 };
    let off = Vec3::new(-yaw.sin(), 0.0, -yaw.cos()) * 3.5;
    let cam = render::Camera {
        target: heli + off,
        yaw,
        pitch: 45f32.to_radians(),
        dist: 40.0,
        half_h: 11.0 / 2f32.sqrt(),
        stretch: 2f32.sqrt(),
        ortho,
    };
    let (w, h) = (184 * 4, 176 * 4);
    let px = r.capture(w, h, Some((&cam, [0.0, 0.0, w as f32, h as f32])), None, [0.0, 0.0, 0.0]);
    write_ppm(out, w, h, &px);
}

/// Offscreen demo: play a game with scripted keys and save composed frames (3D + HUD).
/// Script lines: `COUNT [KEY ...]` = hold those Spectrum keys for COUNT iterations.
pub fn demo(script: &str, dir: &str, every: usize, ortho: bool) {
    let mut keys: Vec<sys::Keys> = Vec::new();
    for line in std::fs::read_to_string(script).expect("script").lines() {
        let mut it = line.split_whitespace();
        let Some(n) = it.next().and_then(|n| n.parse::<usize>().ok()) else { continue };
        let mut k = sys::Keys::default();
        for name in it {
            const ROWS: [&str; 8] = ["SHIFT Z X C V", "A S D F G", "Q W E R T", "1 2 3 4 5", "0 9 8 7 6", "P O I U Y", "ENTER L K J H", "SPACE SYM M N B"];
            for (r, row) in ROWS.iter().enumerate() {
                if let Some(b) = row.split(' ').position(|x| x == name) {
                    k.rows[r] |= 1 << b;
                }
            }
        }
        keys.extend(std::iter::repeat(k).take(n));
    }
    std::fs::create_dir_all(dir).unwrap();
    let shared = sys::Shared::new();
    let mut s = sys::Sys::new(shared.clone(), None, false);
    s.publish_headless = true;
    let mut g = game::Game::new(zx::Mem::original(), s);
    let mut r = render::headless();
    let mut p = app::Presenter::new();
    p.ortho = ortho;
    let dir = dir.to_string();
    let mut i = 0usize;
    g.on_iteration = Some(Box::new(move |g: &mut game::Game| {
        if let Some(f) = shared.frame.lock().unwrap().clone() {
            let now = std::time::Instant::now();
            p.push(f, now);
            let cam = p.prepare(&mut r, now, 0.1, (i / 3) % 2 == 1, Some(1.0));
            if i % every == 0 {
                let (w, h) = (960u32, 720u32);
                let l = app::layout(w, h);
                let px = r.capture(w, h, cam.as_ref().map(|c| (c, l.view)), Some(l.screen), [0.0, 0.0, 0.0]);
                write_ppm(&format!("{dir}/demo_{i:05}.ppm"), w, h, &px);
            }
        }
        if i >= keys.len() {
            return false;
        }
        g.sys.scripted = keys[i];
        i += 1;
        true
    }));
    pollster::block_on(g.play_from_start());
}

/// Parse a key script: either trace lines (8 hex half-row bytes, optional `seed=XXXX`) or
/// `COUNT [KEY ...]` lines. Returns per-iteration keys and optional RNG resync values.
pub fn parse_script(text: &str) -> Vec<(sys::Keys, Option<u16>)> {
    const ROWS: [&str; 8] = ["SHIFT Z X C V", "A S D F G", "Q W E R T", "1 2 3 4 5", "0 9 8 7 6", "P O I U Y", "ENTER L K J H", "SPACE SYM M N B"];
    let mut v = Vec::new();
    for line in text.lines() {
        let toks: Vec<&str> = line.split_whitespace().collect();
        if toks.len() >= 8 && toks[..8].iter().all(|t| t.len() == 2 && u8::from_str_radix(t, 16).is_ok()) {
            let mut k = sys::Keys::default();
            for r in 0..8 {
                k.rows[r] = u8::from_str_radix(toks[r], 16).unwrap();
            }
            let seed = toks.iter().find_map(|t| t.strip_prefix("seed=")).and_then(|x| u16::from_str_radix(x, 16).ok());
            v.push((k, seed));
            continue;
        }
        let Some(n) = toks.first().and_then(|n| n.parse::<usize>().ok()) else { continue };
        let mut k = sys::Keys::default();
        for name in &toks[1..] {
            for (r, row) in ROWS.iter().enumerate() {
                if let Some(b) = row.split(' ').position(|x| x == *name) {
                    k.rows[r] |= 1 << b;
                }
            }
        }
        v.extend(std::iter::repeat((k, None)).take(n));
    }
    v
}

/// Render a gameplay video (MP4 with the beeper soundtrack) from a start image and key script.
/// `extra_n`: iterations at which N (view change) is also pressed, to show the camera turning.
/// `wire_at`: iterations at which the 3D view toggles between textured and wireframe (as F2).
pub fn video(start: &str, script: &str, out: &str, max_iters: usize, extra_n: Vec<usize>, wire_at: Vec<usize>) {
    use std::io::Write;
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::{Arc, Mutex};
    const FPS: f64 = 40.0;
    let (w, h) = (960u32, 720u32);
    let ffmpeg = std::env::var("CYCLONE_FFMPEG").unwrap_or_else(|_| "ffmpeg".into());
    let tmp_video = format!("{out}.video.mp4");
    let tmp_audio = format!("{out}.wav");
    let child = std::process::Command::new(&ffmpeg)
        .args(["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", &format!("{w}x{h}"), "-r", "40", "-i", "-",
               "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", &tmp_video])
        .stdin(std::process::Stdio::piped())
        .spawn()
        .expect("ffmpeg");
    let child = Arc::new(Mutex::new(Some(child)));

    let bytes = std::fs::read(start).expect("start image");
    let mut mem = zx::Mem::original();
    mem.0.copy_from_slice(&bytes[..65536]);
    let mut keys = parse_script(&std::fs::read_to_string(script).expect("script"));
    keys.truncate(max_iters);
    for &i in &extra_n {
        if let Some(k) = keys.get_mut(i) {
            k.0.rows[7] |= 1 << 3;
        }
    }
    let mut s = sys::Sys::new(sys::Shared::new(), None, false);
    s.publish_headless = true;
    s.record = Some(Vec::new());
    let mut r = render::headless();
    let mut p = app::Presenter::new();
    let mut vt = 0.0f64;
    let mut t0 = 0.0f64;
    let c2 = child.clone();
    let wire = Arc::new(AtomicBool::new(false));
    let w2 = wire.clone();
    s.on_frame = Some(Box::new(move |f| {
        let t1 = f.t;
        p.push(f, std::time::Instant::now());
        while vt < t1 {
            let a = if t1 > t0 { ((vt - t0) / (t1 - t0)) as f32 } else { 1.0 };
            let flash = (vt / 0.32) as u64 % 2 == 1;
            let cam = p.prepare(&mut r, std::time::Instant::now(), (1.0 / FPS) as f32, flash, Some(a.clamp(0.0, 1.0)));
            // the wipe between textured and wireframe takes 0.9 s, as in the live game
            let to = if w2.load(Ordering::Relaxed) { 1.0 } else { 0.0 };
            r.wire += (to - r.wire).clamp(-1.0 / FPS as f32 / 0.9, 1.0 / FPS as f32 / 0.9);
            let l = app::layout(w, h);
            let px = r.capture(w, h, cam.as_ref().map(|c| (c, l.view)), Some(l.screen), [0.0, 0.0, 0.0]);
            if let Some(ch) = c2.lock().unwrap().as_mut() {
                ch.stdin.as_mut().unwrap().write_all(&px).expect("ffmpeg pipe");
            }
            vt += 1.0 / FPS;
        }
        t0 = t1;
    }));
    let mut g = game::Game::new(mem, s);
    let mut i = 0usize;
    let out = out.to_string();
    g.on_iteration = Some(Box::new(move |g: &mut game::Game| {
        if i >= keys.len() {
            // finish: close the video, render the soundtrack, mux
            if let Some(mut ch) = child.lock().unwrap().take() {
                drop(ch.stdin.take());
                ch.wait().ok();
            }
            let tones = g.sys.record.take().unwrap_or_default();
            let pcm = audio::render_pcm(&tones, g.sys.t, 44100);
            audio::write_wav(&tmp_audio, &pcm, 44100);
            let st = std::process::Command::new(&ffmpeg)
                .args(["-y", "-loglevel", "error", "-i", &tmp_video, "-i", &tmp_audio, "-c:v", "copy", "-c:a", "aac", "-b:a", "128k", "-shortest", &out])
                .status()
                .expect("ffmpeg mux");
            if st.success() {
                std::fs::remove_file(&tmp_video).ok();
                std::fs::remove_file(&tmp_audio).ok();
            }
            println!("{out}: {:.1} s", g.sys.t);
            return false;
        }
        if wire_at.contains(&i) {
            wire.fetch_xor(true, Ordering::Relaxed);
        }
        let (k, seed) = keys[i];
        g.sys.scripted = k;
        if let Some(sd) = seed {
            g.m.w16(game::SEED, sd);
        }
        i += 1;
        true
    }));
    pollster::block_on(g.play_from_start());
}

