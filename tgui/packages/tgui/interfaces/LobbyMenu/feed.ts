const SPRITE_SIZE = 128;
const MAX_PIXEL_RATIO = 1.5;
const TRACER_TAIL = 0.05;
const MUZZLE_TIME = 0.09;
const FLARE_LIFE = 11;
const ARTILLERY_LIFE = 2.5;
const BLOOM_DIVISOR = 4;
const WRECK_X = 0.82;
const WRECK_Y = 0.84;

const USCM_STROKE = 'rgb(110,255,130)';
const USCM_CORE = 'rgb(225,255,225)';
const USCM_DISTANT_CORE = 'rgb(200,255,200)';
const UPP_STROKE = 'rgb(255,80,50)';
const UPP_CORE = 'rgb(255,225,205)';
const UPP_DISTANT_CORE = 'rgb(255,200,180)';
const SKYLINE_BACK = '#1a2420';
const SKYLINE = '#0a0f0d';
const SKYLINE_RIBS = '#18221d';
const RUBBLE = '#030504';

type Sprite = HTMLCanvasElement;

type Tracer = {
  x: number;
  y: number;
  originX: number;
  originY: number;
  velocityX: number;
  velocityY: number;
  wait: number;
  width: number;
  alpha: number;
  near: boolean;
  glow?: Sprite;
  stroke: string;
  core: string;
  range: number;
};

type Fire = {
  x: number;
  y: number;
  size: number;
  phase: number;
  near?: boolean;
};

type Smoke = {
  x: number;
  y: number;
  radius: number;
  alpha: number;
  speed: number;
};

type Flash = {
  x: number;
  y: number;
  time: number;
  glow: Sprite;
};

type Flare = {
  x: number;
  y: number;
  start: number;
  intensity: number;
  phase: number;
};

type Artillery = {
  x: number;
  y: number;
  time: number;
};

const random = (low: number, high: number) =>
  low + Math.random() * (high - low);

const seeded = (seed: number) => () => {
  seed = (seed + 0x6d2b79f5) | 0;
  let value = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  value = (value + Math.imul(value ^ (value >>> 7), 61 | value)) ^ value;
  return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
};

const makeSprite = (red: number, green: number, blue: number) => {
  const canvas = document.createElement('canvas');
  canvas.width = SPRITE_SIZE;
  canvas.height = SPRITE_SIZE;
  const context = canvas.getContext('2d')!;
  const half = SPRITE_SIZE / 2;
  const gradient = context.createRadialGradient(
    half,
    half,
    0,
    half,
    half,
    half,
  );
  gradient.addColorStop(0, `rgba(${red},${green},${blue},1)`);
  gradient.addColorStop(0.45, `rgba(${red},${green},${blue},0.42)`);
  gradient.addColorStop(1, `rgba(${red},${green},${blue},0)`);
  context.fillStyle = gradient;
  context.fillRect(0, 0, SPRITE_SIZE, SPRITE_SIZE);
  return canvas;
};

const fireFlicker = (fire: Fire, time: number) =>
  0.75 +
  0.25 *
    Math.sin(time * 7 + fire.phase) *
    Math.sin(time * 3.1 + fire.phase * 2);

export class FeedScene {
  private readonly canvas: HTMLCanvasElement;
  private readonly context: CanvasRenderingContext2D;
  private readonly bloom: HTMLCanvasElement;
  private readonly bloomContext: CanvasRenderingContext2D;
  private readonly smokeSprite = makeSprite(78, 72, 64);
  private readonly orange = makeSprite(255, 120, 40);
  private readonly flareSprite = makeSprite(255, 236, 200);
  private readonly green = makeSprite(110, 255, 130);
  private readonly red = makeSprite(255, 70, 50);
  private width = 1;
  private height = 1;
  private scale = 1;
  private base = 0;
  private far?: HTMLCanvasElement;
  private near?: HTMLCanvasElement;
  private antenna = { x: 0, y: 0 };
  private fires: Fire[] = [];
  private smoke: Smoke[] = [];
  private tracers: Tracer[] = [];
  private flashes: Flash[] = [];
  private flares: Flare[] = [];
  private artillery: Artillery[] = [];
  private nextFlare = 0;
  private nextDistant = 0;

