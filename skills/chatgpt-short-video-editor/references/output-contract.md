# Output contract

Keep the following under the source-adjacent `edit/` directory. Do not place
work files in the source repository or alter the original media.

```
edit/
├── project.md
├── transcripts/<source>.json
├── corrected-transcript.md         # numbered paragraphs used in steps 4–5
├── edl.json
├── style/style-recipe.md            # step 6 recipe (or the clean default)
├── reference/                      # step 6 reference video, frames, analysis (never used in output)
├── master.srt
├── clips/                         # retained per-segment work when produced
├── animations/slot_<id>/          # source and output when animation is used
├── qa/                             # boundary samples, decode and QA evidence
├── preview.mp4                     # complete 720p review render
└── final.mp4                       # the single 1080×1920 formal final
```

`project.md` records the approved strategy, meaningful decisions, source
identifiers, outstanding questions, and each render/QA pass. `edl.json` is the
machine-readable edit record; `corrected-transcript.md` retains the human-read
correction without replacing the cached verbatim transcript.

When used, retain each animation's editable source and rendered output under
its slot. Keep QA evidence sufficient to review every cut boundary (±1.5s),
first/last/mid samples, subtitle safety, and full decode results.

Preview QA precedes preview approval. Final-file QA happens only after
`final.mp4` is rendered: retain its boundary/sample inspection and full-decode
evidence, then deliver only if those final checks pass.

Outwardly report one formal final only. The evidence report must distinguish
what was observed from what remains unverified and include: source inspected,
consent state, transcript/cache state, approved strategy, preview path and
checks, final path and decode evidence, self-fix-pass count, retained artifacts,
and unresolved issues. If `final.mp4` is absent or unverified, say so plainly;
never substitute a planned file for a completed deliverable.
