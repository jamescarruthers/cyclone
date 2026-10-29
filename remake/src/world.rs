//! Turning the original world data into 3D geometry.
//!
//! The original draws each map cell as a *column* of 8x8 characters: the char for tile `t`
//! at stack level `k` is the byte at page ($63+k) (north view) or ($6C+k) (south view),
//! ending with $FF ($FE = nothing at this level). Level k is drawn k rows above the cell and
//! nearer rows overwrite farther ones. That is exactly an oblique view from the south of a
//! stack of cubes: the level-k char is the south face of cube k and the last char is the top
//! face. The south-view page set holds the north faces. Trees, crates and survivors are
//! drawn as upright cards that turn to face the camera.

use bytemuck::{Pod, Zeroable};

use crate::zx::{attr_colours, PALETTE};

pub const WORLD: usize = 768;

#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable, Debug)]
pub struct Vertex {
    pub pos: [f32; 3],
    pub uv: [f32; 2],
    /// char code shown in the north / south view
    pub ch: [u32; 2],
    pub flags: u32,
    /// billboard offset along the camera's right vector (cards and sprites)
    pub side: f32,
}

pub const F_TOP: u32 = 1;
pub const F_CARD: u32 = 2;
pub const F_SHADE: u32 = 4;
pub const F_SPRITE: u32 = 8;
pub const F_OPAQUE: u32 = 16;

/// Rise of a house roof from the eaves to the ridge (levels).
pub const RIDGE: f32 = 0.5;

#[derive(Default)]
pub struct Mesh {
    pub verts: Vec<Vertex>,
    pub idx: Vec<u32>,
}

impl Mesh {
    pub fn quad(&mut self, p: [[f32; 3]; 4], uv: [[f32; 2]; 4], ch: [u32; 2], flags: u32, side: [f32; 4]) {
        let b = self.verts.len() as u32;
        for i in 0..4 {
            self.verts.push(Vertex { pos: p[i], uv: uv[i], ch, flags, side: side[i] });
        }
        self.idx.extend_from_slice(&[b, b + 1, b + 2, b, b + 2, b + 3]);
    }

    /// A convex polygon, drawn as a triangle fan.
    pub fn poly(&mut self, p: &[[f32; 3]], uv: &[[f32; 2]], ch: [u32; 2], flags: u32) {
        let b = self.verts.len() as u32;
        for i in 0..p.len() {
            self.verts.push(Vertex { pos: p[i], uv: uv[i], ch, flags, side: 0.0 });
        }
        for i in 1..p.len().saturating_sub(1) as u32 {
            self.idx.extend_from_slice(&[b, b + i, b + i + 1]);
        }
    }
}

const UV: [[f32; 2]; 4] = [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]];

pub fn is_object(c: u8) -> bool {
    matches!(c, 0x30..=0x32 | 0x45..=0x56)
}

/// One island block of the tile store (from the 20-byte records at F230).
pub struct Island {
    #[cfg_attr(target_arch = "wasm32", allow(dead_code))]
    pub name: String,
    pub x0: i32,
    pub y0: i32,
    pub w: i32,
    pub h: i32,
    pub base: u16,
}

pub fn islands(m: &[u8; 65536]) -> Vec<Island> {
    let names = [
        "BANANA ISLAND", "ORTE ROCKS", "KOKOLA ISLAND", "LAGOON ISLAND", "PEAK ISLAND", "BASE ISLAND",
        "GILLIGANS ISLAND", "RED ISLAND", "SKEG ISLAND", "BONE ISLAND", "GIANTS GATEWAY", "CLAW ISLAND",
        "LUKELAND ISLES", "ENTERPRISE ISLAND",
    ];
    let mut v = Vec::new();
    let mut a = 0xF230usize;
    let mut i = 0;
    while m[a] != 0xFF {
        let r = |o: usize| m[a + o] as i32;
        v.push(Island {
            name: names.get(i).unwrap_or(&"?").to_string(),
            x0: r(0) * 256 + r(6),
            y0: r(1) * 256 + r(8),
            w: r(3) - r(6) + 1,
            h: r(5) - r(8) + 1,
            base: m[a + 10] as u16 | (m[a + 11] as u16) << 8,
        });
        a += 20;
        i += 1;
    }
    v
}

