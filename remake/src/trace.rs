//! Headless verification mode: runs a game from a memory image with scripted keys and prints
//! the game state at the start of every main-loop iteration, in the same format as
//! `re/tools/reftrace.py` prints for the original program running under SkoolKit.
//!
//! cyclone --trace START.bin SCRIPT.txt > rust.trace
//!   START.bin: 64 KB memory image taken at $5B00 (game start)
//!   SCRIPT.txt: one line per iteration: 8 hex bytes (keyboard half-rows, bit set = pressed),
//!               optionally followed by "seed=XXXX" to resynchronise the RNG (the original's
//!               crash noise calls the RNG from the interrupt, which is timing dependent).

use std::io::{BufRead, Write};

use crate::game::{Game, SEED};
use crate::sys::{Keys, Shared, Sys};
use crate::zx::Mem;

pub fn fnv(bytes: impl Iterator<Item = u8>) -> u32 {
    let mut h: u32 = 0x811C9DC5;
    for b in bytes {
        h ^= b as u32;
        h = h.wrapping_mul(0x01000193);
    }
    h
}

/// The state line shared with reftrace.py.
pub fn state_line(i: usize, m: &[u8; 65536]) -> String {
    let hex = |a: usize, n: usize| m[a..a + n].iter().map(|b| format!("{b:02X}")).collect::<String>();
    let mut vars = m[0x7500..0x7564].to_vec();
    // render-only scratch pointers and the interrupt's rotor sound phase (as reftrace.py)
    for o in [0x09, 0x0A, 0x0B, 0x0C, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x29, 0x2A, 0x2B, 0x2C, 0x3C, 0x3D, 0x3E, 0x3F, 0x5D] {
        vars[o] = 0;
    }
    let vars: String = vars.iter().map(|b| format!("{b:02X}")).collect();
    let store = fnv(m[0x9300..0xDE00].iter().copied());
    let hud = fnv((0..24usize).flat_map(|row| {
        let cols: Vec<usize> = if row >= 22 { (0..32).collect() } else { (24..32).collect() };
        cols.into_iter().flat_map(move |col| {
            (0..8usize)
                .map(move |line| crate::zx::pixel_addr(row * 8 + line, col) as usize)
                .chain(std::iter::once(0x5800 + row * 32 + col))
        })
    }).map(|a| m[a]));
    format!(
        "{i} seed={} v={vars} score={} misc={}{}{}{}{}{} air={} store={store:08X} hud={hud:08X}",
        hex(0x5C76, 2),
        hex(0x661E, 7),
        hex(0x87EF, 1),
        hex(0x8A69, 3),
        hex(0x5B93, 1),
        hex(0x828C, 1),
        hex(0x9245, 1),
        hex(0x7A81, 9),
        hex(0xE86C, 95),
    )
}

pub fn run(start: &str, script: &str) {
    let bytes = std::fs::read(start).expect("start image");
    let mut mem = Mem::original();
    mem.0.copy_from_slice(&bytes[..65536]);
    let lines: Vec<String> = std::io::BufReader::new(std::fs::File::open(script).expect("script"))
        .lines()
        .map(|l| l.unwrap())
        .collect();
    let sys = Sys::new(Shared::new(), None, false);
    let mut game = Game::new(mem, sys);
    let mut i = 0usize;
    game.on_iteration = Some(Box::new(move |g: &mut Game| {
        if i >= lines.len() {
            return false;
        }
        let mut parts = lines[i].split_whitespace();
        let mut k = Keys::default();
        for row in 0..8 {
            let h = parts.next().unwrap_or("00");
            k.rows[row] = u8::from_str_radix(h, 16).unwrap_or(0);
        }
        println!("{}", state_line(i, &g.m.0));
        for p in parts {
            if let Some(s) = p.strip_prefix("seed=") {
                let v = u16::from_str_radix(s, 16).unwrap();
                g.m.w16(SEED, v);
            }
        }
        std::io::stdout().flush().ok();
        g.sys.scripted = k;
        i += 1;
        true
    }));
    pollster::block_on(game.play_from_start());
}
