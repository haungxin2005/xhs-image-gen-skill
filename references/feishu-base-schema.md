# Feishu Base Schema Mapping

This skill does not ship with a real user's Base token or field ids. Read the active mapping from:

```text
config/config.json
```

The required shape is defined in:

```text
config/config.example.json
```

## Required Base Tables

### Account Pool Table

The account pool table stores KOC accounts and their template images.

Required fields in `feishu.account_fields`:

| Config key | Expected field type | Purpose |
|---|---|---|
| `name` | text | Account display name |
| `template_images` | attachment | One or more template/reference images for this account |

Optional fields:

| Config key | Expected field type | Purpose |
|---|---|---|
| `homepage` | text/url | Account homepage |
| `report_price` | text/number | Report price metadata |
| `direct_price` | text/number | Direct publishing price metadata |
| `original_price` | text/number | Original content price metadata |
| `followers` | text/number | Follower count metadata |

### Image Task Table

The task table records each generation run.

Required fields in `feishu.task_fields`:

| Config key | Expected field type | Purpose |
|---|---|---|
| `summary` | text | Short task title |
| `account` | link | Link to account pool record |
| `source_url` | text/url | Original Xiaohongshu note URL |
| `source_images` | attachment | Downloaded source images |
| `generated_images` | attachment | Final generated images |
| `status` | select | Current task status |
| `original_title` | text | Original XHS note title (preserved verbatim from `meta.json`) |
| `original_content` | text | Original XHS note description (preserved verbatim from `meta.json`) |
| `new_title` | text | Rewritten title — Top 1 pick from `Skill(dbs-xhs-title)` |
| `new_title_alternatives` | text | Top 2 + Top 3 picks from `dbs-xhs-title`, joined by newline |
| `title_formula` | text | Formula # cited for `new_title` (e.g. `#26 [数字] 个达成 [结果] 的小窍门`) |
| `new_content` | text | Rewritten content — agent rewrites following dbs-content five-dimension principles |

Optional fields:

| Config key | Expected field type | Purpose |
|---|---|---|
| `failure_reason` | text | Error detail when the run fails |
| `notes` | text | Human notes |

> Field IDs created in production Base `<your-base-token>` task table `tblXXXXXXXXXXXXXX` (2026-04-26):
> `original_title=fld_original_title`, `original_content=fld_original_content`, `new_title=fld_new_title`, `new_title_alternatives=fld_new_title_alts`, `title_formula=fld_title_formula`, `new_content=fld_new_content`.

## Status Values

Use `feishu.status_values` from config. Defaults are Chinese labels:

```json
{
  "generating": "生成中",
  "done": "完成",
  "partial": "部分完成",
  "quota_exhausted": "配额用完",
  "failed": "失败"
}
```

## Base URL

Return record URLs by combining:

```text
<feishu.base_url>?table=<feishu.task_table_id>&record_id=<record_id>
```

If `base_url` is empty, return the record id and local output paths instead.