/// The whole world as a 768x768 grid of tile codes (sea = 0).
pub fn world_grid(m: &[u8; 65536], isl: &[Island]) -> Vec<u8> {
    let mut g = vec![0u8; WORLD * WORLD];
    for i in isl {
        for r in 0..i.h {
            for c in 0..i.w {
                let t = m[i.base.wrapping_add((r * 128 + c) as u16) as usize];
                let (x, y) = (i.x0 + c, i.y0 + r);
                if t != 0 && (0..WORLD as i32).contains(&x) && (0..WORLD as i32).contains(&y) {
                    g[y as usize * WORLD + x as usize] = t;
                }
            }
        }
    }
    g
}

/// The char column of tile `t` in the page set starting at `page`.
pub fn column(m: &[u8; 65536], page: u8, t: u8) -> Vec<Option<u8>> {
    let mut v = Vec::new();
    for k in 0..12u16 {
        let c = m[((page as u16 + k) << 8 | t as u16) as usize];
        match c {
            0xFF => break,
            0xFE => v.push(None),
            c => v.push(Some(c)),
        }
    }
    v
}

/// Per-tile geometry description derived from the column tables.
#[derive(Clone)]
pub struct TileGeo {
    /// north-view chars per level
    pub n: Vec<Option<u8>>,
    /// south-view chars per level
    pub s: Vec<Option<u8>>,
    /// number of solid cube levels; the top face is at this height
    pub top: usize,
    /// first object level (cards from here up)
    pub obj: Option<usize>,
    /// A terrace's corner on the coast is drawn with a top char that has one corner cut off
    /// diagonally ($19/$1A in the view that sees the cut, nearest the camera). Here the whole
    /// column is cut: (north, east) of the corner that is cut away.
    pub cut: Option<(bool, bool)>,
}

const NORTH: usize = 0;
const SOUTH: usize = 1;
const EAST: usize = 2;
const WEST: usize = 3;

pub fn tile_geo(m: &[u8; 65536]) -> Vec<TileGeo> {
    (0..=255u8)
        .map(|t| {
            let n = column(m, 0x63, t);
            let s = column(m, 0x6C, t);
            let obj = n.iter().position(|c| matches!(c, Some(c) if is_object(*c)));
            let top = obj.unwrap_or(n.len().saturating_sub(1));
            // in the south view the top face is turned round, so $1A cuts the south-east corner
            let cut = match (obj, n.get(top).copied().flatten(), s.get(top).copied().flatten()) {
                (Some(_), ..) => None,
                (None, Some(0x19), _) => Some((true, true)),
                (None, Some(0x1A), _) => Some((true, false)),
                (None, _, Some(0x1A)) => Some((false, true)),
                (None, _, Some(0x19)) => Some((false, false)),
                _ => None,
            };
            TileGeo { n, s, top, obj, cut }
        })
        .collect()
}

impl TileGeo {
    fn solid(&self, k: usize) -> bool {
        k < self.top && matches!(self.n.get(k), Some(Some(_)))
    }

    /// The side has no wall: it is one of the two sides of a cut corner.
    fn open(&self, side: usize) -> bool {
        self.cut.is_some_and(|(n, e)| side == if n { NORTH } else { SOUTH } || side == if e { EAST } else { WEST })
    }

    /// Level k fills this side of the tile, so the neighbour there needs no wall facing it.
    fn closes(&self, k: usize, side: usize) -> bool {
        self.solid(k) && !self.open(side)
    }

