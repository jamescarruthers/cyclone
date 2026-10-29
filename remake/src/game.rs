//! Port of the Cyclone game logic.
//!
//! Every routine below corresponds to a routine of the original program (its address is in
//! the doc comment; see `re/build/cyclone.asm` and `re/notes/*.md`). The port keeps the
//! original memory layout, so variables, self-modified operands, tables, the tile store, the
//! view buffer and the screen are all accessed at their original addresses. Rendering
//! routines that only draw the 23x22 view (762C, 7E10's projection, 7ADC/7BB8 shadow, 85D4,
//! 86AF) are not ported: the 3D renderer replaces them, reading the same state.

use crate::audio::Tone;
use crate::sys::{Kind, Rope, Sys, CPU_HZ};
use crate::zx::{pixel_addr, Mem, INFO_SCR, LOADING_SCR, MAP_SCR, MENU_SCR};

// ---- live variables ($7500-$7563, initial values at $7564, per-life reset values at $75C8)
pub const POS_X: u16 = 0x7500;
pub const POS_Y: u16 = 0x7502;
pub const VIEW: u16 = 0x7504;
pub const CRASHED: u16 = 0x7505;
pub const HEADING: u16 = 0x7506;
pub const HEADING_DISP: u16 = 0x7507;
pub const HEADING_NEXT: u16 = 0x7508;
pub const ALT: u16 = 0x750D;
pub const TOUCHDOWN: u16 = 0x7514;
pub const LANDED: u16 = 0x7515;
pub const NO_FUEL: u16 = 0x7516;
pub const FUEL_TICK: u16 = 0x7517;
pub const FUEL_PTR: u16 = 0x7518;
pub const CLIMB_RATE: u16 = 0x751A;
pub const DESCENT_RATE: u16 = 0x751B;
pub const TIME_PTR: u16 = 0x751C;
pub const ALT_PTR: u16 = 0x751E;
pub const TURN_TIMER: u16 = 0x7521;
pub const CONTROLS: u16 = 0x7522;
pub const PLANE_COL: u16 = 0x7524;
pub const PLANE_ROW: u16 = 0x7525;
pub const UI_FLAGS: u16 = 0x7526;
pub const SPEED: u16 = 0x7527;
pub const TIME_TICK: u16 = 0x7528;
pub const SOUND_OFF: u16 = 0x752D;
pub const ON_PAD: u16 = 0x752E;
pub const PLANE_DRAWN: u16 = 0x752F;
pub const PLANE_NEAR: u16 = 0x7530;
pub const HELI_LEVEL: u16 = 0x7533;
pub const AIR_TICK: u16 = 0x7534;
pub const WAVE_X: u16 = 0x7535;
pub const WAVE_Y: u16 = 0x7536;
pub const WAVE_TICK: u16 = 0x7537;
pub const WAVE_PTR: u16 = 0x7538;
pub const ROTOR_FRAME: u16 = 0x753A;
pub const MOVE_DIR: u16 = 0x753B;
pub const MAP_HX: u16 = 0x7540;
pub const MAP_HY: u16 = 0x7541;
pub const MAP_BLINK: u16 = 0x7542;
pub const MAP_HATTR: u16 = 0x7543;
pub const MAP_HPIX: u16 = 0x7545;
pub const MAP_CATTR: u16 = 0x7547;
pub const MAP_CPIX: u16 = 0x7549;
pub const CYC_X: u16 = 0x754B;
pub const CYC_Y: u16 = 0x754C;
pub const OFF_MAP: u16 = 0x754D;
pub const CYC_TICK: u16 = 0x754E;
pub const CYC_LEG: u16 = 0x754F;
pub const CYC_DIST: u16 = 0x7550;
pub const PICK_TILE: u16 = 0x7551;
pub const ISLAND: u16 = 0x7552;
pub const CRATES: u16 = 0x7554;
pub const WINCH: u16 = 0x7555;
pub const ROPE_STATE: u16 = 0x7556;
pub const PICK_SPR: u16 = 0x7557;
pub const SURV_ANIM1: u16 = 0x755B;
pub const SURV_ANIM2: u16 = 0x755C;
pub const ROTOR_SND: u16 = 0x755D;

// ---- variables and self-modified operands elsewhere
pub const SEED: u16 = 0x5C76;
pub const WIND_THRESHOLD: u16 = 0x5B93; // operand of CP n at 5B92
pub const CONTROL_METHOD: u16 = 0x7FD5;
pub const TIME_PERIOD: u16 = 0x828C; // operand of CP n at 828B
pub const PLANE_LEVEL: u16 = 0x87EF;
pub const SCHED_PTR: u16 = 0x8A69;
pub const SCHED_STEP: u16 = 0x8A6B;
pub const CYC_MASK: u16 = 0x90D0; // operand of AND n at 90CF
pub const CYC_BITS: u16 = 0x90D2; // operand of OR n at 90D1
pub const EXPLO_PTR: u16 = 0x9243;
pub const LIVES_LOST: u16 = 0x9245;
pub const ROTOR_SHIFT: u16 = 0x8D02; // NOP / ADD A,A
pub const PAGE_BASE: u16 = 0x7B18; // tile-column page base ($63 north, $6C south)

// ---- buffers and tables
pub const VIEWBUF: u16 = 0xF74E; // 23 x 29 tile codes
pub const FOOT: u16 = 0x7A81; // 9 raw codes under the helicopter
pub const FOOT_LEVEL: u16 = 0x7A8B; // their height classes
pub const FOOT_SHADOW: u16 = 0x7A95;
pub const SPRITE: u16 = 0x6950; // 24x24 helicopter sprite buffer
pub const SCORE: u16 = 0x661E; // 7 ASCII digits, '.' = blank
pub const HISCORE: u16 = 0x6627;
pub const ISLANDS: u16 = 0xF230;
pub const BASE_ISLAND: u16 = 0xF294;
pub const AIRCRAFT: u16 = 0xE86C;

/// Main-loop iteration cost not spent in beeps (the original free-runs at ~4-5.6 frames).
const ITERATION_TIME: f64 = 0.098;
/// One step of the crash sequence (24 steps take ~132 frames).
const DEATH_STEP_TIME: f64 = 0.108;

pub enum Flow {
    Continue,
    NextLevel,
    NewLife,
    Menu,
}

pub struct Game {
    pub m: Mem,
    pub sys: Sys,
    pub overlay: [[bool; 32]; 24],
    pub rope: Option<Rope>,
    death: u8,
    /// Called at the start of every main-loop iteration (verification traces).
    pub on_iteration: Option<Box<dyn FnMut(&mut Game) -> bool + Send>>,
}

#[inline]
fn hi(v: u16) -> u8 {
    (v >> 8) as u8
}
#[inline]
fn lo(v: u16) -> u8 {
    v as u8
}
#[inline]
fn hl(h: u8, l: u8) -> u16 {
    (h as u16) << 8 | l as u16
}

impl Game {
    pub fn new(m: Mem, sys: Sys) -> Game {
        Game { m, sys, overlay: [[false; 32]; 24], rope: None, death: 0, on_iteration: None }
    }

    // ------------------------------------------------------------------ environment

    fn r(&self, a: u16) -> u8 {
        self.m.r(a)
    }
    fn w(&mut self, a: u16, v: u8) {
        self.m.w(a, v)
    }

    /// Let `dt` seconds of virtual time pass, running the 50 Hz interrupt.
    pub async fn wait(&mut self, dt: f64) {
        let end = self.sys.t + dt;
        while self.sys.next_int <= end {
            self.sys.t = self.sys.next_int;
            self.interrupt();
            self.sys.next_int += crate::sys::FRAME;
        }
        self.sys.t = end;
        self.sys.sync().await;
    }

    async fn wait_tstates(&mut self, t: f64) {
        self.wait(t / CPU_HZ).await;
    }

    /// ROM BEEPER (03B5): DE cycles at pitch HL. Interrupts are disabled while it runs.
    async fn beep(&mut self, hl: u16, de: u16) {
        let freq = 437_500.0 / (hl as f64 + 30.125);
        let half = 0.5 / freq;
        let dur = de as f64 / freq;
        self.sys.tone(Tone { start: self.sys.t, high: half, low: half, cycles: de as u32 });
        self.sys.t += dur;
        while self.sys.next_int <= self.sys.t {
            self.sys.next_int += crate::sys::FRAME; // missed while DI
        }
        self.sys.sync().await;
    }

    fn publish(&mut self, kind: Kind) {
        let death = self.death;
        let rope = self.rope;
        self.sys.publish(&self.m.0, kind, &self.overlay, rope, death);
    }

    /// RNG at 8B74: seed' = (254*seed + 253) mod 65537 (in 16 bits). Returns HL.
    pub fn rnd(&mut self) -> u16 {
        let seed = self.m.r16(SEED) as u32;
        let v = 254 * seed + 253;
        let a = v >> 16;
        let l = v & 0xFFFF;
        let r = if l >= a { l - a } else { (l + 0x10000 - a + 1) & 0xFFFF } as u16;
        self.m.w16(SEED, r);
        r
    }

