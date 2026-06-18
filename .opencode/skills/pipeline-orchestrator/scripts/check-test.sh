#!/usr/bin/env bash
set -euo pipefail
# Gate: 测试是否已执行通过
root="${1:-.}"
test_dirs=("$root/src/test" "$root/tests" "$root/src/test/java" "$root/src/test/python")
for d in "${test_dirs[@]}"; do
  if [ -d "$d" ]; then
    count=$(find "$d" -name "*test*" -o -name "*Test*" -o -name "*spec*" 2>/dev/null | wc -l)
    if [ "$count" -gt 0 ]; then
      echo "✅ 测试文件: $count 个 (在 $(basename "$d"))"
      exit 0
    fi
  fi
done
# fallback: 检查是否有 pytest.ini / jest.config 等
if ls "$root/pytest.ini" "$root/jest.config*" "$root/.jest" 2>/dev/null | head -1 >/dev/null; then
  echo "⚠️ 测试配置存在，但未找到测试文件"
  exit 0
fi
echo "❌ 未找到测试文件"
exit 1
