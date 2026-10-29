//! Per-frame dynamic 3D content built from the published game memory: the helicopter, its
//! shadow and rope, the aircraft and their shadows, and the sea-wave sparkles. Sprites come
//! from the original frames; the frame is chosen from the heading *relative to the camera*,
//! so the 16 original headings turn smoothly as the camera rotates.

use glam::{Vec2, Vec3};

use crate::game::*;
use crate::render::{SPRITE_H, SPRITE_W};
use crate::sys::{Frame, Rope};
use crate::world::{Mesh, TileGeo, F_CARD, F_SPRITE, F_TOP, WORLD};

/// Sprite texture layout (SPRITE_W x SPRITE_H).
const HELI: (u32, u32) = (0, 0);
const HELI_SHADOW: (u32, u32) = (24, 0);
const ROPE: (u32, u32) = (248, 0);
const AIR_ROW: u32 = 24;
const AIR_SHADOW_ROW: u32 = 48;
const MAX_AIR: usize = 10;

pub struct Sprites {
    pub rgba: Vec<u8>,
}

impl Sprites {
    pub fn new() -> Sprites {
        Sprites { rgba: vec![0; (SPRITE_W * SPRITE_H * 4) as usize] }
    }
    fn clear(&mut self) {
        self.rgba.fill(0);
    }
    fn px(&mut self, x: u32, y: u32) {
        let o = ((y * SPRITE_W + x) * 4) as usize;
        self.rgba[o..o + 4].copy_from_slice(&[0, 0, 0, 255]);
    }
    /// 72-byte column-major 24x24 sprite (3 columns of 24 bytes).
    fn sprite24(&mut self, at: (u32, u32), bytes: &[u8]) {
        for col in 0..3u32 {
            for row in 0..24u32 {
                let b = bytes[(col * 24 + row) as usize];
                for bit in 0..8 {
                    if b & (0x80 >> bit) != 0 {
                        self.px(at.0 + col * 8 + bit, at.1 + row);
                    }
                }
            }
        }
    }
}

/// Heading steps (of 22.5 degrees) the camera has turned from the original north view.
fn yaw_steps(yaw: f32) -> i32 {
    (yaw / (std::f32::consts::TAU / 16.0)).round() as i32
}

fn rel_frame(f: u8, yaw: f32) -> u8 {
    (f as i32 + yaw_steps(yaw)).rem_euclid(16) as u8
}

pub struct Interp {
    /// helicopter ground cell centre (world x, world y) and altitude (pixels)
    pub heli: Vec2,
    pub alt: f32,
    pub aircraft: Vec<Vec2>,
}

/// Positions interpolated between two published frames.
pub fn interpolate(prev: &Frame, cur: &Frame, a: f32) -> Interp {
    let pos = |m: &[u8; 65536]| {
        let x = (m[POS_X as usize] as u16 | (m[POS_X as usize + 1] as u16) << 8) as i16 as f32;
        let y = (m[POS_Y as usize] as u16 | (m[POS_Y as usize + 1] as u16) << 8) as i16 as f32;
        Vec2::new(x + 11.5, y + 14.5)
    };
    let lerp2 = |p: Vec2, c: Vec2| if (c - p).abs().max_element() <= 3.0 { p.lerp(c, a) } else { c };
    let heli = lerp2(pos(&prev.mem), pos(&cur.mem));
    let (pa, ca) = (prev.mem[ALT as usize] as f32, cur.mem[ALT as usize] as f32);
    let alt = if (ca - pa).abs() <= 8.0 { pa + (ca - pa) * a } else { ca };
    let air = |m: &[u8; 65536]| -> Vec<Vec2> {
        let mut v = Vec::new();
        let mut p = AIRCRAFT as usize;
        while m[p] != 0xFF && v.len() < 32 {
            let x = (m[p + 1] as u16 | (m[p + 2] as u16) << 8) as i16 as f32;
            let y = (m[p + 3] as u16 | (m[p + 4] as u16) << 8) as i16 as f32;
            v.push(Vec2::new(x + 11.5, y + 14.5));
            p += 5;
        }
        v
    };
    let (ap, ac) = (air(&prev.mem), air(&cur.mem));
    let aircraft = ac.iter().enumerate().map(|(i, c)| ap.get(i).map_or(*c, |p| lerp2(*p, *c))).collect();
    Interp { heli, alt, aircraft }
}

