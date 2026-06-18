#!/usr/bin/env bash
set -euo pipefail
# Gate: PRD 文档是否已生成
root="${1:-.}"
dir="$root/doc/prd"
if [ ! -d "$dir" ] || ! ls "$dir"/*.md &>/dev/null 2>&1; then
  echo "❌ PRD 文档不存在"
  exit 1
fi
# 检查是否有非空 md 文件
for f in "$dir"/*.md; do
  [ -s "$f" ] && echo "✅ PRD: $(basename "$f")" && exit 0
done
echo "❌ PRD 文档全部为空"
exit 1
