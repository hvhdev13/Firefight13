import array
import os
import subprocess
import sys

FPS = 40
RATE = 8000
DIGITS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"


def band(path, audio_filter):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-af", audio_filter, "-ar", str(RATE), "-f", "s16le", "-"],
        check=True,
        capture_output=True,
    ).stdout
    samples = array.array("h", raw)
    step = RATE // FPS
    levels = []
    for start in range(0, len(samples) - step + 1, step):
        chunk = samples[start:start + step]
        levels.append((sum(s * s for s in chunk) / step) ** 0.5)
    return levels


def percentile(values, share):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(len(ordered) * share))] or 1


def onsets(levels, window=6):
    hits = []
    for i, level in enumerate(levels):
        before = levels[max(0, i - window):i] or [level]
        hits.append(max(0.0, level - sum(before) / len(before)))
    return hits


def scale(values, share=0.985):
    top = percentile(values, share)
    return [min(1.0, value / top) for value in values]


def smooth(values, width):
    out = []
    total = 0.0
    for i, value in enumerate(values):
        total += value
        if i >= width:
            total -= values[i - width]
        out.append(total / min(i + 1, width))
    return out


def encode(values):
    return "".join(DIGITS[round(value * 63)] for value in values)


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: lobby_beats.py <track>")
    track = sys.argv[1]
    kick = scale(onsets(band(track, "lowpass=f=150,lowpass=f=150")))
    snare = scale(onsets(band(track, "highpass=f=1500,highpass=f=1500"), 3))
    energy = scale(smooth(band(track, "anull"), FPS * 2), 0.99)
    frames = min(len(kick), len(snare), len(energy))
    out = os.path.splitext(track)[0] + ".beats"
    with open(out, "w", newline="\n") as f:
        f.write(f"{FPS}\n{encode(kick[:frames])}\n{encode(snare[:frames])}\n{encode(energy[:frames])}\n")
    print(f"Wrote {out}: {frames} frames")


if __name__ == "__main__":
    main()
