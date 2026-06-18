#!/usr/bin/env bash
set -euo pipefail
# Gate: DDL 脚本是否已生成
root="${1:-.}"
dir="$root/doc/db"
if [ ! -d "$dir" ] || ! ls "$dir"/*.sql "$dir"/*.md &>/dev/null 2>&1; then
  echo "❌ DDL 脚本不存在"
  exit 1
fi
for f in "$dir"/*.sql "$dir"/*.md; do
  [ -s "$f" ] && echo "✅ DDL: $(basename "$f")" && exit 0
done
echo "❌ DDL 脚本全部为空"
exit 1
