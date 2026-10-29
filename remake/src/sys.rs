//! The environment the ported game code runs in: a virtual clock (with the 50 Hz interrupt),
//! the keyboard/joystick ports, the beeper and publication of frames to the renderer.
//!
//! The game is straight-line code, exactly like the original: a beep or a delay blocks it.
//! The routines that pass time are `async`, and `Sys::sync` is the one point where the game
//! waits for the wall clock. On the desktop the game runs on its own thread and `sync` sleeps;
//! in the browser the game is a future polled once per animation frame and `sync` returns
//! `Pending` while virtual time is ahead of the clock. In headless mode (verification traces)
//! time is purely virtual and `sync` never waits.

use std::future::Future;
use std::pin::Pin;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll};
#[cfg(not(target_arch = "wasm32"))]
use std::time::Duration;
use web_time::Instant;

use crate::audio::{AudioQueue, Tone};

pub const CPU_HZ: f64 = 3_500_000.0;
pub const FRAME: f64 = 69888.0 / CPU_HZ;

/// Host input mapped onto the Spectrum keyboard matrix and a Kempston joystick.
#[derive(Clone, Copy, Default, Debug)]
pub struct Keys {
    /// Half-rows 0..7 (port address bits A8..A15 low), bit n set = key n pressed.
    pub rows: [u8; 8],
    /// Kempston port $1F, active high: b0 right, b1 left, b2 down, b3 up, b4 fire.
    pub kempston: u8,
}

/// What the renderer should show for a frame.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Kind {
    /// Menu / information screen: the 2D screen only.
    Screen,
    /// In flight: the 3D view in the 23x22 window plus the 2D HUD.
    View,
    /// Map screen: 2D only (HUD keeps running).
    Map,
}

/// Rope / winch load drawn under the helicopter this iteration: `lines` pixel rows of the
/// 1-byte-wide graphic starting at `gfx`.
#[derive(Clone, Copy, Debug)]
pub struct Rope {
    pub gfx: u16,
    pub lines: u8,
}

pub struct Frame {
    pub mem: Box<[u8; 65536]>,
    pub t: f64,
    pub kind: Kind,
    /// Cells of the 3D window area overwritten by 2D text (e.g. " NO FUEL ").
    pub overlay: [[bool; 32]; 24],
    pub rope: Option<Rope>,
    /// Death sequence step (24..1), 0 when not dying.
    pub death: u8,
    pub seq: u64,
}

pub struct Shared {
    pub frame: Mutex<Option<Arc<Frame>>>,
    pub keys: Mutex<Keys>,
    pub quit: AtomicBool,
    pub epoch: Instant,
    /// Seconds the game clock lags the wall clock since `epoch` (f64 bits). It grows when the
    /// browser stops animating a hidden tab, so the game resumes instead of catching up.
    lag: AtomicU64,
    /// Virtual time reached by the game at its last `sync` (f64 bits).
    game_t: AtomicU64,
}

impl Shared {
    pub fn new() -> Arc<Shared> {
        Arc::new(Shared {
            frame: Mutex::new(None),
            keys: Mutex::new(Keys::default()),
            quit: AtomicBool::new(false),
            epoch: Instant::now(),
            lag: AtomicU64::new(0),
            game_t: AtomicU64::new(0),
        })
    }

    /// The game clock: what virtual time should have reached by now.
    pub fn now(&self) -> f64 {
        self.epoch.elapsed().as_secs_f64() - f64::from_bits(self.lag.load(Ordering::Relaxed))
    }

    #[cfg_attr(not(target_arch = "wasm32"), allow(dead_code))]
    pub fn game_t(&self) -> f64 {
        f64::from_bits(self.game_t.load(Ordering::Relaxed))
    }

    /// If the game has fallen more than `max` seconds behind the clock, hold the clock back
    /// instead of letting the game run flat out to catch up.
    #[cfg_attr(not(target_arch = "wasm32"), allow(dead_code))]
    pub fn limit_lag(&self, max: f64) {
        let behind = self.now() - self.game_t();
        if behind > max {
            let lag = f64::from_bits(self.lag.load(Ordering::Relaxed)) + behind - max;
            self.lag.store(lag.to_bits(), Ordering::Relaxed);
        }
    }
}