  constructor(canvas: HTMLCanvasElement, bloom: HTMLCanvasElement) {
    this.canvas = canvas;
    this.context = canvas.getContext('2d')!;
    this.bloom = bloom;
    this.bloomContext = bloom.getContext('2d')!;
  }

  build() {
    const bounds = this.canvas.getBoundingClientRect();
    const ratio = Math.min(MAX_PIXEL_RATIO, window.devicePixelRatio || 1);
    this.width = Math.max(1, Math.round(bounds.width * ratio));
    this.height = Math.max(1, Math.round(bounds.height * ratio));
    this.canvas.width = this.width;
    this.canvas.height = this.height;
    this.bloom.width = Math.max(1, Math.round(this.width / BLOOM_DIVISOR));
    this.bloom.height = Math.max(1, Math.round(this.height / BLOOM_DIVISOR));
    this.scale = this.height / 540;
    this.base = this.height * 0.7;
    const roll = seeded(11);
    this.far = this.buildSkyline(roll);
    this.near = this.buildRubble(roll);
    this.fires = [];
    for (let index = 0; index < 5; index++) {
      this.fires.push({
        x: this.width * (0.08 + roll() * 0.84),
        y: this.base - roll() * 6 * this.scale,
        size: 0.6 + roll() * 0.6,
        phase: roll() * 10,
      });
    }
    this.fires.push({
      x: this.width * WRECK_X + 30 * this.scale,
      y: this.height * WRECK_Y - 38 * this.scale,
      size: 0.7,
      phase: 2,
      near: true,
    });
    this.smoke = [];
    for (let index = 0; index < 14; index++) {
      this.smoke.push({
        x: roll() * this.width,
        y: this.base - (10 + roll() * 210) * this.scale,
        radius: (80 + roll() * 170) * this.scale,
        alpha: 0.05 + roll() * 0.08,
        speed: (4 + roll() * 10) * this.scale,
      });
    }
    this.tracers = [];
    this.flashes = [];
  }

  private layer() {
    const canvas = document.createElement('canvas');
    canvas.width = this.width;
    canvas.height = this.height;
    return canvas;
  }

