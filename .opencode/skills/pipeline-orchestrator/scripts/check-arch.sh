#!/usr/bin/env bash
set -euo pipefail
# Gate: 架构文档(SAD)是否已生成
root="${1:-.}"
dir="$root/doc/arch"
if [ ! -d "$dir" ] || ! ls "$dir"/*.md &>/dev/null 2>&1; then
  echo "❌ 架构文档不存在"
  exit 1
fi
for f in "$dir"/*.md; do
  [ -s "$f" ] && echo "✅ 架构: $(basename "$f")" && exit 0
done
echo "❌ 架构文档全部为空"
exit 1
