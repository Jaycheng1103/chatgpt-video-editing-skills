#!/usr/bin/env python3
"""Turn the captions and an effects plan into one HyperFrames overlay project
(transparent 1080x1920 HTML/CSS/GSAP), rendered as a WebM with alpha. The
captions are drawn here with CSS, on the top layer, so no FFmpeg subtitle
filter (libass) is needed.

  python3 build_effects.py --captions <edit>/captions/captions.json \
      --plan <edit>/effects/plan.json --out <edit>/effects/overlay
  npx hyperframes check <edit>/effects/overlay --json
  npx hyperframes render <edit>/effects/overlay --format webm -o <edit>/effects/overlay.webm

plan.json (times are on the OUTPUT timeline, taken from captions/captions.json):
{
  "duration": 60.02,                 # ffprobe length of the cut video
  "accent": "#FFD84D",               # highlight colour (optional)
  "progress": true,                  # thin progress bar at the top (optional)
  "highlight": ["流量", "諮詢"],       # caption words shown in the accent colour
  "effects": [
    {"type": "keyword", "start": 2.5, "end": 4.2, "text": "流量目標"},
    {"type": "step", "start": 12.7, "end": 15.0, "num": "1", "text": "做流量"},
    {"type": "list", "start": 40.0, "end": 46.0, "title": "一個系統管理",
     "items": ["報名", "出席", "直播"]},
    {"type": "punch", "start": 8.9, "end": 11.0, "scale": 1.12}
  ]
}

`punch` is a zoom on the footage itself; compose_video.py applies it with
FFmpeg. Every other type becomes an animated element in the overlay.
Only one keyword/step/list is on screen at a time. Without --plan the
overlay holds the captions only; without --captions, the effects only.
"""
from __future__ import annotations

import argparse
import html
import json
import shutil
import sys
import unicodedata
from pathlib import Path

W, H = 1080, 1920
GSAP = "https://cdn.jsdelivr.net/npm/gsap@3.15.0/dist/gsap.min.js"
FONT_FILE = "SourceHanSansTW-Bold.otf"
CAP_SIZE = 84          # 8 characters = 672 px: clear of the right-hand action rail
CAP_TOP = 1050         # caption band 1050-1200 px: inside every platform safe area
LIMITS = {"keyword": 8, "step": 8, "list_item": 8, "list_title": 10}


def width(s: str) -> float:
    return sum(1.0 if unicodedata.east_asian_width(c) in ("W", "F") else 0.5 for c in s)


def find_font() -> Path | None:
    for d in (Path.home() / "Library/Fonts", Path("/Library/Fonts"), Path.home() / ".local/share/fonts"):
        p = d / FONT_FILE
        if p.is_file():
            return p
    return None


def check_plan(plan: dict) -> list[str]:
    errs = []
    dur = float(plan.get("duration", 0))
    if dur <= 0:
        errs.append("plan.duration must be the ffprobe length of the cut video")
    shown = []
    for i, fx in enumerate(plan.get("effects", [])):
        t, s, e = fx.get("type"), float(fx.get("start", -1)), float(fx.get("end", -1))
        tag = f"effect {i + 1} ({t})"
        if t not in ("keyword", "step", "list", "punch"):
            errs.append(f"{tag}: unknown type")
            continue
        if not (0 <= s < e <= dur + 1e-3):
            errs.append(f"{tag}: start/end must satisfy 0 <= start < end <= duration")
        if t == "keyword":
            if not fx.get("text") or width(fx["text"]) > LIMITS["keyword"]:
                errs.append(f"{tag}: text must be 1-8 characters")
            if e - s < 0.8:
                errs.append(f"{tag}: hold at least 0.8 s so it can be read")
        if t == "step":
            if not fx.get("text") or width(fx["text"]) > LIMITS["step"]:
                errs.append(f"{tag}: text must be 1-8 characters")
        if t == "list":
            items = fx.get("items") or []
            if not 2 <= len(items) <= 4:
                errs.append(f"{tag}: 2-4 items")
            if any(width(x) > LIMITS["list_item"] for x in items):
                errs.append(f"{tag}: each item at most 8 characters")
            if width(fx.get("title", "")) > LIMITS["list_title"]:
                errs.append(f"{tag}: title at most 10 characters")
            if e - s < 1.2 + 0.3 * len(items):
                errs.append(f"{tag}: too short to read every item")
        if t == "punch":
            sc = float(fx.get("scale", 1.1))
            if not 1.03 <= sc <= 1.25:
                errs.append(f"{tag}: scale between 1.03 and 1.25")
        if t != "punch":
            shown.append((s, e, tag))
    shown.sort()
    for (s1, e1, a), (s2, e2, b) in zip(shown, shown[1:]):
        if s2 < e1:
            errs.append(f"{a} and {b} overlap; show one at a time")
    return errs


