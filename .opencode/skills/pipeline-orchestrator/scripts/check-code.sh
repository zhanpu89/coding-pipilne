#!/usr/bin/env bash
set -euo pipefail
# Gate: 业务代码是否已生成
root="${1:-.}"
src="$root/src"
if [ ! -d "$src" ]; then
  echo "❌ src/ 目录不存在"
  exit 1
fi
count=$(find "$src" -name "*.py" -o -name "*.java" -o -name "*.go" -o -name "*.js" -o -name "*.ts" -o -name "*.rs" 2>/dev/null | wc -l)
if [ "$count" -eq 0 ]; then
  echo "❌ src/ 中未找到代码文件"
  exit 1
fi
echo "✅ 代码文件: $count 个"
exit 0
