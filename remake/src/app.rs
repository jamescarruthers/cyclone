//! The windowed game: winit + wgpu front end for the game. On the desktop the game runs on
//! its own thread; in the browser it is a future polled once per animation frame.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use web_time::Instant;

use glam::Vec3;
use winit::application::ApplicationHandler;
use winit::event::{ElementState, WindowEvent};
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
use winit::keyboard::{KeyCode, PhysicalKey};
use winit::window::{Fullscreen, Window, WindowId};

use crate::audio::{Audio, AudioQueue};
use crate::game::{Game, VIEW};
use crate::render::{Camera, Renderer, SPRITE_H, SPRITE_W};
use crate::sys::{Frame, Kind, Shared, Sys};
use crate::world::{self, TileGeo};
use crate::zx::{screen_to_rgba, Mem};

/// Logical display: the 256x192 screen inside a border.
const BORDER_X: f32 = 32.0;
const BORDER_Y: f32 = 24.0;
const LOGICAL_W: f32 = 256.0 + 2.0 * BORDER_X;
const LOGICAL_H: f32 = 192.0 + 2.0 * BORDER_Y;

fn spectrum_key(k: KeyCode) -> Option<(usize, u8)> {
    use KeyCode::*;
    Some(match k {
        ShiftLeft | ShiftRight => (0, 0),
        KeyZ => (0, 1),
        KeyX => (0, 2),
        KeyC => (0, 3),
        KeyV => (0, 4),
        KeyA => (1, 0),
        KeyS => (1, 1),
        KeyD => (1, 2),
        KeyF => (1, 3),
        KeyG => (1, 4),
        KeyQ => (2, 0),
        KeyW => (2, 1),
        KeyE => (2, 2),
        KeyR => (2, 3),
        KeyT => (2, 4),
        Digit1 => (3, 0),
        Digit2 => (3, 1),
        Digit3 => (3, 2),
        Digit4 => (3, 3),
        Digit5 => (3, 4),
        Digit0 => (4, 0),
        Digit9 => (4, 1),
        Digit8 => (4, 2),
        Digit7 => (4, 3),
        Digit6 => (4, 4),
        KeyP => (5, 0),
        KeyO => (5, 1),
        KeyI => (5, 2),
        KeyU => (5, 3),
        KeyY => (5, 4),
        Enter => (6, 0),
        KeyL => (6, 1),
        KeyK => (6, 2),
        KeyJ => (6, 3),
        KeyH => (6, 4),
        Space => (7, 0),
        ControlLeft | AltLeft => (7, 1),
        KeyM => (7, 2),
        KeyN => (7, 3),
        KeyB => (7, 4),
        _ => return None,
    })
}

/// Arrow keys and right Ctrl act as a Kempston joystick (menu option 4).
fn kempston_bit(k: KeyCode) -> Option<u8> {
    use KeyCode::*;
    Some(match k {
        ArrowRight => 0,
        ArrowLeft => 1,
        ArrowDown => 2,
        ArrowUp => 3,
        ControlRight | AltRight => 4,
        _ => return None,
    })
}

struct Gfx {
    window: Arc<Window>,
    surface: wgpu::Surface<'static>,
    config: wgpu::SurfaceConfiguration,
    r: Renderer,
}

