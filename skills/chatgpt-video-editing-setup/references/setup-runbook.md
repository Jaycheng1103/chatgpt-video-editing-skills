# Setup runbook

`scripts/check_env.sh` (read-only) and `scripts/install_missing.sh` (dry run by
default, `--yes` after one approval of the listed changes) automate this
runbook; this file documents the sources and hard stops they enforce. The user
approves the step's whole list once; anything discovered later that is not on
that list needs its own question. Re-read the upstream documentation at
execution time because install instructions can change.

## 1. Inspect and propose

Use exact official HTTPS origins. Do not accept a fork, a similarly named
repository, a missing `origin`, or another transport form, and never rewrite a
remote automatically:

- video-use: `https://github.com/browser-use/video-use.git`
- HyperFrames CLI: the npm package `hyperframes`, pinned to `0.9.86`
  (`npx -y hyperframes@0.9.86`), from `https://github.com/heygen-com/hyperframes`.
  No source checkout is needed.

Check the required video-use location before acting. Do not inspect only for a `.git`
directory: in a linked worktree, `.git` is a file. The following preflight
recognizes both normal checkouts and linked worktrees, and rejects any existing
path that is not the expected clean repository:

```sh
inspect_repo() {
  repo=$1
  expected_origin=$2

  if [ ! -e "$repo" ] && [ ! -L "$repo" ]; then
    printf '%s\n' "missing repository: $repo"
    return 2
  fi

  inside=$(git -C "$repo" rev-parse --is-inside-work-tree 2>/dev/null) || {
    printf '%s\n' "STOP: existing path is not a Git worktree: $repo" >&2
    return 1
  }
  [ "$inside" = true ] || {
    printf '%s\n' "STOP: existing path is not inside a Git worktree: $repo" >&2
    return 1
  }

  commit=$(git -C "$repo" rev-parse --verify HEAD) || return 1
  branch=$(git -C "$repo" branch --show-current) || return 1
  [ -n "$branch" ] || branch="(detached at $commit)"
  actual_origin=$(git -C "$repo" remote get-url origin) || {
    printf '%s\n' "STOP: origin is missing: $repo" >&2
    return 1
  }
  [ "$actual_origin" = "$expected_origin" ] || {
    printf '%s\n' "STOP: unexpected origin for $repo: $actual_origin" >&2
    return 1
  }
  status=$(git -C "$repo" status --short) || return 1
  printf '%s\n' "repo=$repo" "origin=$actual_origin" \
    "branch=$branch" "commit=$commit" "status=${status:-clean}"
  [ -z "$status" ] || {
    printf '%s\n' "STOP: repository is dirty: $repo" >&2
    return 1
  }
}

video_use_origin=https://github.com/browser-use/video-use.git
inspect_repo "$HOME/Developer/video-use" "$video_use_origin" || {
  result=$?
  [ "$result" -eq 2 ] || exit 1
}
command -v git uv ffmpeg ffprobe python3
```

The `2` result means the expected path is absent and may be proposed for an
approved clone. Every other failure is a hard stop. In particular, an existing
non-repository path, missing or mismatched origin, invalid commit, or non-empty
status must stop the workflow before pull, reset, reclone, dependency install,
or Skill registration. Report the evidence and ask the user to resolve it or
choose a separate safe action. A clean fork is still the wrong repository.

Also inspect the subtitle font state so a missing font can be proposed as its
own approval item; the check itself mutates nothing:

```sh
case "$(uname -s)" in
  Darwin) font_dir="$HOME/Library/Fonts" ;;
  Linux) font_dir="$HOME/.local/share/fonts" ;;
  *) printf '%s\n' 'STOP: unsupported platform; the subtitle font was not checked.' >&2; exit 1 ;;
esac
for weight in Regular Bold; do
  font_file="$font_dir/SourceHanSansTW-$weight.otf"
  if [ -f "$font_file" ] && [ ! -L "$font_file" ]; then
    printf '%s\n' "font present: $font_file"
  else
    printf '%s\n' "font missing: $font_file"
  fi
done
if command -v fc-list >/dev/null 2>&1; then
  fc-list | grep -i "Source Han Sans TW" || printf '%s\n' 'fontconfig does not list Source Han Sans TW'
fi
```

