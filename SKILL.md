---
name: xhs-image-gen
description: Use whenever the user gives a Xiaohongshu note link + a KOC/KOL account name (or mentions /xhs, /xhs-image-gen, "换皮生图", "改成 xx 账号风格", "把这条小红书改成我自己账号的样子"), or asks for native 3:4 XHS posters written into Feishu Base. Any agent (Claude, Codex, or others) can run this skill — image generation uses the agent's built-in image_gen tool when available (Path A, e.g. Codex), or shells out to a `codex exec` sidecar when not (Path B, e.g. Claude). Title and content are also rewritten — title via Skill(dbs-xhs-title) Top-1 pick, content by the running agent itself following dbs-content's five-dimension principles. All artifacts (original + rewritten title/content + generated images) are written back to a Feishu Base task record. Triggers via natural language match, /xhs alias, or /xhs-image-gen slash command.
---

# xhs-image-gen

## Purpose

Run the complete Xiaohongshu image-and-text rewrite workflow:

```text
XHS note URL + target account
-> fetch source images + extract original title/description
-> resolve or download account templates
-> create/update Feishu Base task (write original title + content)
-> rewrite title (Skill(dbs-xhs-title) Top-1) + rewrite content (agent itself, dbs-content principles)
-> match the right template per source image
-> generate native 3:4 images (Path A: built-in image_gen | Path B: codex exec sidecar)
-> compose cover thumbnails when needed
-> upload generated images + new title/content/alternatives to Feishu Base
-> return Base record URL and local output paths
```

This skill is **agent-neutral**. Both Claude and Codex (and any other agent) can run it. The only step that branches by agent capability is image generation (Step 11). Everything else (lark-cli ops, file I/O, dbs-xhs-title invocation, content rewriting) is identical across agents.

## Private Config

All user-specific information lives in one file:

```text
<skill_root>/config/config.json
```

Do not hardcode user paths, Feishu Base tokens, table ids, field ids, account ids, or output folders in prompts or scripts.

If `config/config.json` is missing, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup.ps1
```

Then ask the user to fill `config/config.json` and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
```

Read `config/config.example.json` for the schema. Read `references/feishu-base-schema.md` only when you need field mapping guidance.

## Read Order

When this skill triggers:

1. Read this `SKILL.md`.
2. Check `config/config.json`; if missing, use `scripts/setup.ps1`.
3. Run or inspect `scripts/doctor.ps1` before the first real workflow on a new machine.
4. Read `references/account-template-cache.md` when resolving account cache.
5. Read `references/prompt-template.md` when writing image prompts.
6. Read `references/troubleshooting.md` when a dependency, trigger, or permission fails.

## Hard Rules

### Image Rules

- Final delivery images must be native 3:4 vertical posters.
  - Good: `1080x1440`, `1086x1448`, any true `0.75` ratio.
  - Bad: `1024x1536`, `2:3`, `9:16`, or padded fake 3:4.
- If an image is not native 3:4, regenerate it first. `scripts/normalize-3x4.ps1` is a fallback, not the preferred final.
- The source XHS note is content only: product category, facts, source images, selling points, and section order.
- The target account template is design authority: layout family, typography, colors, card system, accents, product placement, and visual density.
- Do not copy the source author's visual identity when it conflicts with the target account template.
- Do not add template-external sections, footer navigation, labels, slogans, category menus, or decorative bars.

### Cover Rules

- Detail pages usually preserve source content order and apply target account style.
- Cover/overview pages use the target cover template as structure authority.
- **STRICT ORDERING: cover MUST be generated AFTER all detail pages are saved. Do NOT parallelize cover with details.** The cover prompt loads the actual `out_N.png` detail thumbnails as `view_image` references so that the 4 preview cards on the cover match the detail pages' visual style.
- If the selected target cover has preview-card slots, generate detail pages first, then use `scripts/compose-cover.ps1` to paste real detail thumbnails into the cover.
- If the selected target cover has no preview-card slots, do not invent preview cards.

### Text Rewriting Rules

