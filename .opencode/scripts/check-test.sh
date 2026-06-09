#!/usr/bin/env bash
# 检查测试代码产出物（阶段二）
# 返回: 0=通过, 1=失败

TESTER_DIR="doc/tester"
SRC_TEST_DIR="src/test"
ERRORS=0

# 检查测试用例文档
if [ -d "$TESTER_DIR" ]; then
  TC_FILES=$(find "$TESTER_DIR" -name "*测试用例*" -o -name "*testcase*" 2>/dev/null)
  if [ -z "$TC_FILES" ]; then
    echo "❌ 没有测试用例文档"
    ERRORS=$((ERRORS + 1))
  else
    for f in $TC_FILES; do
      echo "  ✅ 用例: $(basename "$f") ($(wc -c < "$f") bytes)"
    done
  fi

  # 检查测试报告
  REPORT_FILES=$(find "$TESTER_DIR" -name "*测试报告*" -o -name "*report*" 2>/dev/null)
  if [ -z "$REPORT_FILES" ]; then
    echo "⚠️  没有测试报告"
    ERRORS=$((ERRORS + 1))
  else
    for f in $REPORT_FILES; do
      echo "  ✅ 报告: $(basename "$f")"
    done
  fi
else
  echo "❌ doc/tester 目录不存在"
  ERRORS=$((ERRORS + 1))
fi

# 检查测试代码
if [ -d "$SRC_TEST_DIR" ]; then
  TEST_FILES=$(find "$SRC_TEST_DIR" -type f 2>/dev/null | wc -l)
  if [ "$TEST_FILES" -eq 0 ]; then
    echo "⚠️  src/test 目录为空"
    ERRORS=$((ERRORS + 1))
  else
    echo "✅ 测试代码文件: $TEST_FILES"
  fi
else
  echo "⚠️  src/test 目录不存在"
  ERRORS=$((ERRORS + 1))
fi

[ "$ERRORS" -eq 0 ] && echo "✅ 测试检查通过" || echo "⚠️ 测试检查完成，$ERRORS 个问题"
exit $([ "$ERRORS" -eq 0 ] && echo 0 || echo 1)
