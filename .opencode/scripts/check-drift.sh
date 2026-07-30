#!/usr/bin/env bash
# 检查 P7 规范漂移检测产出物
# 验证 task-decomposer 同步后的契约文档与代码一致
# 检测代码实现与架构约束之间的系统偏差
# 返回: 0=通过, 1=失败

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DETAILED_DIR="doc/detailed"
SRC_DIR="$PROJECT_DIR/src"
ERRORS=0

echo "=== P7 规范漂移检测 ==="

# ---- 1. 架构漂移检测 ----
# 对比 tech-stack.json 中的 architectureRules 与当前代码实现
TS_FILE="$PROJECT_DIR/doc/arch/tech-stack.json"
if [ -f "$TS_FILE" ]; then
  ARCH_RULES=$(python3 -c "
import json
with open('$TS_FILE') as f:
    d = json.load(f)
ar = d.get('architectureRules', {})
print('layerCount=' + str(len(ar.get('layerIsolation', []))))
" 2>/dev/null)

  if echo "$ARCH_RULES" | grep -q "layerCount=[1-9]"; then
    echo ""
    echo "--- 架构漂移扫描 ---"
    # 以正向检测思路：发现代码中有违反架构规则的模式
    # 但由于 code-developer 在 P5a 已经通过了 check-arch-compliance.sh，
    # 这里只检查增量：对比 git diff 是否有绕过架构约束的新代码
    if git rev-parse --git-dir >/dev/null 2>&1; then
      CHANGED_FILES=$(git diff --name-only HEAD~1 2>/dev/null || git diff --name-only HEAD 2>/dev/null || echo "")
      if [ -n "$CHANGED_FILES" ]; then
        echo "  本次变更文件: $(echo "$CHANGED_FILES" | wc -l) 个"
        # 用 check-arch-compliance.sh 验证变更文件中的架构合规性
        COMPLIANCE_RESULT=$("$PROJECT_DIR/.opencode/scripts/check-arch-compliance.sh" 2>&1 || true)
        if echo "$COMPLIANCE_RESULT" | grep -q "违规\|⚠️"; then
          echo "  ⚠️  检测到架构漂移: 新代码违反 architectureRules"
          echo "$COMPLIANCE_RESULT" | grep "⚠️"
          ERRORS=$((ERRORS + 1))
        else
          echo "  架构约束一致性检查通过 ✅"
        fi
      else
        echo "  无新增变更，跳过增量架构漂移检测"
      fi
    fi
  else
    echo "  无 architectureRules，跳过架构漂移检测"
  fi
else
  echo "  无 tech-stack.json，跳过架构漂移检测"
fi

# ---- 2. 规范文档完整性检查 ----
echo ""
echo "--- 规范文档检查 ---"
for req in "项目规则.md" "编码规范.md"; do
  if [ -f "$PROJECT_DIR/$DETAILED_DIR/$req" ]; then
    RULES_SIZE=$(wc -c < "$PROJECT_DIR/$DETAILED_DIR/$req")
    echo "  ✅ $req ($RULES_SIZE bytes)"
    [ "$RULES_SIZE" -lt 100 ] && echo "  ⚠️  $req 文件过小" && ERRORS=$((ERRORS + 1))
  else
    echo "  ℹ️  $req 不存在"
  fi
done

# ---- 3. P7 进化记录检查 ----
if [ -f "$PROJECT_DIR/$DETAILED_DIR/项目规则.md" ]; then
  P7_COUNT=$(grep -c "P7-.*自动进化" "$PROJECT_DIR/$DETAILED_DIR/项目规则.md" 2>/dev/null || echo 0)
  [ "$P7_COUNT" -gt 0 ] && echo "  ✅ 项目规则.md 记录了 $P7_COUNT 次 P7 进化"
fi
if [ -f "$PROJECT_DIR/$DETAILED_DIR/编码规范.md" ]; then
  P7_COUNT=$(grep -c "P7-.*自动进化" "$PROJECT_DIR/$DETAILED_DIR/编码规范.md" 2>/dev/null || echo 0)
  [ "$P7_COUNT" -gt 0 ] && echo "  ✅ 编码规范.md 记录了 $P7_COUNT 次 P7 进化"
fi

# ---- 汇总 ----
echo ""
[ "$ERRORS" -eq 0 ] && echo "✅ P7 漂移检查通过" || echo "⚠️ P7 漂移检查完成，$ERRORS 个问题"
exit $([ "$ERRORS" -eq 0 ] && echo 0 || echo 1)
