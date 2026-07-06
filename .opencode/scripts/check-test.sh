#!/usr/bin/env bash
# 检查测试代码产出物（阶段二）
# 返回: 0=通过, 1=失败

TESTER_DIR="doc/tester"
SRC_TEST_DIR="src/test"
ERRORS=0

# 检查测试用例文档
if [ -d "$TESTER_DIR" ]; then
  TC_FILES=()
  while IFS= read -r -d '' f; do
    TC_FILES+=("$f")
  done < <(find "$TESTER_DIR" \( -name "*测试用例*" -o -name "*testcase*" -o -name "*用例*" \) -print0 2>/dev/null)

  if [ ${#TC_FILES[@]} -eq 0 ]; then
    echo "❌ 没有测试用例文档"
    ERRORS=$((ERRORS + 1))
  else
    for f in "${TC_FILES[@]}"; do
      SIZE=$(wc -c < "$f")
      echo "  ✅ 用例文档: $(basename "$f") ($SIZE bytes)"

      # 验证用例文档包含 TC-ID 格式
      TC_COUNT=$(grep -cE "TC-[A-Z]+-(UNIT|INTG|SEC|PERF|FE)-[0-9]+" "$f" 2>/dev/null || echo 0)
      if [ "$TC_COUNT" -gt 0 ]; then
        echo "      → 含 $TC_COUNT 个标准格式用例 ID"
      fi

      [ "$SIZE" -lt 200 ] && echo "⚠️  用例文档过小" && ERRORS=$((ERRORS + 1))
    done
  fi

  REPORT_FILES=()
  while IFS= read -r -d '' f; do
    REPORT_FILES+=("$f")
  done < <(find "$TESTER_DIR" \( -name "*测试报告*" -o -name "*report*" -o -name "*报告*" \) -print0 2>/dev/null)

  if [ ${#REPORT_FILES[@]} -eq 0 ]; then
    echo "⚠️  没有测试报告"
  else
    for f in "${REPORT_FILES[@]}"; do
      echo "  ✅ 测试报告: $(basename "$f")"
      # 验证报告含结论
      if grep -qiE "(PASS|FAIL|通过|失败|✅|❌)" "$f" 2>/dev/null; then
        CONCLUSION=$(grep -iE "(PASS|FAIL|通过|失败|✅|❌)" "$f" | head -1 | tr -dc '[:print:]' | head -c 80)
        echo "      → 含结论: $CONCLUSION"
      fi
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

    # 统计断言数量（验证测试真实存在）
    ASSERT_COUNT=0
    for ext in py java ts js go rs; do
      count=$(grep -rE "(assert|expect|Assert|shouldBe)" "$SRC_TEST_DIR" --include="*.$ext" 2>/dev/null | wc -l)
      ASSERT_COUNT=$((ASSERT_COUNT + count))
    done
    if [ "$ASSERT_COUNT" -gt 0 ]; then
      echo "✅  断言语句总数: $ASSERT_COUNT"
    else
      echo "⚠️  未找到断言语句，测试文件可能为空壳"
    fi
  fi
else
  echo "⚠️  src/test 目录不存在"
  ERRORS=$((ERRORS + 1))
fi

[ "$ERRORS" -eq 0 ] && echo "✅ 测试检查通过" || echo "⚠️ 测试检查完成，$ERRORS 个问题"
exit $([ "$ERRORS" -eq 0 ] && echo 0 || echo 1)
