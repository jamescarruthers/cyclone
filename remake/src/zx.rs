//! ZX Spectrum memory image, screen layout and palette.
//!
//! The game logic is a port of the original Z80 code that keeps the original memory layout:
//! variables, tables, the tile store, the view buffer and the screen all live in one 64 KB
//! array at their original addresses. This makes the port directly comparable, byte for byte,
//! with the original running under an emulator.

pub const MEM_BIN: &[u8; 65536] = include_bytes!("../data/mem.bin");
pub const MENU_SCR: &[u8; 6912] = include_bytes!("../data/menu.scr");
pub const INFO_SCR: &[u8; 6912] = include_bytes!("../data/info.scr");
pub const MAP_SCR: &[u8; 6912] = include_bytes!("../data/map.scr");
/// The SCREEN$ loaded from tape before the game (block "Cyclone2").
pub const LOADING_SCR: &[u8; 6912] = include_bytes!("../data/loading.scr");

#[derive(Clone)]
pub struct Mem(pub Box<[u8; 65536]>);

impl Mem {
    pub fn original() -> Mem {
        Mem(Box::new(*MEM_BIN))
    }
    #[inline]
    pub fn r(&self, a: u16) -> u8 {
        self.0[a as usize]
    }
    #[inline]
    pub fn w(&mut self, a: u16, v: u8) {
        self.0[a as usize] = v;
    }
    #[inline]
    pub fn r16(&self, a: u16) -> u16 {
        self.r(a) as u16 | (self.r(a.wrapping_add(1)) as u16) << 8
    }
    #[inline]
    pub fn w16(&mut self, a: u16, v: u16) {
        self.w(a, v as u8);
        self.w(a.wrapping_add(1), (v >> 8) as u8);
    }
    pub fn copy(&mut self, src: u16, dst: u16, len: u16) {
        // LDIR semantics (forward byte copy, overlapping allowed)
        for i in 0..len {
            let v = self.r(src.wrapping_add(i));
            self.w(dst.wrapping_add(i), v);
        }
    }
    pub fn load_screen(&mut self, scr: &[u8; 6912]) {
        self.0[0x4000..0x5B00].copy_from_slice(scr);
    }
}

/// Address of pixel line `line` (0-191) of character column `col` in the display file.
pub fn pixel_addr(line: usize, col: usize) -> u16 {
    (0x4000 | ((line & 0xC0) << 5) | ((line & 7) << 8) | ((line & 0x38) << 2) | col) as u16
}

/// Spectrum palette (normal, bright), RGB.
pub const PALETTE: [[u8; 3]; 16] = [
    [0x00, 0x00, 0x00],
    [0x00, 0x00, 0xD7],
    [0xD7, 0x00, 0x00],
    [0xD7, 0x00, 0xD7],
    [0x00, 0xD7, 0x00],
    [0x00, 0xD7, 0xD7],
    [0xD7, 0xD7, 0x00],
    [0xD7, 0xD7, 0xD7],
    [0x00, 0x00, 0x00],
    [0x00, 0x00, 0xFF],
    [0xFF, 0x00, 0x00],
    [0xFF, 0x00, 0xFF],
    [0x00, 0xFF, 0x00],
    [0x00, 0xFF, 0xFF],
    [0xFF, 0xFF, 0x00],
    [0xFF, 0xFF, 0xFF],
];

/// (ink, paper) palette indices of an attribute byte, honouring FLASH.
pub fn attr_colours(attr: u8, flash_phase: bool) -> (usize, usize) {
    let bright = if attr & 0x40 != 0 { 8 } else { 0 };
    let mut ink = (attr & 7) as usize + bright;
    let mut paper = ((attr >> 3) & 7) as usize + bright;
    if attr & 0x80 != 0 && flash_phase {
        std::mem::swap(&mut ink, &mut paper);
    }
    (ink, paper)
}

/// Convert a 6912-byte screen to RGBA (256x192). Cells where `transparent[row][col]` is set
/// get alpha 0 so the 3D view underneath shows through.
pub fn screen_to_rgba(scr: &[u8], flash_phase: bool, transparent: &[[bool; 32]; 24], out: &mut [u8]) {
    for line in 0..192 {
        let row = line >> 3;
        for col in 0..32 {
            let a = pixel_addr(line, col) as usize - 0x4000;
            let bits = scr[a];
            let attr = scr[6144 + row * 32 + col];
            let (ink, paper) = attr_colours(attr, flash_phase);
            let clear = transparent[row][col];
            for x in 0..8 {
                let c = if bits & (0x80 >> x) != 0 { ink } else { paper };
                let o = (line * 256 + col * 8 + x) * 4;
                out[o..o + 3].copy_from_slice(&PALETTE[c]);
                out[o + 3] = if clear { 0 } else { 255 };
            }
        }
    }
}