  private buildSkyline(roll: () => number) {
    const { width, base, scale } = this;
    const canvas = this.layer();
    const context = canvas.getContext('2d')!;
    context.fillStyle = SKYLINE_BACK;
    let backX = -20;
    while (backX < width) {
      const blockWidth = (30 + roll() * 90) * scale;
      const blockHeight = (20 + roll() * 90) * scale;
      context.fillRect(
        backX,
        base - blockHeight - 12 * scale,
        blockWidth,
        blockHeight + 12 * scale,
      );
      backX += blockWidth * 0.8;
    }
    context.fillStyle = SKYLINE;
    const domeX = width * 0.74;
    const domeRadius = 95 * scale;
    context.beginPath();
    context.ellipse(domeX, base, domeRadius, domeRadius * 0.62, 0, Math.PI, 0);
    context.fill();
    context.strokeStyle = SKYLINE_RIBS;
    context.lineWidth = 1.4 * scale;
    for (let rib = 1; rib < 5; rib++) {
      context.beginPath();
      context.ellipse(
        domeX,
        base,
        (domeRadius * rib) / 5,
        domeRadius * 0.62,
        0,
        Math.PI,
        0,
      );
      context.stroke();
    }
    context.beginPath();
    context.ellipse(domeX, base, domeRadius, domeRadius * 0.31, 0, Math.PI, 0);
    context.stroke();
    context.fillStyle = SKYLINE_BACK;
    context.beginPath();
    context.moveTo(domeX + domeRadius * 0.15, base - domeRadius * 0.6);
    context.lineTo(domeX + domeRadius * 0.55, base - domeRadius * 0.46);
    context.lineTo(domeX + domeRadius * 0.4, base - domeRadius * 0.3);
    context.lineTo(domeX + domeRadius * 0.25, base - domeRadius * 0.38);
    context.closePath();
    context.fill();
    const antennaX = width * 0.31;
    this.antenna = { x: antennaX, y: base - 235 * scale };
    context.strokeStyle = SKYLINE;
    context.lineWidth = 3 * scale;
    context.beginPath();
    context.moveTo(antennaX, base);
    context.lineTo(antennaX, base - 235 * scale);
    context.stroke();
    context.lineWidth = 1.2 * scale;
    context.beginPath();
    for (let y = base; y > base - 220 * scale; y -= 22 * scale) {
      context.moveTo(antennaX - 9 * scale, y);
      context.lineTo(antennaX + 9 * scale, y - 22 * scale);
      context.moveTo(antennaX + 9 * scale, y);
      context.lineTo(antennaX - 9 * scale, y - 22 * scale);
    }
    context.stroke();
    context.fillStyle = SKYLINE;
    let x = -10;
    while (x < width + 10) {
      const blockWidth = (16 + roll() * 64) * scale;
      let blockHeight = (30 + roll() * 130) * scale;
      if (roll() < 0.12) blockHeight *= 1.7;
      let lowest = 1;
      context.beginPath();
      context.moveTo(x, base);
      context.lineTo(x, base - blockHeight);
      if (roll() < 0.5) {
        const steps = 3 + Math.floor(roll() * 4);
        for (let step = 1; step <= steps; step++) {
          const top = 0.45 + roll() * 0.55;
          lowest = Math.min(lowest, top);
          context.lineTo(
            x + (blockWidth * step) / steps,
            base - blockHeight * top,
          );
        }
      } else {
        context.lineTo(x + blockWidth, base - blockHeight);
      }
      context.lineTo(x + blockWidth, base);
      context.closePath();
      context.fill();
      for (
        let windowY = base - blockHeight * lowest + 8 * scale;
        windowY < base - 6 * scale;
        windowY += 9 * scale
      ) {
        for (
          let windowX = x + 4 * scale;
          windowX < x + blockWidth - 4 * scale;
          windowX += 8 * scale
        ) {
          if (roll() < 0.035) {
            context.fillStyle =
              roll() < 0.6 ? 'rgba(255,150,70,0.55)' : 'rgba(200,230,255,0.25)';
            context.fillRect(windowX, windowY, 2.5 * scale, 3 * scale);
            context.fillStyle = SKYLINE;
          }
        }
      }
      x += blockWidth + (roll() < 0.25 ? roll() * 30 * scale : -2 * scale);
    }
    context.fillRect(0, base, width, this.height - base);
    return canvas;
  }

  private buildRubble(roll: () => number) {
    const { width, height, scale } = this;
    const canvas = this.layer();
    const context = canvas.getContext('2d')!;
    context.fillStyle = RUBBLE;
    context.beginPath();
    context.moveTo(0, height);
    for (let x = 0; x <= width + 20 * scale; x += 14 * scale) {
      context.lineTo(
        x,
        height * 0.835 +
          Math.sin((x * 0.004) / scale) * 12 * scale -
          roll() * 14 * scale,
      );
    }
    context.lineTo(width, height);
    context.closePath();
    context.fill();
    const wallWidth = width * 0.16;
    context.beginPath();
    context.moveTo(0, height);
    context.lineTo(0, height * 0.5);
    for (let step = 1; step <= 9; step++) {
      context.lineTo(
        (wallWidth * step) / 9,
        height * (0.5 + 0.2 * (step / 9) + (roll() - 0.5) * 0.05),
      );
    }
    context.lineTo(wallWidth * 1.1, height);
    context.closePath();
    context.fill();
    context.strokeStyle = RUBBLE;
    context.lineWidth = 1.6 * scale;
    for (let bar = 0; bar < 7; bar++) {
      const barX = roll() * wallWidth * 0.9;
      const barY = height * (0.5 + (0.2 * barX) / wallWidth) + 4 * scale;
      context.beginPath();
      context.moveTo(barX, barY);
      context.lineTo(
        barX + (roll() - 0.3) * 20 * scale,
        barY - (16 + roll() * 28) * scale,
      );
      context.stroke();
    }
    const wreckX = width * WRECK_X;
    const wreckY = height * WRECK_Y;
    context.beginPath();
    context.moveTo(wreckX - 95 * scale, wreckY);
    context.lineTo(wreckX - 84 * scale, wreckY - 34 * scale);
    context.lineTo(wreckX + 50 * scale, wreckY - 40 * scale);
    context.lineTo(wreckX + 98 * scale, wreckY - 18 * scale);
    context.lineTo(wreckX + 104 * scale, wreckY);
    context.closePath();
    context.fill();
    context.fillRect(
      wreckX - 95 * scale,
      wreckY - 6 * scale,
      199 * scale,
      height - wreckY + 6 * scale,
    );
    context.beginPath();
    context.roundRect(
      wreckX - 82 * scale,
      wreckY - 18 * scale,
      180 * scale,
      30 * scale,
      12 * scale,
    );
    context.fill();
    context.beginPath();
    context.moveTo(wreckX - 36 * scale, wreckY - 34 * scale);
    context.lineTo(wreckX - 30 * scale, wreckY - 60 * scale);
    context.lineTo(wreckX + 18 * scale, wreckY - 60 * scale);
    context.lineTo(wreckX + 26 * scale, wreckY - 36 * scale);
    context.closePath();
    context.fill();
    context.save();
    context.translate(wreckX + 12 * scale, wreckY - 50 * scale);
    context.rotate(-0.35);
    context.fillRect(0, -3 * scale, 84 * scale, 6 * scale);
    context.restore();
    for (let wheel = 0; wheel < 4; wheel++) {
      context.beginPath();
      context.arc(
        wreckX - 60 * scale + wheel * 45 * scale,
        wreckY - 2 * scale,
        13 * scale,
        0,
        Math.PI * 2,
      );
      context.fill();
    }
    return canvas;
  }