    /// Positive on the part of the tile that is there, negative on a cut corner (`u`, `v`: 0..1
    /// eastwards and southwards across the tile).
    pub fn inside(&self, u: f32, v: f32) -> f32 {
        match self.cut {
            None => 1.0,
            Some((true, true)) => v - u,
            Some((true, false)) => u + v - 1.0,
            Some((false, true)) => 1.0 - u - v,
            Some((false, false)) => u - v,
        }
    }

    /// Houses are two tiles deep, with a red roof char on top: $2E on the front (south) row and
    /// $2D on the back row. The original draws the roof flat; here it is a gable whose ridge
    /// runs east-west between the rows. `Some(true)` when the ridge is on this tile's north edge.
    pub fn ridge_north(&self) -> Option<bool> {
        match (self.obj, self.n.get(self.top).copied().flatten()) {
            (None, Some(0x2E)) => Some(true),
            (None, Some(0x2D)) => Some(false),
            _ => None,
        }
    }

    /// Height of the top surface at `v` (0..1 southwards across the tile).
    pub fn surface(&self, v: f32) -> f32 {
        let h = self.top as f32;
        match self.ridge_north() {
            Some(true) => h + RIDGE * (1.0 - v),
            Some(false) => h + RIDGE * v,
            None => h,
        }
    }
}

/// A solid char code (codes $80+ are plain attribute blocks) with the given paper colour.
fn solid_char_for_paper(m: &[u8; 65536], paper: usize) -> Option<u8> {
    (0x80..=0x8Fu8).find(|&c| attr_colours(m[0xFE00 + c as usize], false).1 == paper)
}

