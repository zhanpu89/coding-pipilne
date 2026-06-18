#!/usr/bin/env bash
set -euo pipefail
# Gate: 评审报告是否已生成
root="${1:-.}"
dir="$root/doc/review"
if [ ! -d "$dir" ] || ! ls "$dir"/*.md &>/dev/null 2>&1; then
  echo "❌ 评审报告不存在"
  exit 1
fi
for f in "$dir"/*.md; do
  [ -s "$f" ] && echo "✅ 评审报告: $(basename "$f")" && exit 0
done
echo "❌ 评审报告全部为空"
exit 1
