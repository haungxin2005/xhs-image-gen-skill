# Account Template Cache

The cache avoids downloading and reclassifying account templates every run.

## Location

Use this priority:

1. `config/config.json` `workspace_root/cache` when `workspace_root` is set.
2. `<skill_root>/cache` when `workspace_root` is empty.
3. Explicit `-CacheRoot` passed to `scripts/resolve-account-cache.ps1`.

Expected structure:

```text
cache/
├── account-aliases.json
└── accounts/
    └── <account_slug>/
        ├── manifest.json
        ├── style-profile.md
        └── templates/
            ├── cover.jpg
            ├── detail.jpg
            ├── product.jpg
            └── comparison.jpg
```

## Template naming convention (CRITICAL)

When uploading account templates to the Feishu account-pool record's "模板图" attachment field, **the attachment name must contain a role keyword** so SKILL Step 10 can resolve `(file_token, role)` from filename without LLM judgment.

Accepted naming patterns (any one is fine):

| Pattern | Examples | Role |
|---|---|---|
| Chinese full name | `模板03-总览封面.png` / `cover_总览封面.jpg` | `cover` |
| | `模板02-选购攻略.jpg` / `detail_选购攻略.png` | `detail` |
| | `模板04-单品说明.png` / `product_单品说明.png` | `product` |
| | `模板01-参数对比表.png` / `comparison_参数对比表.png` | `comparison` |
| English keyword | `template_cover.png` / `tpl_cover.jpg` / `cover_xxx.png` | `cover` |
| | `template_detail.jpg` / `tpl_detail.jpg` / `detail_xxx.jpg` | `detail` |
| | `template_product.png` / `tpl_product.png` / `product_xxx.png` | `product` |
| | `template_comparison.png` / `tpl_comparison.png` / `comparison_xxx.png` | `comparison` |

**Resolver order** (Step 10.1 implementation):
1. Substring match: filename contains 总览封面 / 参数对比表 / 选购攻略 / 单品说明 → role
2. Substring match: filename contains template_cover / template_detail / template_product / template_comparison → role
3. Prefix match: filename starts with cover_ / detail_ / product_ / comparison_ / tpl_cover / tpl_detail / tpl_product / tpl_comparison → role
4. **Fallback**: ask user to rename the attachment in Feishu UI to follow the convention; do NOT guess by viewing the image

After resolving, save each template locally as `<role>.<ext>` (e.g., `cover.png`, `detail.jpg`) so downstream codex prompts can reference `<run_dir>/templates/<role>.<ext>` directly.

**For new accounts** being added to the pool: pick one naming pattern and stick to it across all 4 templates of that account.

## account-aliases.json

Maps user-friendly names to cached account folders.

```json
{
  "momo": {
    "account_name": "茉茉评测",
    "account_slug": "momo",
    "record_id": "recxxxx"
  }
}
```

## manifest.json

```json
{
  "schema_version": 1,
  "account_name": "茉茉评测",
  "account_slug": "momo",
  "record_id": "recxxxx",
  "updated_at": "2026-04-26T12:00:00+08:00",
  "template_roles": {
    "cover": "templates/cover.jpg",
    "detail": "templates/detail.jpg",
    "product": "templates/product.jpg",
    "comparison": "templates/comparison.jpg"
  },
  "source_file_tokens": {
    "cover": "file_token_if_known"
  },
  "notes": [
    "cover template is used for source_1 overview pages",
    "detail template is used for guide/detail pages"
  ]
}
```

## style-profile.md

Write concise, executable visual rules:

```markdown
# Account style profile

## Visual DNA
- Outer background:
- Inner cards:
- Title style:
- Accent colors:
- Density:

## Cover Rules
- Use the cover template as layout authority.
- If preview slots exist, compose real generated details into them.

## Detail Rules
- Preserve source content order.
- Apply this account's card, color, and type system.

## Forbidden
- Do not add footer navigation unless the template has it.
- Do not generate 2:3, 9:16, or padded fake 3:4 images.
```

## Cache Refresh Rules

Refresh the cache when:

- The account's Base template attachments changed.
- The user says the account template changed.
- The generated output no longer matches the account style.
- `manifest.json` file tokens do not match current Base attachments.
