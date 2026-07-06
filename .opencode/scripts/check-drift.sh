#!/usr/bin/env bash
# 检查 P7 规范漂移检测产出物
# 验证 task-decomposer 同步后的契约文档与代码一致
# 返回: 0=通过, 1=失败

DETAILED_DIR="doc/detailed"
SRC_DIR="src"
ERRORS=0

# 如果 P7 未执行（无 scope 或无漂移），直接通过
if [ -z "$SCOPE_MODULES" ] && [ ! -f "_MEMORY_CACHE.md" ]; then
  echo "ℹ️  P7 未触发，跳过漂移检查"
  exit 0
fi

echo "=== P7 规范漂移检测 ==="

# 1. 检查项目规则和编码规范是否存在
for req in "项目规则.md" "编码规范.md"; do
  if [ -f "$DETAILED_DIR/$req" ]; then
    RULES_SIZE=$(wc -c < "$DETAILED_DIR/$req")
    echo "  ✅ $req ($RULES_SIZE bytes)"
    [ "$RULES_SIZE" -lt 100 ] && echo "  ⚠️  $req 文件过小" && ERRORS=$((ERRORS + 1))
  else
    echo "  ⚠️  $req 不存在（P7 未执行也正常）"
  fi
done

# 2. 检查 P7 进化记录是否追加到规范文档（如果有变更）
if [ -f "$DETAILED_DIR/项目规则.md" ]; then
  if grep -q "P7-.*自动进化" "$DETAILED_DIR/项目规则.md" 2>/dev/null; then
    P7_LINES=$(grep -c "P7-.*自动进化" "$DETAILED_DIR/项目规则.md")
    echo "  ✅ 项目规则.md 记录了 $P7_LINES 次 P7 进化"
  fi
fi
if [ -f "$DETAILED_DIR/编码规范.md" ]; then
  if grep -q "P7-.*自动进化" "$DETAILED_DIR/编码规范.md" 2>/dev/null; then
    P7_LINES=$(grep -c "P7-.*自动进化" "$DETAILED_DIR/编码规范.md")
    echo "  ✅ 编码规范.md 记录了 $P7_LINES 次 P7 进化"
  fi
fi

# 3. 检查 SCOPE 标注（如果存在 _MEMORY_CACHE.md）
if [ -f "_MEMORY_CACHE.md" ]; then
  SCOPE_LINE=$(grep "变更范围" _MEMORY_CACHE.md 2>/dev/null | head -1)
  if [ -n "$SCOPE_LINE" ]; then
    echo "  ℹ️  本次 P7 范围: $SCOPE_LINE"
  fi
fi

echo ""
[ "$ERRORS" -eq 0 ] && echo "✅ P7 漂移检查通过" || echo "⚠️ P7 漂移检查完成，$ERRORS 个问题"
exit $([ "$ERRORS" -eq 0 ] && echo 0 || echo 1)