impl Gfx {
    async fn new(window: Arc<Window>) -> Gfx {
        // in the browser: WebGPU if the browser has it, otherwise WebGL 2
        #[cfg(target_arch = "wasm32")]
        let instance = wgpu::util::new_instance_with_webgpu_detection(&wgpu::InstanceDescriptor::default()).await;
        #[cfg(not(target_arch = "wasm32"))]
        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor::default());
        let surface = instance.create_surface(window.clone()).expect("surface");
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::HighPerformance,
                compatible_surface: Some(&surface),
                force_fallback_adapter: false,
            })
            .await
            .expect("adapter");
        log::info!("adapter: {:?}", adapter.get_info());
        let (device, queue) = adapter
            .request_device(&wgpu::DeviceDescriptor {
                required_limits: wgpu::Limits::downlevel_webgl2_defaults().using_resolution(adapter.limits()),
                ..Default::default()
            })
            .await
            .expect("device");
        let caps = surface.get_capabilities(&adapter);
        let format = caps.formats.iter().copied().find(|f| f.is_srgb()).unwrap_or(caps.formats[0]);
        // a WebGPU canvas has no sRGB formats: render through an sRGB view of it instead
        let view_format = format.add_srgb_suffix();
        let size = window.inner_size();
        let config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format,
            width: 1,
            height: 1,
            present_mode: wgpu::PresentMode::AutoVsync,
            alpha_mode: caps.alpha_modes[0],
            view_formats: if view_format != format { vec![view_format] } else { vec![] },
            desired_maximum_frame_latency: 2,
        };
        let r = Renderer::new(device, queue, view_format, &Mem::original().0);
        let mut g = Gfx { window, surface, config, r };
        g.resize(size.width, size.height);
        g.surface.configure(&g.r.device, &g.config);
        g
    }

    fn resize(&mut self, w: u32, h: u32) {
        let max = self.r.device.limits().max_texture_dimension_2d;
        let (w, h) = (w.clamp(1, max), h.clamp(1, max));
        if (w, h) == (self.config.width, self.config.height) {
            return;
        }
        self.config.width = w;
        self.config.height = h;
        self.surface.configure(&self.r.device, &self.config);
    }
}

/// Turns published game frames into what the renderer draws (shared by the window and the
/// offscreen demo capture).
pub struct Presenter {
    prev: Option<Arc<Frame>>,
    cur: Option<Arc<Frame>>,
    cur_arrival: Instant,
    pub yaw: f32,
    /// Where the camera is heading, in 45 degree steps from the original north view.
    pub turn: i32,
    /// The game's view (north / south) seen in the last frame.
    south: Option<bool>,
    pub ortho: bool,
    built_store: Vec<u8>,
    built_glyphs: [u8; 16],
    geo: Vec<TileGeo>,
    grid: Vec<u8>,
    screen_rgba: Vec<u8>,
}

pub struct Layout {
    pub screen: [f32; 4],
    pub view: [f32; 4],
}

pub fn layout(w: u32, h: u32) -> Layout {
    let s = (w as f32 / LOGICAL_W).min(h as f32 / LOGICAL_H);
    let ox = (w as f32 - LOGICAL_W * s) / 2.0 + BORDER_X * s;
    let oy = (h as f32 - LOGICAL_H * s) / 2.0 + BORDER_Y * s;
    Layout { screen: [ox, oy, 256.0 * s, 192.0 * s], view: [ox, oy, 184.0 * s, 176.0 * s] }
}

impl Presenter {
    pub fn new() -> Presenter {
        let mem = Mem::original();
        let isl = world::islands(&mem.0);
        Presenter {
            prev: None,
            cur: None,
            cur_arrival: Instant::now(),
            yaw: 0.0,
            turn: 0,
            south: None,
            ortho: false,
            built_store: Vec::new(),
            built_glyphs: [0; 16],
            geo: world::tile_geo(&mem.0),
            grid: world::world_grid(&mem.0, &isl),
            screen_rgba: vec![0; 256 * 192 * 4],
        }
    }

    pub fn push(&mut self, f: Arc<Frame>, now: Instant) {
        if self.cur.as_ref().map(|c| c.seq) != Some(f.seq) {
            self.prev = self.cur.take().or_else(|| Some(f.clone()));
            self.cur = Some(f);
            self.cur_arrival = now;
        }
    }

