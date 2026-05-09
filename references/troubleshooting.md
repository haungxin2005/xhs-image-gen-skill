# Troubleshooting

## Skill Does Not Trigger

Codex skills are not CLI slash commands. Use natural language:

```text
用 xhs-image-gen skill 处理这个小红书链接：<url>，账号：<account>
```

If the skill was installed after the Codex session started, restart Codex (or for Claude, the skill list usually hot-loads on the next message).

## Missing Config

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup.ps1
```

Then fill `config/config.json`. As a one-shot fallback (no config), the verified production IDs are:
- `base_token`: `<your-base-token>`
- `account_table_id`: `tblYYYYYYYYYYYYYY`
- `task_table_id`: `tblXXXXXXXXXXXXXX`

## Feishu Permission Errors

Run:

```powershell
lark-cli auth status
lark-cli auth login
```

Then:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
```

## XHS Download Fails

Set `xhs_downloader_dir` in `config/config.json` or `XHS_DOWNLOADER_DIR` in the environment. The directory must contain `main.py`.

## Image Ratio Is Wrong

Regenerate first. `normalize-3x4.ps1` is only a fallback when native regeneration is unavailable.

## Built-in Image Output Path

The built-in image tool saves under:

```text
$env:USERPROFILE\.codex\generated_images
```

Copy the selected generated file into the current run's `generated/` folder before uploading to Feishu.

---

## Lark-CLI Quirks (verified pitfalls)

### Cell-value format for `+record-upsert --json '{...}'`

| Field type | Cell value example |
|---|---|
| Text / multi-line text | `"plain string"` |
| URL (text with style.type=url) | `"https://..."` (plain string OK; lark-cli wraps) |
| Single-Select | `"完成"` (option name string) |
| Multi-Select | `["A", "B"]` |
| Link (relation to other table) | `["recvXXXXXXXXXXXX"]` (array of record IDs, NOT `{"record_ids":[...]}`) |
| Attachment | ⚠️ **Do NOT pass via upsert.** Use `+record-upload-attachment --file ...` separately, one call per file. |

### `+record-list` Has No `--filter` Flag

Trying `+record-list --filter "..."` throws `unknown flag: --filter`. To filter:
- Server-side: use `+record-search` (different command).
- Client-side: fetch all then filter in jq/python.

### jq Path Gotcha for `+record-get`

Fields are at `.data.record["<中文字段名>"]`, NOT `.data.record.fields`. Wrong path returns `null` silently.

```bash
# ✓ correct
lark-cli base +record-get ... --jq '.data.record["生成图"] | length'

# ✗ wrong (returns null)
lark-cli base +record-get ... --jq '.data.record.fields["生成图"] | length'
```

### `+record-list` Output Shape

Records come as parallel arrays at `.data.data` (values per record) and `.data.record_id_list` (IDs). Zip them client-side. Field names are at `.data.fields`, IDs at `.data.field_id_list`.

### `tokenStatus: needs_refresh` Is Often a False Alarm

If `lark-cli auth status` warns `needs_refresh` but a real call (`+record-list`) returns valid data, the token is fine. Only re-login if a real call fails with auth error.

### Attachment Upload Working Directory

`--file ./source_1.jpeg` requires the file to be findable from cwd. Per memory `feedback_larkcli_file_relative_path.md`:
- Always `cd` to the file's dir first
- Use `./filename` not absolute Windows path
- For parallel uploads of files in the same dir: `cd` in the **first** call of the chain works most of the time, but for safety pre-`cd` in every parallel call.

### Parallel Attachment Uploads to Same Field Are Safe

Attachment fields are append-only. Concurrent appends do not race. Tested 10 source files in parallel + 4 generated in parallel without issue.

---

## Codex `image_gen` Quirks (verified pitfalls)

### Architecture Works; Failures Are Prompt-Specific

- Verified `codex exec ... image_gen` **works** for: red apple test (1024×1024), real product photos in 3:4 (1086×1448, 1085×1450).
- Verified `codex exec ... image_gen` **fails** for: trademarked IP characters (e.g. Minions). Same exact prompt repeated → same exact ~7045-token failure with `stream disconnected`.
- This is **NOT** general network — the same Codex session can do other tools (text, shell) just fine.
- Hypothesis: OpenAI content review intercepts the image_gen call and surfaces as stream disconnect.

### Failure Pattern Recognition

Stop and rewrite the prompt (do NOT retry blindly) when stdout shows ALL of:
- `tokens used` ≈ `7000` (i.e. died right after loading the imagegen skill)
- `stream disconnected before completion`
- `Reconnecting 1/5 .. 5/5` (all 5 fail)
- A real OpenAI request ID (proves the request reached OpenAI; the rejection is server-side)

