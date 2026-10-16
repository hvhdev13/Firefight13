import { useEffect, useMemo, useRef, useState } from 'react';
import { resolveAsset } from 'tgui/assets';

import { beatLevel, findDrops, LightBar, parseBeats } from './beats';
import { FeedScene } from './feed';

const INTRO_TIME = 1300;
const GLITCH_TIME = 1.2;
const TICKER_SPEED = 70;
const LOAD_RETRIES = 5;
const FEED_YEAR = 2182;
const HEADING = 300;
const TAPE_BLUR = '2.45 1.7';
const FRINGE = 0.75;
const BLACK_LEVEL = -0.06;
const GRAIN_WIDTH = 560;
const GRAIN_HEIGHT = 420;
const TONE = {
  type: 'linear',
  slope: 1 / (1 + BLACK_LEVEL),
  intercept: BLACK_LEVEL / (1 + BLACK_LEVEL),
} as const;

const COMPASS_POINTS = {
  0: 'N',
  45: 'NE',
  90: 'E',
  135: 'SE',
  180: 'S',
  225: 'SW',
  270: 'W',
  315: 'NW',
};

const COMPASS = [0, 1].flatMap(() =>
  Array.from({ length: 24 }, (_, step) => {
    const degrees = step * 15;
    return COMPASS_POINTS[degrees] || (degrees % 45 ? '·' : `${degrees}`);
  }),
);

