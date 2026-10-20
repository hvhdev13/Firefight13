const DIGITS =
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

const PULSE_GAP = 0.5;
const PULSE_ATTACK = 0.06;
const PULSE_DECAY = 0.18;
const PULSE_FLOOR = 0.08;
const PULSE_SHARE = 0.55;
const RECENT_DECAY = 3;
const CRUISE_GAP = 0.9;
const CRUISE_PEAK = 0.5;
const DROP_LEVEL = 0.6;
const DROP_RISE = 0.3;
const DROP_WINDOW = 6;
const DROP_GAP = 15;

export type LobbyBeats = {
  fps: number;
  kick: string;
  snare: string;
  energy: string;
};

export const parseBeats = (text?: string): LobbyBeats | null => {
  const [fps, kick, snare, energy] = (text || '')
    .split('\n')
    .map((line) => line.trim());
  return energy ? { fps: Number(fps), kick, snare, energy } : null;
};

export const beatLevel = (row: string, index: number) =>
  Math.max(0, DIGITS.indexOf(row[index] || 'A')) / 63;

export const findDrops = (beats: LobbyBeats) => {
  const drops: number[] = [];
  const window = beats.fps * DROP_WINDOW;
  let last = -Infinity;
  for (let index = window; index < beats.energy.length; index++) {
    const level = beatLevel(beats.energy, index);
    if (level < DROP_LEVEL || index - last <= beats.fps * DROP_GAP) {
      continue;
    }
    for (let back = index - window; back < index; back++) {
      if (beatLevel(beats.energy, back) <= level - DROP_RISE) {
        drops.push(index / beats.fps);
        last = index;
        break;
      }
    }
  }
  return drops;
};

export class LightBar {
  level = 0;
  lastPulse = -10;
  private peak = 0;
  private recent = 0;
  private lastLevel = 0;
  private lastTime = 0;

  update(time: number, level: number, cruise: boolean) {
    this.recent = Math.max(
      level,
      this.recent * Math.exp(-(time - this.lastTime) / RECENT_DECAY),
    );
    this.lastTime = time;
    const sincePulse = time - this.lastPulse;
    if (sincePulse >= PULSE_GAP) {
      if (
        level >= Math.max(PULSE_FLOOR, this.recent * PULSE_SHARE) &&
        level > this.lastLevel
      ) {
        this.pulse(time, Math.min(1, 0.5 + 0.6 * level));
      } else if (cruise && sincePulse >= CRUISE_GAP) {
        this.pulse(time, CRUISE_PEAK);
      }
    }
    this.lastLevel = level;
    const age = time - this.lastPulse;
    this.level =
      this.peak *
      Math.min(1, age / PULSE_ATTACK) *
      Math.exp(-Math.max(0, age - PULSE_ATTACK) / PULSE_DECAY);
  }

  private pulse(time: number, peak: number) {
    this.peak = peak;
    this.lastPulse = time;
  }
}
