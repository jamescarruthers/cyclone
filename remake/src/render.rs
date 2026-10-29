//! wgpu renderer: the 3D world (islands, sea, sprites) and the 2D Spectrum screen on top.

use glam::{Mat4, Vec3};
use wgpu::util::DeviceExt;

use crate::world::{self, Mesh, Vertex};

pub const SAMPLES: u32 = 4;

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
struct CamU {
    viewproj: [[f32; 4]; 4],
    right: [f32; 4],
    params: [f32; 4],
    view: [f32; 4],
}

/// Camera looking at `target` from `yaw` (0 = from the south, the original north view) and
/// `pitch` above the horizon. `half_h` is the half height of the visible area at the target
/// (world units, before `stretch`); `stretch` > 1 stretches the image vertically, which is
/// what makes the original's oblique projection (cube faces and tops both 8 px tall).
#[derive(Clone, Copy, Debug)]
pub struct Camera {
    pub target: Vec3,
    pub yaw: f32,
    pub pitch: f32,
    pub dist: f32,
    pub half_h: f32,
    pub stretch: f32,
    pub ortho: bool,
}

impl Camera {
    pub fn right(&self) -> Vec3 {
        Vec3::new(self.yaw.cos(), 0.0, -self.yaw.sin())
    }
    pub fn eye(&self) -> Vec3 {
        let (sp, cp) = self.pitch.sin_cos();
        self.target + self.dist * Vec3::new(self.yaw.sin() * cp, sp, self.yaw.cos() * cp)
    }
    pub fn south(&self) -> bool {
        let y = self.yaw.rem_euclid(std::f32::consts::TAU);
        y > std::f32::consts::FRAC_PI_2 && y < 3.0 * std::f32::consts::FRAC_PI_2
    }
    pub fn viewproj(&self, pixel_aspect: f32) -> Mat4 {
        let view = Mat4::look_at_rh(self.eye(), self.target, Vec3::Y);
        let aspect = pixel_aspect * self.stretch;
        let proj = if self.ortho {
            let hh = self.half_h;
            let hw = hh * aspect;
            Mat4::orthographic_rh(-hw, hw, -hh, hh, 1.0, self.dist * 4.0 + 400.0)
        } else {
            let fovy = 2.0 * (self.half_h / self.dist).atan();
            Mat4::perspective_rh(fovy, aspect, 0.5, self.dist * 4.0 + 600.0)
        };
        proj * view
    }
}

pub struct GpuMesh {
    vb: wgpu::Buffer,
    ib: wgpu::Buffer,
    n: u32,
}

impl GpuMesh {
    pub fn new(device: &wgpu::Device, m: &Mesh) -> Option<GpuMesh> {
        if m.idx.is_empty() {
            return None;
        }
        let vb = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("vb"),
            contents: bytemuck::cast_slice(&m.verts),
            usage: wgpu::BufferUsages::VERTEX,
        });
        let ib = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("ib"),
            contents: bytemuck::cast_slice(&m.idx),
            usage: wgpu::BufferUsages::INDEX,
        });
        Some(GpuMesh { vb, ib, n: m.idx.len() as u32 })
    }
}

pub struct Targets {
    pub size: (u32, u32),
    msaa: wgpu::TextureView,
    depth: wgpu::TextureView,
}

pub struct Renderer {
    pub device: wgpu::Device,
    pub queue: wgpu::Queue,
    pub format: wgpu::TextureFormat,
    world_pipe: wgpu::RenderPipeline,
    screen_pipe: wgpu::RenderPipeline,
    world_bg: wgpu::BindGroup,
    screen_bg: wgpu::BindGroup,
    cam_buf: wgpu::Buffer,
    atlas: wgpu::Texture,
    pub sprites: wgpu::Texture,
    screen: wgpu::Texture,
    pub islands: Vec<Option<GpuMesh>>,
    sea: GpuMesh,
    dynamic: Option<GpuMesh>,
    targets: Option<Targets>,
    /// Wireframe wipe: 0 = textured, 1 = wireframe, in between = part way across the view.
    pub wire: f32,
}

pub const SPRITE_W: u32 = 256;
pub const SPRITE_H: u32 = 96;

fn tex(device: &wgpu::Device, w: u32, h: u32, label: &str) -> wgpu::Texture {
    device.create_texture(&wgpu::TextureDescriptor {
        label: Some(label),
        size: wgpu::Extent3d { width: w, height: h, depth_or_array_layers: 1 },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::Rgba8UnormSrgb,
        usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
        view_formats: &[],
    })
}

