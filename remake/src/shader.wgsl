// World pass: faces textured with the original 8x8 chars (atlas), upright cards that turn to
// face the camera (trees, crates, survivors, helicopter, aircraft) and decals (shadows).
// Wireframe mode draws the cube edges, the outlines of cut-out chars and sprites and a grid on
// the sea; a diagonal wipe moves between the two looks.

struct Camera {
    viewproj: mat4x4<f32>,
    right: vec4<f32>,
    // x: 1 = south view (use the south-view chars, rotate top faces 180 degrees)
    // y: wireframe wipe, 0 = textured .. 1 = wireframe
    params: vec4<f32>,
    // the 3D viewport in framebuffer pixels (x, y, w, h)
    view: vec4<f32>,
};

@group(0) @binding(0) var<uniform> cam: Camera;
@group(0) @binding(1) var atlas: texture_2d<f32>;
@group(0) @binding(2) var sprites: texture_2d<f32>;
@group(0) @binding(3) var samp: sampler;

struct VIn {
    @location(0) pos: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) ch: vec2<u32>,
    @location(3) flags: u32,
    @location(4) side: f32,
};

struct VOut {
    @builtin(position) clip: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) @interpolate(flat) ch: u32,
    @location(2) @interpolate(flat) flags: u32,
    // position on the face (0..1 across each quad) and in the world, for the wireframe
    @location(3) quv: vec2<f32>,
    @location(4) wpos: vec3<f32>,
};

const F_TOP: u32 = 1u;
const F_CARD: u32 = 2u;
const F_SHADE: u32 = 4u;
const F_SPRITE: u32 = 8u;
const F_OPAQUE: u32 = 16u;

@vertex
fn vs(v: VIn) -> VOut {
    var p = v.pos;
    if ((v.flags & F_CARD) != 0u) {
        p = p + cam.right.xyz * v.side;
    }
    var o: VOut;
    o.clip = cam.viewproj * vec4<f32>(p, 1.0);
    let south = cam.params.x > 0.5;
    var uv = v.uv;
    if (south && (v.flags & F_TOP) != 0u) {
        uv = vec2<f32>(1.0, 1.0) - uv;
    }
    o.uv = uv;
    o.ch = select(v.ch.x, v.ch.y, south);
    o.flags = v.flags;
    o.quv = v.uv;
    o.wpos = p;
    return o;
}

// Texel `t` of the char/sprite being drawn is solid. Outside an atlas cell, faces count as
// solid (the quad edge is drawn instead) and cards as empty.
fn solid(i: VOut, t: vec2<i32>) -> bool {
    if ((i.flags & F_SPRITE) != 0u) {
        return textureLoad(sprites, t, 0).a >= 0.5;
    }
    if (any(t < vec2<i32>(0)) || any(t > vec2<i32>(7))) {
        return (i.flags & F_CARD) == 0u;
    }
    let cell = vec2<i32>(i32(i.ch % 16u), i32(i.ch / 16u)) * 8;
    return textureLoad(atlas, cell + t, 0).a >= 0.5;
}

// The colour a face's edges are drawn in: the brightest colour of its char.
fn edge_colour(ch: u32) -> vec3<f32> {
    let cell = vec2<i32>(i32(ch % 16u), i32(ch / 16u)) * 8;
    var best = vec3<f32>(0.0);
    for (var y = 0; y < 8; y += 2) {
        for (var x = 0; x < 8; x += 2) {
            let c = textureLoad(atlas, cell + vec2<i32>(x, y) + vec2<i32>(y / 2 % 2, 0), 0);
            if (c.a >= 0.5 && dot(c.rgb, vec3<f32>(1.0)) > dot(best, vec3<f32>(1.0))) {
                best = c.rgb;
            }
        }
    }
    return best;
}

fn bright(c: vec3<f32>) -> vec3<f32> {
    // black ink would vanish on the black background
    return select(c, vec3<f32>(0.8), max(c.r, max(c.g, c.b)) < 0.2);
}

const LINE: f32 = 1.1; // half width of a line in pixels