/// The tile at world cell (x, y) (the sea outside the world).
fn tile_at<'a>(geo: &'a [TileGeo], grid: &[u8], x: i32, y: i32) -> &'a TileGeo {
    if x < 0 || y < 0 || x >= WORLD as i32 || y >= WORLD as i32 {
        return &geo[0];
    }
    &geo[grid[y as usize * WORLD + x as usize] as usize]
}

fn uv_rect(at: (u32, u32), w: u32, h: u32) -> [[f32; 2]; 4] {
    let (x0, y0) = (at.0 as f32 / SPRITE_W as f32, at.1 as f32 / SPRITE_H as f32);
    let (x1, y1) = ((at.0 + w) as f32 / SPRITE_W as f32, (at.1 + h) as f32 / SPRITE_H as f32);
    [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]
}

/// Upright camera-facing card: bottom centre at `base`, size w x h (world units).
fn card(mesh: &mut Mesh, base: Vec3, w: f32, h: f32, uv: [[f32; 2]; 4]) {
    let top = base + Vec3::Y * h;
    mesh.quad(
        [top.to_array(), top.to_array(), base.to_array(), base.to_array()],
        uv,
        [0, 0],
        F_CARD | F_SPRITE,
        [-w / 2.0, w / 2.0, w / 2.0, -w / 2.0],
    );
}

/// A 3x3-cell decal lying on the ground, centred at `c`, rotated by the camera yaw so that the
/// sprite's top edge points away from the camera. The position is interpolated, so a cell can
/// straddle tiles of different heights: it is cut along the tile edges and each piece lies on
/// its own tile (on the slope, for a roof), rather than sinking into a higher terrace or
/// floating over a lower one.
fn decal(mesh: &mut Mesh, geo: &[TileGeo], grid: &[u8], c: Vec2, yaw: f32, at: (u32, u32), cells: &[bool; 9]) {
    let (s, co) = yaw.sin_cos();
    // camera "right" and "away" directions on the ground (x, y=south)
    let right = Vec2::new(co, -s);
    let away = Vec2::new(-s, -co);
    for col in 0..3 {
        for row in 0..3 {
            if !cells[col * 3 + row] {
                continue;
            }
            let ox = col as f32 - 1.5;
            let oy = 1.5 - row as f32; // row 0 = top of the sprite = farthest from camera
            let corner = |dx: f32, dy: f32| c + right * (ox + dx) + away * (oy - dy);
            let uv = uv_rect((at.0 + col as u32 * 8, at.1 + row as u32 * 8), 8, 8);
            let cell: Vec<(Vec2, Vec2)> = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
                .iter()
                .zip(uv)
                .map(|(&(dx, dy), t)| (corner(dx, dy), Vec2::from(t)))
                .collect();
            let (lo, hi) = cell.iter().fold((Vec2::MAX, Vec2::MIN), |(lo, hi), (p, _)| (lo.min(*p), hi.max(*p)));
            for ty in lo.y.floor() as i32..=hi.y.floor() as i32 {
                for tx in lo.x.floor() as i32..=hi.x.floor() as i32 {
                    let piece = clip_to_tile(&cell, tx as f32, ty as f32);
                    if piece.len() < 3 {
                        continue;
                    }
                    // a cut corner is cut again along its diagonal: the cut part lies on the sea
                    let g = tile_at(geo, grid, tx, ty);
                    let (ox, oy) = (tx as f32, ty as f32);
                    let on = clip(&piece, |p| g.inside(p.x - ox, p.y - oy));
                    let off = if g.cut.is_some() { clip(&piece, |p| -g.inside(p.x - ox, p.y - oy)) } else { Vec::new() };
                    for (part, top) in [(on, true), (off, false)] {
                        if part.len() < 3 {
                            continue;
                        }
                        let h = |v: Vec2| if top { g.surface(v.y - oy) } else { 0.0 } + 0.03;
                        let p: Vec<[f32; 3]> = part.iter().map(|(v, _)| [v.x, h(*v), v.y]).collect();
                        let t: Vec<[f32; 2]> = part.iter().map(|(_, t)| t.to_array()).collect();
                        mesh.poly(&p, &t, [0, 0], F_SPRITE);
                    }
                }
            }
        }
    }
}