pub fn upload(queue: &wgpu::Queue, t: &wgpu::Texture, x: u32, y: u32, w: u32, h: u32, rgba: &[u8]) {
    queue.write_texture(
        wgpu::TexelCopyTextureInfo {
            texture: t,
            mip_level: 0,
            origin: wgpu::Origin3d { x, y, z: 0 },
            aspect: wgpu::TextureAspect::All,
        },
        rgba,
        wgpu::TexelCopyBufferLayout { offset: 0, bytes_per_row: Some(w * 4), rows_per_image: Some(h) },
        wgpu::Extent3d { width: w, height: h, depth_or_array_layers: 1 },
    );
}

impl Renderer {
    pub fn new(device: wgpu::Device, queue: wgpu::Queue, format: wgpu::TextureFormat, mem: &[u8; 65536]) -> Renderer {
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("shader.wgsl").into()),
        });
        let atlas = tex(&device, 128, 128, "atlas");
        let sprites = tex(&device, SPRITE_W, SPRITE_H, "sprites");
        let screen = tex(&device, 256, 192, "screen");
        upload(&queue, &atlas, 0, 0, 128, 128, &world::char_atlas(mem));
        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            mag_filter: wgpu::FilterMode::Nearest,
            min_filter: wgpu::FilterMode::Nearest,
            ..Default::default()
        });
        let cam_buf = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("camera"),
            size: std::mem::size_of::<CamU>() as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        let tex_entry = |binding| wgpu::BindGroupLayoutEntry {
            binding,
            visibility: wgpu::ShaderStages::FRAGMENT,
            ty: wgpu::BindingType::Texture {
                sample_type: wgpu::TextureSampleType::Float { filterable: true },
                view_dimension: wgpu::TextureViewDimension::D2,
                multisampled: false,
            },
            count: None,
        };
        let samp_entry = |binding| wgpu::BindGroupLayoutEntry {
            binding,
            visibility: wgpu::ShaderStages::FRAGMENT,
            ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
            count: None,
        };
        let world_bgl = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("world bgl"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
                tex_entry(1),
                tex_entry(2),
                samp_entry(3),
            ],
        });
        let screen_bgl = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("screen bgl"),
            entries: &[tex_entry(0), samp_entry(1)],
        });
        let av = atlas.create_view(&Default::default());
        let sv = sprites.create_view(&Default::default());
        let scv = screen.create_view(&Default::default());
        let world_bg = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("world bg"),
            layout: &world_bgl,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: cam_buf.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::TextureView(&av) },
                wgpu::BindGroupEntry { binding: 2, resource: wgpu::BindingResource::TextureView(&sv) },
                wgpu::BindGroupEntry { binding: 3, resource: wgpu::BindingResource::Sampler(&sampler) },
            ],
        });
        let screen_bg = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("screen bg"),
            layout: &screen_bgl,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::TextureView(&scv) },
                wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::Sampler(&sampler) },
            ],
        });
        let depth_state = Some(wgpu::DepthStencilState {
            format: wgpu::TextureFormat::Depth32Float,
            depth_write_enabled: true,
            depth_compare: wgpu::CompareFunction::LessEqual,
            stencil: Default::default(),
            bias: Default::default(),
        });
        let ms = wgpu::MultisampleState { count: SAMPLES, mask: !0, alpha_to_coverage_enabled: false };
        let world_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: None,
            bind_group_layouts: &[&world_bgl],
            push_constant_ranges: &[],
        });
        let world_pipe = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("world"),
            layout: Some(&world_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vs"),
                compilation_options: Default::default(),
                buffers: &[wgpu::VertexBufferLayout {
                    array_stride: std::mem::size_of::<Vertex>() as u64,
                    step_mode: wgpu::VertexStepMode::Vertex,
                    attributes: &wgpu::vertex_attr_array![0 => Float32x3, 1 => Float32x2, 2 => Uint32x2, 3 => Uint32, 4 => Float32],
                }],
            },
            // Every quad is wound clockwise as seen from its visible side. Culling the back
            // faces matters where a char's cyan pixels are cut out: through the hole you see
            // the sea, as in the original, and not the inside of the cube's other faces.
            primitive: wgpu::PrimitiveState {
                front_face: wgpu::FrontFace::Cw,
                cull_mode: Some(wgpu::Face::Back),
                ..Default::default()
            },
            depth_stencil: depth_state.clone(),
            multisample: ms,
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fs"),
                compilation_options: Default::default(),
                targets: &[Some(wgpu::ColorTargetState { format, blend: None, write_mask: wgpu::ColorWrites::ALL })],
            }),
            multiview: None,
            cache: None,
        });
        let screen_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: None,
            bind_group_layouts: &[&screen_bgl],
            push_constant_ranges: &[],
        });
        let screen_pipe = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("screen"),
            layout: Some(&screen_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vs2"),
                compilation_options: Default::default(),
                buffers: &[],
            },
            primitive: Default::default(),
            depth_stencil: Some(wgpu::DepthStencilState {
                format: wgpu::TextureFormat::Depth32Float,
                depth_write_enabled: false,
                depth_compare: wgpu::CompareFunction::Always,
                stencil: Default::default(),
                bias: Default::default(),
            }),
            multisample: ms,
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fs2"),
                compilation_options: Default::default(),
                targets: &[Some(wgpu::ColorTargetState { format, blend: None, write_mask: wgpu::ColorWrites::ALL })],
            }),
            multiview: None,
            cache: None,
        });
        // the sea: one big plane just below level 0, solid bright cyan
        let mut sea = Mesh::default();
        let (a, b, y) = (-2000.0f32, 2768.0f32, -0.02f32);
        sea.quad(
            [[a, y, a], [b, y, a], [b, y, b], [a, y, b]],
            [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]],
            [0x80, 0x80],
            world::F_OPAQUE,
            [0.0; 4],
        );
        let sea = GpuMesh::new(&device, &sea).unwrap();
        let mut r = Renderer {
            device,
            queue,
            format,
            world_pipe,
            screen_pipe,
            world_bg,
            screen_bg,
            cam_buf,
            atlas,
            sprites,
            screen,
            islands: Vec::new(),
            sea,
            dynamic: None,
            targets: None,
            wire: 0.0,
        };
        r.rebuild_world(mem, None);
        r
    }

    /// (Re)build island meshes from the tile store. `only` limits the rebuild to some islands.
    pub fn rebuild_world(&mut self, mem: &[u8; 65536], only: Option<&[usize]>) {
        let isl = world::islands(mem);
        let geo = world::tile_geo(mem);
        let grid = world::world_grid(mem, &isl);
        if self.islands.len() != isl.len() {
            self.islands = (0..isl.len()).map(|_| None).collect();
        }
        for (i, island) in isl.iter().enumerate() {
            if let Some(o) = only {
                if !o.contains(&i) {
                    continue;
                }
            }
            let mesh = world::island_mesh(mem, &geo, &grid, island);
            self.islands[i] = GpuMesh::new(&self.device, &mesh);
        }
    }

    /// Update char glyphs that the game animates (survivors) from game memory.
    pub fn update_atlas_chars(&mut self, mem: &[u8; 65536], codes: &[u8]) {
        let full = world::char_atlas(mem);
        for &c in codes {
            let (cx, cy) = ((c as u32 % 16) * 8, (c as u32 / 16) * 8);
            let mut px = vec![0u8; 8 * 8 * 4];
            for row in 0..8u32 {
                let o = (((cy + row) * 128 + cx) * 4) as usize;
                px[(row * 32) as usize..(row * 32 + 32) as usize].copy_from_slice(&full[o..o + 32]);
            }
            upload(&self.queue, &self.atlas, cx, cy, 8, 8, &px);
        }
    }

    pub fn set_dynamic(&mut self, m: &Mesh) {
        self.dynamic = GpuMesh::new(&self.device, m);
    }

    pub fn set_screen(&mut self, rgba: &[u8]) {
        upload(&self.queue, &self.screen, 0, 0, 256, 192, rgba);
    }

    fn ensure_targets(&mut self, w: u32, h: u32) {
        if self.targets.as_ref().map(|t| t.size) == Some((w, h)) {
            return;
        }
        let mk = |format, label| {
            self.device
                .create_texture(&wgpu::TextureDescriptor {
                    label: Some(label),
                    size: wgpu::Extent3d { width: w, height: h, depth_or_array_layers: 1 },
                    mip_level_count: 1,
                    sample_count: SAMPLES,
                    dimension: wgpu::TextureDimension::D2,
                    format,
                    usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
                    view_formats: &[],
                })
                .create_view(&Default::default())
        };
        self.targets = Some(Targets {
            size: (w, h),
            msaa: mk(self.format, "msaa"),
            depth: mk(wgpu::TextureFormat::Depth32Float, "depth"),
        });
    }

    /// Draw a frame into `target` (size w x h): the 3D view inside `view_rect` (x, y, w, h in
    /// pixels) if a camera is given, then the 2D screen inside `screen_rect`.
    pub fn draw(
        &mut self,
        target: &wgpu::TextureView,
        w: u32,
        h: u32,
        cam: Option<(&Camera, [f32; 4])>,
        screen_rect: Option<[f32; 4]>,
        clear: [f64; 3],
    ) {
        self.ensure_targets(w, h);
        if let Some((c, r)) = cam {
            let u = CamU {
                viewproj: c.viewproj(r[2] / r[3]).to_cols_array_2d(),
                right: c.right().extend(0.0).to_array(),
                params: [if c.south() { 1.0 } else { 0.0 }, self.wire, 0.0, 0.0],
                view: r,
            };
            self.queue.write_buffer(&self.cam_buf, 0, bytemuck::bytes_of(&u));
        }
        let t = self.targets.as_ref().unwrap();
        let mut enc = self.device.create_command_encoder(&Default::default());
        {
            let mut pass = enc.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("frame"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &t.msaa,
                    depth_slice: None,
                    resolve_target: Some(target),
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color { r: clear[0], g: clear[1], b: clear[2], a: 1.0 }),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                    view: &t.depth,
                    depth_ops: Some(wgpu::Operations { load: wgpu::LoadOp::Clear(1.0), store: wgpu::StoreOp::Store }),
                    stencil_ops: None,
                }),
                timestamp_writes: None,
                occlusion_query_set: None,
            });
            if let Some((_, r)) = cam {
                pass.set_viewport(r[0], r[1], r[2], r[3], 0.0, 1.0);
                pass.set_scissor_rect(r[0] as u32, r[1] as u32, (r[2] as u32).max(1), (r[3] as u32).max(1));
                pass.set_pipeline(&self.world_pipe);
                pass.set_bind_group(0, &self.world_bg, &[]);
                let meshes = std::iter::once(Some(&self.sea))
                    .chain(self.islands.iter().map(|m| m.as_ref()))
                    .chain(std::iter::once(self.dynamic.as_ref()));
                for m in meshes.flatten() {
                    pass.set_vertex_buffer(0, m.vb.slice(..));
                    pass.set_index_buffer(m.ib.slice(..), wgpu::IndexFormat::Uint32);
                    pass.draw_indexed(0..m.n, 0, 0..1);
                }
            }
            if let Some(r) = screen_rect {
                pass.set_viewport(r[0], r[1], r[2], r[3], 0.0, 1.0);
                pass.set_scissor_rect(0, 0, w, h);
                pass.set_pipeline(&self.screen_pipe);
                pass.set_bind_group(0, &self.screen_bg, &[]);
                pass.draw(0..3, 0..1);
            }
        }
        self.queue.submit(Some(enc.finish()));
    }

    /// Render offscreen and read back RGBA pixels.
    #[cfg(not(target_arch = "wasm32"))]
    pub fn capture(
        &mut self,
        w: u32,
        h: u32,
        cam: Option<(&Camera, [f32; 4])>,
        screen_rect: Option<[f32; 4]>,
        clear: [f64; 3],
    ) -> Vec<u8> {
        let target = self.device.create_texture(&wgpu::TextureDescriptor {
            label: Some("capture"),
            size: wgpu::Extent3d { width: w, height: h, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: self.format,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::COPY_SRC,
            view_formats: &[],
        });
        let view = target.create_view(&Default::default());
        self.draw(&view, w, h, cam, screen_rect, clear);
        let bpr = (w * 4).div_ceil(256) * 256;
        let buf = self.device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("readback"),
            size: (bpr * h) as u64,
            usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
            mapped_at_creation: false,
        });
        let mut enc = self.device.create_command_encoder(&Default::default());
        enc.copy_texture_to_buffer(
            wgpu::TexelCopyTextureInfo {
                texture: &target,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            wgpu::TexelCopyBufferInfo {
                buffer: &buf,
                layout: wgpu::TexelCopyBufferLayout { offset: 0, bytes_per_row: Some(bpr), rows_per_image: Some(h) },
            },
            wgpu::Extent3d { width: w, height: h, depth_or_array_layers: 1 },
        );
        self.queue.submit(Some(enc.finish()));
        let slice = buf.slice(..);
        slice.map_async(wgpu::MapMode::Read, |_| {});
        let _ = self.device.poll(wgpu::PollType::Wait);
        let data = slice.get_mapped_range();
        let mut out = vec![0u8; (w * h * 4) as usize];
        for y in 0..h as usize {
            let src = &data[y * bpr as usize..y * bpr as usize + w as usize * 4];
            out[y * w as usize * 4..(y + 1) * w as usize * 4].copy_from_slice(src);
        }
        if matches!(self.format, wgpu::TextureFormat::Bgra8UnormSrgb | wgpu::TextureFormat::Bgra8Unorm) {
            for p in out.chunks_mut(4) {
                p.swap(0, 2);
            }
        }
        out
    }
}

/// Create a device without a window (screenshots).
#[cfg(not(target_arch = "wasm32"))]
pub fn headless() -> Renderer {
    let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor::default());
    let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
        power_preference: wgpu::PowerPreference::HighPerformance,
        compatible_surface: None,
        force_fallback_adapter: false,
    }))
    .expect("no GPU adapter");
    let (device, queue) = pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor::default())).expect("device");
    Renderer::new(device, queue, wgpu::TextureFormat::Rgba8UnormSrgb, crate::zx::MEM_BIN)
}