/// Build the mesh of one island block from the world grid.
pub fn island_mesh(m: &[u8; 65536], geo: &[TileGeo], grid: &[u8], isl: &Island) -> Mesh {
    let mut mesh = Mesh::default();
    let tile = |x: i32, y: i32| -> u8 {
        if x < 0 || y < 0 || x >= WORLD as i32 || y >= WORLD as i32 {
            0
        } else {
            grid[y as usize * WORLD + x as usize]
        }
    };
    for y in isl.y0..isl.y0 + isl.h {
        for x in isl.x0..isl.x0 + isl.w {
            let t = tile(x, y);
            if t == 0 {
                continue;
            }
            let g = &geo[t as usize];
            let (fx, fz) = (x as f32, y as f32);
            for k in 0..g.top {
                let Some(c) = g.n[k] else { continue };
                if is_object(c) {
                    continue;
                }
                let cs = g.s.get(k).copied().flatten().unwrap_or(c) as u32;
                let c = c as u32;
                // A house's front wall is its south face in the north view and its north face
                // in the south view, so the original swaps the window and plain chars between
                // the views. The east and west walls show the windowed one in both, so the
                // windows stay put as the camera turns (a door becomes a window).
                let side = match g.ridge_north() {
                    Some(_) => {
                        let w = [c, cs].into_iter().find(|&x| matches!(x, 0x58..=0x5A)).unwrap_or(c);
                        let w = if w == 0x58 { 0x5A } else { w };
                        [w, w]
                    }
                    None => [c, cs],
                };
                // A cut corner's walls all use the chars of the view that sees the cut (the
                // other view's are its far edge and mostly see-through).
                let (c, cs, side) = match g.cut {
                    Some((north, _)) => {
                        let f = if north { c } else { cs };
                        (f, f, [f, f])
                    }
                    None => (c, cs, side),
                };
                let (y0, y1) = (k as f32, k as f32 + 1.0);
                // south face (+Z)
                if !g.open(SOUTH) && !geo[tile(x, y + 1) as usize].closes(k, NORTH) {
                    mesh.quad(
                        [[fx, y1, fz + 1.0], [fx + 1.0, y1, fz + 1.0], [fx + 1.0, y0, fz + 1.0], [fx, y0, fz + 1.0]],
                        UV, [c, c], 0, [0.0; 4],
                    );
                }
                // north face (-Z)
                if !g.open(NORTH) && !geo[tile(x, y - 1) as usize].closes(k, SOUTH) {
                    mesh.quad(
                        [[fx + 1.0, y1, fz], [fx, y1, fz], [fx, y0, fz], [fx + 1.0, y0, fz]],
                        UV, [cs, cs], 0, [0.0; 4],
                    );
                }
                // east face (+X)
                if !g.open(EAST) && !geo[tile(x + 1, y) as usize].closes(k, WEST) {
                    mesh.quad(
                        [[fx + 1.0, y1, fz + 1.0], [fx + 1.0, y1, fz], [fx + 1.0, y0, fz], [fx + 1.0, y0, fz + 1.0]],
                        UV, side, F_SHADE, [0.0; 4],
                    );
                }
                // west face (-X)
                if !g.open(WEST) && !geo[tile(x - 1, y) as usize].closes(k, EAST) {
                    mesh.quad(
                        [[fx, y1, fz], [fx, y1, fz + 1.0], [fx, y0, fz + 1.0], [fx, y0, fz]],
                        UV, side, F_SHADE, [0.0; 4],
                    );
                }
                // the diagonal wall of a cut corner, from its left end to its right end as
                // seen from outside
                if let Some(cut) = g.cut {
                    let (nw, ne, sw, se) = ([fx, fz], [fx + 1.0, fz], [fx, fz + 1.0], [fx + 1.0, fz + 1.0]);
                    let (l, r) = match cut {
                        (true, true) => (se, nw),
                        (true, false) => (ne, sw),
                        (false, true) => (sw, ne),
                        (false, false) => (nw, se),
                    };
                    mesh.quad(
                        [[l[0], y1, l[1]], [r[0], y1, r[1]], [r[0], y0, r[1]], [l[0], y0, l[1]]],
                        UV, [c, c], F_SHADE, [0.0; 4],
                    );
                }
            }
            // top face
            let h = g.top as f32;
            let top = match g.obj {
                Some(k) => {
                    // ground under an object: a plain block in the object's paper colour
                    let c = g.n[k].unwrap();
                    let paper = attr_colours(m[0xFE00 + c as usize], false).1;
                    solid_char_for_paper(m, paper).map(|c| (c as u32, c as u32))
                }
                None => g.n.get(g.top).copied().flatten().map(|c| {
                    (c as u32, g.s.get(g.top).copied().flatten().unwrap_or(c) as u32)
                }),
            };
            if let Some((cn, cs)) = top {
                let (hn, hs) = (g.surface(0.0), g.surface(1.0));
                let mut p = [[fx, hn, fz], [fx + 1.0, hn, fz], [fx + 1.0, hs, fz + 1.0], [fx, hs, fz + 1.0]];
                let (mut uv, mut ch) = (UV, [cn, cs]);
                // a cut corner's top is a triangle: the cut corner of the quad moves onto a
                // neighbouring one. It is plain, in the cut char's ink: the char's stepped
                // edge would leave slivers along the diagonal wall.
                if let Some(cut) = g.cut {
                    let (drop, onto) = match cut {
                        (true, true) => (1, 0),
                        (true, false) => (0, 1),
                        (false, true) => (2, 1),
                        (false, false) => (3, 0),
                    };
                    p[drop] = p[onto];
                    uv[drop] = uv[onto];
                    let ink = attr_colours(m[0xFE00 + if cut.0 { cn } else { cs } as usize], false).0;
                    let c = solid_char_for_paper(m, ink).map_or(cn, |c| c as u32);
                    ch = [c, c];
                }
                mesh.quad(p, uv, ch, F_TOP, [0.0; 4]);
            }
            // a house roof's gable ends, in the colour of the wall below. The gable triangles
            // are quads whose two top corners meet at the ridge.
            if let Some(rn) = g.ridge_north() {
                let wall = g.top.checked_sub(1).and_then(|k| g.n[k]).map_or(0x89, |c| {
                    let paper = attr_colours(m[0xFE00 + c as usize], false).1;
                    solid_char_for_paper(m, paper).unwrap_or(0x89)
                }) as u32;
                let roof = |t: u8, north: bool| geo[t as usize].top == g.top && geo[t as usize].ridge_north() == Some(north);
                let apex = |x: f32| [x, h + RIDGE, if rn { fz } else { fz + 1.0 }];
                if !roof(tile(x + 1, y), rn) {
                    let a = apex(fx + 1.0);
                    mesh.quad([a, a, [fx + 1.0, h, fz], [fx + 1.0, h, fz + 1.0]], UV, [wall, wall], F_SHADE, [0.0; 4]);
                }
                if !roof(tile(x - 1, y), rn) {
                    let a = apex(fx);
                    mesh.quad([a, a, [fx, h, fz + 1.0], [fx, h, fz]], UV, [wall, wall], F_SHADE, [0.0; 4]);
                }
                // the ridge is open where the other half of the house is missing
                let (h1, h0) = (h + RIDGE, h);
                if rn && !roof(tile(x, y - 1), false) {
                    mesh.quad(
                        [[fx + 1.0, h1, fz], [fx, h1, fz], [fx, h0, fz], [fx + 1.0, h0, fz]],
                        UV, [wall, wall], 0, [0.0; 4],
                    );
                }
                if !rn && !roof(tile(x, y + 1), true) {
                    mesh.quad(
                        [[fx, h1, fz + 1.0], [fx + 1.0, h1, fz + 1.0], [fx + 1.0, h0, fz + 1.0], [fx, h0, fz + 1.0]],
                        UV, [wall, wall], 0, [0.0; 4],
                    );
                }
            }
            // object cards
            if let Some(k0) = g.obj {
                for k in k0..g.n.len() {
                    let Some(c) = g.n[k] else { continue };
                    let cs = g.s.get(k).copied().flatten().unwrap_or(c) as u32;
                    let (cx, cz) = (fx + 0.5, fz + 0.5);
                    let (y0, y1) = (k as f32, k as f32 + 1.0);
                    mesh.quad(
                        [[cx, y1, cz], [cx, y1, cz], [cx, y0, cz], [cx, y0, cz]],
                        UV, [c as u32, cs], F_CARD, [-0.5, 0.5, 0.5, -0.5],
                    );
                }
            }
        }
    }
    mesh
}

