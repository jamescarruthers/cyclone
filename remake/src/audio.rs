//! 1-bit beeper synthesis. The game thread emits square-wave `Tone`s stamped with virtual
//! time (ROM BEEPER calls, the interrupt-driven rotor chop, the crash noise); the audio
//! callback renders them against the same clock with a small fixed latency.

use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

use crate::sys::Shared;

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

#[derive(Clone, Copy, Debug)]
pub struct Tone {
    /// Start, in virtual seconds.
    pub start: f64,
    /// Speaker-high time per cycle (s).
    pub high: f64,
    /// Speaker-low time per cycle (s).
    pub low: f64,
    pub cycles: u32,
}

impl Tone {
    fn end(&self) -> f64 {
        self.start + (self.high + self.low) * self.cycles as f64
    }
    fn level(&self, t: f64) -> bool {
        let p = self.high + self.low;
        if p <= 0.0 {
            return false;
        }
        let ph = (t - self.start) % p;
        ph < self.high
    }
}

pub struct AudioQueue {
    q: Mutex<VecDeque<Tone>>,
}

impl AudioQueue {
    pub fn new() -> Arc<AudioQueue> {
        Arc::new(AudioQueue { q: Mutex::new(VecDeque::new()) })
    }

    pub fn push(&self, t: Tone) {
        let mut q = self.q.lock().unwrap();
        if q.len() < 4096 {
            q.push_back(t);
        }
    }
}

pub struct Audio {
    _stream: cpal::Stream,
}

const LATENCY: f64 = 0.07;

/// Start the output stream, playing the tones pushed to `queue` against the game clock.
/// In the browser this must be called from a user gesture (key press or click).
pub fn start(shared: Arc<Shared>, queue: Arc<AudioQueue>) -> Option<Audio> {
    let host = cpal::default_host();
    let device = host.default_output_device()?;
    let supported = device.default_output_config().ok()?;
    if supported.sample_format() != cpal::SampleFormat::F32 {
        log::warn!("audio: unsupported sample format {:?}", supported.sample_format());
        return None;
    }
    let config: cpal::StreamConfig = supported.into();
    let rate = config.sample_rate.0 as f64;
    let channels = config.channels as usize;
    let q = queue;
    let mut active: Vec<Tone> = Vec::new();
    let mut clock: Option<f64> = None;
    let mut lp = 0.0f32;
    let mut dc = 0.0f32;
    let stream = device
        .build_output_stream(
            &config,
            move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                let frames = data.len() / channels;
                let ideal = shared.now() - LATENCY;
                let mut t = match clock {
                    Some(c) if (c - ideal).abs() < 0.15 => c,
                    _ => ideal,
                };
                {
                    let mut qq = q.q.lock().unwrap();
                    while let Some(tone) = qq.pop_front() {
                        if tone.end() > t - 0.5 {
                            active.push(tone);
                        }
                    }
                }
                active.retain(|x| x.end() > t);
                let dt = 1.0 / rate;
                for f in 0..frames {
                    let mut on = false;
                    for tone in &active {
                        if t >= tone.start && t < tone.end() && tone.level(t) {
                            on = true;
                            break;
                        }
                    }
                    let target = if on { 1.0f32 } else { 0.0 };
                    // gentle low-pass (speaker) and DC removal
                    lp += (target - lp) * 0.35;
                    dc += (lp - dc) * 0.002;
                    let s = (lp - dc) * 0.22;
                    for c in 0..channels {
                        data[f * channels + c] = s;
                    }
                    t += dt;
                }
                clock = Some(t);
            },
            |e| log::warn!("audio stream error: {e}"),
            None,
        )
        .ok()?;
    stream.play().ok()?;
    Some(Audio { _stream: stream })
}

/// Offline rendering of recorded tones to 16-bit mono PCM (same speaker model as the live
/// stream).
#[cfg(not(target_arch = "wasm32"))]
pub fn render_pcm(tones: &[Tone], duration: f64, rate: u32) -> Vec<i16> {
    let mut tones = tones.to_vec();
    tones.sort_by(|a, b| a.start.partial_cmp(&b.start).unwrap());
    let n = (duration * rate as f64) as usize;
    let mut out = Vec::with_capacity(n);
    let (mut lp, mut dc) = (0.0f32, 0.0f32);
    let mut first = 0usize;
    for i in 0..n {
        let t = i as f64 / rate as f64;
        while first < tones.len() && tones[first].end() < t - 2.0 {
            first += 1;
        }
        let mut on = false;
        for tone in &tones[first..] {
            if tone.start > t {
                break;
            }
            if t < tone.end() && tone.level(t) {
                on = true;
                break;
            }
        }
        let target = if on { 1.0f32 } else { 0.0 };
        lp += (target - lp) * 0.35;
        dc += (lp - dc) * 0.002;
        out.push(((lp - dc) * 0.5 * 32767.0) as i16);
    }
    out
}

#[cfg(not(target_arch = "wasm32"))]
pub fn write_wav(path: &str, pcm: &[i16], rate: u32) {
    let mut b = Vec::with_capacity(44 + pcm.len() * 2);
    let data = (pcm.len() * 2) as u32;
    b.extend_from_slice(b"RIFF");
    b.extend_from_slice(&(36 + data).to_le_bytes());
    b.extend_from_slice(b"WAVEfmt ");
    b.extend_from_slice(&16u32.to_le_bytes());
    b.extend_from_slice(&1u16.to_le_bytes());
    b.extend_from_slice(&1u16.to_le_bytes());
    b.extend_from_slice(&rate.to_le_bytes());
    b.extend_from_slice(&(rate * 2).to_le_bytes());
    b.extend_from_slice(&2u16.to_le_bytes());
    b.extend_from_slice(&16u16.to_le_bytes());
    b.extend_from_slice(b"data");
    b.extend_from_slice(&data.to_le_bytes());
    for s in pcm {
        b.extend_from_slice(&s.to_le_bytes());
    }
    std::fs::write(path, b).expect("wav");
}
