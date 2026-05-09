# xhs-image-gen

A Claude Code skill that runs the complete Xiaohongshu (小红书) image-and-text rewrite workflow:

```
XHS note URL + target account
-> fetch source images + extract original title/description
-> resolve or download account templates from Feishu Base
-> create/update Feishu task record (writes original title + content)
-> rewrite title via dbs-xhs-title (Top-1 auto-pick) + rewrite content
-> match the right template per source image
-> generate native 3:4 images (Path A: built-in image_gen | Path B: codex exec sidecar)
-> upload generated images + new title/content/alternatives back to Feishu Base
-> return Base record URL and local output paths
```

Agent-neutral. Both Claude and Codex (and any other agent with `image_gen` access) can run it.

## Quick start

1. Copy `config/config.example.json` to `config/config.json` and fill in your Feishu Base token + table/field IDs (your `config.json` is gitignored — never commit it).
2. Run `scripts/setup.ps1` then `scripts/doctor.ps1` to validate the environment.
3. From Claude Code: invoke this skill with `XHS-note-URL + target-account-name`.

See `SKILL.md` for the full workflow contract, hard rules, and field memos accumulated from production runs.

## What this skill is good at

- Native 3:4 (1086×1448) Xiaohongshu posters that match a target KOC account's visual identity, not the source author's
- Detail pages that preserve source copy verbatim while applying target template's style
- Cover composition with strict template-locked layout (no copy-paste skinning)
- Inline-content prompt mode that bypasses codex `view_image` mis-binding when many similar source images are present (≥10 sources)

## What this skill is NOT for

- Viral image generation from scratch (it serves account-locked KOC content production, not creative ideation)
- Replacing your own taste — the dbs-xhs-title Top-1 auto-pick is opinionated; review before publishing

## Distribution rule

This repo intentionally ships **without** real `config/config.json`, real Base tokens, real record IDs, or any production user data. See SKILL.md "Distribution Rule" section.