If you see this pattern twice in a row with the same prompt → switch to OpenAI Image API direct (Path C) or rewrite the prompt to avoid IP/unusual-aspect triggers.

### Performance Budget per `codex exec` Call

| Workload | Wall time | Tokens |
|---|---|---|
| Pure text (e.g. "中国首都") | ~12s | ~6.8k |
| Tool use (shell echo) | ~15s | ~13.6k |
| image_gen simple (red apple 1024×1024) | ~50s | ~13.5k |
| image_gen full workflow (template + source via view_image, native 3:4, content preservation) | ~3-5 min | ~30-45k |

Each `codex exec` invocation is a fresh Codex session — earlier sessions' context does NOT carry over (no warm prompt cache).

### Parallel Safety: 3 Concurrent OK

3 concurrent `codex exec` calls verified to work — different Codex sessions, no interference. Higher concurrency untested. For 10 detail images, prefer 3-batch parallel ≈ ~12 min total (vs. ~40 min serial).

### Output Filename Quirk

Codex picks its own filename like `dishwasher_style_transfer_1086x1448.png` and may save to `<run_dir>/generated/` OR `<run_dir>/` root inconsistently.

**Mitigation** (already in SKILL.md Step 11): explicitly tell Codex:
1. The exact target path: `请将生成图最终保存到: <run_dir>\generated\out_<N>.png`
2. The required output line: `OUT_PATH=<that path>`

When in doubt, search recursively from `<run_dir>` for any new `*.png` modified after the call started.

### Codex Cruft Files (verified leftovers)

Codex sometimes leaves working files in the run dir:
- `make_out_N.ps1` — codex's PowerShell compose script
- `out_N_tmp.png` / `out_N_<dim>_work.png` — intermediate copies before final move
- `test_save.png` (often 121 bytes) — codex testing if it can write to the dir
- `write_test.txt` — same purpose

**Always run after each batch** (in `<run_dir>/generated/`):
```bash
find . -maxdepth 1 -type f ! -name 'out_*.png' -exec rm -fv {} \;
```

Otherwise these get included in Step 15's attachment upload and pollute the Base record's "生成图" field.

---

## XHS-Downloader Quirks

### v2.8 Does NOT Persist Note Body

Even with `--download_record true`, XHS-Downloader v2.8:
- Does NOT write a `.json` or `.txt` with the note body
- Does NOT populate `ExploreData.db` (table `explore_data` exists but stays empty)
- DOES encode the title in the image filename: `<日期>_<时间>_<作者>_<标题>_<N>.<ext>`

`scripts/extract-meta.py` parses that filename pattern as a fallback. But for the full description body, use `scripts/fetch-xhs-meta.py` (the primary metadata path) which uses XHS-Downloader's official async API `XHS().extract(url, download=False)` — that DOES return `desc`.

### XHS-Downloader Async API Spits Chinese Logs to stdout

The `XHS().extract()` async API uses `rich.print` to log progress (中文进度) to stdout. Our `fetch-xhs-meta.py` wraps the call in `contextlib.redirect_stdout(sys.stderr)` so that **only the final JSON** lands on stdout. If you write a custom wrapper, do the same — otherwise downstream JSON parsing breaks.

### Windows + Chinese Path + bash Variable Substitution Edge Case

`bash -c "python ... > $VAR_WITH_CHINESE_PATH/meta.json"` sometimes fails to write the file even when stdout is non-empty. Workarounds:
- Use absolute ASCII path
- Or write the JSON file from inside Python directly (don't rely on bash `>` redirect)

---

## Common Workflow Failures

### Step 6 (fetch-xhs.sh) succeeded but meta.json shows empty `description`

`fetch-xhs-meta.py` (the primary path) failed silently. Look at the run dir's `fetch.err` file. Common causes:
- XHS_DOWNLOADER_DIR not set / wrong path
- `from source import XHS` ImportError (XHS-Downloader version mismatch)
- xsec_token expired (try a fresh share link)

`extract-meta.py` (fallback) ran and got title from filename — that's why `title` is filled but `description` is empty.

### Step 11 (codex exec) succeeded but no file at the expected path

Codex saved to `<run_dir>/<some_descriptive_name>.png` instead of `<run_dir>/generated/out_<N>.png`. See "Output Filename Quirk" above.

### Step 15 (Base upload) silently uploads 0 generated images

You used `--filter` on `+record-list` (doesn't exist) OR queried jq path `.data.record.fields["生成图"]` (wrong). See "Lark-CLI Quirks > jq Path Gotcha".

### Whole run takes >40 minutes

You're running Path B serial. Use 3-batch parallel — see SKILL.md Operational Notes.