  private glow(
    sprite: Sprite,
    x: number,
    y: number,
    radius: number,
    alpha: number,
  ) {
    this.context.globalAlpha = Math.max(0, Math.min(1, alpha));
    this.context.drawImage(
      sprite,
      x - radius,
      y - radius,
      radius * 2,
      radius * 2,
    );
  }

  shoot(uscm: boolean) {
    const { width, height, scale } = this;
    const count = 3 + Math.floor(Math.random() * 3);
    for (let index = 0; index < count; index++) {
      const y = height * random(0.5, 0.78);
      this.tracers.push({
        x: uscm ? -random(2, 14) * scale : width + random(2, 14) * scale,
        y,
        originX: uscm ? 0 : width,
        originY: y,
        velocityX: (uscm ? 1 : -1) * random(1100, 1500) * scale,
        velocityY: random(-170, -50) * scale,
        wait: index * random(0.04, 0.08),
        width: 1.7 * scale,
        alpha: 1,
        near: true,
        glow: uscm ? this.green : this.red,
        stroke: uscm ? USCM_STROKE : UPP_STROKE,
        core: uscm ? USCM_CORE : UPP_CORE,
        range: Infinity,
      });
    }
  }

  drop(time: number) {
    this.artillery.push({
      x: this.width * random(0.25, 0.7),
      y: this.base,
      time,
    });
  }

  private drawTracer(tracer: Tracer) {
    const { context } = this;
    const endX = tracer.x - tracer.velocityX * TRACER_TAIL;
    const endY = tracer.y - tracer.velocityY * TRACER_TAIL;
    context.globalAlpha = tracer.alpha * 0.22;
    context.strokeStyle = tracer.stroke;
    context.lineWidth = tracer.width * 3.2;
    context.beginPath();
    context.moveTo(tracer.x, tracer.y);
    context.lineTo(endX, endY);
    context.stroke();
    context.globalAlpha = tracer.alpha;
    context.strokeStyle = tracer.core;
    context.lineWidth = tracer.width;
    context.beginPath();
    context.moveTo(tracer.x, tracer.y);
    context.lineTo(endX, endY);
    context.stroke();
  }