CSS = """
@font-face { font-family: "CapFont"; src: url("assets/fonts/%(font)s"); font-weight: 700; }
:root { --accent: %(accent)s; --ink: #111111; --paper: #ffffff; }
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { width: 1080px; height: 1920px; overflow: hidden; background: transparent; }
#root { position: relative; width: 100%%; height: 100%%; font-family: "CapFont", sans-serif; }
.slot { position: absolute; left: 0; width: 1080px; }
/* keyword: big word with a marker sweep, in the upper band (300-520 px, clear of the platform top bar) */
.kw { top: 300px; height: 220px; display: flex; justify-content: center; align-items: center; }
.kw .fx { position: relative; padding: 18px 40px; }
.kw .mark { position: absolute; left: 0; right: 0; bottom: 14px; height: 46%%; background: var(--accent);
  border-radius: 14px; transform-origin: left center; }
.kw .word { position: relative; font-size: 128px; line-height: 1; color: var(--paper);
  -webkit-text-stroke: 10px var(--ink); paint-order: stroke fill; letter-spacing: 0.02em; }
/* step chip: badge + short label, top-left */
.st { top: 330px; height: 150px; padding-left: 96px; }
.st .fx { display: inline-flex; align-items: center; gap: 22px; background: var(--paper);
  border-radius: 999px; padding: 16px 40px 16px 16px; box-shadow: 0 10px 0 var(--ink); border: 5px solid var(--ink); }
.st .num { width: 92px; height: 92px; border-radius: 50%%; background: var(--accent); color: var(--ink);
  display: flex; align-items: center; justify-content: center; font-size: 60px; border: 5px solid var(--ink); }
.st .label { font-size: 66px; color: var(--ink); line-height: 1; }
/* list card: title + 2-4 items that tick in one by one, above the caption band */
.ls { top: 600px; height: 430px; display: flex; justify-content: center; }
.ls .fx { width: 860px; background: rgba(255,255,255,0.96); border: 6px solid var(--ink); border-radius: 36px;
  box-shadow: 0 14px 0 var(--ink); padding: 30px 46px; }
.ls .title { font-size: 54px; color: var(--ink); margin-bottom: 14px; }
.ls .item { display: flex; align-items: center; gap: 22px; font-size: 58px; color: var(--ink); line-height: 1.5; }
.ls .tick { width: 54px; height: 54px; border-radius: 14px; background: var(--accent); border: 5px solid var(--ink);
  display: flex; align-items: center; justify-content: center; font-size: 34px; }
/* captions: one line, never wraps, pops in, top layer */
.caps { top: %(cap_top)spx; height: 150px; z-index: 10; }
.cap { position: absolute; left: 0; width: 1080px; height: 150px; display: flex; justify-content: center; padding-right: 110px;
  align-items: center; visibility: hidden; opacity: 0; }
.cap span.t { display: inline-block; white-space: nowrap; font-size: %(cap_size)spx; line-height: 1; color: var(--paper);
  -webkit-text-stroke: 13px var(--ink); paint-order: stroke fill; letter-spacing: 0.03em; }
.cap .hl { color: var(--accent); }
/* progress bar */
.pg { top: 0; height: 10px; }
.pg .fx { width: 100%%; height: 10px; background: var(--accent); transform-origin: left center; }
"""


def caption_html(text: str, words: list[str]) -> str:
    """Escape the caption and colour the highlight words."""
    marks = [False] * len(text)
    for w in sorted({w for w in words if w}, key=len, reverse=True):
        i = text.find(w)
        while i != -1:
            for k in range(i, i + len(w)):
                marks[k] = True
            i = text.find(w, i + len(w))
    out, i = [], 0
    while i < len(text):
        j = i
        while j < len(text) and marks[j] == marks[i]:
            j += 1
        chunk = html.escape(text[i:j])
        out.append(f'<span class="hl">{chunk}</span>' if marks[i] else chunk)
        i = j
    return "".join(out)


