"use client";
/**
 * Quivo sound engine — 100% procedural Web Audio (no asset files, no licensing, works offline
 * at a venue). Game-show SFX synthesized on the fly; volume kept polite.
 *
 * Mobile/desktop autoplay policy: the AudioContext starts suspended until a user gesture —
 * call `unlock()` from the first tap (host: create/start; player: join). Every play() call
 * also retries resume, so a missed unlock self-heals on the next interaction-triggered sound.
 */

let ctx: AudioContext | null = null;
let unlocked = false;

function ac(): AudioContext | null {
  if (typeof window === "undefined") return null;
  if (!ctx) {
    const AC = window.AudioContext ?? (window as any).webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
  }
  return ctx;
}

export function unlock() {
  const c = ac();
  if (!c) return;
  if (c.state === "suspended") void c.resume();
  unlocked = true;
}

type ToneOpts = {
  freq: number;
  time?: number; // start offset (s)
  dur?: number; // seconds
  type?: OscillatorType;
  vol?: number;
  slide?: number; // target freq to glide to
};

function tone({ freq, time = 0, dur = 0.15, type = "sine", vol = 0.2, slide }: ToneOpts) {
  const c = ac();
  if (!c) return;
  if (c.state === "suspended") {
    if (!unlocked) return;
    void c.resume();
  }
  const t0 = c.currentTime + time;
  const osc = c.createOscillator();
  const gain = c.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t0);
  if (slide) osc.frequency.exponentialRampToValueAtTime(slide, t0 + dur);
  gain.gain.setValueAtTime(0, t0);
  gain.gain.linearRampToValueAtTime(vol, t0 + 0.012);
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.connect(gain).connect(c.destination);
  osc.start(t0);
  osc.stop(t0 + dur + 0.05);
}

function noise({ time = 0, dur = 0.2, vol = 0.12, from = 400, to = 4000 }) {
  const c = ac();
  if (!c || (c.state === "suspended" && !unlocked)) return;
  const t0 = c.currentTime + time;
  const len = Math.max(1, Math.floor(c.sampleRate * dur));
  const buf = c.createBuffer(1, len, c.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
  const src = c.createBufferSource();
  src.buffer = buf;
  const filter = c.createBiquadFilter();
  filter.type = "bandpass";
  filter.frequency.setValueAtTime(from, t0);
  filter.frequency.exponentialRampToValueAtTime(to, t0 + dur);
  const gain = c.createGain();
  gain.gain.setValueAtTime(vol, t0);
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  src.connect(filter).connect(gain).connect(c.destination);
  src.start(t0);
}

export const sfx = {
  /** a player joined the lobby — bubbly pop */
  join() {
    tone({ freq: 620, dur: 0.09, type: "sine", vol: 0.16 });
    tone({ freq: 930, time: 0.06, dur: 0.12, type: "sine", vol: 0.14 });
  },
  /** question appears — attention swoosh + chime */
  question() {
    noise({ dur: 0.25, vol: 0.08, from: 300, to: 3500 });
    tone({ freq: 523, time: 0.1, dur: 0.18, type: "triangle", vol: 0.16 });
    tone({ freq: 784, time: 0.18, dur: 0.22, type: "triangle", vol: 0.14 });
  },
  /** countdown tick (last seconds) */
  tick(urgent = false) {
    tone({ freq: urgent ? 1100 : 880, dur: 0.05, type: "square", vol: urgent ? 0.1 : 0.06 });
  },
  /** player locked an answer */
  lock() {
    tone({ freq: 340, dur: 0.06, type: "square", vol: 0.14 });
    tone({ freq: 220, time: 0.05, dur: 0.08, type: "square", vol: 0.1 });
  },
  /** reveal — correct: bright major arpeggio */
  correct() {
    [523, 659, 784, 1047].forEach((f, i) => tone({ freq: f, time: i * 0.07, dur: 0.22, type: "triangle", vol: 0.16 }));
  },
  /** reveal — wrong: soft descending thud */
  wrong() {
    tone({ freq: 220, dur: 0.25, type: "sawtooth", vol: 0.1, slide: 110 });
  },
  /** leaderboard swap whoosh */
  whoosh() {
    noise({ dur: 0.3, vol: 0.07, from: 2000, to: 300 });
  },
  /** podium fanfare */
  fanfare() {
    const seq = [392, 523, 659, 784, 659, 784, 1047];
    seq.forEach((f, i) => tone({ freq: f, time: i * 0.11, dur: 0.28, type: "triangle", vol: 0.18 }));
    noise({ time: 0.7, dur: 0.5, vol: 0.05, from: 1500, to: 6000 });
  },
  /** money hit — coin cascade (the payout moment) */
  coin() {
    [1319, 1568, 2093].forEach((f, i) => tone({ freq: f, time: i * 0.08, dur: 0.3, type: "sine", vol: 0.16 }));
    tone({ freq: 2637, time: 0.26, dur: 0.4, type: "sine", vol: 0.12 });
  },
  /** on-chain anchor blip (subtle, for the ticker) */
  anchor() {
    tone({ freq: 1760, dur: 0.05, type: "sine", vol: 0.05 });
  },
};

/** Phone haptics (Android Chrome etc.); silently no-ops elsewhere. */
export function buzz(pattern: number | number[] = 30) {
  try {
    navigator?.vibrate?.(pattern);
  } catch {
    /* unsupported */
  }
}