  frame(time: number, delta: number, glitch: number) {
    const { context, width, height, base, scale, far, near } = this;
    if (!far || !near) return;
    const shake = glitch * 5 * scale;
    context.setTransform(
      1,
      0,
      0,
      1,
      (Math.random() - 0.5) * shake,
      (Math.random() - 0.5) * shake,
    );
    context.globalCompositeOperation = 'source-over';
    context.globalAlpha = 1;
    const sky = context.createLinearGradient(0, 0, 0, base);
    sky.addColorStop(0, '#020404');
    sky.addColorStop(0.5, '#0d1413');
    sky.addColorStop(1, '#4a2c16');
    context.fillStyle = sky;
    context.fillRect(-10, -10, width + 20, base + 20);
    context.globalCompositeOperation = 'lighter';
    for (const fire of this.fires) {
      if (!fire.near) {
        this.glow(
          this.orange,
          fire.x,
          fire.y,
          220 * scale * fire.size,
          0.16 * fireFlicker(fire, time),
        );
      }
    }
    for (const flare of this.flares) {
      this.glow(
        this.flareSprite,
        flare.x,
        flare.y,
        width * 0.45,
        0.11 * flare.intensity,
      );
    }
    context.globalCompositeOperation = 'source-over';
    context.globalAlpha = 1;
    context.drawImage(far, 0, 0);
    context.globalCompositeOperation = 'lighter';
    for (const flare of this.flares) {
      this.glow(
        this.flareSprite,
        flare.x,
        base,
        width * 0.35,
        0.06 * flare.intensity,
      );
    }
    for (const fire of this.fires) {
      if (!fire.near) {
        const flicker = fireFlicker(fire, time);
        this.glow(
          this.orange,
          fire.x,
          fire.y,
          28 * scale * fire.size,
          0.65 * flicker,
        );
        this.glow(
          this.flareSprite,
          fire.x,
          fire.y,
          7 * scale * fire.size,
          0.5 * flicker,
        );
      }
    }
    if (time % 1.6 < 0.3) {
      this.glow(this.red, this.antenna.x, this.antenna.y, 7 * scale, 0.9);
    }
    for (const shell of this.artillery) {
      const age = time - shell.time;
      const swell =
        Math.min(1, age / 0.25) * Math.exp(-Math.max(0, age - 0.25) / 0.5);
      this.glow(
        this.flareSprite,
        shell.x,
        shell.y,
        (0.06 + 0.22 * Math.min(1, age / 0.3)) * width,
        0.4 * swell,
      );
      this.glow(this.orange, shell.x, shell.y, 0.3 * width, 0.35 * swell);
    }
    context.lineCap = 'round';
    for (const tracer of this.tracers) {
      if (!tracer.near && tracer.wait <= 0) this.drawTracer(tracer);
    }
    context.globalCompositeOperation = 'source-over';
    for (const cloud of this.smoke) {
      cloud.x -= cloud.speed * delta;
      if (cloud.x < -cloud.radius) cloud.x = width + cloud.radius;
      context.globalAlpha = cloud.alpha;
      context.drawImage(
        this.smokeSprite,
        cloud.x - cloud.radius,
        cloud.y - cloud.radius * 0.6,
        cloud.radius * 2,
        cloud.radius * 1.2,
      );
    }
    for (const flare of this.flares) {
      const age = time - flare.start;
      for (let puff = 1; puff < 7; puff++) {
        const puffX =
          flare.x +
          Math.sin((time - puff * 0.4) * 0.7 + flare.phase) *
            6 *
            scale *
            puff *
            0.3;
        context.globalAlpha =
          0.06 * flare.intensity * (1 - puff / 7) * Math.min(1, age);
        context.drawImage(
          this.smokeSprite,
          puffX - 14 * scale,
          flare.y - puff * 22 * scale - 14 * scale,
          28 * scale,
          28 * scale,
        );
      }
    }
    context.globalAlpha = 1;
    context.drawImage(near, 0, 0);
    context.globalCompositeOperation = 'lighter';
    for (const fire of this.fires) {
      if (fire.near) {
        const flicker = fireFlicker(fire, time);
        this.glow(this.orange, fire.x, fire.y, 60 * scale, 0.5 * flicker);
        this.glow(this.flareSprite, fire.x, fire.y, 10 * scale, 0.5 * flicker);
      }
    }
    for (const tracer of this.tracers) {
      if (tracer.near && tracer.wait <= 0) this.drawTracer(tracer);
    }
    for (const flash of this.flashes) {
      const fade = 1 - (time - flash.time) / MUZZLE_TIME;
      if (fade > 0) {
        this.glow(this.flareSprite, flash.x, flash.y, 26 * scale, 0.9 * fade);
        this.glow(flash.glow, flash.x, flash.y, 80 * scale, 0.5 * fade);
      }
    }
    for (const flare of this.flares) {
      this.glow(
        this.flareSprite,
        flare.x,
        flare.y,
        18 * scale,
        0.9 * flare.intensity,
      );
      this.glow(this.flareSprite, flare.x, flare.y, 4 * scale, flare.intensity);
    }
    context.globalCompositeOperation = 'source-over';
    context.globalAlpha = 1;
    if (glitch > 0.03) {
      context.setTransform(1, 0, 0, 1, 0, 0);
      const strips = 2 + Math.floor(7 * glitch);
      for (let strip = 0; strip < strips; strip++) {
        const y = random(0, height);
        const stripHeight = random(4, 34) * scale;
        const offset = random(-50, 50) * scale * glitch;
        context.drawImage(
          this.canvas,
          0,
          y,
          width,
          stripHeight,
          offset,
          y,
          width,
          stripHeight,
        );
      }
      for (let block = 0; block < 4 + 10 * glitch; block++) {
        context.fillStyle =
          Math.random() < 0.5
            ? `rgba(110,255,140,${0.14 * glitch})`
            : `rgba(255,80,60,${0.14 * glitch})`;
        context.fillRect(
          random(0, width),
          random(0, height),
          random(20, 160) * scale,
          random(2, 8) * scale,
        );
      }
    }
    this.bloomContext.globalCompositeOperation = 'copy';
    this.bloomContext.drawImage(
      this.canvas,
      0,
      0,
      this.bloom.width,
      this.bloom.height,
    );
    this.advance(time, delta);
  }