def check_captions(cards: list[dict], dur: float) -> list[str]:
    errs = []
    for i, c in enumerate(cards):
        if "\n" in c["text"] or width(c["text"]) > 8:
            errs.append(f"caption {i + 1} breaks the one-line, 8-character rule: {c['text']!r}")
        if i and cards[i - 1]["end"] > c["start"] + 1e-6:
            errs.append(f"captions {i} and {i + 1} overlap")
        if c["end"] > dur + 0.05:
            errs.append(f"caption {i + 1} ends after the video ({c['end']} > {dur})")
    return errs


def build(plan: dict, out: Path, font: Path, cards: list[dict]) -> None:
    dur = float(plan["duration"])
    accent = plan.get("accent", "#FFD84D")
    els, js = [], []
    track = 1
    if cards:
        caps = "".join(f'<div id="c{i}" class="cap"><span class="t">{caption_html(c["text"], plan.get("highlight", []))}</span></div>'
                       for i, c in enumerate(cards))
        els.append(f'<div id="caps" class="clip slot caps" data-start="0" data-duration="{dur:.3f}" '
                   f'data-track-index="3" data-track-kind="captions">{caps}</div>')
        for i, c in enumerate(cards):
            s, e = float(c["start"]), min(float(c["end"]), dur)
            js += [
                f'tl.set("#c{i}", {{visibility: "visible", opacity: 1}}, {s:.3f});',
                f'tl.fromTo("#c{i} .t", {{scale: 0.84, y: 14}}, {{scale: 1, y: 0, duration: 0.18, ease: "back.out(2.6)"}}, {s:.3f});',
                f'tl.set("#c{i}", {{visibility: "hidden", opacity: 0}}, {e:.3f});',
            ]
    if plan.get("progress"):
        els.append(f'<div id="pg" class="clip slot pg" data-start="0" data-duration="{dur:.3f}" '
                   f'data-track-index="0"><div class="fx"></div></div>')
        js.append(f'tl.fromTo("#pg .fx", {{scaleX: 0}}, {{scaleX: 1, duration: {dur:.3f}, ease: "none"}}, 0);')
    n = 0
    for fx in sorted(plan.get("effects", []), key=lambda f: float(f["start"])):
        t = fx["type"]
        if t == "punch":
            continue
        n += 1
        s, e = float(fx["start"]), float(fx["end"])
        d = e - s
        eid = f"{t[:2]}{n}"
        sel = f"#{eid}"
        head = (f'<div id="{eid}" class="clip slot {"kw" if t == "keyword" else "st" if t == "step" else "ls"}" '
                f'data-start="{s:.3f}" data-duration="{d:.3f}" data-track-index="{track}">')
        track = 2 if track == 1 else 1
        out_at = max(0.0, d - 0.22)
        if t == "keyword":
            els.append(head + f'<div class="fx"><div class="mark"></div>'
                       f'<div class="word">{html.escape(fx["text"])}</div></div></div>')
            js += [
                f'tl.fromTo("{sel} .fx", {{scale: 0.55, y: 40, opacity: 0, filter: "blur(10px)"}}, '
                f'{{scale: 1, y: 0, opacity: 1, filter: "blur(0px)", duration: 0.38, ease: "back.out(2.2)"}}, {s:.3f});',
                f'tl.fromTo("{sel} .mark", {{scaleX: 0}}, {{scaleX: 1, duration: 0.32, ease: "power3.out"}}, {s + 0.14:.3f});',
                f'tl.to("{sel} .fx", {{opacity: 0, scale: 1.08, filter: "blur(8px)", duration: 0.2, ease: "power2.in"}}, {s + out_at:.3f});',
            ]
        elif t == "step":
            num = html.escape(str(fx.get("num", "")))
            els.append(head + f'<div class="fx"><div class="num">{num}</div>'
                       f'<div class="label">{html.escape(fx["text"])}</div></div></div>')
            js += [
                f'tl.fromTo("{sel} .fx", {{x: -140, opacity: 0}}, {{x: 0, opacity: 1, duration: 0.45, ease: "expo.out"}}, {s:.3f});',
                f'tl.fromTo("{sel} .num", {{rotation: -90, scale: 0.4}}, {{rotation: 0, scale: 1, duration: 0.7, ease: "elastic.out(1, 0.5)"}}, {s + 0.08:.3f});',
                f'tl.to("{sel} .fx", {{x: -60, opacity: 0, duration: 0.2, ease: "power3.in"}}, {s + out_at:.3f});',
            ]
        else:
            items = "".join(f'<div class="item"><div class="tick">✓</div><div>{html.escape(x)}</div></div>'
                            for x in fx["items"])
            title = f'<div class="title">{html.escape(fx.get("title", ""))}</div>' if fx.get("title") else ""
            els.append(head + f'<div class="fx">{title}{items}</div></div>')
            js += [
                f'tl.fromTo("{sel} .fx", {{y: 60, opacity: 0}}, {{y: 0, opacity: 1, duration: 0.42, ease: "power4.out"}}, {s:.3f});',
                f'tl.fromTo("{sel} .item", {{x: 40, opacity: 0}}, {{x: 0, opacity: 1, duration: 0.34, ease: "back.out(1.7)", stagger: 0.3}}, {s + 0.3:.3f});',
                f'tl.fromTo("{sel} .tick", {{scale: 0}}, {{scale: 1, duration: 0.3, ease: "back.out(3)", stagger: 0.3}}, {s + 0.42:.3f});',
                f'tl.to("{sel} .fx", {{y: 30, opacity: 0, duration: 0.22, ease: "power2.in"}}, {s + out_at:.3f});',
            ]
    out.mkdir(parents=True, exist_ok=True)
    (out / "assets/fonts").mkdir(parents=True, exist_ok=True)
    dst = out / "assets/fonts" / FONT_FILE
    if not dst.exists():
        shutil.copy2(font, dst)
    page = f"""<!doctype html>
<html lang="zh-Hant" data-resolution="portrait">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width={W}, height={H}" />
    <script src="{GSAP}"></script>
    <style>{CSS % {"font": FONT_FILE, "accent": html.escape(accent), "cap_top": CAP_TOP, "cap_size": CAP_SIZE}}</style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="{dur:.3f}"
         data-width="{W}" data-height="{H}" data-layout-allow-overlap>
      {chr(10).join("      " + e for e in els).strip()}
    </div>
    <script>
      const tl = gsap.timeline({{ paused: true }});
      {chr(10).join("      " + j for j in js).strip()}
      window.__timelines["main"] = tl;
      tl.seek(0);
    </script>
  </body>
</html>
"""
    (out / "index.html").write_text(page, encoding="utf-8")
    (out / "hyperframes.json").write_text(json.dumps({"paths": {"assets": "assets"}}, indent=2), encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--captions", help="captions/captions.json from build_captions.py")
    ap.add_argument("--plan", help="effects plan (see above)")
    ap.add_argument("--duration", type=float, help="video length when there is no plan")
    ap.add_argument("--out", required=True, help="HyperFrames project directory to write")
    ap.add_argument("--font", help=f"path to {FONT_FILE} (default: the installed one)")
    args = ap.parse_args()
    if not args.plan and not args.captions:
        sys.exit("STOP: pass --captions, --plan, or both.")
    plan = json.loads(Path(args.plan).read_text(encoding="utf-8")) if args.plan else {}
    if args.duration:
        plan["duration"] = args.duration
    plan.setdefault("effects", [])
    cards = json.loads(Path(args.captions).read_text(encoding="utf-8"))["cards"] if args.captions else []
    errs = check_plan(plan) + check_captions(cards, float(plan.get("duration", 0)))
    if errs:
        for e in errs:
            print(f"EFFECTS_FAIL {e}")
        sys.exit(1)
    font = Path(args.font) if args.font else find_font()
    if not font or not font.is_file():
        sys.exit(f"STOP: {FONT_FILE} not found; run the setup Skill.")
    build(plan, Path(args.out), font, cards)
    kinds = [f["type"] for f in plan.get("effects", [])]
    print(f"EFFECTS_OK {len(cards)} captions, {len(kinds)} effects ({', '.join(sorted(set(kinds))) or 'none'}), "
          f"progress={'on' if plan.get('progress') else 'off'}, project {Path(args.out).resolve()}")


if __name__ == "__main__":
    main()