/// RGBA atlas (128x128) of all 256 char codes in their attribute colours. Paper pixels whose
/// paper is cyan (sea / sky behind the column) are transparent. So is the paper of object chars
/// (trees, crates, survivors): it is whatever the original drew behind the object (ground,
/// cliff, helipad or sea), which the 3D view shows for real, and an opaque card would hide
/// the shadows and the ground behind it. The yellow tree's foliage ($53, $54) is its paper.
pub fn char_atlas(m: &[u8; 65536]) -> Vec<u8> {
    let mut img = vec![0u8; 128 * 128 * 4];
    for code in 0..256usize {
        let attr = m[0xFE00 + code];
        let (ink, paper) = attr_colours(attr, false);
        let cut_paper = paper == 5 || paper == 13 || (is_object(code as u8) && !matches!(code, 0x53 | 0x54));
        for row in 0..8 {
            let bits = if code < 0x80 { m[0xFA00 + code * 8 + row] } else { 0 };
            for col in 0..8 {
                let set = bits & (0x80 >> col) != 0;
                let c = if set { ink } else { paper };
                let transparent = !set && cut_paper;
                let px = (code % 16) * 8 + col;
                let py = (code / 16) * 8 + row;
                let o = (py * 128 + px) * 4;
                img[o..o + 3].copy_from_slice(&PALETTE[c]);
                img[o + 3] = if transparent { 0 } else { 255 };
            }
        }
    }
    img
}