- Always preserve the original XHS title and description verbatim into Base fields `原标题` / `原文案` (config keys `original_title` / `original_content`). Never overwrite the originals.
- **Title rewriting**: invoke `Skill(dbs-xhs-title)` with the original title as 话题 + the account category (or note tags) as 行业. Parse the `## Top 3 推荐` section of its output. Take Top 1 → 新标题. The remaining picks (Top 2 / Top 3) → join into 新标题候选. The formula # cited for Top 1 → 标题公式 (e.g. `#26 [数字] 个达成 [结果] 的小窍门`).
- **Content rewriting**: the running agent rewrites the content itself, following the five-dimension standards from dbs-content (文字洁癖 / 价值密度 / 认知落差 / 表达效率 / 平台契合). **Do NOT invoke `Skill(dbs-content)`** — that skill is diagnosis-only by design ("不帮人写内容"). Instead, internalize its principles and produce one rewritten version → 新文案.
- All four text fields (新标题, 新标题候选, 标题公式, 新文案) are required outputs. If any cannot be produced (e.g., source had empty description), write a clear placeholder like `(原文案为空，未改写)`.

## Workspace Rules

Resolve paths from config:

- `workspace_root`: base folder for cache/output. `setup.ps1` fills this with `$env:USERPROFILE\.xhs-image-gen` when empty.
- `output_root`: run output root. `setup.ps1` fills this with `<workspace_root>/output/native3x4` when empty.
- `publish_dir`: optional final delivery copy folder.
- `xhs_downloader_dir`: local `JoeanAmier/XHS-Downloader` checkout. Empty means `$HOME/tools/XHS-Downloader` or `XHS_DOWNLOADER_DIR`.

Create each run under:

```text
<output_root>/<run_id>/
├── source/         (source_1.jpg .. source_N.jpg + meta.json)
├── templates/
└── generated/
```

## Operational Notes (verified end-to-end on 2026-04-26 with note `69e0b0cf...`)

### Time budget
| Step | Duration |
|---|---|
| `fetch-xhs.sh` (10-image note + meta) | ~25-35s |
| `Skill(dbs-xhs-title)` | <30s (text only, no network) |
| Path B `codex exec` per image | ~3-5 min, ~13-45k tokens |
| Path B per image (simple subject, no aspect override) | ~50s, ~13k tokens |
| Lark Base record + 14 attachment uploads | ~30s |
| **B-mode total (4 representative images, parallel)** | ~15 min |
| **Full A-mode (10 images, 3-batch parallel)** | ~30-40 min |

### Parallelization rules
- **Path B `codex exec`: cap at 3 concurrent.** Verified working at 3; higher untested.
- **Cover (source_1) is NOT one of the parallel batch.** Generate cover AFTER all detail `out_N.png` are saved (per Cover Rules).
- **Lark attachment uploads: parallel safe within same field.** Attachment fields are append-only; concurrent appends do not race. Tested 10 source files in parallel + 4 generated in parallel.

### Codex output filename quirk
- `codex exec` picks its own filename (e.g. `dishwasher_style_transfer_1086x1448.png`).
- Sometimes saves to `<run_dir>/generated/`, sometimes to `<run_dir>/` root — inconsistent.
- **Mitigation**: in the Path B prompt template (Step 11), tell Codex the EXACT target path AND require `OUT_PATH=` line. See Step 11 for the wording.

### Network failure pattern recognition
- `stream disconnected` + `Reconnecting 1-5/5` + token count ~7000 = **prompt rejected by content review**, not generic network.
  - Trademarked IP characters (e.g. Minions, Disney chars): always fails.
  - Real product photos in 3:4 (1086×1448): always works.
- If you see this 2x with same prompt → don't retry, switch path.

### Skipped optional steps
- `scripts/resolve-account-cache.ps1` was bypassed in the verified end-to-end run — direct `lark-cli base +record-list` call worked fine. Cache layer is for repeat runs; for one-shots, direct list is simpler and equally fast.
- `scripts/compose-cover.ps1` was NOT used — instead, the cover `codex exec` prompt loaded `out_2/3/7.png` as `view_image` references and Codex drew the preview cards itself, matching the detail style. Output quality acceptable. Compose script is the more controlled path; Codex-draws-preview-cards is the lighter path.

## Standard Workflow

