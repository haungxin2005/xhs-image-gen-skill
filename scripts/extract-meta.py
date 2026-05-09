#!/usr/bin/env python3
"""
extract-meta.py

Read XHS-Downloader's per-note metadata in <out_dir> and write a normalized
<out_dir>/meta.json with {title, description, tags}.

Sources tried, in order:
  1. *.json files (XHS-Downloader's machine-readable record, when --download_record true)
  2. *.txt files (XHS-Downloader's human-readable note dump)
  3. Image filenames matching `<YYYY-MM-DD>_<HH.MM.SS>_<author>_<title>_<N>.<ext>`
     (XHS-Downloader v2.8 encodes title in filename when --download_record true,
     even though it does NOT write a separate metadata file)

Called by fetch-xhs.sh BEFORE the source_N rename step (otherwise filenames
have already been normalized and source 3 won't work).

Idempotent. If no metadata can be found, writes meta.json with empty fields
(downstream code does not need to special-case missing files).

Usage:
    python extract-meta.py <out_dir>
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

TITLE_KEYS = ("作品标题", "title", "Title", "name")
DESC_KEYS = ("作品描述", "desc", "description", "Description", "content")
TAG_KEYS = ("作品标签", "tag_list", "tags", "Tags")

# XHS-Downloader filename pattern when --download_record true
#   2026-04-16_18.06.15_阿懒玩转家电_三天三夜爆肝研究！洗碗机产品推荐！_1.jpeg
FILENAME_PATTERN = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})_"
    r"(?P<time>\d{2}\.\d{2}\.\d{2})_"
    r"(?P<author>[^_]+)_"
    r"(?P<title>.+)_"
    r"\d+\.\w+$"
)


def coerce_tags(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(v).strip().lstrip("#") for v in value if str(v).strip()]
    if isinstance(value, str):
        parts = [p.strip().lstrip("#") for p in value.replace(",", " ").split() if p.strip()]
        return parts
    return []


def first_nonempty(d: dict, keys: tuple[str, ...]) -> str:
    for k in keys:
        v = d.get(k)
        if v is None:
            continue
        s = str(v).strip()
        if s:
            return s
    return ""


def parse_json_file(path: Path) -> dict | None:
    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return None
    if isinstance(data, dict) and "data" in data and isinstance(data["data"], (dict, list)):
        data = data["data"]
    if isinstance(data, list) and data:
        data = data[0]
    if not isinstance(data, dict):
        return None
    return {
        "title": first_nonempty(data, TITLE_KEYS),
        "description": first_nonempty(data, DESC_KEYS),
        "tags": coerce_tags(
            data.get(TAG_KEYS[0]) or data.get(TAG_KEYS[1]) or data.get(TAG_KEYS[2]) or data.get(TAG_KEYS[3])
        ),
    }


def parse_txt_file(path: Path) -> dict | None:
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return None
    lines = [ln.rstrip() for ln in text.splitlines() if ln.strip()]
    if not lines:
        return None
    title = lines[0]
    description = "\n".join(lines[1:])
    tags: list[str] = []
    for ln in lines[1:]:
        for token in ln.split():
            if token.startswith("#") and len(token) > 1:
                tags.append(token.lstrip("#"))
    return {"title": title, "description": description, "tags": tags}


def parse_filename(out_dir: Path) -> dict | None:
    """Last-resort: extract title from XHS-Downloader's filename pattern."""
    for img in sorted(out_dir.rglob("*")):
        if not img.is_file():
            continue
        m = FILENAME_PATTERN.match(img.name)
        if m:
            return {
                "title": m.group("title"),
                "description": "",  # body is not in filename
                "tags": [],
                "author": m.group("author"),
                "publish_time": f"{m.group('date')} {m.group('time').replace('.', ':')}",
            }
    return None


def find_meta(out_dir: Path) -> dict:
    json_candidates = [p for p in sorted(out_dir.rglob("*.json")) if p.name != "meta.json"]
    for jf in json_candidates:
        result = parse_json_file(jf)
        if result and (result["title"] or result["description"]):
            return result
    for tf in sorted(out_dir.rglob("*.txt")):
        result = parse_txt_file(tf)
        if result and (result["title"] or result["description"]):
            return result
    fn_result = parse_filename(out_dir)
    if fn_result:
        return fn_result
    return {"title": "", "description": "", "tags": []}


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: extract-meta.py <out_dir>", file=sys.stderr)
        return 2
    out_dir = Path(sys.argv[1]).resolve()
    if not out_dir.is_dir():
        print(f"out_dir not found or not a directory: {out_dir}", file=sys.stderr)
        return 3
    meta = find_meta(out_dir)
    target = out_dir / "meta.json"
    target.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    # ASCII-only summary so cp936/gbk consoles (Windows default) don't crash on encode.
    title_flag = "OK" if meta.get("title") else "--"
    desc_flag = "OK" if meta.get("description") else "--"
    print(f"meta extracted: title={title_flag} desc={desc_flag} tags={len(meta.get('tags', []))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
