#!/usr/bin/env bash
# 检查代码产出物
# 返回: 0=通过, 1=失败

SRC_DIR="src"
ERRORS=0

if [ ! -d "$SRC_DIR" ]; then
  echo "❌ src 目录不存在"
  exit 1
fi

# 统计各语言文件
echo "文件统计:"
find "$SRC_DIR" -type f \( -name "*.java" -o -name "*.py" -o -name "*.go" -o -name "*.ts" -o -name "*.js" -o -name "*.vue" -o -name "*.rs" \) 2>/dev/null | awk -F. '{counts[$NF]++} END{for(ext in counts) printf "  %s: %d files\n", ext, counts[ext]}'

TOTAL_FILES=$(find "$SRC_DIR" -type f 2>/dev/null | wc -l)
echo "  总文件数: $TOTAL_FILES"

if [ "$TOTAL_FILES" -eq 0 ]; then
  echo "❌ src 目录为空"
  exit 1
fi

# 检查是否有空文件
EMPTY_FILES=$(find "$SRC_DIR" -type f -empty 2>/dev/null | wc -l)
[ "$EMPTY_FILES" -gt 0 ] && echo "⚠️  空文件: $EMPTY_FILES 个" && ERRORS=$((ERRORS + EMPTY_FILES))

[ "$ERRORS" -eq 0 ] && echo "✅ 代码检查通过" || echo "⚠️ 代码检查完成，$ERRORS 个问题"
exit $([ "$ERRORS" -eq 0 ] && echo 0 || echo 1)
