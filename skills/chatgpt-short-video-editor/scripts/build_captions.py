#!/usr/bin/env python3
"""Build one-line short-video captions (max 8 characters per card) from
ElevenLabs Scribe word timestamps and an EDL.

Run with uv so the two text helpers are fetched automatically:

  uv run --with opencc --with jieba python build_captions.py --edit-dir <edit>

Reads   <edit>/edl.json and the transcripts it names.
Writes  <edit>/captions/master.srt     plain one-line cues (upload to platforms)
        <edit>/captions/captions.json  the same cards, which build_effects.py
                                       draws with CSS (pop-in, keyword colour)
Then it validates its own output and exits non-zero if any rule fails.

Rules (fixed, not style options):
  * one visible line per card, never two or three stacked lines;
  * at most 8 display characters per card (CJK and full-width = 1,
    half-width letters, digits and spaces = 0.5);
  * a longer phrase becomes the next card, split at word boundaries
    (jieba), never inside a word, an English word, or a number;
  * cards never overlap and never cross an EDL range boundary;
  * punctuation is not shown; it only marks where a card may end.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

MAX_WIDTH_DEFAULT = 8.0
PAUSE_BREAK_S = 0.35      # a silence this long always ends a card
MERGE_GAP_S = 0.25        # hold a card until the next one if the gap is short
MIN_CARD_S = 0.35
FILLERS = {"呃", "嗯", "额", "唔", "um", "uh", "erm"}
BREAK_TOKENS = re.compile(r"^[\s,，。．.!！?？;；:：、…—–\-~～·]+$")
STRIP_CHARS = "，。．、；：？！…—–「」『』（）()【】《》〈〉\"'“”‘’,;:!?~～·"


# ---------------------------------------------------------------- width ----

def char_width(ch: str) -> float:
    if ch == " ":
        return 0.5
    if unicodedata.east_asian_width(ch) in ("W", "F"):
        return 1.0
    return 0.5


def text_width(s: str) -> float:
    return sum(char_width(c) for c in s)


def fmt_width(w: float) -> str:
    return f"{w:g}"


# ------------------------------------------------------------- loading -----

def load_ranges(edit_dir: Path) -> tuple[list[dict], dict[str, dict]]:
    edl_path = edit_dir / "edl.json"
    if not edl_path.exists():
        sys.exit(f"STOP: {edl_path} not found; build the EDL first.")
    edl = json.loads(edl_path.read_text(encoding="utf-8"))
    transcripts: dict[str, dict] = {}
    names = edl.get("transcripts") or {}
    for key in {r["source"] for r in edl["ranges"]}:
        rel = names.get(key)
        if not rel:
            sys.exit(f"STOP: edl.json has no transcript for source {key!r}.")
        p = (edit_dir / rel).resolve()
        if not p.exists():
            sys.exit(f"STOP: transcript not found: {p}")
        transcripts[key] = json.loads(p.read_text(encoding="utf-8"))
    ranges = sorted(edl["ranges"], key=lambda r: float(r["offset"]))
    return ranges, transcripts


# --------------------------------------------------------- tokenising ------

class Tok:
    __slots__ = ("text", "start", "end")

    def __init__(self, text: str, start: float, end: float):
        self.text, self.start, self.end = text, start, end

    def __repr__(self) -> str:  # pragma: no cover - debug aid
        return f"Tok({self.text!r},{self.start:.2f},{self.end:.2f})"


def phrases_for_range(rng: dict, words: list[dict], keep_fillers: bool) -> list[list[Tok]]:
    """Return phrases (lists of raw character/word tokens on the OUTPUT timeline)."""
    r0, r1, off = float(rng["start"]), float(rng["end"]), float(rng["offset"])
    eps = 0.02
    phrases: list[list[Tok]] = []
    cur: list[Tok] = []
    last_end: float | None = None
    pending_space = False

    def flush() -> None:
        nonlocal cur
        if cur:
            phrases.append(cur)
        cur = []

    for w in words:
        s, e = float(w.get("start", 0.0)), float(w.get("end", 0.0))
        if s < r0 - eps or e > r1 + eps:
            continue
        kind = w.get("type", "word")
        text = w.get("text", "")
        if kind == "spacing":
            pending_space = True
            continue
        if kind != "word":          # audio_event etc. are never captioned
            flush()
            continue
        if BREAK_TOKENS.match(text) or text.strip() == "":
            flush()
            pending_space = False
            continue
        if not keep_fillers and text.strip().lower() in FILLERS:
            pending_space = False
            continue
        if last_end is not None and s - last_end >= PAUSE_BREAK_S:
            flush()
        so = max(off, s - r0 + off)
        eo = min(off + (r1 - r0), e - r0 + off)
        eo = max(eo, so)
        # Keep one space between two Latin words; none next to CJK.
        if pending_space and cur and re.search(r"[A-Za-z0-9]$", cur[-1].text) and re.match(r"[A-Za-z0-9]", text):
            text = " " + text
        cur.append(Tok(text, so, eo))
        pending_space = False
        last_end = e
    flush()
    return phrases


def char_stream(phrase: list[Tok]) -> list[Tok]:
    """Explode tokens into per-character tokens, spreading time evenly."""
    out: list[Tok] = []
    for t in phrase:
        n = len(t.text)
        span = (t.end - t.start) / n if n else 0.0
        for i, ch in enumerate(t.text):
            out.append(Tok(ch, t.start + i * span, t.start + (i + 1) * span))
    return out


def remap(chars: list[Tok], new_text: str) -> list[Tok]:
    """Give each character of new_text a time, proportionally if lengths differ."""
    if len(new_text) == len(chars):
        return [Tok(c, o.start, o.end) for c, o in zip(new_text, chars)]
    n_old, n_new = len(chars), len(new_text)
    out = []
    for i, c in enumerate(new_text):
        a = chars[min(n_old - 1, i * n_old // n_new)]
        b = chars[min(n_old - 1, max(0, ((i + 1) * n_old - 1) // n_new))]
        out.append(Tok(c, a.start, b.end))
    return out


def apply_replacements(chars: list[Tok], reps: list[tuple[str, str]]) -> tuple[list[Tok], set[int]]:
    """Apply user corrections; return new chars and indices that start a locked span."""
    locked: set[int] = set()   # positions inside a replaced span (no break inside)
    for src, dst in reps:
        text = "".join(c.text for c in chars)
        if src not in text:
            continue
        out: list[Tok] = []
        new_locked: set[int] = set()
        i = 0
        while i < len(chars):
            if text.startswith(src, i):
                span = chars[i:i + len(src)]
                rep = remap(span, dst) if dst else []
                base = len(out)
                out.extend(rep)
                for k in range(base + 1, base + len(rep)):
                    new_locked.add(k)
                i += len(src)
            else:
                if i in locked:
                    new_locked.add(len(out))
                out.append(chars[i])
                i += 1
        chars, locked = out, new_locked
    return chars, locked


def to_traditional_units(phrase: list[Tok], cc, jieba, reps) -> list[Tok]:
    """Simplified phrase -> Traditional word units (each unit is unbreakable)."""
    chars = char_stream(phrase)
    simp = "".join(c.text for c in chars)
    if not simp.strip():
        return []
    # Word boundaries come from jieba on the original (Simplified) text.
    cuts: set[int] = set()
    pos = 0
    for w in jieba.cut(simp, HMM=True):
        pos += len(w)
        cuts.add(pos)
    trad = cc.convert(simp)
    if len(trad) != len(simp):
        # Rare length-changing conversion: convert word by word instead.
        pieces, pos, new_cuts = [], 0, set()
        for w in jieba.cut(simp, HMM=True):
            tw = cc.convert(w)
            pieces.append(tw)
            pos += len(tw)
            new_cuts.add(pos)
        trad, cuts = "".join(pieces), new_cuts
    chars = remap(chars, trad)
    # Mark cut positions on the characters, then apply user corrections.
    boundary = [i in cuts for i in range(1, len(chars) + 1)]   # boundary after char i
    chars2, locked = apply_replacements(chars, reps)
    if len(chars2) != len(chars):
        # Recompute boundaries after replacement with jieba on the new text.
        text2 = "".join(c.text for c in chars2)
        cuts2, pos = set(), 0
        for w in jieba.cut(text2, HMM=True):
            pos += len(w)
            cuts2.add(pos)
        boundary = [i in cuts2 for i in range(1, len(chars2) + 1)]
    chars = chars2
    # Never break inside a Latin word/number or inside a replaced span.
    units: list[Tok] = []
    cur: Tok | None = None
    for i, c in enumerate(chars):
        if cur is None:
            cur = Tok(c.text, c.start, c.end)
        else:
            cur.text += c.text
            cur.end = c.end
        nxt = chars[i + 1].text if i + 1 < len(chars) else ""
        latin_join = bool(re.match(r"[A-Za-z0-9.%+#&'_-]", c.text)) and bool(re.match(r"[A-Za-z0-9.%+#&'_-]", nxt))
        if i + 1 < len(chars) and (latin_join or (i + 1) in locked or not boundary[i]):
            continue
        units.append(cur)
        cur = None
    if cur is not None:
        units.append(cur)
    # Strip punctuation inside units (a correction may have carried some).
    clean: list[Tok] = []
    for u in units:
        t = u.text.translate({ord(ch): None for ch in STRIP_CHARS})
        if t.strip():
            clean.append(Tok(t, u.start, u.end))
    # A leading space on a unit only matters between two Latin units.
    for i, u in enumerate(clean):
        if u.text.startswith(" ") and (i == 0 or not re.search(r"[A-Za-z0-9]$", clean[i - 1].text)):
            u.text = u.text.lstrip()
    return clean


# ------------------------------------------------------------ splitting ----

def split_long_unit(u: Tok, max_w: float) -> list[Tok]:
    """A single unit wider than the limit (very rare): split by characters."""
    out, cur = [], None
    for c in char_stream([u]):
        if cur is not None and text_width((cur.text + c.text).strip()) > max_w:
            out.append(cur)
            cur = None
        if cur is None:
            cur = Tok(c.text.lstrip(), c.start, c.end)
        else:
            cur.text += c.text
            cur.end = c.end
    if cur is not None:
        out.append(cur)
    return out


LEAD_WORDS = ("是", "就是", "因為", "所以", "但是", "可是", "然後", "如果", "還是", "只是",
              "而且", "或是", "或者", "讓", "跟", "和", "去", "把", "在", "其實", "那")
TAIL_CHARS = ("的", "了", "呢", "嗎", "吧", "啊", "喔", "說", "到")
KEEP_WORDS = ("一对一", "一对多", "一人公司", "体验课", "公开课", "短视频", "逐字稿")


def break_bonus(left: str, right: str) -> float:
    """How natural it is to start a new card between two units."""
    bonus = 0.0
    if right.startswith(LEAD_WORDS):
        bonus += 6.0
    if left.endswith(TAIL_CHARS) and not re.search(r"(我|你|他|她|它|們|您)的$", left):
        bonus += 4.0
    if re.match(r"(我|你|他|她|它|您)", right):
        bonus += 3.0          # a card may start with a pronoun
    if bool(re.search(r"[A-Za-z0-9]$", left)) != bool(re.match(r"\s*[A-Za-z0-9]", right)):
        bonus += 5.0          # switch between English and Chinese
    return bonus


def split_phrase(units: list[Tok], max_w: float) -> list[list[Tok]]:
    """DP: fewest, most even cards, each <= max_w wide, breaking between units."""
    flat: list[Tok] = []
    for u in units:
        flat.extend(split_long_unit(u, max_w) if text_width(u.text.strip()) > max_w else [u])
    n = len(flat)
    if n == 0:
        return []

    def card_text(i: int, j: int) -> str:
        return "".join(t.text for t in flat[i:j]).strip()

    INF = float("inf")
    best = [INF] * (n + 1)
    back = [0] * (n + 1)
    best[0] = 0.0
    for j in range(1, n + 1):
        for i in range(j - 1, -1, -1):
            w = text_width(card_text(i, j))
            if w > max_w:
                break
            # Fewest cards first, then natural break points, then even widths.
            cost = best[i] + 30.0 + 0.5 * (max_w - w) ** 2
            if w < 2 and n > 1:
                cost += 60.0          # avoid a lonely one-character card
            if i > 0:
                cost -= break_bonus(flat[i - 1].text, flat[i].text)
            if cost < best[j]:
                best[j], back[j] = cost, i
    cards: list[list[Tok]] = []
    j = n
    while j > 0:
        i = back[j]
        cards.append(flat[i:j])
        j = i
    return cards[::-1]


# -------------------------------------------------------------- writing ----

def ts_srt(t: float) -> str:
    ms = max(0, int(round(t * 1000)))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def build(args: argparse.Namespace) -> list[dict]:
    try:
        import jieba  # type: ignore
        import opencc  # type: ignore
    except ImportError:
        sys.exit("STOP: run with `uv run --with opencc --with jieba python build_captions.py ...`")
    jieba.setLogLevel(60)
    for wd in KEEP_WORDS:
        jieba.add_word(wd, freq=200000)
    cc = opencc.OpenCC("s2twp")
    reps: list[tuple[str, str]] = []
    if args.replace:
        for line in Path(args.replace).read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                a, b = line.split("=", 1)
                reps.append((a.strip(), b.strip()))
    edit_dir = Path(args.edit_dir).resolve()
    ranges, transcripts = load_ranges(edit_dir)
    cards: list[dict] = []
    for ri, rng in enumerate(ranges):
        words = transcripts[rng["source"]].get("words", [])
        for phrase in phrases_for_range(rng, words, args.keep_fillers):
            units = to_traditional_units(phrase, cc, jieba, reps)
            for card in split_phrase(units, args.max_chars):
                text = "".join(t.text for t in card).strip()
                if not text:
                    continue
                cards.append({"range": ri, "text": text, "start": card[0].start, "end": card[-1].end})
    # Timing clean-up: no overlaps, short gaps held, minimum duration.
    range_end = {i: float(r["offset"]) + float(r["end"]) - float(r["start"]) for i, r in enumerate(ranges)}
    cards.sort(key=lambda c: c["start"])
    for i, c in enumerate(cards):
        nxt = cards[i + 1]["start"] if i + 1 < len(cards) else None
        limit = range_end[c["range"]]
        if nxt is not None:
            limit = min(limit, nxt)
        end = max(c["end"], c["start"] + MIN_CARD_S)
        if nxt is not None and 0 <= nxt - end <= MERGE_GAP_S and cards[i + 1]["range"] == c["range"]:
            end = nxt
        c["end"] = round(min(end, limit), 3)
        c["start"] = round(c["start"], 3)
    cards = [c for c in cards if c["end"] - c["start"] >= 0.08]
    return cards


def write_outputs(cards: list[dict], args: argparse.Namespace) -> Path:
    out_dir = Path(args.out_dir).resolve() if args.out_dir else Path(args.edit_dir).resolve() / "captions"
    out_dir.mkdir(parents=True, exist_ok=True)
    srt = []
    for i, c in enumerate(cards, 1):
        srt.append(f"{i}\n{ts_srt(c['start'])} --> {ts_srt(c['end'])}\n{c['text']}\n")
    (out_dir / "master.srt").write_text("\n".join(srt), encoding="utf-8")

    meta = {"max_chars": args.max_chars, "cards": cards}
    (out_dir / "captions.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    return out_dir


def validate(cards: list[dict], max_w: float) -> list[str]:
    problems = []
    for i, c in enumerate(cards):
        t = c["text"]
        if "\n" in t or "\\N" in t:
            problems.append(f"card {i + 1} has more than one line: {t!r}")
        w = text_width(t)
        if w > max_w:
            problems.append(f"card {i + 1} is {fmt_width(w)} wide (> {fmt_width(max_w)}): {t}")
        if any(ch in STRIP_CHARS for ch in t):
            problems.append(f"card {i + 1} shows punctuation: {t}")
        if c["end"] <= c["start"]:
            problems.append(f"card {i + 1} has no duration")
        if i and cards[i - 1]["end"] > c["start"] + 1e-6:
            problems.append(f"cards {i} and {i + 1} overlap")
    return problems


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--edit-dir", required=True)
    ap.add_argument("--out-dir", help="default: <edit-dir>/captions")
    ap.add_argument("--max-chars", type=float, default=MAX_WIDTH_DEFAULT,
                    help="display width per card; 8 is the house rule, lower only on request")
    ap.add_argument("--replace", help="UTF-8 file of corrections, one `錯字=正字` per line (e.g. chat gpt=ChatGPT)")
    ap.add_argument("--keep-fillers", action="store_true", help="keep 呃/嗯 instead of dropping them")
    args = ap.parse_args()
    if args.max_chars > MAX_WIDTH_DEFAULT:
        sys.exit("STOP: the caption rule is at most 8 characters per line.")

    cards = build(args)
    out_dir = write_outputs(cards, args)
    problems = validate(cards, args.max_chars)
    widest = max((text_width(c["text"]) for c in cards), default=0)
    print(f"CAPTIONS {len(cards)} cards, widest {fmt_width(widest)}, out {out_dir}")
    if problems:
        for p in problems:
            print(f"CAPTION_FAIL {p}")
        sys.exit(1)
    print("CAPTION_CHECK PASS one line per card, <= "
          f"{fmt_width(args.max_chars)} characters, no overlaps, no punctuation")


if __name__ == "__main__":
    main()