const feedClock = () => {
  const now = new Date();
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${FEED_YEAR}.${pad(now.getMonth() + 1)}.${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}Z`;
};

const noiseTexture = () => {
  const canvas = document.createElement('canvas');
  canvas.width = 160;
  canvas.height = 120;
  const context = canvas.getContext('2d')!;
  const image = context.createImageData(160, 120);
  for (let pixel = 0; pixel < image.data.length; pixel += 4) {
    const grey = Math.random() * 255;
    image.data[pixel] = grey;
    image.data[pixel + 1] = grey;
    image.data[pixel + 2] = grey;
    image.data[pixel + 3] = 255;
  }
  context.putImageData(image, 0, 0);
  return `url(${canvas.toDataURL()})`;
};

type LobbyBackdropProps = {
  readonly music?: string;
  readonly beats?: string;
  readonly credit?: string;
  readonly volume: number;
  readonly effects: boolean;
  readonly news: string[];
  readonly place: string;
};

export const LobbyBackdrop = (props: LobbyBackdropProps) => {
  const { music, beats, credit, volume, effects, news, place } = props;

  const backdrop = useRef<HTMLDivElement>(null);
  const scene = useRef<HTMLCanvasElement>(null);
  const bloom = useRef<HTMLCanvasElement>(null);
  const noise = useRef<HTMLDivElement>(null);
  const compass = useRef<HTMLDivElement>(null);
  const ticker = useRef<HTMLDivElement>(null);
  const player = useRef<HTMLAudioElement>(null);
  const playerVolume = useRef(volume);
  const retries = useRef(0);
  const tickerWidth = useRef(1);

  const [texture] = useState(noiseTexture);
  const [clock, setClock] = useState(feedClock);
  const [intro, setIntro] = useState(true);
  const [creditShown, setCreditShown] = useState(0);

  const newsKey = news.join(' | ');
  const track = useMemo(() => parseBeats(beats), [beats]);
  const drops = useMemo(() => (track ? findDrops(track) : []), [track]);

  const startMusic = () => {
    const audio = player.current;
    if (!audio || playerVolume.current <= 0 || !audio.paused) return;
    audio
      .play()
      .then(() => setCreditShown(Date.now()))
      .catch(() => {});
  };

  useEffect(() => {
    const ticking = setInterval(() => setClock(feedClock()), 1000);
    const introEnd = setTimeout(() => setIntro(false), INTRO_TIME);
    document.addEventListener('pointerdown', startMusic);
    return () => {
      clearInterval(ticking);
      clearTimeout(introEnd);
      document.removeEventListener('pointerdown', startMusic);
    };
  }, []);

  useEffect(() => {
    tickerWidth.current = 1;
  }, [newsKey]);

  useEffect(() => {
    playerVolume.current = volume;
    const audio = player.current;
    if (!audio) return;
    audio.volume = volume;
    if (volume <= 0) {
      audio.pause();
    } else {
      startMusic();
    }
  }, [volume, music]);

  useEffect(() => {
    const screen = backdrop.current!.closest<HTMLElement>('.LobbyScreen')!;
    const set = (name: string, value: number) =>
      screen.style.setProperty(name, value.toFixed(3));

    const feed = new FeedScene(scene.current!, bloom.current!);
    const uscm = new LightBar();
    const upp = new LightBar();
    let compassWidth = 1;
    let glitchUntil = 0;
    let lastTrackTime = 0;
    let scroll = 0;
    let last = performance.now();
    let frame = 0;

    const aim = (heading: number) => {
      const strip = compass.current!;
      strip.style.transform = `translateX(${strip.parentElement!.clientWidth / 2 - (heading / 360) * compassWidth - compassWidth / 48}px)`;
    };

    const fit = () => {
      feed.build();
      compassWidth = compass.current!.scrollWidth / 2;
      aim(HEADING);
      if (!effects) feed.frame(performance.now() / 1000, 0, 0);
    };
    const resize = new ResizeObserver(fit);
    resize.observe(scene.current!);

    if (!effects) {
      set('--uscm', 0.3);
      set('--upp', 0.3);
      set('--glitch', 0);
    }

    const step = (now: number) => {
      const delta = Math.min(0.1, (now - last) / 1000);
      last = now;
      const time = now / 1000;

      const text = ticker.current;
      if (text) {
        scroll += delta * TICKER_SPEED;
        if (scroll >= tickerWidth.current) {
          tickerWidth.current = Math.max(1, text.scrollWidth / 2);
          scroll %= tickerWidth.current;
        }
        text.style.transform = `translateX(${-scroll}px)`;
      }

      if (effects) {
        const audio = player.current;
        let kickLevel = 0;
        let snareLevel = 0;
        if (track && audio && !audio.paused) {
          const trackTime = audio.currentTime;
          const index = Math.floor(trackTime * track.fps);
          kickLevel = beatLevel(track.kick, index);
          snareLevel = beatLevel(track.snare, index);
          if (
            trackTime - lastTrackTime < 0.5 &&
            drops.some((drop) => drop > lastTrackTime && drop <= trackTime)
          ) {
            glitchUntil = time + GLITCH_TIME;
            feed.drop(time);
          }
          lastTrackTime = trackTime;
        }

        const uscmPulse = uscm.lastPulse;
        uscm.update(time, kickLevel, true);
        if (uscm.lastPulse !== uscmPulse) feed.shoot(true);
        const uppPulse = upp.lastPulse;
        upp.update(time, snareLevel, time - uscm.lastPulse >= 0.3);
        if (upp.lastPulse !== uppPulse) feed.shoot(false);
        const glitch =
          glitchUntil > time
            ? Math.sin((Math.PI * (glitchUntil - time)) / GLITCH_TIME)
            : 0;

        set('--uscm', uscm.level);
        set('--upp', upp.level);
        set('--glitch', glitch);
        feed.frame(time, delta, glitch);

        aim(HEADING + 25 * Math.sin(time * 0.05) + 3 * Math.sin(time * 0.4));
        noise.current!.style.transform = `translate(${-Math.floor(Math.random() * GRAIN_WIDTH)}px, ${-Math.floor(Math.random() * GRAIN_HEIGHT)}px)`;
      }

      frame = requestAnimationFrame(step);
    };

    frame = requestAnimationFrame(step);
    return () => {
      cancelAnimationFrame(frame);
      resize.disconnect();
    };
  }, [track, drops, effects]);

  const retry = () => {
    if (retries.current >= LOAD_RETRIES) return;
    retries.current++;
    setTimeout(() => {
      player.current?.load();
      startMusic();
    }, 3000);
  };

  return (
    <div className="feedBackdrop" ref={backdrop}>
      {!!music && (
        <audio src={resolveAsset(music)} ref={player} loop onError={retry} />
      )}
      <svg className="feedFilters">
        <filter
          id="feedTape"
          x="-5%"
          y="-5%"
          width="110%"
          height="110%"
          colorInterpolationFilters="sRGB"
        >
          <feGaussianBlur
            in="SourceGraphic"
            stdDeviation={TAPE_BLUR}
            result="soft"
          />
          <feColorMatrix
            in="soft"
            type="matrix"
            values="1 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0"
            result="red"
          />
          <feOffset in="red" dx={-FRINGE} dy="0" result="redShift" />
          <feColorMatrix
            in="soft"
            type="matrix"
            values="0 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 1 0"
            result="cyan"
          />
          <feOffset in="cyan" dx={FRINGE} dy="0" result="cyanShift" />
          <feBlend in="redShift" in2="cyanShift" mode="screen" />
        </filter>
        <filter id="feedTone" colorInterpolationFilters="sRGB">
          <feComponentTransfer>
            <feFuncR {...TONE} />
            <feFuncG {...TONE} />
            <feFuncB {...TONE} />
          </feComponentTransfer>
        </filter>
      </svg>
      <div className="feedPicture">
        <canvas className="feedScene" ref={scene} />
        <canvas className="feedBloom" ref={bloom} />
      </div>
      <div className="feedTint" />
      <div className="feedSide feedSideUscm" />
      <div className="feedSide feedSideUpp" />
      <div
        className="feedNoise"
        ref={noise}
        style={{ backgroundImage: texture }}
      />
      <div className="feedLines" />
      <div className="feedVignette" />
      <div className="feedHud">
        <div className="feedCorner feedCornerTopLeft" />
        <div className="feedCorner feedCornerTopRight" />
        <div className="feedCorner feedCornerBottomLeft" />
        <div className="feedCorner feedCornerBottomRight" />
        <div className="feedHudTopLeft">
          <span className="feedRec">●</span> LIVE · FEED 07 · {place}
          {!!credit && !!creditShown && (
            <div key={creditShown} className="feedCredit">
              NOW PLAYING: {credit}
            </div>
          )}
        </div>
        <div className="feedCompass">
          <div className="feedCompassStrip" ref={compass}>
            {COMPASS.map((point, index) => (
              <span key={index}>{point}</span>
            ))}
          </div>
          <div className="feedCompassNeedle">▲</div>
        </div>
        <div className="feedHudTopRight">CAM 2 · IR · ZOOM 2.0X</div>
        <div className="feedReticle" />
        <div className="feedHudBottomRight">
          {clock}
          <br />
          GRID 41-09 · RNG 0420M
        </div>
      </div>
      <div className="feedTicker">
        <div className="feedTickerTag">LIVE MATCH</div>
        <div className="feedTickerTrack">
          <div className="feedTickerText" ref={ticker}>
            {[0, 1].map((copy) => (
              <span key={copy} className="feedTickerCopy">
                {news.map((line, index) => (
                  <span key={index}>
                    <span className="feedTickerMark">■</span>
                    {line}
                  </span>
                ))}
              </span>
            ))}
          </div>
        </div>
      </div>
      {intro && effects && (
        <div className="feedIntro">
          <div
            className="feedIntroNoise"
            style={{ backgroundImage: texture }}
          />
          <div className="feedIntroText">
            &gt; ESTABLISHING UPLINK
            <br />
            &gt; FEED 07 · {place}
            <br />
            &gt; SIGNAL OK
          </div>
        </div>
      )}
    </div>
  );
};
