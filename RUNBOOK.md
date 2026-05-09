# xhs-image-gen Portable Runbook

This runbook is intentionally generic. Real user values belong in `config/config.json`.

## First-Time Setup

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup.ps1
```

Edit:

```text
config/config.json
```

Then verify:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
```

## Config Owns User Data

Store these in `config/config.json`:

- Feishu Base URL/token
- Feishu table ids
- Feishu field ids
- local workspace/output/publish directories
- XHS-Downloader path
- default account or account aliases
- image target dimensions

Never hardcode them into `SKILL.md`, scripts, or references.

## Normal Trigger

Use natural language, not a slash command:

```text
用 xhs-image-gen skill 处理这个小红书链接：<url>，账号：<account>
```

## Normal Run

1. Load config.
2. Resolve account cache.
3. Fetch XHS source images.
4. Create Feishu task record.
5. Upload source images.
6. Match each source image to the best template role.
7. Generate detail pages first when the cover has preview cards.
8. Generate the cover base.
9. Compose real detail thumbnails into the cover when needed.
10. Upload generated images.
11. Mark Feishu task complete or partial.

## Dependency Checks

Use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
```

The script checks config, `lark-cli`, XHS-Downloader, and the Codex generated image folder.