/// The part of a convex polygon (ground position, texture coordinate) where `d` >= 0, for a
/// `d` linear in the position (one Sutherland-Hodgman step).
fn clip(poly: &[(Vec2, Vec2)], d: impl Fn(Vec2) -> f32) -> Vec<(Vec2, Vec2)> {
    let mut out = Vec::new();
    for i in 0..poly.len() {
        let (a, b) = (poly[i], poly[(i + 1) % poly.len()]);
        let (da, db) = (d(a.0), d(b.0));
        if da >= 0.0 {
            out.push(a);
        }
        if (da >= 0.0) != (db >= 0.0) {
            let k = da / (da - db);
            out.push((a.0.lerp(b.0, k), a.1.lerp(b.1, k)));
        }
    }
    out
}

/// The part of a convex polygon inside the tile whose corner is (x, y).
fn clip_to_tile(poly: &[(Vec2, Vec2)], x: f32, y: f32) -> Vec<(Vec2, Vec2)> {
    let p = clip(poly, |p| p.x - x);
    let p = clip(&p, |p| x + 1.0 - p.x);
    let p = clip(&p, |p| p.y - y);
    clip(&p, |p| y + 1.0 - p.y)
}

pub struct Scene {
    pub mesh: Mesh,
    pub sprites: Sprites,
}