1. Parse the user input for:
   - XHS note URL
   - target account name or alias
   - optional delivery/publish preference
2. Load `config/config.json`.
3. Run `scripts/doctor.ps1 -SkipFeishuProbe` for quick local checks when the machine is unfamiliar.
4. Resolve the account cache first:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/resolve-account-cache.ps1 -Account "<account>"
```

5. If cache misses, list/select the account from Feishu Base using config values, download all template attachments, classify them, and write cache files.
6. Fetch source images **and metadata**:

```bash
bash scripts/fetch-xhs.sh "<xhs_url>" "<run_dir>/source"
```

After this completes, `<run_dir>/source/` contains:
- `source_1.<ext> .. source_N.<ext>` (the images)
- `meta.json` with `{title, description, tags, author, publish_time}` (auto-produced; primary source `scripts/fetch-xhs-meta.py` via XHS-Downloader async API → reliably has full **description body with emojis**; fallback `scripts/extract-meta.py` parses filename/json/txt → only has title/author).

If WSL/Git Bash path handling fails on Windows, run XHS-Downloader directly with Windows Python and the configured `xhs_downloader_dir`.

7. Read source metadata:

```bash
cat <run_dir>/source/meta.json
```

Capture `title` → original title, `description` → original content, `tags` → for industry inference in Step 12.5. If `meta.json` is missing or empty, treat originals as empty strings and proceed (the downstream rewrite step will write a placeholder).

8. Create or update a Feishu task record. Write **all** of these on creation:
   - `feishu.task_fields.summary` → `<account name> <YYYY-MM-DD HH:mm>`
   - `feishu.task_fields.account` → link to account pool record
   - `feishu.task_fields.source_url` → user input URL
   - `feishu.task_fields.original_title` → meta.json `title` (新增字段)
   - `feishu.task_fields.original_content` → meta.json `description` (新增字段)
   - `feishu.task_fields.status` → `feishu.status_values.generating`

9. Upload downloaded source images to `feishu.task_fields.source_images` (attachment field — use `+record-upload-attachment`, not upsert).

10. **Classify every source image and write a decision artifact (HARD STEP — do NOT skip)**:

    Past failure mode: agents skim 1-2 source images, default the rest to `detail`, and let codex pick visual style by smelling the source — leading to mixed product/comparison styles inside a "supposed to be all detail" run.

    10.1 **Resolve template role from filename FIRST** (no LLM judgment needed):

    Account templates follow a naming convention — parse `(file_token, role)` map directly from attachment names. No need to `view_image` the template just to figure out its role.

    | Filename pattern | role |
    |---|---|
    | contains `参数对比表` / `template_comparison` / `comparison_*` / `tpl_comparison*` | `comparison` |
    | contains `选购攻略` / `template_detail` / `detail_*` / `tpl_detail*` | `detail` |
    | contains `总览封面` / `template_cover` / `cover_*` / `tpl_cover*` | `cover` |
    | contains `单品说明` / `template_product` / `product_*` / `tpl_product*` | `product` |

    Implementation: when downloading templates from the account pool record's attachment field, save each as `<role>.<ext>` locally (e.g., `cover.png`, `detail.jpg`). The downstream codex prompt then references `<run_dir>/templates/<role>.<ext>` directly.

    If filename matches none of the patterns, fall back to 10.2 (visual classification) AND prompt user to rename the attachment in Feishu UI to follow the convention.

    10.2 `view_image` ALL source images (templates already classified by filename, no need to view them just to assign role).

    10.3 Write `<run_dir>/source/classification.json` with one entry per source image. Schema:
    ```json
    {
      "source_1": {"role": "cover", "template": "tpl_cover.png", "reason": "总览大标题 + 预览卡"},
      "source_2": {"role": "detail", "template": "tpl_detail.jpg", "reason": "选购攻略章节展开"}
    }
    ```

    10.4 Use these 4 hooks to decide each source's role:

    | Source Shape | Template Role |
    |---|---|
    | Large title, product hero, overview, preview cards | `cover` |
    | 多张白卡 + 章节序号 / 选购攻略章节展开（**即便里面有大产品图也算 detail**） | `detail` |
    | 整机产品图占比 ≥ 30% 且只讲一个型号（不是攻略系列） | `product` |
    | 多列 × 多行规格表 | `comparison` |

    10.5 **Boundary rule (critical, see field memo)**: If the note is a "选购攻略系列" (e.g., chapters labeled 一/二/三/四/五/六), classify ALL chapter pages as `detail` even if some chapters embed a large product hero shot. Note-level narrative > single-page local visual density. Do not fragment a series across roles.

    10.6 If a source is genuinely ambiguous, set `"ambiguous": true` and STOP — confirm with the user before continuing to Step 11.

11. **Generate each image** — branches by which agent is running this skill:

    ### Path A — Agent has the built-in `image_gen` tool (e.g., Codex)

    Use the agent's native `image_gen` tool directly. Steps inside the agent:
    - `view_image` the selected template (visual reference) and the source image (content reference)
    - Call `image_gen` with the prompt from the "Image Prompt Requirements" section below — request native 3:4 (1080x1440 or true 0.75 ratio)
    - Output saves to `$env:USERPROFILE\.codex\generated_images\<session>\ig_*.png` automatically
    - The agent already knows the saved path

    ### Path B — Agent does NOT have `image_gen` (e.g., Claude)

    Shell out to a Codex sidecar:

    ```bash
    codex exec --skip-git-repo-check "<prompt>"
    ```

    The `<prompt>` MUST follow this **3-stage structure** (do NOT collapse to a single "transfer the style" line — that wording lets the model smell the source and drift):

    **Stage 1 — Template confirmation (must precede image_gen)**:
    ```
    我为本张选的是 <tpl_X.png>，角色 <role>。
    请你先 view_image 这张模板，用一句话回述它的视觉系统
    （背景色 / 卡片形状 / 章节标记样式 / 强调色 / 产品摆放位 / 装饰元素）。
    若你认为我选错了，立刻停笔报告，不要 image_gen。
    ```

    **Stage 2 — Visual rebuild (not transfer, not skinning)**:
    ```
    用 <tpl_X.png> 的视觉系统**从零重建**一张 native 3:4 海报。
    源图 <source_N.png> 仅贡献：文字内容、章节顺序、产品名/型号、参数数字。
    视觉特征**零继承**：不复用源图的字体、配色、卡片形状、装饰元素、产品图位置、标签样式。
    输出严格符合 tpl_X 的卡片数量、章节标记样式（橙ribbon / ▶ / 绿勾...）、产品摆放位、配色十六进制。
    ```

    **Stage 3 — Style-lock guardrail (critical, see field memo)**:
    ```
    不论源图里有什么（即使有一台大产品图、一张参数表、一张对比表），
    输出都必须严格对位 tpl_X 的调性。
    源图里的大产品图 → 缩小嵌到 tpl_X 的产品图位（detail 模板就嵌到卡片小图位），
                  不要让产品图成为视觉中心。
    源图里的参数表 → 转写成 tpl_X 该有的章节标记样式（detail 用 📍引导多行 + 绿勾建议条），
                  不要画成参数表。
    严禁因源图视觉密度而把输出风格漂移到 product/comparison。
    ```

    **Plus 2 mechanical requirements**:
    1. **Specify the exact final save path** to dodge Codex's filename quirk:
       ```
       请将生成图最终保存到: <run_dir>\generated\out_<N>.png
       (codex sandbox 会拦截 PowerShell Copy-Item，请你只生图并打印生成路径，不要尝试 cp)
       ```
    2. Require the response to end with one line:
       ```
       OUT_PATH=<run_dir>\generated\out_<N>.png
       ```

    Without the 3 stages, Codex defaults to a "borrow source's bones, recolor a bit" approach and outputs styles that mix product/comparison cues into a supposedly all-detail batch. Without the path requirement, Codex picks its own filename (e.g. `dishwasher_style_transfer_1086x1448.png`) and may save to the run dir root instead of `generated/`.

    Parsing:
    - Read stdout for `OUT_PATH=`. Verify file exists at that path.
    - Fallback if missing: search `$env:USERPROFILE\.codex\generated_images\<session>\ig_*.png` (newest) AND search `<run_dir>` recursively for any new png modified after the call started.

    Notes for Path B:
    - If stdout contains `stream disconnected` / `Reconnecting 1-5/5` / `os error 10054` AND token count is `~7000` (i.e. died right after loading the imagegen skill), the cause is **prompt-specific** — usually trademarked IP characters trigger silent content review, OR an unusual aspect (1024x1536 fake-3:4 etc.). Do NOT retry the same prompt; rewrite or switch to OpenAI Image API direct (Path C below).
    - Each `codex exec` invocation is a fresh Codex session — earlier sessions' context does not carry over (no warm cache).
    - **Parallel batch safe at 3 concurrent calls**. Higher untested. For 10 detail images, prefer 3-batch parallel ≈ ~12 min total (vs ~40 min serial).

    ### Path C — OpenAI Image API direct (fallback when Path B fails repeatedly)

    Skipped here for brevity; only use if user provides `OPENAI_API_KEY`. Single HTTPS POST, no streaming, most resilient. Model `gpt-image-1` (one notch below built-in `gpt-image-2`).

    Either path: capture the absolute file path of the saved image for Step 12.

12. **Orchestrator must pull file from codex temp dir** — codex sandbox blocks PowerShell `Copy-Item` / `cp` / `[System.IO.File]::Copy(...)` with `rejected: blocked by policy`, so codex CANNOT move the file itself. Even when codex prints `OUT_PATH=<run_dir>\generated\out_N.png`, the file is actually at `$env:USERPROFILE\.codex\generated_images\<session_uuid>\ig_*.png`. Workflow:

    1. Parse codex stdout for `session id: <uuid>` (appears once near the top).
    2. `cp "$HOME/.codex/generated_images/<uuid>/"ig_*.png "<run_dir>/generated/out_N.png"` — orchestrator does this from outside the sandbox.
    3. Verify dimensions are native 3:4 (1086x1448 typical).

    **Clean up codex cruft after each batch.** Codex sometimes leaves working files in `<run_dir>/generated/`: `make_out_N.ps1` (its compose script), `out_N_tmp.png` / `out_N_*_work.png` (intermediate copies), `test_save.png` / `write_test.txt` (its own write tests). These are NOT deliverables. After each batch:

    ```bash
    cd <run_dir>/generated && find . -maxdepth 1 -type f ! -name 'out_*.png' -exec rm -fv {} \;
    ```

    This keeps `generated/` to exactly the deliverable `out_*.png` files — required before the Step 15 attachment upload (otherwise cruft files also get uploaded to Base).

12.5. **Rewrite title and content** (can run in parallel with Steps 11-12 since it doesn't depend on the generated images):

    ### Title rewriting

    Invoke `Skill(dbs-xhs-title)` with input shaped as:

    ```
    话题: <meta.json title>
    行业: <derived from account category in account pool, or top tag from meta.json tags>
    ```

    From dbs-xhs-title's output, locate the `## Top 3 推荐` section and parse the three picks (each is `**[标题]** — [一句话理由]`). Then:
    - Top 1 → `新标题` (config key `new_title`)
    - Join Top 2 + Top 3 with newline → `新标题候选` (config key `new_title_alternatives`)
    - Find Top 1's source formula in the per-type sections above (each title block has `公式 #N: ...`). Capture as `#N <formula template>` → `标题公式` (config key `title_formula`)

    ### Content rewriting

    The orchestrating agent (you) rewrites the content directly. **Do NOT call `Skill(dbs-content)`** — that skill is diagnosis-only by design ("不帮人写内容"). Internalize dbs-content's five-dimension principles and produce ONE rewritten version:

    | Dimension | Standard |
    |---|---|
    | 文字洁癖 | No emoji堆叠. No 排比堆叠. No "请记住" / "真相是" / "其实" 这类无能创作者句式. Public, verifiable language only. |
    | 价值密度 | 一句话能说清就一句话. Cut filler. Every sentence carries info. |
    | 认知落差 | Surface the underlying insight, not just restate facts the reader already knew. |
    | 表达效率 | Avoid 用 99% 的篇幅包装 1% 的内容. Service the product, not self-expression. |
    | 平台契合 | 小红书 voice — casual, direct, with substance; not Weibo joke, not Zhihu lecture. |

    Result → `新文案` (config key `new_content`).

    If the original content is empty, write `(原文案为空，未改写)` as the placeholder.