    /// Prepare textures and meshes; returns the 3D camera if the 3D view is shown.
    /// `alpha`: None = interpolate by wall-clock time since the frame arrived.
    pub fn prepare(&mut self, r: &mut Renderer, now: Instant, dt: f32, flash: bool, alpha: Option<f32>) -> Option<Camera> {
        let cur = self.cur.clone()?;
        let prev = self.prev.clone().unwrap_or(cur.clone());
        let span = (cur.t - prev.t).max(0.02) as f32;
        let a = alpha.unwrap_or_else(|| ((now - self.cur_arrival).as_secs_f32() / span).clamp(0.0, 1.0));

        // 2D screen; the 3D view shows through the 23x22 play area while flying
        let mut clear = [[false; 32]; 24];
        if cur.kind == Kind::View {
            for (r, row) in clear.iter_mut().enumerate().take(22) {
                for (c, cell) in row.iter_mut().enumerate().take(23) {
                    *cell = !cur.overlay[r][c];
                }
            }
        }
        screen_to_rgba(&cur.mem[0x4000..0x5B00], flash, &clear, &mut self.screen_rgba);
        r.set_screen(&self.screen_rgba);
        if cur.kind != Kind::View {
            return None;
        }
        // world geometry follows the tile store (crates and survivors come and go)
        let store = &cur.mem[0x9300..0xDE00];
        if self.built_store.as_slice() != store {
            r.rebuild_world(&cur.mem, None);
            let isl = world::islands(&cur.mem);
            self.grid = world::world_grid(&cur.mem, &isl);
            self.built_store = store.to_vec();
        }
        let glyphs: [u8; 16] = cur.mem[0xFB88..0xFB98].try_into().unwrap();
        if glyphs != self.built_glyphs {
            r.update_atlas_chars(&cur.mem, &[0x31, 0x32]);
            self.built_glyphs = glyphs;
        }
        // camera: the game's N key swings it round between the north and south views (always
        // the same way round) and [ / ] turn it in 45 degree steps; it eases towards the goal
        let south = cur.mem[VIEW as usize] != 0;
        if self.south != Some(south) {
            if self.south.is_some() || south {
                self.turn += 4;
            }
            self.south = Some(south);
        }
        let target = self.turn as f32 * std::f32::consts::FRAC_PI_4;
        let d = target - self.yaw;
        self.yaw += d * (dt * 7.0).min(1.0);
        if d.abs() < 0.002 {
            self.turn = self.turn.rem_euclid(8);
            self.yaw = self.turn as f32 * std::f32::consts::FRAC_PI_4;
        }
        let ip = crate::scene::interpolate(&prev, &cur, a);
        let scene = crate::scene::build(&cur, &ip, self.yaw, &self.geo, &self.grid);
        r.set_dynamic(&scene.mesh);
        crate::render::upload(&r.queue, &r.sprites, 0, 0, SPRITE_W, SPRITE_H, &scene.sprites.rgba);
        let (sy, cy) = self.yaw.sin_cos();
        let away = Vec3::new(-sy, 0.0, -cy);
        Some(Camera {
            target: Vec3::new(ip.heli.x, 0.0, ip.heli.y) + away * 3.5,
            yaw: self.yaw,
            pitch: 45f32.to_radians(),
            dist: 40.0,
            half_h: 11.0 / 2f32.sqrt(),
            stretch: 2f32.sqrt(),
            ortho: self.ortho,
        })
    }
}

/// Wireframe view on/off (F2, or the page's button through `toggle_wireframe`).
static WIREFRAME: AtomicBool = AtomicBool::new(false);

/// Browser: switch the 3D view between textured and wireframe. Returns the new state.
#[cfg(target_arch = "wasm32")]
#[wasm_bindgen::prelude::wasm_bindgen]
pub fn toggle_wireframe() -> bool {
    !WIREFRAME.fetch_xor(true, Ordering::Relaxed)
}

pub struct App {
    shared: Arc<Shared>,
    gfx: Option<Gfx>,
    tones: Arc<AudioQueue>,
    audio: Option<Audio>,
    p: Presenter,
    last: Instant,
    /// The game, polled every frame.
    #[cfg(target_arch = "wasm32")]
    game: std::pin::Pin<Box<dyn std::future::Future<Output = ()>>>,
    /// Filled when the asynchronous GPU setup completes.
    #[cfg(target_arch = "wasm32")]
    pending: std::rc::Rc<std::cell::RefCell<Option<Gfx>>>,
}

impl App {
    fn new() -> App {
        let shared = Shared::new();
        let tones = AudioQueue::new();
        let s = shared.clone();
        let q = tones.clone();
        #[cfg(not(target_arch = "wasm32"))]
        let audio = {
            let audio = crate::audio::start(shared.clone(), tones.clone());
            let q = audio.is_some().then_some(q);
            std::thread::Builder::new()
                .name("game".into())
                .spawn(move || pollster::block_on(Game::new(Mem::original(), Sys::new(s, q, true)).run()))
                .unwrap();
            audio
        };
        App {
            shared,
            gfx: None,
            tones,
            #[cfg(not(target_arch = "wasm32"))]
            audio,
            #[cfg(target_arch = "wasm32")]
            audio: None,
            p: Presenter::new(),
            last: Instant::now(),
            #[cfg(target_arch = "wasm32")]
            game: Box::pin(async move { Game::new(Mem::original(), Sys::new(s, Some(q), true)).run().await }),
            #[cfg(target_arch = "wasm32")]
            pending: Default::default(),
        }
    }