pub fn build(f: &Frame, ip: &Interp, yaw: f32, geo: &[TileGeo], grid: &[u8]) -> Scene {
    let m = &f.mem;
    let mut sp = Sprites::new();
    sp.clear();
    let mut mesh = Mesh::default();
    let (s, c) = yaw.sin_cos();
    let toward = Vec2::new(s, c); // horizontal direction towards the camera (x, y)

    // ---- helicopter
    let hd = m[HEADING_DISP as usize];
    let f16 = rel_frame(hd, yaw);
    let mut body = [0u8; 72];
    if f.death > 0 {
        body.copy_from_slice(&m[SPRITE as usize..SPRITE as usize + 72]);
    } else {
        let src = 0xE930 + 72 * f16 as usize;
        body.copy_from_slice(&m[src..src + 72]);
        let landed = m[LANDED as usize] == 1 || m[NO_FUEL as usize] != 0;
        let page = if landed { 0x67 } else { 0x70 } + m[ROTOR_FRAME as usize] as usize;
        for (i, b) in body.iter_mut().enumerate() {
            let mut o = m[page * 256 + i];
            if f16 > 9 {
                o = o.wrapping_add(o);
            }
            *b ^= o;
        }
    }
    sp.sprite24(HELI, &body);
    let alt = ip.alt / 8.0;
    let base = ip.heli + toward * 1.5;
    card(&mut mesh, Vec3::new(base.x, alt + 0.25, base.y), 3.0, 3.0, uv_rect(HELI, 24, 24));

    // ---- helicopter shadow (not while crashed)
    if m[CRASHED as usize] != 1 {
        let sh = 0xEDB0 + 72 * f16 as usize;
        let mut cells = [false; 9];
        for col in 0..3 {
            for k in 0..3 {
                let a = sh + (col * 3 + k) * 8;
                if m[a] == 0xFF {
                    continue;
                }
                let row = 2 - k;
                cells[col * 3 + row] = true;
                for line in 0..8 {
                    let b = m[a + line];
                    for bit in 0..8 {
                        if b & (0x80 >> bit) != 0 {
                            sp.px(HELI_SHADOW.0 + col as u32 * 8 + bit, HELI_SHADOW.1 + row as u32 * 8 + line as u32);
                        }
                    }
                }
            }
        }
        decal(&mut mesh, geo, grid, ip.heli, yaw, HELI_SHADOW, &cells);
    }

    // ---- rope / winch load
    if let Some(Rope { gfx, lines }) = f.rope {
        for i in 0..lines as u32 {
            let b = m[gfx.wrapping_add(i as u16) as usize];
            for bit in 0..8 {
                if b & (0x80 >> bit) != 0 {
                    sp.px(ROPE.0 + bit, ROPE.1 + i);
                }
            }
        }
        let top = alt + 1.25;
        let h = lines as f32 / 8.0;
        let b = ip.heli + toward * 0.5;
        card(&mut mesh, Vec3::new(b.x, top - h, b.y), 1.0, h, uv_rect(ROPE, 8, lines as u32));
    }

    // ---- aircraft within range (all of them share the level 87EF, as in the original)
    if f.death == 0 {
        let lvl = m[PLANE_LEVEL as usize] as f32;
        let mut n = 0;
        let mut p = AIRCRAFT as usize;
        let mut idx = 0;
        while m[p] != 0xFF {
            let pos = ip.aircraft.get(idx).copied().unwrap_or_default();
            let d = pos - ip.heli;
            if d.x.abs() <= 22.0 && d.y.abs() <= 26.0 && n < MAX_AIR {
                let fr = rel_frame(m[p] >> 2, yaw) as usize;
                let src = 0xDDB8 + 72 * (fr + 1);
                let at = (n as u32 * 24, AIR_ROW);
                sp.sprite24(at, &m[src..src + 72]);
                let mut dith = [0u8; 72];
                for i in 0..72 {
                    dith[i] = m[src + i] & if i % 2 == 0 { 0xAA } else { 0x55 };
                }
                let sat = (n as u32 * 24, AIR_SHADOW_ROW);
                sp.sprite24(sat, &dith);
                let b = pos + toward * 1.5;
                card(&mut mesh, Vec3::new(b.x, lvl, b.y), 3.0, 3.0, uv_rect(at, 24, 24));
                decal(&mut mesh, geo, grid, pos, yaw, sat, &[true; 9]);
                n += 1;
            }
            p += 5;
            idx += 1;
        }
    }

    // ---- sea-wave sparkles (projected buffer chars 00-02 on open sea)
    let x0 = ip_origin(m);
    let south = m[VIEW as usize] != 0;
    for r in 0..22usize {
        for col in 0..23usize {
            let ch = m[VIEWBUF as usize + r * 23 + col];
            if ch > 2 {
                continue;
            }
            let (wx, wy) = if south {
                (x0.0 + 22 - col as i32, x0.1 + 28 - r as i32)
            } else {
                (x0.0 + col as i32, x0.1 + r as i32)
            };
            if tile_at(geo, grid, wx, wy).top > 0 {
                continue;
            }
            let (fx, fz, y) = (wx as f32, wy as f32, 0.005);
            mesh.quad(
                [[fx, y, fz], [fx + 1.0, y, fz], [fx + 1.0, y, fz + 1.0], [fx, y, fz + 1.0]],
                [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]],
                [ch as u32, ch as u32],
                F_TOP,
                [0.0; 4],
            );
        }
    }
    Scene { mesh, sprites: sp }
}

fn ip_origin(m: &[u8; 65536]) -> (i32, i32) {
    let x = (m[POS_X as usize] as u16 | (m[POS_X as usize + 1] as u16) << 8) as i16 as i32;
    let y = (m[POS_Y as usize] as u16 | (m[POS_Y as usize + 1] as u16) << 8) as i16 as i32;
    (x, y)
}
