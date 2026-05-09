#!/usr/bin/env python3
"""
fetch-xhs-meta.py <xhs_url>

通过 XHS-Downloader 的官方 async API 拿小红书笔记完整 metadata（含正文 desc），
JSON 打印到 stdout。仅采集，不下载图片/视频。

输出字段（中文 key 来自 XHS-Downloader 的 schema）：
  title         <- 作品标题
  description   <- 作品描述（这就是笔记 body 正文，本脚本核心目标）
  tags          <- 作品标签
  author        <- 作者昵称
  publish_time  <- 发布时间

依赖：XHS-Downloader 已 git clone（默认 ~/tools/XHS-Downloader，可通过
环境变量 XHS_DOWNLOADER_DIR 覆盖）。

退出码：
  0 = 成功（即使 description 为空也算成功，下游自己判断）
  2 = 调用方式错误
  3 = XHS-Downloader 未找到 / import 失败
  4 = extract() 抛异常
"""

from __future__ import annotations

import asyncio
import contextlib
import json
import os
import sys
from pathlib import Path


def setup_xhs_path() -> Path:
    xhs_dir = Path(
        os.environ.get("XHS_DOWNLOADER_DIR")
        or (Path.home() / "tools" / "XHS-Downloader")
    )
    if not (xhs_dir / "main.py").is_file():
        print(
            f"XHS-Downloader 未找到: {xhs_dir} (set XHS_DOWNLOADER_DIR to override)",
            file=sys.stderr,
        )
        sys.exit(3)
    sys.path.insert(0, str(xhs_dir))
    return xhs_dir


async def fetch(url: str) -> dict:
    setup_xhs_path()
    try:
        from source import XHS  # noqa: E402  (path-dependent import)
    except ImportError as e:
        print(f"import source.XHS failed: {e}", file=sys.stderr)
        sys.exit(3)

    # XHS-Downloader 会往 stdout 打中文进度日志(rich.print 等)。
    # 我们的脚本协议是"stdout = JSON",必须把这些日志改道到 stderr,否则 JSON 被污染。
    with contextlib.redirect_stdout(sys.stderr):
        async with XHS(
            record_data=False,
            image_download=False,
            video_download=False,
            download_record=False,
        ) as xhs:
            try:
                result = await xhs.extract(url)
            except Exception as e:
                print(f"xhs.extract() raised: {type(e).__name__}: {e}", file=sys.stderr)
                sys.exit(4)

    # extract() 文档不明，可能返回 list[dict] 或 dict，统一规范化
    if isinstance(result, list):
        note = result[0] if result else {}
    elif isinstance(result, dict):
        note = result
    else:
        note = {}

    if not note:
        return {"title": "", "description": "", "tags": [], "author": "", "publish_time": ""}

    tags = note.get("作品标签", [])
    if isinstance(tags, str):
        # 兼容标签字段返回字符串的情况
        tags = [t.strip().lstrip("#") for t in tags.replace(",", " ").split() if t.strip()]
    elif isinstance(tags, list):
        tags = [str(t).strip().lstrip("#") for t in tags if str(t).strip()]
    else:
        tags = []

    return {
        "title": str(note.get("作品标题", "")).strip(),
        "description": str(note.get("作品描述", "")).strip(),
        "tags": tags,
        "author": str(note.get("作者昵称", "")).strip(),
        "publish_time": str(note.get("发布时间", "")).strip(),
    }


def main() -> int:
    # 强制 stdout 走 utf-8。Windows 默认 cp936 写不下 emoji（如 ✅），
    # 笔记正文里几乎一定带 emoji,不修就直接 UnicodeEncodeError。
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    if len(sys.argv) != 2:
        print("usage: fetch-xhs-meta.py <xhs_url>", file=sys.stderr)
        return 2
    url = sys.argv[1].strip()
    if not url:
        print("empty url", file=sys.stderr)
        return 2
    meta = asyncio.run(fetch(url))
    # JSON to stdout. ensure_ascii=False 保留中文+emoji。
    print(json.dumps(meta, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
