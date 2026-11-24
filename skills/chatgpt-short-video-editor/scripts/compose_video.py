#!/usr/bin/env python3
"""Final composite, in the fixed order: footage (with punch-ins) -> CSS effects
overlay -> captions LAST.

  python3 compose_video.py --base <edit>/base_preview.mp4 \
      [--overlay <edit>/effects/overlay.webm] [--plan <edit>/effects/plan.json] \
      --ass <edit>/captions/captions.ass -o <edit>/preview.mp4 [--preview]

Render the cut with video-use using --no-subtitles first: its built-in
subtitle style would replace these one-line captions.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def probe(path: Path) -> tuple[int, int, float]:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height:format=duration", "-of", "json", str(path)],
        check=True, capture_output=True, text=True).stdout
    j = json.loads(out)
    s = j["streams"][0]
    return int(s["width"]), int(s["height"]), float(j["format"]["duration"])


def esc(p: Path) -> str:
    """Escape a path for an unquoted FFmpeg filter option value."""
    out = str(p.resolve())
    for ch in "\\:',;[]=":
        out = out.replace(ch, "\\" + ch)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", required=True, type=Path)
    ap.add_argument("--overlay", type=Path, help="WebM with alpha from build_effects.py + hyperframes render")
    ap.add_argument("--plan", type=Path, help="effects plan; its punch entries zoom the footage")
    ap.add_argument("--ass", type=Path, help="captions.ass from build_captions.py")
    ap.add_argument("--fontsdir", type=Path, default=Path.home() / "Library/Fonts")
    ap.add_argument("-o", "--output", required=True, type=Path)
    ap.add_argument("--preview", action="store_true", help="faster encode for the 720p preview")
    a = ap.parse_args()

    w, h, dur = probe(a.base)
    chain = []
    punches = []
    if a.plan:
        plan = json.loads(a.plan.read_text(encoding="utf-8"))
        punches = [f for f in plan.get("effects", []) if f.get("type") == "punch"]
    if punches:
        z = "+".join(f"between(t,{float(p['start']):.3f},{float(p['end']):.3f})*{float(p.get('scale', 1.1)) - 1:.3f}"
                     for p in punches)
        # Scale up inside the punch windows, then crop the centre back to the frame size.
        chain.append(f"[0:v]scale=w='trunc(iw*(1+{z})/2)*2':h='trunc(ih*(1+{z})/2)*2':eval=frame,"
                     f"crop={w}:{h}:(in_w-{w})/2:(in_h-{h})/2,setsar=1[v0]")
    else:
        chain.append("[0:v]null[v0]")
    cur = "[v0]"
    inputs = ["-i", str(a.base)]
    if a.overlay:
        if not a.overlay.exists():
            sys.exit(f"STOP: overlay not found: {a.overlay}")
        ow, oh, odur = probe(a.overlay)
        if abs(odur - dur) > 0.25:
            print(f"WARN overlay is {odur:.2f}s but the video is {dur:.2f}s")
        inputs += ["-c:v", "libvpx-vp9", "-i", str(a.overlay)]
        chain.append(f"[1:v]format=yuva420p,scale={w}:{h}[ov]")
        chain.append(f"{cur}[ov]overlay=0:0:format=auto:eof_action=pass[v1]")
        cur = "[v1]"
    if a.ass:
        if not a.ass.exists():
            sys.exit(f"STOP: captions not found: {a.ass}")
        chain.append(f"{cur}ass=filename={esc(a.ass)}:fontsdir={esc(a.fontsdir)}[v2]")
        cur = "[v2]"
    chain.append(f"{cur}format=yuv420p[outv]")
    crf = "23" if a.preview else "18"
    preset = "veryfast" if a.preview else "medium"
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", *inputs,
           "-filter_complex", ";".join(chain), "-map", "[outv]", "-map", "0:a?",
           "-c:v", "libx264", "-preset", preset, "-crf", crf, "-c:a", "copy",
           "-movflags", "+faststart", str(a.output)]
    subprocess.run(cmd, check=True)
    ow, oh, odur = probe(a.output)
    print(f"COMPOSED {a.output} {ow}x{oh} {odur:.2f}s punches={len(punches)} "
          f"overlay={'yes' if a.overlay else 'no'} captions={'yes' if a.ass else 'no'}")


if __name__ == "__main__":
    main()