    /// Browsers only allow sound to start from a key press or click.
    fn user_gesture(&mut self) {
        if cfg!(target_arch = "wasm32") && self.audio.is_none() {
            self.audio = crate::audio::start(self.shared.clone(), self.tones.clone());
        }
    }

    /// Browser: run the game until it is level with the clock (it then waits in `Sys::sync`).
    #[cfg(target_arch = "wasm32")]
    fn step_game(&mut self) {
        // after a hidden tab stops the animation, carry on instead of racing to catch up
        self.shared.limit_lag(0.25);
        let mut cx = std::task::Context::from_waker(std::task::Waker::noop());
        let _ = self.game.as_mut().poll(&mut cx);
    }

    fn render(&mut self) {
        #[cfg(target_arch = "wasm32")]
        {
            if self.gfx.is_none() {
                self.gfx = self.pending.borrow_mut().take();
            }
            if self.gfx.is_some() {
                self.step_game();
            }
        }
        let Some(g) = self.gfx.as_mut() else { return };
        // a resize can arrive before the (asynchronous) GPU setup has finished
        let size = g.window.inner_size();
        g.resize(size.width, size.height);
        let now = Instant::now();
        let dt = (now - self.last).as_secs_f32().min(0.1);
        self.last = now;
        if let Some(f) = self.shared.frame.lock().unwrap().clone() {
            self.p.push(f, now);
        }
        let flash = (self.shared.epoch.elapsed().as_secs_f64() / 0.32) as u64 % 2 == 1;
        let cam = self.p.prepare(&mut g.r, now, dt, flash, None);
        // the wipe between textured and wireframe takes 0.9 s
        let to = if WIREFRAME.load(Ordering::Relaxed) { 1.0 } else { 0.0 };
        g.r.wire += (to - g.r.wire).clamp(-dt / 0.9, dt / 0.9);
        let (w, h) = (g.config.width, g.config.height);
        let l = layout(w, h);
        let frame = match g.surface.get_current_texture() {
            Ok(f) => f,
            Err(_) => {
                g.surface.configure(&g.r.device, &g.config);
                return;
            }
        };
        let view = frame.texture.create_view(&wgpu::TextureViewDescriptor { format: Some(g.r.format), ..Default::default() });
        g.r.draw(&view, w, h, cam.as_ref().map(|c| (c, l.view)), Some(l.screen), [0.0, 0.0, 0.0]);
        frame.present();
        // CYCLONE_SNAPSHOT=SECONDS:FILE.ppm saves one composed frame and quits (testing)
        #[cfg(not(target_arch = "wasm32"))]
        if let Ok(spec) = std::env::var("CYCLONE_SNAPSHOT") {
            if let Some((secs, path)) = spec.split_once(':') {
                if self.shared.epoch.elapsed().as_secs_f32() > secs.parse().unwrap_or(5.0) {
                    let px = g.r.capture(w, h, cam.as_ref().map(|c| (c, l.view)), Some(l.screen), [0.0, 0.0, 0.0]);
                    let mut out = format!("P6\n{w} {h}\n255\n").into_bytes();
                    for p in px.chunks(4) {
                        out.extend_from_slice(&p[..3]);
                    }
                    std::fs::write(path, out).ok();
                    std::process::exit(0);
                }
            }
        }
    }
}