13. Verify dimensions and file size before upload.

14. For covers with preview slots, generate a cover base, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compose-cover.ps1 -RunDir "<run_dir>\generated"
```

15. Upload final generated images **AND text rewrites** to Feishu Base:
    - Generated images → `feishu.task_fields.generated_images` (attachment, use `+record-upload-attachment`)
    - `feishu.task_fields.new_title` → 新标题
    - `feishu.task_fields.new_title_alternatives` → 新标题候选
    - `feishu.task_fields.title_formula` → 标题公式
    - `feishu.task_fields.new_content` → 新文案
    - Set status:
      - `done` if all images succeeded
      - `partial` if some images succeeded
      - `quota_exhausted` if image generation quota blocks completion

    ### Feishu attachment field is append-only (CRITICAL)

    `+record-upload-attachment` only appends — it can never replace an existing attachment.
    Tested fail paths (do NOT retry these on a redo):
    - `lark-cli base +record-batch-update` patch `fld_generated_images: []` → returns `update: {}`, field unchanged
    - `lark-cli base +record-batch-update` patch `fld_generated_images: null` → same
    - `lark-cli api PUT /open-apis/bitable/v1/apps/.../tables/.../records/...` body `{"fields":{"生成图":[]}}` → `1254027 UploadAttachNotAllowed`
    - `lark-cli api PUT` body with file_token list (only 6 new tokens, hoping to drop 12 old) → returns 200 but field unchanged

    **Conclusion**: When you need to "replace" a generated image (regen after user feedback), do NOT try to clear the field. Pick one of:
    - **(preferred) New record v2** — `+record-batch-create` a sibling record summarized as `<acct> <ts> (v2)`, upload only the new images. Old record stays as v1 archive. Cheapest, reversible.
    - **Append + manual cleanup** — upload new image with name like `out_N_v2.png`. The user manually deletes old attachment in Feishu UI. Avoid for >2 swaps.
    - **Delete and recreate** — `+record-delete` original record, recreate everything. Loses record_id, requires re-uploading source images and rewriting all text fields.
      - `failed` with failure reason if no usable outputs are produced

16. Return:
    - Base record URL, if `feishu.base_url` is configured
    - local run directory
    - generated image paths
    - 新标题 + 新文案 preview (a few lines)
    - any uncertain template matches or failed pages

## Image Prompt Requirements

Use wording like:

```text
Create a NEW native 3:4 Xiaohongshu infographic poster.
Exact intended canvas aspect ratio: 3:4 vertical, like 1080x1440.
Do NOT create a 2:3 poster, do NOT create 1024x1536, do NOT create 9:16,
and do NOT rely on padding or borders to fake the ratio.
```

For detail pages:

```text
Keep the source content structure and order.
Apply the selected template's visual style.
Do not add unrelated labels, footer navigation, extra categories, or invented sections.
Output only the image.
```

For cover bases:

```text
Use the target cover template as the strict primary structure.
Use source_1 only for topic, product, and selling points.
Do not inherit source_1 visual style.
If and only if the target cover template has preview-card slots, leave those slots as empty frames for programmatic compositing.
If the target cover template has no preview-card slots, do not add preview cards.
```

## Feishu Safety

- Treat `lark-cli` operations that touch the same Base record as serial.
- Never publish a real user's `config/config.json`.
- Use `config/config.example.json` in distributable copies.
- If a Feishu command fails due to auth or field ids, run `scripts/doctor.ps1` and report the exact failing check.

## Distribution Rule

This skill is distributable when it contains:

- `SKILL.md`
- `config/config.example.json`
- `scripts/setup.ps1`
- `scripts/doctor.ps1`
- `scripts/fetch-xhs-meta.py` (primary metadata via XHS-Downloader async API)
- `scripts/extract-meta.py` (fallback: filename/json/txt parsing)
- bundled workflow scripts
- references
- optional example cache with no private credentials

It is not distributable if it contains:

- real `config/config.json`
- private Base tokens
- hardcoded user home directories
- hardcoded project-specific output directories
- API keys or cookies