@fragment
fn fs(i: VOut) -> @location(0) vec4<f32> {
    let sprite = (i.flags & F_SPRITE) != 0u;
    let cell = vec2<f32>(f32(i.ch % 16u), f32(i.ch / 16u));
    let local = clamp(i.uv, vec2<f32>(0.0005), vec2<f32>(0.9995));
    // texel coordinates (in the sprite sheet, or within the 8x8 char)
    let tc = select(local * 8.0, i.uv * vec2<f32>(textureDimensions(sprites)), sprite);
    // derivatives must be taken before any branching
    let px_tc = fwidth(tc);
    let px_q = fwidth(i.quv);
    let px_w = fwidth(i.wpos.xz);
    var c: vec4<f32>;
    if (sprite) {
        c = textureSampleLevel(sprites, samp, i.uv, 0.0);
    } else {
        c = textureSampleLevel(atlas, samp, (cell + local) / 16.0, 0.0);
    }
    if ((i.flags & F_OPAQUE) == 0u && c.a < 0.5) {
        discard;
    }
    var rgb = c.rgb;
    if ((i.flags & F_SHADE) != 0u) {
        rgb = rgb * 0.72;
    }

    // which side of the wipe this pixel is on
    let wipe = cam.params.y;
    if (wipe <= 0.0) {
        return vec4<f32>(rgb, 1.0);
    }
    let sp = (i.clip.xy - cam.view.xy) / cam.view.zw;
    let s = sp.x + (sp.y - 0.5) * 0.35;
    let e = mix(-0.2, 1.2, wipe);
    let d = (e - s) * cam.view.z; // pixels inside the wireframe side
    var out = rgb;
    if (d > 0.0) {
        var line = 0.0;
        var col = vec3<f32>(0.0);
        if ((i.flags & F_OPAQUE) != 0u) {
            // the sea: a grid on the tile boundaries, faded out where it gets too dense
            let g = abs(fract(i.wpos.xz + 0.5) - 0.5) / max(px_w, vec2<f32>(1e-5));
            let fade = 1.0 - smoothstep(0.15, 0.4, max(px_w.x, px_w.y));
            line = (1.0 - smoothstep(LINE - 0.5, LINE + 0.5, min(g.x, g.y))) * fade;
            col = vec3<f32>(0.0, 0.42, 0.55);
        } else {
            // quad edges of the cube faces
            if ((i.flags & (F_CARD | F_SPRITE)) == 0u) {
                let q = min(i.quv, 1.0 - i.quv) / max(px_q, vec2<f32>(1e-5));
                line = 1.0 - smoothstep(LINE - 0.5, LINE + 0.5, min(q.x, q.y));
            }
            // outlines where a solid texel meets an empty one
            let t = vec2<i32>(floor(tc));
            let f = fract(tc) / max(px_tc, vec2<f32>(1e-5));
            let g = (1.0 - fract(tc)) / max(px_tc, vec2<f32>(1e-5));
            var o = 1e9;
            if (!solid(i, t + vec2<i32>(-1, 0))) { o = min(o, f.x); }
            if (!solid(i, t + vec2<i32>(1, 0))) { o = min(o, g.x); }
            if (!solid(i, t + vec2<i32>(0, -1))) { o = min(o, f.y); }
            if (!solid(i, t + vec2<i32>(0, 1))) { o = min(o, g.y); }
            line = max(line, 1.0 - smoothstep(LINE - 0.5, LINE + 0.5, o));
            col = select(edge_colour(i.ch), c.rgb, sprite);
            col = bright(col);
            if ((i.flags & F_SHADE) != 0u) {
                col = col * 0.8;
            }
        }
        out = col * line;
    }
    // the wipe's leading edge
    if (wipe < 1.0) {
        let a = abs(d);
        out = mix(out, vec3<f32>(1.0), 1.0 - smoothstep(1.0, 2.5, a));
        out = out + vec3<f32>(0.0, 0.8, 1.0) * 0.5 * exp(-a / 10.0);
    }
    return vec4<f32>(out, 1.0);
}

// 2D pass: the emulated Spectrum screen (HUD, menus, map), transparent where the 3D view
// shows through.

@group(0) @binding(0) var scr: texture_2d<f32>;
@group(0) @binding(1) var samp2: sampler;

struct O2 {
    @builtin(position) p: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

@vertex
fn vs2(@builtin(vertex_index) i: u32) -> O2 {
    let x = f32((i << 1u) & 2u);
    let y = f32(i & 2u);
    var o: O2;
    o.p = vec4<f32>(x * 2.0 - 1.0, 1.0 - y * 2.0, 0.0, 1.0);
    o.uv = vec2<f32>(x, y);
    return o;
}

@fragment
fn fs2(i: O2) -> @location(0) vec4<f32> {
    let c = textureSampleLevel(scr, samp2, i.uv, 0.0);
    if (c.a < 0.5) {
        discard;
    }
    return vec4<f32>(c.rgb, 1.0);
}
