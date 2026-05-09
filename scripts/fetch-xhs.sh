#!/usr/bin/env bash
# Usage: fetch-xhs.sh <xhs-url> <output-dir>
# 扒小红书笔记的所有图片到 output-dir/source_1.jpg .. source_N.jpg
# 退出码：0=成功；非 0=失败（stderr 打印原因）
# 依赖：XHS_DOWNLOADER_DIR 环境变量指向本地 JoeanAmier/XHS-Downloader checkout
# 默认：$HOME/tools/XHS-Downloader

set -euo pipefail

URL="${1:-}"
OUT_DIR="${2:-}"

if [[ -z "$URL" || -z "$OUT_DIR" ]]; then
  echo "Usage: $0 <xhs-url> <output-dir>" >&2
  exit 2
fi

: "${XHS_DOWNLOADER_DIR:=$HOME/tools/XHS-Downloader}"

if [[ ! -f "$XHS_DOWNLOADER_DIR/main.py" ]]; then
  echo "XHS_DOWNLOADER_DIR 指向的目录里找不到 main.py：$XHS_DOWNLOADER_DIR" >&2
  echo "请先 git clone https://github.com/JoeanAmier/XHS-Downloader 到该路径" >&2
  exit 3
fi

mkdir -p "$OUT_DIR"
OUT_DIR_ABS="$(cd "$OUT_DIR" && pwd)"
PARENT="$(dirname "$OUT_DIR_ABS")"
FOLDER="$(basename "$OUT_DIR_ABS")"

# XHS-Downloader v2.8 实际用法（基于项目 README）：
#   --url              笔记链接
#   --work_path        父目录（工具会在这下面按 --folder_name 建子目录）
#   --folder_name      子目录名
#   --download_record  true = 文件名带"<日期>_<时间>_<作者>_<标题>_<序号>.<扩展>"
#                      （extract-meta.py 从这里抠标题；XHS-Downloader v2.8 不写 .json/.txt 元数据，
#                       因此文件名是当前可靠的标题来源）
#   --image_format     AUTO = 用原格式
# 工具本身不支持"只图片"过滤，下完后脚本负责删 mp4/mov
(
  cd "$XHS_DOWNLOADER_DIR"
  python main.py \
    --url "$URL" \
    --work_path "$PARENT" \
    --folder_name "$FOLDER" \
    --image_format AUTO \
    --download_record true
) 2> "$OUT_DIR_ABS/fetch.err" || {
  echo "XHS-Downloader 扒图失败：" >&2
  cat "$OUT_DIR_ABS/fetch.err" >&2
  exit 1
}

# 工具可能在 $OUT_DIR 下再建一层（按作品标题/ID 命名），把所有图片递归平铺到 $OUT_DIR 根
find "$OUT_DIR_ABS" -mindepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
  -exec mv -n {} "$OUT_DIR_ABS/" \; 2>/dev/null || true

# 删除视频。**保留 .json/.txt** —— 万一 XHS-Downloader 后续版本写了，extract-meta.py 优先用。
find "$OUT_DIR_ABS" -type f \( -iname '*.mp4' -o -iname '*.mov' \) -delete 2>/dev/null || true

# **抽 metadata 必须在归一化重命名之前** —— 标题藏在 XHS-Downloader 原始文件名里，
# 一旦改成 source_N.<ext> 就再也抠不到了。
#
# 优先级:
#   1. fetch-xhs-meta.py: 调 XHS-Downloader 的 async API,能拿到完整正文 description (含 emoji)
#   2. extract-meta.py:   fallback,从 .json/.txt/原始文件名 解析 (拿不到正文)
#
# 两者都失败 → 写空 meta.json,下游容忍。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META_OK=""
if [[ -f "$SCRIPT_DIR/fetch-xhs-meta.py" ]]; then
  TMP_META="$OUT_DIR_ABS/.meta.tmp.json"
  if python "$SCRIPT_DIR/fetch-xhs-meta.py" "$URL" > "$TMP_META" 2>>"$OUT_DIR_ABS/fetch.err"; then
    # 校验 JSON 解析 + 至少有 title 或 description
    if python -c "
import json, sys
with open(r'$TMP_META', 'r', encoding='utf-8') as f:
    d = json.load(f)
sys.exit(0 if d.get('title') or d.get('description') else 1)
" 2>>"$OUT_DIR_ABS/fetch.err"; then
      mv "$TMP_META" "$OUT_DIR_ABS/meta.json"
      META_OK=1
      echo "meta from XHS API: title+desc OK" >&2
    else
      rm -f "$TMP_META"
    fi
  else
    rm -f "$TMP_META"
  fi
fi
if [[ -z "$META_OK" && -f "$SCRIPT_DIR/extract-meta.py" ]]; then
  echo "warn: XHS API 抽 meta 失败,回退到文件名/JSON/TXT 解析" >&2
  python "$SCRIPT_DIR/extract-meta.py" "$OUT_DIR_ABS" >&2 || \
    echo "warn: extract-meta.py 也失败,meta.json 可能为空" >&2
fi

# 归一化文件名为 source_1.<ext> .. source_N.<ext>
cd "$OUT_DIR_ABS"
i=1
for f in $(ls -1 | grep -Ei '\.(jpe?g|png|webp)$' | sort); do
  ext="${f##*.}"
  if [[ "$f" == source_*.* ]]; then continue; fi
  mv -- "$f" "source_${i}.${ext}"
  i=$((i+1))
done

# 清理空子目录
find "$OUT_DIR_ABS" -mindepth 1 -type d -empty -delete 2>/dev/null || true

count=$((i-1))
if [[ $count -eq 0 ]]; then
  echo "XHS-Downloader 未扒到任何图片，请检查链接是否有效" >&2
  exit 4
fi

echo "$count" # 输出扒到的图片张数，供调用方读取