impl ApplicationHandler for App {
    fn resumed(&mut self, el: &ActiveEventLoop) {
        if self.gfx.is_some() {
            return;
        }
        #[cfg(not(target_arch = "wasm32"))]
        {
            let attrs = Window::default_attributes()
                .with_title("Cyclone")
                .with_inner_size(winit::dpi::LogicalSize::new(LOGICAL_W as f64 * 3.0, LOGICAL_H as f64 * 3.0));
            let window = Arc::new(el.create_window(attrs).expect("window"));
            self.gfx = Some(pollster::block_on(Gfx::new(window)));
        }
        #[cfg(target_arch = "wasm32")]
        {
            if self.pending.borrow().is_some() {
                return;
            }
            // the page's <canvas id="cyclone">, sized by CSS
            use wasm_bindgen::JsCast;
            use winit::platform::web::WindowAttributesExtWebSys;
            let canvas = web_sys::window()
                .and_then(|w| w.document())
                .and_then(|d| d.get_element_by_id("cyclone"))
                .and_then(|e| e.dyn_into::<web_sys::HtmlCanvasElement>().ok());
            let attrs = Window::default_attributes().with_title("Cyclone").with_canvas(canvas).with_prevent_default(true);
            let window = Arc::new(el.create_window(attrs).expect("window"));
            window.focus_window();
            let pending = self.pending.clone();
            wasm_bindgen_futures::spawn_local(async move {
                let g = Gfx::new(window).await;
                g.window.request_redraw();
                *pending.borrow_mut() = Some(g);
            });
        }
    }

    fn window_event(&mut self, el: &ActiveEventLoop, _id: WindowId, event: WindowEvent) {
        match event {
            WindowEvent::CloseRequested => {
                self.shared.quit.store(true, Ordering::Relaxed);
                el.exit();
            }
            WindowEvent::Resized(size) => {
                if let Some(g) = self.gfx.as_mut() {
                    g.resize(size.width, size.height);
                }
            }
            WindowEvent::MouseInput { state: ElementState::Pressed, .. } => self.user_gesture(),
            WindowEvent::KeyboardInput { event, .. } => {
                let PhysicalKey::Code(code) = event.physical_key else { return };
                let down = event.state == ElementState::Pressed;
                if down {
                    self.user_gesture();
                }
                if down && !event.repeat {
                    match code {
                        KeyCode::F1 => self.p.ortho = !self.p.ortho,
                        KeyCode::BracketLeft => self.p.turn -= 1,
                        KeyCode::BracketRight => self.p.turn += 1,
                        KeyCode::F2 => {
                            WIREFRAME.fetch_xor(true, Ordering::Relaxed);
                        }
                        KeyCode::F11 => {
                            if let Some(g) = &self.gfx {
                                let fs = g.window.fullscreen().is_some();
                                g.window.set_fullscreen(if fs { None } else { Some(Fullscreen::Borderless(None)) });
                            }
                        }
                        KeyCode::Escape => {
                            if let Some(g) = &self.gfx {
                                if g.window.fullscreen().is_some() {
                                    g.window.set_fullscreen(None);
                                }
                            }
                        }
                        _ => {}
                    }
                }
                let mut k = self.shared.keys.lock().unwrap();
                if let Some((row, bit)) = spectrum_key(code) {
                    if down {
                        k.rows[row] |= 1 << bit;
                    } else {
                        k.rows[row] &= !(1 << bit);
                    }
                }
                if let Some(bit) = kempston_bit(code) {
                    if down {
                        k.kempston |= 1 << bit;
                    } else {
                        k.kempston &= !(1 << bit);
                    }
                }
            }
            WindowEvent::Focused(false) => {
                *self.shared.keys.lock().unwrap() = Default::default();
            }
            WindowEvent::RedrawRequested => {
                self.render();
                // browser: draw on every animation frame
                #[cfg(target_arch = "wasm32")]
                if let Some(g) = &self.gfx {
                    g.window.request_redraw();
                }
            }
            _ => {}
        }
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn about_to_wait(&mut self, _el: &ActiveEventLoop) {
        if let Some(g) = &self.gfx {
            g.window.request_redraw();
        }
    }
}

#[cfg(not(target_arch = "wasm32"))]
pub fn run() {
    let el = EventLoop::new().expect("event loop");
    el.set_control_flow(ControlFlow::Poll);
    let mut app = App::new();
    el.run_app(&mut app).expect("run");
    std::process::exit(0);
}

/// Browser entry: the event loop runs from the page's animation frames.
#[cfg(target_arch = "wasm32")]
pub fn run() {
    use winit::platform::web::EventLoopExtWebSys;
    let el = EventLoop::new().expect("event loop");
    el.set_control_flow(ControlFlow::Wait);
    el.spawn_app(App::new());
}
