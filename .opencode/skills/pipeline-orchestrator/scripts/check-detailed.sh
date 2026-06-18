#!/usr/bin/env bash
set -euo pipefail
# Gate: 详细设计文档是否已生成
root="${1:-.}"
dir="$root/doc/detailed"
if [ ! -d "$dir" ] || ! ls "$dir"/*.md &>/dev/null 2>&1; then
  echo "❌ 详细设计文档不存在"
  exit 1
fi
for f in "$dir"/*.md; do
  [ -s "$f" ] && echo "✅ 详设: $(basename "$f")" && exit 0
done
echo "❌ 详细设计文档全部为空"
exit 1
