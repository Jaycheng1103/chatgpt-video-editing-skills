#!/bin/sh
# Download (if a URL) and measure a reference short video for style analysis.
#   analyze_reference.sh <url-or-file> <edit-dir>
# Writes <edit-dir>/reference/{ref.*,analysis.txt,contact.jpg,frames/*.jpg}.
# The reference is for studying pace and look only; never reuse it in output.
set -u

src=${1:-}
edit_dir=${2:-}
[ -n "$src" ] && [ -n "$edit_dir" ] || { printf '%s\n' 'usage: analyze_reference.sh <url-or-file> <edit-dir>' >&2; exit 64; }
command -v ffmpeg >/dev/null 2>&1 && command -v ffprobe >/dev/null 2>&1 || { printf '%s\n' 'STOP: ffmpeg/ffprobe missing; run the setup Skill.' >&2; exit 1; }

ref_dir="$edit_dir/reference"
mkdir -p "$ref_dir/frames"

case "$src" in
  http://*|https://*)
    if command -v yt-dlp >/dev/null 2>&1; then ytdlp="yt-dlp"
    elif command -v uvx >/dev/null 2>&1; then ytdlp="uvx yt-dlp"
    else printf '%s\n' 'STOP: yt-dlp not found and uv is missing; run the setup Skill.' >&2; exit 1; fi
    # shellcheck disable=SC2086
    $ytdlp --no-playlist --max-filesize 300M -f 'bv*[height<=1920]+ba/b' \
      --merge-output-format mp4 -o "$ref_dir/ref.%(ext)s" "$src" || {
      printf '%s\n' 'DOWNLOAD_FAILED: the platform may require login. Ask the user to save the video and drag the file in.' >&2
      exit 3
    }
    ref=$(ls "$ref_dir"/ref.* 2>/dev/null | head -n 1)
    ;;
  *)
    [ -f "$src" ] || { printf '%s\n' "STOP: not a file: $src" >&2; exit 1; }
    ref=$src
    ;;
esac
[ -n "${ref:-}" ] && [ -f "$ref" ] || { printf '%s\n' 'STOP: reference video not found after download.' >&2; exit 1; }

out="$ref_dir/analysis.txt"
dur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$ref")
wh=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$ref")
fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=nw=1:nk=1 "$ref")
has_audio=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$ref" | head -n 1)

# Scene-change cut detection (threshold 0.3 is a common starting point; tune if needed).
cuts=$(ffmpeg -hide_banner -nostats -i "$ref" -an -vf "select='gt(scene,0.3)',showinfo" -f null - 2>&1 |
  sed -n 's/.*pts_time:\([0-9.]*\).*/\1/p')
ncuts=$(printf '%s\n' "$cuts" | grep -c '[0-9]' || true)
avg=$(awk -v d="$dur" -v n="$ncuts" 'BEGIN { if (d > 0) printf "%.2f", d / (n + 1); else print "?" }')

{
  printf 'reference=%s\n' "$ref"
  printf 'duration_s=%s\nresolution=%s\nfps=%s\naudio=%s\n' "$dur" "$wh" "$fps" "${has_audio:+yes}"
  printf 'detected_cuts=%s\naverage_shot_s=%s\n' "$ncuts" "$avg"
  printf 'cut_times_s=%s\n' "$(printf '%s' "$cuts" | tr '\n' ' ')"
  printf '%s\n' 'note: scene detection misses soft cuts and can flag fast motion; confirm by looking at the frames.'
} > "$out"

# Frames at fixed points plus a contact sheet for visual inspection.
for pct in 3 15 30 50 70 85 97; do
  t=$(awk -v d="$dur" -v p="$pct" 'BEGIN { printf "%.2f", d * p / 100 }')
  ffmpeg -hide_banner -loglevel error -y -ss "$t" -i "$ref" -frames:v 1 -vf "scale=540:-2" "$ref_dir/frames/at_${pct}pct.jpg"
done
step=$(awk -v d="$dur" 'BEGIN { s = d / 12; if (s < 0.5) s = 0.5; printf "%.2f", s }')
ffmpeg -hide_banner -loglevel error -y -i "$ref" -vf "fps=1/$step,scale=270:-2,tile=6x2" -frames:v 1 "$ref_dir/contact.jpg"

cat "$out"
printf 'FRAMES %s\nCONTACT %s\n' "$ref_dir/frames" "$ref_dir/contact.jpg"