    /// The IM2 interrupt handler (83C2): sound only, plus the RNG calls of the crash noise.
    fn interrupt(&mut self) {
        if self.r(SOUND_OFF) == 1 {
            return;
        }
        let t = self.sys.t;
        if self.r(CRASHED) == 1 {
            // 5FDC crash noise
            let v = self.rnd();
            let (h, l) = (hi(v), lo(v));
            if l < 0x46 {
                return;
            }
            let mut start = t;
            let hp = (h & 0xF0) as f64 * 43.0 / CPU_HZ;
            let lp = (l & 0xF0) as f64 * 43.0 / CPU_HZ;
            for _ in 0..3 {
                if h & 0xF0 == 0 {
                    break;
                }
                self.sys.tone(Tone { start, high: hp, low: if l & 0xF0 == 0 { 0.0 } else { lp }, cycles: 1 });
                start += hp + lp;
                if l & 0xF0 == 0 {
                    break;
                }
            }
            return;
        }
        if self.r(LANDED) | self.r(NO_FUEL) != 0 {
            return;
        }
        let mut start = t;
        if self.r(WINCH) != 0 {
            let freq = 437_500.0 / (0x32 as f64 + 30.125);
            self.sys.tone(Tone { start, high: 0.5 / freq, low: 0.5 / freq, cycles: 8 });
            start += 8.0 / freq;
        }
        let mut a = self.r(ROTOR_SND).wrapping_add(1);
        let (c, mut d, mut e);
        if a < 2 {
            c = 10u32;
            e = 0x12u8;
            d = 0x12u8;
        } else {
            if a >= 4 {
                a = 0;
            }
            c = 6;
            d = 0x24;
            e = 0x24;
        }
        self.w(ROTOR_SND, a);
        let b = self.r(SPEED).wrapping_mul(2);
        d = d.wrapping_sub(b);
        e = e.wrapping_sub(b);
        let tsl = |n: u8| (if n == 0 { 256.0 } else { n as f64 }) * 13.0;
        let high = (tsl(e) + 22.0) / CPU_HZ;
        let low = (tsl(d) + 25.0) / CPU_HZ;
        self.sys.tone(Tone { start, high, low, cycles: c });
    }

    /// E3F8: ROM key scan in L mode. Returns the ASCII code of the key pressed, if any.
    fn get_key(&self) -> Option<u8> {
        const MAP: [&[u8; 5]; 8] = [b"\0zxcv", b"asdfg", b"qwert", b"12345", b"09876", b"poiuy", b"\rlkjh", b" \0mnb"];
        let k = self.sys.keys();
        for (row, keys) in MAP.iter().enumerate() {
            for bit in 0..5 {
                if k.rows[row] & (1 << bit) != 0 && keys[bit] != 0 {
                    return Some(keys[bit]);
                }
            }
        }
        None
    }

    async fn wait_no_key(&mut self, kind: Kind) {
        while self.get_key().is_some() {
            self.publish(kind);
            self.wait(0.01).await;
        }
    }

    // ------------------------------------------------------------------ top level

    /// Runs the game for ever: main menu, information screen and games.
    pub async fn run(&mut self) {
        // the loading screen, as left on screen by the tape loader, until a key or 4 seconds
        self.m.load_screen(LOADING_SCR);
        let until = self.sys.t + 4.0;
        while self.sys.t < until && self.get_key().is_none() {
            self.publish(Kind::Screen);
            self.wait(0.02).await;
        }
        loop {
            self.main_menu().await;
            self.play().await;
        }
    }