HyperFrames draws the captions and CSS effects, so it is part of step 2. It
needs Node.js 22 or newer and downloads its own headless Chrome:

```sh
node_major=$(node -p 'process.versions.node.split(".")[0]') || exit 1
case "$node_major" in *[!0-9]*|'') exit 1 ;; esac
[ "$node_major" -ge 22 ] || {
  printf '%s\n' "STOP: HyperFrames requires Node.js 22 or newer; found major $node_major" >&2
  exit 1
}
npx --no-install hyperframes@0.9.86 browser path
```

If Node.js is absent, `install_missing.sh` proposes `brew install node` on
macOS. If an older Node.js is present, stop: propose an isolated
version-manager setup as a separate approval item and never replace or change
the user's existing Node.js on your own.

Before mutation, show an approval checklist tailored to what is missing:

- clone or update the source repositories;
- install Python, Node, FFmpeg, or package dependencies;
- download and install the Source Han Sans TW subtitle font files;
- download a large dependency or full media baseline;
- create/change a symlink or register an agent Skill;
- create or tighten the credential file.

Wait for a clear approval that covers the proposed changes. Do not treat a
request to “set it up” as approval after discovery reveals extra changes. Git
state can drift while approval is pending, so rerun the applicable `inspect_repo`
preflight immediately before every dependency installation and Skill
registration. Stop if origin, branch/commit validity, or cleanliness changed.

## 2. Install or repair video-use

The official source is `https://github.com/browser-use/video-use.git`. Keep the
whole repository at `~/Developer/video-use`; registering only a copied
`SKILL.md` is insufficient because its helpers are part of the workflow.

For a missing, approved checkout:

```sh
git clone https://github.com/browser-use/video-use.git "$HOME/Developer/video-use"
inspect_repo "$HOME/Developer/video-use" "https://github.com/browser-use/video-use.git"
cd "$HOME/Developer/video-use"
uv sync
```

Use the repository's current `install.md` and lockfile/package metadata at the
checked-out revision. If it directs a different supported installer, explain
that change and get approval before using it. Install FFmpeg only if `ffmpeg`
and `ffprobe` are absent; it is required by the workflow. Optional online-source
tools are separate and need their own approval.

Register the **entire** repository with the active agent's Skills directory.
After approval, rerun `inspect_repo` and preflight the exact destination before
creating any link. For the Codex location, use the following pattern:

```sh
target="$HOME/Developer/video-use"
destination="$HOME/.codex/skills/video-use"
test -d "$(dirname "$destination")" || exit 1
if [ -L "$destination" ]; then
  readlink "$destination"
  test "$(readlink "$destination")" = "$target" || exit 1
elif [ -e "$destination" ]; then
  exit 1
else
  ln -s "$target" "$destination"
fi
```

Report the `readlink` result for an existing symlink. Accept it only when it is
the exact intended target; otherwise stop. If any real file or directory exists
at the destination, stop. Create only a plain symlink at a confirmed absent
destination after approval—never replace, nest, or retarget an existing link.
Adapt the target to the current agent only after showing the exact link change.

## 3. Install the subtitle font (Source Han Sans TW)

Burned-in Traditional Chinese subtitles need a CJK font, or the render falls
back to an unsuitable system font or missing-glyph boxes. The workflow default
is Source Han Sans TW（思源黑體）, released by Adobe under the SIL Open Font
License 1.1. The only accepted source is the official repository's `release`
branch at `https://github.com/adobe-fonts/source-han-sans`. Do not download the
font from mirrors, aggregator sites, or similarly named repositories, and do
not substitute another font silently.