/// Resolves once the game clock reaches `t` (browser pacing; the driver polls every frame).
#[cfg_attr(not(target_arch = "wasm32"), allow(dead_code))]
struct Pace<'a> {
    t: f64,
    shared: &'a Shared,
}

impl Future for Pace<'_> {
    type Output = ();
    fn poll(self: Pin<&mut Self>, _cx: &mut Context) -> Poll<()> {
        if self.shared.now() >= self.t {
            Poll::Ready(())
        } else {
            Poll::Pending
        }
    }
}

pub struct Sys {
    /// Virtual time in seconds.
    pub t: f64,
    pub next_int: f64,
    realtime: bool,
    pub shared: Arc<Shared>,
    pub audio: Option<Arc<AudioQueue>>,
    seq: u64,
    /// Keys used in headless mode (set per iteration by the trace driver).
    pub scripted: Keys,
    /// Publish frames even in headless mode (offscreen demo capture).
    pub publish_headless: bool,
    /// Headless: every published frame is handed to this callback (video capture).
    pub on_frame: Option<Box<dyn FnMut(Arc<Frame>) + Send>>,
    /// Headless: beeper tones are recorded here (video soundtrack).
    pub record: Option<Vec<Tone>>,
}

impl Sys {
    pub fn new(shared: Arc<Shared>, audio: Option<Arc<AudioQueue>>, realtime: bool) -> Sys {
        Sys { t: 0.0, next_int: FRAME, realtime, shared, audio, seq: 0, scripted: Keys::default(), publish_headless: false, on_frame: None, record: None }
    }

    pub fn keys(&self) -> Keys {
        if self.realtime {
            *self.shared.keys.lock().unwrap()
        } else {
            self.scripted
        }
    }

    /// `IN A,(hi*256 + $FE)`: bits 0-4 active low for the half-rows selected by zero bits of
    /// `hi`; bits 5-7 read as 1 (as `OR $E0` in the original makes irrelevant anyway).
    pub fn in_fe(&self, hi: u8) -> u8 {
        let k = self.keys();
        let mut v = 0u8;
        for row in 0..8 {
            if hi & (1 << row) == 0 {
                v |= k.rows[row];
            }
        }
        !v & 0x1F | 0xE0
    }

    pub fn in_kempston(&self) -> u8 {
        self.keys().kempston & 0x1F
    }

    #[cfg(not(target_arch = "wasm32"))]
    pub fn quit_requested(&self) -> bool {
        self.shared.quit.load(Ordering::Relaxed)
    }

    /// Wait until the game clock catches up with virtual time.
    pub async fn sync(&self) {
        if !self.realtime {
            return;
        }
        self.shared.game_t.store(self.t.to_bits(), Ordering::Relaxed);
        #[cfg(not(target_arch = "wasm32"))]
        {
            let ahead = self.t - self.shared.now();
            if ahead > 0.0 {
                std::thread::sleep(Duration::from_secs_f64(ahead));
            }
            if self.quit_requested() {
                // The window has closed: stop the game thread quietly.
                loop {
                    std::thread::park();
                }
            }
        }
        #[cfg(target_arch = "wasm32")]
        Pace { t: self.t, shared: &self.shared }.await;
    }

    pub fn tone(&mut self, tone: Tone) {
        if let Some(r) = &mut self.record {
            r.push(tone);
        }
        if let Some(a) = &self.audio {
            a.push(tone);
        }
    }

    pub fn publish(&mut self, mem: &[u8; 65536], kind: Kind, overlay: &[[bool; 32]; 24], rope: Option<Rope>, death: u8) {
        if !self.realtime && !self.publish_headless {
            return;
        }
        self.seq += 1;
        let f = Frame {
            mem: Box::new(*mem),
            t: self.t,
            kind,
            overlay: *overlay,
            rope,
            death,
            seq: self.seq,
        };
        if let Some(cb) = &mut self.on_frame {
            cb(Arc::new(f));
        } else {
            *self.shared.frame.lock().unwrap() = Some(Arc::new(f));
        }
    }
}