  private advance(time: number, delta: number) {
    const { width, base, scale } = this;
    for (const tracer of this.tracers) {
      if (tracer.wait > 0) {
        tracer.wait -= delta;
        if (tracer.wait <= 0 && tracer.glow) {
          this.flashes.push({
            x: tracer.originX,
            y: tracer.originY,
            time,
            glow: tracer.glow,
          });
        }
        continue;
      }
      tracer.x += tracer.velocityX * delta;
      tracer.y += tracer.velocityY * delta;
    }
    this.tracers = this.tracers.filter(
      (tracer) =>
        tracer.x > -60 * scale &&
        tracer.x < width + 60 * scale &&
        tracer.y > -50 &&
        Math.hypot(tracer.x - tracer.originX, tracer.y - tracer.originY) <
          tracer.range,
    );
    this.flashes = this.flashes.filter(
      (flash) => time - flash.time < MUZZLE_TIME,
    );
    this.artillery = this.artillery.filter(
      (shell) => time - shell.time < ARTILLERY_LIFE,
    );
    if (time > this.nextDistant) {
      this.nextDistant = time + random(0.08, 0.3);
      const uscm = Math.random() < 0.5;
      const x = uscm ? width * random(0.05, 0.48) : width * random(0.52, 0.95);
      const y = base - random(4, 70) * scale;
      this.tracers.push({
        x,
        y,
        originX: x,
        originY: y,
        velocityX: (uscm ? 1 : -1) * random(280, 480) * scale,
        velocityY: random(-30, 8) * scale,
        wait: 0,
        width: scale,
        alpha: 0.65,
        near: false,
        stroke: uscm ? USCM_STROKE : UPP_STROKE,
        core: uscm ? USCM_DISTANT_CORE : UPP_DISTANT_CORE,
        range: width * random(0.15, 0.45),
      });
    }
    if (time > this.nextFlare) {
      this.nextFlare = time + random(6, 10);
      this.flares.push({
        x: width * random(0.2, 0.8),
        y: this.height * 0.03,
        start: time,
        intensity: 0,
        phase: random(0, 6),
      });
    }
    for (const flare of this.flares) {
      const age = time - flare.start;
      flare.y += 13 * scale * delta;
      flare.x += Math.sin(time * 0.7 + flare.phase) * 5 * scale * delta;
      flare.intensity =
        Math.min(1, age / 0.6) *
        (age > 9 ? Math.max(0, (FLARE_LIFE - age) / 2) : 1) *
        (0.92 + 0.08 * Math.sin(time * 23));
    }
    this.flares = this.flares.filter(
      (flare) => time - flare.start < FLARE_LIFE,
    );
  }
}
