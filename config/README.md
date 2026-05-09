# xhs-image-gen config

Copy `config.example.json` to `config.json` by running:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

Put user-specific values only in `config.json`. Do not commit or publish `config.json`.

Required Feishu values:

- `feishu.base_url`: the browser URL prefix for your Base, for example `https://example.feishu.cn/base/<base_token>`
- `feishu.base_token`: Base app token
- `feishu.account_table_id`: account pool table id
- `feishu.task_table_id`: image task table id
- `feishu.account_fields.*`: field ids in the account pool table
- `feishu.task_fields.*`: field ids in the task table

Optional local values:

- `workspace_root`: where runs, output, and cache should live. `setup.ps1` fills this with `$env:USERPROFILE\.xhs-image-gen` when empty.
- `output_root`: where run folders are created. `setup.ps1` fills this with `<workspace_root>/output/native3x4` when empty.
- `publish_dir`: final copied delivery folder. Empty means no extra publish copy.
- `xhs_downloader_dir`: local checkout of `JoeanAmier/XHS-Downloader`. Empty means `$HOME/tools/XHS-Downloader`.
