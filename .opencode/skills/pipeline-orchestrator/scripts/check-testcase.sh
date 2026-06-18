#!/usr/bin/env bash
set -euo pipefail
# Gate: 测试用例文档是否已生成
root="${1:-.}"
dir="$root/doc/tester"
if [ ! -d "$dir" ] || ! ls "$dir"/*.md &>/dev/null 2>&1; then
  echo "❌ 测试用例文档不存在"
  exit 1
fi
for f in "$dir"/*.md; do
  [ -s "$f" ] && echo "✅ 测试用例: $(basename "$f")" && exit 0
done
echo "❌ 测试用例文档全部为空"
exit 1