If the inspection above already found both weights as regular files, report
them as present and skip this section; never re-download or overwrite an
existing font file. If a font path exists but is a symlink, directory, or other
non-regular file, stop and report it instead of replacing it.

For missing weights, list the download as an approval item (about 6 MB per
weight, two weights by default). After approval:

```sh
font_source=https://github.com/adobe-fonts/source-han-sans/raw/release/SubsetOTF/TW
mkdir -p "$font_dir"
for weight in Regular Bold; do
  font_file="$font_dir/SourceHanSansTW-$weight.otf"
  if [ -e "$font_file" ] || [ -L "$font_file" ]; then
    printf '%s\n' "skip existing path: $font_file"
    continue
  fi
  curl -fL --proto '=https' -o "$font_file" \
    "$font_source/SourceHanSansTW-$weight.otf"
done
if [ "$(uname -s)" = Linux ]; then
  command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$font_dir"
fi
```

Verify each installed file is a real OpenType/CFF font before reporting it as
installed; `SourceHanSansTW-Regular.otf` and `SourceHanSansTW-Bold.otf` must
both start with the `OTTO` magic bytes:

```sh
for weight in Regular Bold; do
  font_file="$font_dir/SourceHanSansTW-$weight.otf"
  [ -f "$font_file" ] && [ ! -L "$font_file" ] || {
    printf '%s\n' "STOP: subtitle font is not a regular file: $font_file" >&2
    exit 1
  }
  magic=$(head -c 4 "$font_file" | od -An -tx1 | tr -d ' \n') || exit 1
  [ "$magic" = 4f54544f ] || {
    printf '%s\n' "STOP: not a valid OpenType font: $font_file" >&2
    exit 1
  }
done
```

If a download fails or verification stops, delete nothing automatically; report
the exact path and evidence, and wait for the user's decision. If the user
wants different weights, another regional subset, the Super OTC, or a variable
font, treat that as a separate approval item and follow the official
`SourceHanSansReadMe.pdf` in the upstream repository for the configuration
choice.

## 4. Install HyperFrames for captions and CSS effects

Part of the step-2 approval list. Use the pinned npm CLI; no repository clone,
`bun install`, or HyperFrames agent Skills are needed for this workflow:

```sh
npx -y hyperframes@0.9.86 --version
npx -y hyperframes@0.9.86 browser ensure
```

The two downloads take about 320 MB on disk (measured on macOS arm64). Also
confirm FFmpeg can decode VP9 with alpha, which the composite step needs:

```sh
ffmpeg -hide_banner -decoders | grep libvpx-vp9
```

## 5. Local, no-cost verification

After approved changes, verify the required video-use state locally:

```sh
inspect_repo "$HOME/Developer/video-use" "https://github.com/browser-use/video-use.git"
test -d "$HOME/Developer/video-use/helpers"
command -v ffmpeg ffprobe
```

Also verify the subtitle font, reusing `font_dir` from the platform check:

```sh
for weight in Regular Bold; do
  font_file="$font_dir/SourceHanSansTW-$weight.otf"
  [ -f "$font_file" ] && [ ! -L "$font_file" ] || exit 1
done
if command -v fc-list >/dev/null 2>&1; then
  fc-list | grep -i "Source Han Sans TW"
fi
```

Verify HyperFrames and its render browser:

```sh
node_major=$(node -p 'process.versions.node.split(".")[0]') || exit 1
[ "$node_major" -ge 22 ] || exit 1
npx --no-install hyperframes@0.9.86 --version
chrome=$(npx --no-install hyperframes@0.9.86 browser path | tail -n 1)
test -e "$chrome"
ffmpeg -hide_banner -decoders | grep -q libvpx-vp9
```

Then use the checks in [security and verification](security-and-verification.md).
Do not pass media to any API, invoke transcription, create `edit/`, render, or
claim readiness based only on planned commands.