    /// E280: main menu. Returns when "6" (start game) is pressed.
    async fn main_menu(&mut self) {
        'menu: loop {
            self.w(SOUND_OFF, 1);
            self.publish(Kind::Screen);
            self.beep(0x0666, 0x55).await;
            self.wait_no_key(Kind::Screen).await;
            self.m.load_screen(MENU_SCR); // 84D6 CLS + E2E8 DrawMenu
            let mut method = self.r(CONTROL_METHOD);
            loop {
                // E2BD: highlight the selected control method
                for i in 0..0x80 {
                    self.w(0x5960 + i, 0x45);
                }
                let row = 0x5969u16.wrapping_add((method << 5) as u16);
                for i in 0..13 {
                    self.w(row + i, 0xC5);
                }
                self.publish(Kind::Screen);
                self.beep(0x0300, 0x60).await;
                self.wait_no_key(Kind::Screen).await;
                // E29E: keep shuffling the crates while waiting for a key
                let mut last_pub = self.sys.t;
                loop {
                    self.shuffle_crates();
                    match self.get_key() {
                        Some(b'1') => {
                            self.info_screen().await;
                            continue 'menu;
                        }
                        Some(b'6') => return,
                        Some(k @ b'2'..=b'5') => {
                            method = k - b'2';
                            self.w(CONTROL_METHOD, method);
                            break;
                        }
                        _ => {}
                    }
                    self.wait(0.0025).await;
                    if self.sys.t - last_pub > 0.04 {
                        self.publish(Kind::Screen);
                        last_pub = self.sys.t;
                    }
                }
            }
        }
    }

    /// E3B4: information screen.
    async fn info_screen(&mut self) {
        self.cls();
        self.publish(Kind::Screen);
        self.beep(0x0400, 0x70).await;
        self.wait_no_key(Kind::Screen).await;
        self.m.load_screen(INFO_SCR); // HUD, play area attrs, texts (E3C5-E3ED)
        self.w(PLANE_NEAR, 3);
        self.w(SPEED, 0);
        self.hud_indicators();
        self.print_score();
        self.hiscore();
        while self.get_key().is_none() {
            self.publish(Kind::Screen);
            self.wait(0.02).await;
        }
    }

    /// Crates and survivors as at the start of a round (for showcase renders).
    #[cfg(not(target_arch = "wasm32"))]
    pub fn populate(&mut self) {
        self.shuffle_crates();
        self.place_survivors();
    }

    /// Entry used by verification traces: a game straight from $5B00.
    #[cfg(not(target_arch = "wasm32"))]
    pub async fn play_from_start(&mut self) {
        self.play().await;
    }

    /// 5B00: a game. Returns to the menu on game over or abandon (A+G).
    async fn play(&mut self) {
        self.cls();
        self.clear_view();
        self.draw_hud();
        self.hiscore();
        for i in 0..6 {
            self.w(SCORE + i, b'.');
        }
        self.w(SCORE + 6, b'0');
        self.print_score();
        self.m.copy(0x7564, 0x7500, 100);
        'level: loop {
            // 5B26
            self.level_start().await;
            self.fill_time_bar().await;
            self.shuffle_crates();
            self.place_survivors();
            'life: loop {
                // 5B36
                self.overlay = [[false; 32]; 24];
                self.view_north();
                self.flight_controls();
                self.reset_altimeter();
                loop {
                    match self.iteration().await {
                        Flow::Continue => {}
                        Flow::NextLevel => continue 'level,
                        Flow::NewLife => continue 'life,
                        Flow::Menu => return,
                    }
                }
            }
        }
    }

    /// 5B3C: one iteration of the main loop.
    async fn iteration(&mut self) -> Flow {
        if let Some(mut f) = self.on_iteration.take() {
            let go_on = f(self);
            self.on_iteration = Some(f);
            if !go_on {
                std::process::exit(0);
            }
        }
        self.build_window(); // 76D2
        self.aircraft(); // 87F0
        self.hud_indicators(); // 91B4
        self.waves(); // 8B91
        self.heli_sprite(); // 8CA0
        self.footprint(); // 7E10 (projection itself is the renderer's job)
        self.rope = None;
        self.winch(); // F39A
        self.collision(); // 8A7A
        if self.r(CRASHED) == 1 {
            return self.death().await; // 9246
        }
        let ui = self.r(UI_FLAGS);
        if ui & 0x02 != 0 {
            self.map_tick().await; // 8F12
            let ui = self.r(UI_FLAGS);
            if ui & 0x10 != 0 {
                self.w(UI_FLAGS, ui & !0x10);
                self.draw_map(); // 8D0E, 8D5D, 8E5C
                self.map_markers(); // 8F6A
            }
            self.publish(Kind::Map);
        } else {
            self.publish(Kind::View); // 762C
            self.cyclone(); // 9034
        }
        self.read_controls(); // 7FD6
        let d = self.r(CYC_DIST);
        if d < self.r(WIND_THRESHOLD) {
            self.buffeting(d); // 7378
        }
        if self.r(LANDED) == 1 && self.r(NO_FUEL) == 1 && self.r(ON_PAD) == 0 {
            return self.message_and_lose_life(0x5BF2).await; // " NO FUEL "
        }
        self.keys_mn().await; // 80AA (falls into the flight controls 8135)
        if self.r(CRATES) == 5 && self.r(ON_PAD) == 1 && self.m.r16(ISLAND) == BASE_ISLAND {
            return Flow::NextLevel;
        }
        if lo(self.m.r16(TIME_PTR)) == 0xDE {
            self.w(LIVES_LOST, 2); // 92C8: out of time ends the game
            return self.message_and_lose_life(0x8A6E).await; // " NO TIME "
        }
        self.refuel().await; // 8470
        self.time_tick(); // 8284
        self.animate_survivors(); // F34A
        self.wait(ITERATION_TIME).await;
        if self.sys.in_fe(0xFD) & 0x11 == 0 {
            return Flow::Menu; // A+G: abandon
        }
        Flow::Continue
    }

    // ------------------------------------------------------------------ screen helpers

    /// 84D6: clear the screen (pixels 0, attributes 7).
    fn cls(&mut self) {
        for a in 0x4000..0x5800u16 {
            self.w(a, 0);
        }
        for a in 0x5800..0x5B00u16 {
            self.w(a, 7);
        }
    }

    /// 8D0E: clear and colour the 23x22 play area.
    fn clear_view(&mut self) {
        for row in 0..22u16 {
            for col in 0..23u16 {
                self.w(0x5800 + row * 32 + col, 0x3F);
                for line in 0..8 {
                    self.w(pixel_addr((row * 8 + line) as usize, col as usize), 0);
                }
            }
        }
        for row in 1..21u16 {
            for col in 1..22u16 {
                self.w(0x5800 + row * 32 + col, 0x7C);
            }
        }
    }

    /// 859A: print `n` characters of the 8x8 font (6028) from `text` at screen address `de`.
    fn print(&mut self, text: u16, de: u16, n: u16) {
        let mut de = de;
        for i in 0..n {
            let code = self.r(text + i) as u16;
            let g = 0x6028u16.wrapping_add(code * 8);
            for line in 0..8 {
                let v = self.r(g + line);
                self.w(de.wrapping_add(line << 8), v);
            }
            de = de.wrapping_add(1);
        }
    }

    /// 6F06: print characters leftwards from BC (descending) at DE until $FF, 7 lines each.
    fn print_backwards(&mut self, de: u16, bc: u16) {
        let (d, mut e) = (hi(de), lo(de));
        let mut bc = bc;
        loop {
            let code = self.r(bc);
            if code == 0xFF {
                return;
            }
            let g = 0x6028u16.wrapping_add(code as u16 * 8);
            for line in 0..7u16 {
                let v = self.r(g + line);
                self.w(hl(d, e).wrapping_add(line << 8), v);
            }
            e = e.wrapping_sub(1);
            bc = bc.wrapping_sub(1);
        }
    }

    /// 6F00
    fn print_score(&mut self) {
        self.print_backwards(0x507F, 0x6624);
    }

    /// 6602: add `b` points one unit at a time (B=0 means 256), then print.
    fn add_score(&mut self, b: u8) {
        let n = if b == 0 { 256 } else { b as u32 };
        for _ in 0..n {
            let mut a = 0x6624u16;
            loop {
                let mut v = self.r(a);
                if v == b'.' {
                    v = b'0';
                }
                v += 1;
                if v == 0x3A {
                    self.w(a, b'0');
                    a -= 1;
                    continue;
                }
                self.w(a, v);
                break;
            }
        }
        self.print_score();
    }

    /// 87BC: high score := score if greater (string compare), then print it.
    fn hiscore(&mut self) {
        for i in 0..7 {
            let s = self.r(SCORE + i);
            let h = self.r(HISCORE + i);
            if s != h {
                if s >= h {
                    self.m.copy(SCORE, HISCORE, 7);
                }
                break;
            }
        }
        self.print_backwards(0x509F, 0x662D);
    }

    /// 84F4: draw the HUD panel and the bottom rows.
    fn draw_hud(&mut self) {
        let mut de = 0x5818u16;
        let mut hl_ = 0x7200u16;
        for _ in 0..21 {
            self.m.copy(hl_, de, 8);
            hl_ += 8;
            de += 32;
        }
        self.m.copy(0x7148, 0x5AC0, 0x40);
        let mut src = 0x7300u16;
        for row in 0..15usize {
            for col in 0..8usize {
                let code = self.r(src);
                src += 1;
                if code == 0xFF {
                    continue;
                }
                let g = 0x7400u16 + (code as u16) * 8;
                for line in 0..8 {
                    let v = self.r(g + line as u16);
                    self.w(pixel_addr(row * 8 + line, 24 + col), v);
                }
            }
        }
        self.print(0x6848, 0x50C0, 0x40);
        self.print(0x85B9, 0x5019, 6);
        self.print(0x85BF, 0x5038, 8);
        self.print(0x85C7, 0x48BB, 5);
        self.view_box(0x38, 0x85CC);
    }

    /// 8582/8585: colour the VIEW box rows 13-14 cols 27-31 and print the 5-char view name.
    fn view_box(&mut self, attr: u8, text: u16) {
        for i in 0..5 {
            self.w(0x59BB + i, attr);
            self.w(0x59DB + i, attr);
        }
        self.print(text, 0x48DB, 5);
    }

    // ------------------------------------------------------------------ round / life

    /// 8321: start of a round.
    async fn level_start(&mut self) {
        for i in 0..10 {
            self.w(0x5AC0 + i, 0);
            self.w(0x5AE0 + i, 0);
        }
        for n in 0..5u16 {
            let a = 0x5AC0 + 2 * n;
            for o in [0, 1, 0x20, 0x21] {
                self.w(a + o, 6);
            }
            self.publish(Kind::Screen);
            self.beep(0x03E8, 0x2C).await;
            self.wait_tstates(200.0 * (255.0 * 13.0 + 21.0)).await;
        }
        if self.r(CRATES) != 5 {
            self.w(WIND_THRESHOLD, 5);
            self.w(TIME_PERIOD, 0xFF);
            let l = lo(self.rnd());
            self.w(CYC_X, if l & 1 != 0 { 0x14 } else { 2 });
            self.w(CYC_Y, if l & 2 != 0 { 0x13 } else { 2 });
        } else {
            self.w(CRATES, 0);
            let b = 0xFAu8.wrapping_sub(self.r(LIVES_LOST).wrapping_mul(64));
            self.add_score(b);
            // The original calls 6602 again with whatever B the score printer left: always $66.
            self.add_score(0x66);
            self.w(WIND_THRESHOLD, 6);
            let p = self.r(TIME_PERIOD).wrapping_sub(15);
            self.w(TIME_PERIOD, p);
        }
        self.w(LIVES_LOST, 0);
        self.draw_hud();
    }

    /// 843A: fill the time bar; 40 points for every line still lit.
    async fn fill_time_bar(&mut self) {
        self.w(TIME_TICK, 0);
        let (mut h, mut l) = (0x47u8, 0xBEu8);
        loop {
            let a = hl(h, l);
            if self.r(a) == 0xFF {
                self.add_score(40);
                self.publish(Kind::Screen);
                self.beep(0x00FF, 0x10).await;
            } else {
                self.w(a, 0xFF);
                self.publish(Kind::Screen);
                self.beep(0x00D0, 0x10).await;
            }
            h = h.wrapping_sub(1);
            if h == 0x3F {
                h = 0x47;
                l = l.wrapping_add(0xE0);
                if l == 0x1E {
                    break;
                }
            }
        }
        self.m.w16(TIME_PTR, hl(h, l));
    }

    /// 84AE: reset the altimeter bar, altitude := 8.
    fn reset_altimeter(&mut self) {
        let (mut h, mut l) = (0x40u8, 0x38u8);
        loop {
            self.w(hl(h, l), 0);
            h += 1;
            if h == 0x48 {
                h = 0x40;
                l = l.wrapping_add(0x20);
                if l == 0x18 {
                    break;
                }
            }
        }
        let mut a = 0x5018u16;
        for _ in 0..8 {
            a -= 0x100;
            self.w(a, 0xFF);
        }
        self.m.w16(ALT_PTR, a);
        self.w(ALT, 8);
    }

    /// 9246: crash sequence, then lose a life.
    async fn death(&mut self) -> Flow {
        self.publish(Kind::View);
        self.m.w16(EXPLO_PTR, 0xF550);
        let a = self.r(ALT).wrapping_add(2);
        self.w(ALT, a);
        for b in (1..=24u8).rev() {
            self.death = b;
            self.build_window();
            self.waves();
            self.m.copy(0x9300, SPRITE, 72);
            if b >= 0x16 {
                self.heli_sprite();
            }
            if b == 0x12 {
                let v = self.r(SOUND_OFF).wrapping_add(1);
                self.w(SOUND_OFF, v);
            }
            if b >= 0x14 {
                let p = self.m.r16(EXPLO_PTR);
                for i in 0..72 {
                    let v = self.r(SPRITE + i) ^ self.r(p + i);
                    self.w(SPRITE + i, v);
                }
                self.m.w16(EXPLO_PTR, p + 72);
            }
            self.footprint();
            self.rope = None;
            self.publish(Kind::View);
            self.wait(DEATH_STEP_TIME).await;
        }
        self.death = 0;
        self.lose_life()
    }

    /// 92D0: print a 9-character message at row 3, column 7, beep, lose a life.
    async fn message_and_lose_life(&mut self, text: u16) -> Flow {
        self.print(text, 0x4067, 9);
        for i in 0..9 {
            self.w(0x5867 + i, 0x47);
            self.overlay[3][7 + i as usize] = true;
        }
        self.publish(if self.r(UI_FLAGS) & 2 != 0 { Kind::Map } else { Kind::View });
        self.beep(0x0466, 0x0300).await;
        self.lose_life()
    }

    /// 928A: mark a life lost; game over after 3; else drain the fuel and reset for a new life.
    fn lose_life(&mut self) -> Flow {
        let n = self.r(LIVES_LOST);
        let a = hl(0x59, 0x58u8.wrapping_add(n.wrapping_mul(64)));
        self.w(a, 2);
        self.w(a + 1, 2);
        let n = n + 1;
        self.w(LIVES_LOST, n);
        if n == 3 {
            self.publish(Kind::Screen);
            return Flow::Menu;
        }
        while self.r(NO_FUEL) != 1 {
            self.burn_fuel();
        }
        for i in 0..100u16 {
            let v = self.r(0x75C8 + i);
            if v != 0xFF {
                self.w(0x7500 + i, v);
            }
        }
        Flow::NewLife
    }

    // ------------------------------------------------------------------ crates / survivors

    /// 5EEC (via FE92): remove the last crate placement and place 5 crates on 38 candidates.
    pub fn shuffle_crates(&mut self) {
        let mut p = 0x5F61u16;
        for _ in 0..38 {
            if self.r(p) == 0xFF {
                self.w(p, 0);
                let cell = self.m.r16(p + 1);
                let t = self.r(cell);
                for i in 0..4 {
                    if t == self.r(0x5F59 + i) {
                        let plain = self.r(0x5F5D + i);
                        self.w(cell, plain);
                        break;
                    }
                }
            }
            p += 3;
        }
        for _ in 0..5 {
            loop {
                let l = lo(self.rnd());
                if l >= 0x4C {
                    continue;
                }
                let idx = (l >> 1) as u16;
                let e = 0x5F61 + idx * 3;
                if self.r(e) == 0xFF {
                    continue;
                }
                self.w(e, 0xFF);
                let cell = self.m.r16(e + 1);
                let t = self.r(cell);
                let mut crate_tile = self.r(0x5F5C);
                for i in 0..3 {
                    if t == self.r(0x5F5D + i) {
                        crate_tile = self.r(0x5F59 + i);
                        break;
                    }
                }
                self.w(cell, crate_tile);
                break;
            }
        }
    }

    /// 6072: put a survivor on each of the 45 candidate cells that holds a plain tile.
    fn place_survivors(&mut self) {
        for n in 0..45u16 {
            let cell = self.m.r16(0x6018 + 2 * n);
            let t = self.r(cell);
            for i in 0..3 {
                if t == self.r(0x60AC + i) {
                    let mut s = self.r(0x60AF + i);
                    if self.rnd() & 1 != 0 {
                        s += 1;
                    }
                    self.w(cell, s);
                    break;
                }
            }
        }
    }

    /// F34A: animate the survivor glyphs (chars $31 and $32).
    fn animate_survivors(&mut self) {
        let a = self.r(SURV_ANIM1) + 1;
        let a = match a {
            4 => {
                self.m.copy(0x7DEE, 0xFB88, 7);
                4
            }
            8 => {
                self.m.copy(0x7DF6, 0xFB88, 7);
                0
            }
            _ => a,
        };
        self.w(SURV_ANIM1, a);
        let a = self.r(SURV_ANIM2) + 1;
        let a = match a {
            3 => {
                self.m.copy(0x7DFE, 0xFB90, 8);
                3
            }
            6 => {
                self.m.copy(0x7E06, 0xFB90, 8);
                0
            }
            _ => a,
        };
        self.w(SURV_ANIM2, a);
    }

    // ------------------------------------------------------------------ world window

    /// 76D2: clear the view buffer and fill it from the island whose activation area
    /// contains (X, Y). South view: the same window rotated 180 degrees.
    pub fn build_window(&mut self) {
        for i in 0..667u16 {
            self.w(VIEWBUF + i, 0);
        }
        let x = self.m.r16(POS_X);
        let y = self.m.r16(POS_Y);
        let mut ix = ISLANDS;
        loop {
            if self.r(ix) == 0xFF {
                return;
            }
            let rec = |o: u16| self.m.r(ix + o);
            if hi(x) == rec(0)
                && hi(y) == rec(1)
                && lo(x) >= rec(2)
                && lo(x).wrapping_sub(1) < rec(3)
                && lo(y) >= rec(4)
                && lo(y).wrapping_sub(1) < rec(5)
            {
                break;
            }
            ix += 20;
        }
        self.m.w16(ISLAND, ix);
        let r: [i32; 10] = std::array::from_fn(|o| self.m.r(ix + o as u16) as i32);
        let rec = |o: usize| r[o];
        let base = self.m.r16(ix + 10);
        let w = rec(3) - rec(6) + 1;
        let h = rec(5) - rec(8) + 1;
        let south = self.r(VIEW) != 0;
        for r in 0..29i32 {
            let br = lo(y) as i32 + r - rec(8);
            if br < 0 || br >= h {
                continue;
            }
            for c in 0..23i32 {
                let bc = lo(x) as i32 + c - rec(6);
                if bc < 0 || bc >= w {
                    continue;
                }
                let t = self.r(base.wrapping_add((br * 128 + bc) as u16));
                let dst = if south { (28 - r) * 23 + (22 - c) } else { r * 23 + c };
                self.w(VIEWBUF + dst as u16, t);
            }
        }
    }

    /// 7E10 (first part) + 7ADC (first part): save the raw codes of the 3x3 cells under the
    /// helicopter and their height classes.
    fn footprint(&mut self) {
        let mut i = 0;
        for c in 0..3u16 {
            for k in 0..3u16 {
                let cell = VIEWBUF + (15 - k) * 23 + 10 + c;
                let v = self.r(cell);
                self.w(FOOT + i, v);
                i += 1;
            }
        }
        self.project();
        if self.r(CRASHED) == 1 {
            return; // 7F72: no shadow processing while crashed
        }
        let page = self.r(PAGE_BASE);
        for i in 0..9u16 {
            let code = self.r(FOOT + i);
            let mut c = 0u8;
            let mut t = 0x7AC2u16;
            while code >= self.r(t) {
                c += 1;
                t += 1;
            }
            self.w(FOOT_LEVEL + i, c);
            self.w(FOOT_SHADOW + i, c >> 1);
            let first = self.r(hl(page, code));
            if (0x17..0x27).contains(&first) {
                if first == 0x18 {
                    let v = self.r(FOOT_SHADOW + i) | 0x80;
                    self.w(FOOT_SHADOW + i, v);
                }
                self.w(FOOT_LEVEL + i, 0);
            }
        }
    }

    /// 7E2E-7E60: expand rows 0-23 of the view buffer into char columns in place (level k of
    /// a cell in row r is written k rows up). The 3D renderer does the real drawing; this is
    /// kept because columns of rows 1-7 reach above the buffer (F6E7-F74D), and those bytes
    /// survive to the next iteration where the sea-wave lattice (8B91) skips non-zero cells.
    fn project(&mut self) {
        let page = self.r(0x7E35);
        for c in 0..23u16 {
            let a = VIEWBUF + c;
            let e = self.r(a);
            let v = self.r(hl(page, e));
            self.w(a, v);
        }
        for r in 1..24u16 {
            for c in 0..23u16 {
                let mut p = VIEWBUF + r * 23 + c;
                let e = self.r(p);
                let mut d = page;
                let mut a = self.r(hl(d, e));
                'col: loop {
                    self.w(p, a);
                    loop {
                        p = p.wrapping_sub(23);
                        d = d.wrapping_add(1);
                        a = self.r(hl(d, e));
                        if a < 0xFE {
                            break;
                        }
                        if a == 0xFF {
                            break 'col;
                        }
                    }
                }
            }
        }
    }

    /// 8B91: random sea-wave codes on a lattice of open-sea cells of the view buffer.
    fn waves(&mut self) {
        let tick = self.r(WAVE_TICK) + 1;
        let mut ptr;
        if tick == 3 {
            self.w(WAVE_TICK, 0);
            ptr = hl(0x01, lo(self.rnd()));
            self.m.w16(WAVE_PTR, ptr);
        } else {
            self.w(WAVE_TICK, tick);
            ptr = self.m.r16(WAVE_PTR);
        }
        let col;
        let mut a;
        let base;
        if self.r(SPEED) == 0 {
            col = self.r(WAVE_X);
            base = hl(0xF7, 0x05u8.wrapping_add(col));
            a = self.r(WAVE_Y);
        } else {
            let tab = if self.r(VIEW) != 0 { 0x8C77u16 } else { 0x8C66 };
            let e = tab + self.r(HEADING) as u16;
            let mut c = self.r(WAVE_X).wrapping_add(self.r(e));
            if c >= 9 {
                c = 4;
            }
            self.w(WAVE_X, c);
            col = c;
            base = hl(0xF7, 0x05u8.wrapping_add(c));
            a = self.r(WAVE_Y).wrapping_add(self.r(e + 1));
            if a >= 7 {
                a = 3;
            }
            self.w(WAVE_Y, a);
        }
        let mut b = a;
        if self.r(VIEW) != 0 {
            b = b.wrapping_add(2);
            if b >= 7 {
                b -= 4;
            }
        }
        let mut p = base.wrapping_add(23 * b as u16);
        let mut cols = 4u8;
        let mut skip = 0x4Bu16;
        if col < 4 {
            p = p.wrapping_add(5);
            if col < 2 {
                cols = 5;
                skip = 0x46;
            }
        } else if col < 7 {
            cols = 5;
            skip = 0x46;
        }
        for _ in 0..7 {
            for _ in 0..cols {
                if self.r(p) == 0 {
                    let v = self.r(ptr) & 3;
                    self.w(p, v);
                    ptr = hl(hi(ptr), lo(ptr).wrapping_add(1));
                }
                p = p.wrapping_add(5);
            }
            p = p.wrapping_add(skip);
        }
    }

    // ------------------------------------------------------------------ helicopter

    /// 8CA0: build the helicopter sprite (frame + rotor XOR overlay) in 6950.
    fn heli_sprite(&mut self) {
        let mut f = self.r(HEADING_DISP);
        if self.r(VIEW) != 0 {
            f = f.wrapping_add(8) & !0x10;
        }
        self.w(ROTOR_SHIFT, if f > 9 { 0x87 } else { 0x00 });
        let src = 0xE8E8u16.wrapping_add(72 * (f as u16 + 1));
        self.m.copy(src, SPRITE, 72);
        let (page, k);
        if self.r(LANDED) == 1 || self.r(NO_FUEL) != 0 {
            page = 0x67u8;
            let mut a = self.r(ROTOR_FRAME) + 1;
            if a >= 4 {
                a = 0;
            }
            k = a;
        } else {
            page = 0x70;
            let mut a = self.r(ROTOR_FRAME) + 1;
            if a >= 2 {
                a = 0;
            }
            k = a;
        }
        self.w(ROTOR_FRAME, k);
        let ov = hl(page + k, 0);
        let shift = self.r(ROTOR_SHIFT) == 0x87;
        for i in 0..72u16 {
            let mut a = self.r(ov + i);
            if shift {
                a = a.wrapping_add(a);
            }
            let v = a ^ self.r(SPRITE + i);
            self.w(SPRITE + i, v);
        }
    }

    /// 80F9: view north; patch the tile-column pages.
    fn view_north(&mut self) {
        self.w(VIEW, 0);
        self.view_box(0x38, 0x85CC);
        self.set_pages(0x63);
    }

    /// 8104: view south.
    fn view_south(&mut self) {
        self.w(VIEW, 1);
        self.view_box(0x78, 0x827F);
        self.set_pages(0x6C);
    }

    fn set_pages(&mut self, a: u8) {
        self.w(0x7B18, a);
        self.w(0x7E35, a);
        self.w(0x7E41, a);
        self.w(0x7E6D, a + 3);
        self.w(0x7E93, a + 4);
        self.w(0x7EB9, a + 5);
        self.w(0x7EDF, a + 6);
        self.w(0x7F05, a + 7);
    }

    /// 7FD6: read the selected control device into 7522.
    fn read_controls(&mut self) {
        let mut b = 0u8;
        match self.r(CONTROL_METHOD) {
            1 => {
                b = !(self.sys.in_fe(0xEF) | 0xE0);
                let a = self.sys.in_fe(0xF7);
                if a & 0x10 == 0 {
                    b |= 1;
                }
                if a & 0x08 == 0 {
                    b |= 2;
                }
                if a & 0x04 == 0 {
                    b |= 4;
                }
                if a & 0x02 == 0 {
                    b |= 8;
                }
                if a & 0x01 == 0 {
                    b |= 0x10;
                }
            }
            2 => {
                let a = self.sys.in_kempston();
                if a & 0x10 != 0 {
                    b |= 1;
                }
                if a & 0x08 != 0 {
                    b |= 2;
                }
                if a & 0x04 != 0 {
                    b |= 4;
                }
                if a & 0x01 != 0 {
                    b |= 8;
                }
                if a & 0x02 != 0 {
                    b |= 0x10;
                }
            }
            3 => {
                if self.sys.in_fe(0xF7) & 0x10 == 0 {
                    b |= 0x10;
                }
                let a = self.sys.in_fe(0xEF);
                if a & 0x10 == 0 {
                    b |= 4;
                }
                if a & 0x08 == 0 {
                    b |= 2;
                }
                if a & 0x04 == 0 {
                    b |= 8;
                }
                if a & 0x01 == 0 {
                    b |= 1;
                }
            }
            _ => {
                if self.sys.in_fe(0xFE) | 0xE0 != 0xFF {
                    b |= 1;
                }
                if self.sys.in_fe(0xF7) | 0xE0 != 0xFF {
                    b |= 4;
                }
                if self.sys.in_fe(0xFB) | 0xE0 != 0xFF {
                    b |= 2;
                }
                let a = self.sys.in_fe(0xDF);
                if a & 1 == 0 {
                    b |= 8;
                }
                if a & 2 == 0 {
                    b |= 0x10;
                }
            }
        }
        self.w(CONTROLS, b);
    }

    /// 7378: cyclone buffeting of the controls (distance `d` below the wind threshold).
    fn buffeting(&mut self, d: u8) {
        if self.r(LANDED) == 1 {
            return;
        }
        if d >= 4 {
            let l = lo(self.rnd());
            let v = (l & 0x1A) | self.r(CONTROLS);
            self.w(CONTROLS, v);
        } else if d >= 2 {
            let l = lo(self.rnd());
            let v = (l & 0x1B) | self.r(CONTROLS);
            self.w(CONTROLS, v);
        } else {
            let t = self.r(TURN_TIMER);
            if t != 0 {
                self.w(TURN_TIMER, t - 1);
            }
            self.w(CONTROLS, 0x12);
        }
    }

    /// 80AA: M (map) and N (view) keys, then the flight controls (8135).
    async fn keys_mn(&mut self) {
        let a = self.sys.in_fe(0x7F);
        let mut f = self.r(UI_FLAGS);
        if a & 0x04 != 0 {
            f &= !1;
        } else if f & 1 == 0 {
            self.beep(0x0361, 0x1E).await;
            f |= 1;
            if f & 2 != 0 {
                f &= !2;
                f |= 8;
            } else {
                f |= 2 | 0x10;
            }
        }
        self.w(UI_FLAGS, f);
        if a & 0x08 != 0 {
            let f = self.r(UI_FLAGS) & !4;
            self.w(UI_FLAGS, f);
        } else if self.r(UI_FLAGS) & 4 == 0 {
            let f = self.r(UI_FLAGS) | 4;
            self.w(UI_FLAGS, f);
            self.view_box(0x7F, 0x85CC);
            self.publish(if f & 2 != 0 { Kind::Map } else { Kind::View });
            self.beep(0x0300, 0x28).await;
            if self.r(VIEW) == 0 {
                self.view_south();
            } else {
                self.view_north();
            }
        }
        self.flight_controls();
    }

    /// 8135: turning, thrust/coasting/movement, climb and descent.
    fn flight_controls(&mut self) {
        let c = self.r(CONTROLS);
        let t = self.r(TURN_TIMER);
        let mut skip_turn = false;
        if t != 0 {
            self.w(TURN_TIMER, t - 1);
            if t - 1 == 1 {
                let n = self.r(HEADING_NEXT);
                self.w(HEADING, n);
                self.w(HEADING_DISP, n);
            }
            skip_turn = true;
        } else if self.r(LANDED) == 1 {
            self.climb_and_descend(c);
            return;
        }
        if !skip_turn {
            if c & 0x10 != 0 {
                let h = self.r(HEADING);
                let d = if h == 0 { 0x0F } else { h - 1 };
                self.w(HEADING_DISP, d);
                let n = if d == 0 { 0x0F } else { d - 1 };
                self.w(HEADING_NEXT, n);
                self.w(TURN_TIMER, 3);
            }
            if c & 0x08 != 0 {
                let h = self.r(HEADING);
                let d = if h + 1 == 0x10 { 0 } else { h + 1 };
                self.w(HEADING_DISP, d);
                let n = if d + 1 == 0x10 { 0 } else { d + 1 };
                self.w(HEADING_NEXT, n);
                if self.r(TURN_TIMER) != 0 {
                    self.w(HEADING_DISP, h);
                    self.w(HEADING_NEXT, h);
                    self.w(TURN_TIMER, 0);
                } else {
                    self.w(TURN_TIMER, 3);
                }
            }
        }
        // 81AB: thrust / coasting / movement
        let dir;
        if self.r(NO_FUEL) != 1 && c & 1 != 0 {
            let s = self.r(SPEED);
            if s != 7 {
                self.w(SPEED, s + 1);
            }
            dir = self.r(HEADING);
            self.w(MOVE_DIR, dir);
            self.step(dir);
        } else {
            let s = self.r(SPEED);
            let s = if s == 0 { 0 } else { s - 1 };
            self.w(SPEED, s);
            if s != 0 {
                dir = self.r(MOVE_DIR);
                self.step(dir);
            }
        }
        self.climb_and_descend(c);
    }

    /// 81DC: move one unit using the self-modified INC/DEC opcodes from the table at 826F.
    fn step(&mut self, dir: u8) {
        let xop = self.r(0x826F + dir as u16);
        let yop = self.r(0x8270 + dir as u16);
        self.w(0x81EF, xop);
        self.w(0x81F6, yop);
        let apply = |op: u8, v: u16| match op {
            0x23 => v.wrapping_add(1),
            0x2B => v.wrapping_sub(1),
            _ => v,
        };
        let x = apply(xop, self.m.r16(POS_X));
        self.m.w16(POS_X, x);
        let y = apply(yop, self.m.r16(POS_Y));
        self.m.w16(POS_Y, y);
    }

    /// 81FA-826E: climb (or take off) and descend.
    fn climb_and_descend(&mut self, c: u8) {
        if c & 4 != 0 && self.r(NO_FUEL) != 1 {
            if self.r(LANDED) != 0 {
                self.w(LANDED, 0);
                self.w(ON_PAD, 0);
                return;
            }
            let mut rate = self.r(CLIMB_RATE);
            if rate != 3 {
                rate += 1;
                self.w(CLIMB_RATE, rate);
            }
            for _ in 0..rate {
                let a = self.r(ALT);
                if a >= 0x3C {
                    break;
                }
                self.alt_bar_up();
                self.w(ALT, a + 1);
            }
        } else {
            self.w(CLIMB_RATE, 0);
        }
        if self.r(LANDED) == 1 {
            return;
        }
        if self.r(NO_FUEL) != 1 && c & 2 == 0 {
            self.w(DESCENT_RATE, 0);
            return;
        }
        let mut rate = self.r(DESCENT_RATE);
        if rate != 3 {
            rate += 1;
            self.w(DESCENT_RATE, rate);
        }
        for _ in 0..rate {
            let a = self.r(ALT).wrapping_sub(1);
            if a & 0x80 != 0 {
                self.w(TOUCHDOWN, 1);
                return;
            }
            self.alt_bar_down();
            self.w(ALT, a);
        }
    }

    /// 82D4: light one more line of the altimeter bar.
    fn alt_bar_up(&mut self) {
        let p = self.m.r16(ALT_PTR);
        let (mut h, mut l) = (hi(p).wrapping_sub(1), lo(p));
        if h == 0x47 {
            h = 0x4F;
            l = l.wrapping_add(0xE0);
            if l == 0xF8 {
                h = 0x47;
            }
        } else if h == 0x3F {
            h = 0x47;
            l = l.wrapping_add(0xE0);
            if l == 0xF8 {
                h = 0x47;
            }
        }
        self.w(hl(h, l), 0xFF);
        self.m.w16(ALT_PTR, hl(h, l));
    }

    /// 82FB: clear the top line of the altimeter bar (keeps the original $4F quirk).
    fn alt_bar_down(&mut self) {
        let p = self.m.r16(ALT_PTR);
        self.w(p, 0);
        let (mut h, mut l) = (hi(p).wrapping_add(1), lo(p));
        if h == 0x48 {
            h = 0x40;
            l = l.wrapping_add(0x20);
            if l == 0x18 {
                h = 0x48;
            }
        } else if h == 0x4F {
            h = 0x48;
            l = l.wrapping_add(0x20);
            if l == 0x18 {
                h = 0x48;
            }
        }
        self.m.w16(ALT_PTR, hl(h, l));
    }

    // ------------------------------------------------------------------ fuel / time

    /// 82A7: fuel consumption tick.
    fn burn_fuel(&mut self) {
        let t = self.r(FUEL_TICK) + 1;
        self.w(FUEL_TICK, t);
        if 0x30 >= t {
            return;
        }
        self.w(FUEL_TICK, 0);
        let p = self.m.r16(FUEL_PTR);
        let (mut h, mut l) = (hi(p) + 1, lo(p));
        if h == 0x48 {
            if l == 0xBC {
                self.w(NO_FUEL, 1);
                return;
            }
            h = 0x40;
            l = l.wrapping_add(0x20);
        }
        self.w(hl(h, l), 0);
        self.m.w16(FUEL_PTR, hl(h, l));
    }

    /// 8470: refuel on the pad (one line per iteration, with a beep), else burn fuel.
    async fn refuel(&mut self) {
        if self.r(ON_PAD) == 0 {
            self.burn_fuel();
            return;
        }
        self.w(FUEL_TICK, 0);
        let p = self.m.r16(FUEL_PTR);
        if lo(p) == 0x1C {
            return;
        }
        self.beep(0x00D0, 0x10).await;
        self.w(p, 0xFF);
        let (mut h, mut l) = (hi(p) - 1, lo(p));
        if h == 0x3F {
            h = 0x47;
            l = l.wrapping_add(0xE0);
        }
        self.m.w16(FUEL_PTR, hl(h, l));
        self.w(NO_FUEL, 0);
    }

    /// 8284: one time-bar line every (828C) iterations.
    fn time_tick(&mut self) {
        let t = self.r(TIME_TICK) + 1;
        self.w(TIME_TICK, t);
        if t < self.r(TIME_PERIOD) {
            return;
        }
        self.w(TIME_TICK, 0);
        let p = self.m.r16(TIME_PTR);
        let (mut h, mut l) = (hi(p) + 1, lo(p));
        if h == 0x48 {
            h = 0x40;
            l = l.wrapping_add(0x20);
        }
        self.w(hl(h, l), 0);
        self.m.w16(TIME_PTR, hl(h, l));
    }

    // ------------------------------------------------------------------ HUD indicators

    /// 91B4: compass dot, speed bar, BEWARE AIRCRAFT colours.
    fn hud_indicators(&mut self) {
        for a in [0x591C, 0x591D, 0x591E, 0x595C, 0x595D, 0x595E, 0x593C, 0x593E] {
            self.w(a, 0);
        }
        let dir = if self.r(SPEED) == 0 { self.r(HEADING) } else { self.r(MOVE_DIR) };
        let off = self.m.r16(0x9232 + dir as u16);
        self.w(0x593D_u16.wrapping_add(off), 0x47);
        let mut a = self.r(SPEED) + 1;
        if a >= 7 {
            a = 6;
        }
        let red = a - 1;
        let white = 6 - a;
        let mut p = 0x58BAu16;
        for _ in 0..red {
            self.w(p, 0x52);
            p = p.wrapping_sub(32);
        }
        for _ in 0..white {
            self.w(p, 0x7F);
            p = p.wrapping_sub(32);
        }
        let attr = if self.r(PLANE_NEAR) == 3 { 0xFA } else { 0x3F };
        if self.r(0x5A18) != attr {
            for i in 0..8 {
                self.w(0x5A18 + i, attr);
                self.w(0x5A38 + i, attr);
            }
        }
    }

    // ------------------------------------------------------------------ aircraft

    /// 87F0: aircraft schedule, movement, proximity warning, placement in the view buffer,
    /// sprite set-up and height level.
    fn aircraft(&mut self) {
        self.w(PLANE_DRAWN, 0);
        self.w(PLANE_NEAR, 0);
        let a = self.r(SCHED_STEP) + 1;
        if a == 0x1C {
            self.w(SCHED_STEP, 0);
            let mut p = self.m.r16(SCHED_PTR).wrapping_add(20);
            if hi(p) == 0xE8 && lo(p) >= 0x5A {
                p = 0xE740;
            }
            self.m.w16(SCHED_PTR, p);
            let mut bc = p;
            let mut h = AIRCRAFT;
            loop {
                let v = self.r(bc);
                bc += 1;
                if v == 0xFF {
                    break;
                }
                if v & 0x80 != 0 {
                    self.w(h, v & 0x7F);
                    self.m.copy(h + 1 + 0x60, h + 1, 4);
                    h += 5;
                } else {
                    self.w(h, v);
                    h += 5;
                }
            }
        } else {
            self.w(SCHED_STEP, a);
        }
        // move
        let mut p = AIRCRAFT;
        loop {
            let d = self.r(p);
            let ops = hl(0xE7, d);
            let apply = |op: u8, v: u16| match op {
                0x03 => v.wrapping_add(1),
                0x0B => v.wrapping_sub(1),
                _ => v,
            };
            let mut x = self.m.r16(p + 1);
            x = apply(self.r(ops), x);
            x = apply(self.r(ops + 1), x);
            self.m.w16(p + 1, x);
            let mut y = self.m.r16(p + 3);
            y = apply(self.r(ops + 2), y);
            y = apply(self.r(ops + 3), y);
            self.m.w16(p + 3, y);
            p += 5;
            if self.r(p) == 0xFF {
                break;
            }
        }
        // proximity / visibility
        let hx = self.m.r16(POS_X);
        let hy = self.m.r16(POS_Y);
        let mut ix = AIRCRAFT;
        loop {
            let ax = self.m.r16(ix + 1);
            let ay = self.m.r16(ix + 3);
            let dx = ax.wrapping_sub(hx).wrapping_add(22);
            let dy = ay.wrapping_sub(hy).wrapping_add(25);
            'one: {
                if hi(dx) != 0 || lo(dx) >= 0x2D {
                    break 'one;
                }
                let near = self.r(PLANE_NEAR) | 1;
                self.w(PLANE_NEAR, near);
                let col = lo(dx).wrapping_sub(10);
                if col >= 0x19 {
                    if hi(dy) == 0 && lo(dy) < 0x33 {
                        let near = self.r(PLANE_NEAR) | 2;
                        self.w(PLANE_NEAR, near);
                    }
                    break 'one;
                }
                self.w(PLANE_COL, col);
                if hi(dy) != 0 || lo(dy) >= 0x33 {
                    break 'one;
                }
                let near = self.r(PLANE_NEAR) | 2;
                self.w(PLANE_NEAR, near);
                let row = lo(dy).wrapping_sub(10);
                if row >= 0x1F {
                    break 'one;
                }
                self.place_aircraft(ix, row);
            }
            ix += 5;
            if self.r(ix) == 0xFF {
                break;
            }
        }
    }

    /// 88FF-8A66: write the aircraft codes F6-FE into the view buffer; the first visible
    /// aircraft also gets its sprite (tiles $3C-$44), shadow ($33-$3B) and height level.
    fn place_aircraft(&mut self, ix: u16, row: u8) {
        self.w(PLANE_ROW, row);
        let mut b = row;
        let a;
        if self.r(VIEW) != 0 {
            b = 0x1E - b;
            self.w(PLANE_ROW, b);
            let c = 0x18 - self.r(PLANE_COL);
            self.w(PLANE_COL, c);
            a = c;
        } else {
            a = self.r(PLANE_COL);
        }
        let mut p = 0xF71Eu16.wrapping_add(a as u16).wrapping_add(23 * b as u16);
        if self.r(PLANE_ROW) >= 0x1E {
            if a >= 2 {
                self.w(p, 0xF6);
            }
            p += 1;
            if a != 0 {
                self.w(p, 0xF9);
            }
            p += 1;
            self.w(p, 0xFC);
        } else {
            if a >= 2 {
                self.w(p, 0xF6);
                self.w(p + 23, 0xF7);
                self.w(p + 46, 0xF8);
            }
            p += 1;
            if a != 0 && a != 0x18 {
                self.w(p, 0xF9);
                self.w(p + 23, 0xFA);
                self.w(p + 46, 0xFB);
            }
            if a < 0x17 {
                p += 1;
                self.w(p, 0xFC);
                self.w(p + 23, 0xFD);
                self.w(p + 46, 0xFE);
            }
        }
        if self.r(PLANE_DRAWN) != 0 {
            return;
        }
        self.w(PLANE_DRAWN, 1);
        let mut n = self.r(ix) >> 2;
        if self.r(VIEW) != 0 {
            n = (n + 8) & !0x10;
        }
        let src = 0xDDB8u16.wrapping_add(72 * (n as u16 + 1));
        self.m.copy(src, 0xFBE0, 72);
        for i in 0..36u16 {
            let v = self.r(0xFBE0 + 2 * i) & 0xAA;
            self.w(0xFB98 + 2 * i, v);
            let v = self.r(0xFBE1 + 2 * i) & 0x55;
            self.w(0xFB99 + 2 * i, v);
        }
        // 89CA: step the aircraft level one towards the helicopter's level
        let target = self.r(HELI_LEVEL);
        let mut lvl = self.r(PLANE_LEVEL);
        if lvl != target {
            if lvl > target {
                lvl -= 1;
            } else {
                lvl += 1;
            }
            self.w(PLANE_LEVEL, lvl);
            // rewrite the tile stacks of codes F6-FE in both page sets
            let (mut h, mut d) = (0x64u8, 0x6Du8);
            if lvl != 1 {
                let mut c = 2u8;
                while c != lvl {
                    c += 1;
                    h += 1;
                    d += 1;
                }
                for i in 0..9u16 {
                    self.w(hl(h, 0xF6) + i, 0xFE);
                    self.w(hl(d, 0xF6) + i, 0xFE);
                }
                h += 1;
                d += 1;
            }
            for i in 0..9u16 {
                self.w(hl(h, 0xF6) + i, 0x3C + i as u8);
                self.w(hl(d, 0xF6) + i, 0x3C + i as u8);
            }
            h += 1;
            d += 1;
            for i in 0..9u16 {
                self.w(hl(h, 0xF6) + i, 0xFF);
                self.w(hl(d, 0xF6) + i, 0xFF);
            }
        }
        // 8A20: where aircraft and shadow overlap, OR the shadow into the aircraft tiles
        match self.r(PLANE_LEVEL) {
            2 => {
                for col in 0..3u16 {
                    for i in 0..8u16 {
                        let a = 0xFBF0 + col * 24 + i;
                        let v = self.r(a) | self.r(0xFB98 + col * 24 + i);
                        self.w(a, v);
                    }
                }
            }
            1 => {
                for col in 0..3u16 {
                    for i in 0..16u16 {
                        let a = 0xFBE8 + col * 24 + i;
                        let v = self.r(a) | self.r(0xFB98 + col * 24 + i);
                        self.w(a, v);
                    }
                }
            }
            _ => {}
        }
    }

    // ------------------------------------------------------------------ winch

    /// F39A: lower the rope over a crate or survivor, hook it and reel it in.
    fn winch(&mut self) {
        let w = self.r(WINCH);
        if w.wrapping_sub(1) < 0x10 {
            // F4AB: reeling in
            let a = w - 1;
            let b = self.r(DESCENT_RATE).min(a);
            let a = a - b;
            self.w(WINCH, a);
            if a == 0 {
                let pts = if lo(self.m.r16(PICK_SPR)) == 0x48 { 0x32 } else { 0xFA };
                self.add_score(pts);
                return;
            }
            self.draw_load(a);
            return;
        }
        let t = self.r(FOOT + 4);
        let mut found: Option<(u16, u8, u16)> = None; // (graphic, B, plain-tile address)
        for i in 0..4u16 {
            if t == self.r(0xF511 + i) {
                found = Some((0xF52F, (4 - i) as u8, 0xF51B + i));
                break;
            }
        }
        if found.is_none() {
            for i in 0..3u16 {
                if t == self.r(0xF515 + 2 * i) || t == self.r(0xF516 + 2 * i) {
                    found = Some((0xF548, (3 - i) as u8 + 1, 0xF51B + i));
                    break;
                }
            }
        }
        let Some((gfx, b, plain)) = found else {
            if self.r(ROPE_STATE) != 0 {
                self.w(ROPE_STATE, 0);
                self.draw_rope(0x0C);
            }
            return;
        };
        self.m.w16(PICK_SPR, gfx);
        let pt = self.r(plain);
        self.w(PICK_TILE, pt);
        // gap between the helicopter and the object, in pixel lines
        let obj = 0xFDA1u16.wrapping_sub(8 * b as u16);
        let heli = 0xFD96u16.wrapping_sub(self.r(ALT) as u16);
        let gap = obj.wrapping_sub(heli);
        if hi(gap) != 0 {
            return;
        }
        let e = lo(gap);
        let mut st = self.r(ROPE_STATE);
        if e >= 0x11 {
            // out of reach: the rope dangles (F414)
            self.lower_rope(st, 0x10);
            return;
        }
        if e < 0x0D {
            st += 1;
            self.w(ROPE_STATE, st);
        }
        if st <= 1 {
            self.lower_rope(st, e);
            return;
        }
        // hooked
        let len = e.max(2) - 1;
        self.w(WINCH, len);
        let ix = self.m.r16(ISLAND);
        let base = self.m.r16(ix + 0x0A);
        let row = lo(self.m.r16(POS_Y)).wrapping_add(0x0E).wrapping_sub(self.r(ix + 8)) as u16;
        let col = lo(self.m.r16(POS_X)).wrapping_add(0x0B).wrapping_sub(self.r(ix + 6)) as u16;
        let cell = base.wrapping_add(row * 128).wrapping_add(col);
        let pt = self.r(PICK_TILE);
        self.w(cell, pt);
        self.w(ROPE_STATE, 0);
        if lo(self.m.r16(PICK_SPR)) != 0x48 {
            let n = self.r(CRATES) + 1;
            if n != 6 {
                self.w(CRATES, n);
                let a = hl(0x5A, 0xCAu8.wrapping_sub(2 * n));
                for o in [0, 1, 0x20, 0x21] {
                    self.w(a + o, 2);
                }
            }
        }
        let len = self.r(WINCH);
        self.draw_load(len);
    }

    /// F416-F427: advance the rope state and draw `e` (or 12) lines of rope.
    fn lower_rope(&mut self, st: u8, e: u8) {
        let st = st + 1;
        if st != 1 || e < 0x0D {
            self.w(ROPE_STATE, 2);
            self.draw_rope(e);
        } else {
            self.w(ROPE_STATE, 1);
            self.draw_rope(0x0C);
        }
    }

    fn draw_rope(&mut self, lines: u8) {
        if lines < 0x19 {
            self.rope = Some(Rope { gfx: 0xF51F, lines });
        }
    }

    fn draw_load(&mut self, len: u8) {
        let lines = len.wrapping_add(8);
        if lines < 0x19 {
            let gfx = self.m.r16(PICK_SPR).wrapping_sub(len as u16);
            self.rope = Some(Rope { gfx, lines });
        }
    }

    // ------------------------------------------------------------------ collision

    /// 8A7A: landing and terrain/aircraft collision.
    fn collision(&mut self) {
        if self.r(LANDED) == 1 {
            return;
        }
        let alt = self.r(ALT);
        let b4 = ((alt as i8) >> 2) as u8;
        let t = self.r(AIR_TICK).wrapping_add(1);
        self.w(AIR_TICK, t);
        if t & 4 != 0 {
            let mut a = (b4 as i8 >> 1) as u8 + 1;
            if a == 8 {
                a = 7;
            }
            self.w(HELI_LEVEL, a);
        }
        let mut clear = 0u8;
        // `a` is the value compared with each cell's class. After a "very tall" (aircraft)
        // cell the original carries on with alt/8 instead of alt/4 (8B44 `LD A,E`).
        let mut a = b4;
        for i in 0..9u16 {
            let h = self.r(FOOT_LEVEL + i);
            if a >= h {
                clear += 1;
                continue;
            }
            if h < 0x0F {
                if self.r(DESCENT_RATE) >= 3 {
                    return self.crash();
                }
                self.w(DESCENT_RATE, 0);
                continue;
            }
            // very tall cell: an aircraft
            let e = (a as i8 >> 1) as u8;
            let lvl = self.r(PLANE_LEVEL);
            if lvl.wrapping_sub(1) == e {
                return self.crash();
            }
            if lvl == 7 && e == 7 {
                return self.crash();
            }
            a = e;
            clear += 1;
        }
        if self.r(TOUCHDOWN) != 0 {
            if clear != 9 || self.r(DESCENT_RATE) >= 3 {
                return self.crash();
            }
        } else {
            if clear == 9 {
                return;
            }
            if clear != 0 {
                return self.crash();
            }
        }
        // touch-down test
        let mut pads = 0;
        for i in 0..9u16 {
            let code = self.r(FOOT + i);
            let mut h = 0x63u8;
            loop {
                h += 1;
                if self.r(hl(h, code)) == 0xFF {
                    break;
                }
            }
            let top = self.r(hl(h - 1, code));
            if top & 0x80 != 0 {
                if top == 0x80 || top == 0x86 {
                    return self.crash();
                }
                if top == 0x83 || top == 0x89 {
                    pads += 1;
                }
            } else if top >= 0x2D || top < 0x03 {
                return self.crash();
            }
        }
        if pads == 9 {
            self.w(ON_PAD, 1);
        }
        self.w(LANDED, 1);
        self.w(TOUCHDOWN, 0);
        let old = self.r(ALT);
        let new = ((old.wrapping_add(7) as i8 >> 3) as u8).wrapping_mul(8);
        self.w(ALT, new);
        for _ in 0..new.wrapping_sub(old) {
            self.alt_bar_up();
        }
    }

    fn crash(&mut self) {
        self.w(CRASHED, 1);
    }

    // ------------------------------------------------------------------ cyclone & map

    /// 9034: helicopter map cell, cyclone movement, distance, WIND FORCE bar, DANGER.
    fn cyclone(&mut self) {
        self.w(OFF_MAP, 0);
        let cell = |v: u16, max: u8| -> (u8, bool) {
            let q = v >> 5;
            if hi(q) != 0 {
                // X: H >= $80 gives column 22; Y (9087) jumps past its LD A,$15 and keeps H
                let big = if max == 0x16 { max } else { hi(q) };
                (if hi(q) >= 0x80 { big } else { 0 }, true)
            } else if lo(q) >= max + 1 {
                (max, true)
            } else {
                (lo(q), false)
            }
        };
        let (cx, offx) = cell(self.m.r16(POS_X), 0x16);
        if offx {
            let v = self.r(OFF_MAP) + 1;
            self.w(OFF_MAP, v);
        }
        self.w(MAP_HX, cx);
        let (cy, offy) = cell(self.m.r16(POS_Y), 0x15);
        if offy {
            let v = self.r(OFF_MAP) + 1;
            self.w(OFF_MAP, v);
        }
        self.w(MAP_HY, cy);
        let t = self.r(CYC_TICK) + 1;
        self.w(CYC_TICK, t);
        if t > 0x18 {
            self.w(CYC_TICK, 0);
            let l = self.r(CYC_LEG) + 1;
            self.w(CYC_LEG, l);
            if l > 8 {
                self.w(CYC_LEG, 0);
                let r = lo(self.rnd()) & 0x0F;
                let e = 0x9178 + 2 * r as u16;
                let m = self.r(e);
                let b = self.r(e + 1);
                self.w(CYC_MASK, m);
                self.w(CYC_BITS, b);
            }
            let h = hi(self.rnd());
            let idx = (h & self.r(CYC_MASK)) | self.r(CYC_BITS);
            let p = hl(0x91, 0x98u8.wrapping_add(idx));
            let nx = self.r(CYC_X).wrapping_add(self.r(p));
            if (1..0x16).contains(&nx) {
                self.w(CYC_X, nx);
            } else {
                self.w(CYC_LEG, 8);
                self.w(CYC_TICK, 0x18);
            }
            let ny = self.r(CYC_Y).wrapping_add(self.r(p + 1));
            if (1..0x15).contains(&ny) {
                self.w(CYC_Y, ny);
            } else {
                self.w(CYC_LEG, 8);
                self.w(CYC_TICK, 0x18);
            }
        }
        let absd = |a: u8, b: u8| {
            let d = a.wrapping_sub(b);
            if d >= 0x80 {
                d.wrapping_neg()
            } else {
                d
            }
        };
        let c = absd(self.r(CYC_X), self.r(MAP_HX));
        let mut a = absd(self.r(CYC_Y), self.r(MAP_HY));
        if a < c {
            a = c;
        }
        if a >= 0x10 {
            a = 0x0F;
        }
        self.w(CYC_DIST, a);
        let mut e = a;
        let mut b = 0x10 - a;
        if self.r(OFF_MAP) != 0 {
            b = b.wrapping_sub(1);
            e += 1;
        }
        let mut p = 0x5AF0u16;
        for _ in 0..b {
            self.w(p, 0x52);
            p = hl(hi(p), lo(p).wrapping_add(1));
        }
        for _ in 0..e {
            self.w(p, 0x7F);
            p = hl(hi(p), lo(p).wrapping_add(1));
        }
        let attr = if self.r(CYC_DIST) < 6 { 0xFA } else { 0x38 };
        if self.r(p) == attr {
            return;
        }
        for i in 0..6 {
            self.w(0x5ADA + i, attr);
        }
    }

    /// 8D0E + 8D5D + 8E5C: draw the map (islands, names, frame, north arrow).
    fn draw_map(&mut self) {
        for row in 0..22usize {
            for col in 0..23usize {
                let a = 0x5800 + (row * 32 + col) as u16;
                self.w(a, MAP_SCR[6144 + row * 32 + col]);
                for line in 0..8 {
                    let p = pixel_addr(row * 8 + line, col);
                    self.w(p, MAP_SCR[(p - 0x4000) as usize]);
                }
            }
        }
    }

    /// 8F12: map-mode tick (delay, blinking markers), positions via 9034.
    async fn map_tick(&mut self) {
        self.wait_tstates(40.0 * (255.0 * 13.0 + 21.0)).await;
        let n = self.r(MAP_BLINK) + 1;
        self.w(MAP_BLINK, n);
        if n <= 3 {
            self.cyclone();
            return;
        }
        let mut a = self.r(0x9027);
        if a == 0x3F {
            a = 0x3A;
        }
        let h = self.m.r16(MAP_HATTR);
        self.w(h, a);
        let a = self.r(0x9030);
        let c = self.m.r16(MAP_CATTR);
        self.w(c, a);
        let hp = self.m.r16(MAP_HPIX);
        let cp = self.m.r16(MAP_CPIX);
        for i in 0..8u16 {
            let v = self.r(0x901F + i);
            self.w(hp.wrapping_add(i << 8), v);
        }
        for i in 0..8u16 {
            let v = self.r(0x9028 + i);
            self.w(cp.wrapping_add(i << 8), v);
        }
        if self.r(MAP_BLINK) <= 6 {
            self.cyclone();
            return;
        }
        self.w(MAP_BLINK, 0);
        let a = self.r(0x9027);
        self.w(h, a);
        self.cyclone();
        self.map_markers();
    }

    /// 8F6A: draw the helicopter and cyclone markers on the map, saving what is under them.
    fn map_markers(&mut self) {
        for (cx, cy, attr_var, pix_var, save_attr, save_pix, code) in [
            (MAP_HX, MAP_HY, MAP_HATTR, MAP_HPIX, 0x9027u16, 0x901Fu16, 0x901Du16),
            (CYC_X, CYC_Y, MAP_CATTR, MAP_CPIX, 0x9030, 0x9028, 0x901E),
        ] {
            let col = self.r(cx);
            let row = self.r(cy);
            let a = 0x5800u16 + 32 * row as u16;
            let a = hl(hi(a), lo(a).wrapping_add(col));
            self.m.w16(attr_var, a);
            let v = self.r(a);
            self.w(save_attr, v);
            self.w(a, 0x7A);
            let p = pixel_addr(row as usize * 8, col as usize);
            self.m.w16(pix_var, p);
            for i in 0..8u16 {
                let v = self.r(p + (i << 8));
                self.w(save_pix + i, v);
            }
            self.print(code, p, 1);
        }
    }
}
