#!/usr/bin/env bash
# 自举门禁 — 验证 pipeline 工具自身的结构完整性
# 适用于修改 .opencode/ 下的脚本/规则/SKILL/配置后的自检
# 退出码: 0=通过, 1=警告, 2=阻断
#
# 使用方式:
#   bash .opencode/scripts/check-opencode.sh

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ERRORS=0
WARNINGS=0

echo "=== Pipeline 工具自身检查 ==="

# ---- 1. bash 语法检查 ----
echo ""
echo "--- Shell 语法 ---"
SCRIPT_FILES=()
while IFS= read -r -d '' f; do
  SCRIPT_FILES+=("$f")
done < <(find "$PROJECT_DIR/.opencode/scripts" -name "*.sh" -print0 2>/dev/null)

for f in "${SCRIPT_FILES[@]}"; do
  REL="${f#$PROJECT_DIR/}"
  if bash -n "$f" 2>/dev/null; then
    echo "  ✅ $REL"
  else
    echo "  ❌ $REL — bash 语法错误:"
    bash -n "$f" 2>&1 | sed 's/^/      /'
    ERRORS=$((ERRORS + 1))
  fi
done

# ---- 2. opencode.json 验证 ----
echo ""
echo "--- opencode.json 验证 ---"
if [ -f "$PROJECT_DIR/opencode.json" ]; then
  python3 -c "
import json, sys
with open('$PROJECT_DIR/opencode.json') as f:
    d = json.load(f)
assert 'default_agent' in d, '缺少 default_agent'
assert 'agent' in d, '缺少 agent'
assert 'pipeline-orchestrator' in d['agent'], '缺少 pipeline-orchestrator agent'
# 检查所有 agent 有 description
for name, cfg in d['agent'].items():
    assert 'description' in cfg, f'{name} 缺少 description'
    assert 'prompt' in cfg, f'{name} 缺少 prompt'
print('  ✅ JSON 格式有效，agent 配置完整')
" 2>&1 || {
  echo "  ❌ opencode.json 验证失败"
  ERRORS=$((ERRORS + 1))
}
else
  echo "  ❌ opencode.json 不存在"
  ERRORS=$((ERRORS + 1))
fi

# ---- 3. SKILL.md front matter 检查 ----
echo ""
echo "--- SKILL.md 结构检查 ---"
SKILL_FILES=()
while IFS= read -r -d '' f; do
  SKILL_FILES+=("$f")
done < <(find "$PROJECT_DIR/.opencode/skills" -name "SKILL.md" -print0 2>/dev/null)

for f in "${SKILL_FILES[@]}"; do
  REL="${f#$PROJECT_DIR/}"
  # 检查前 3 行是否为 YAML front matter (--- ... ---)
  LINE1=$(head -1 "$f" 2>/dev/null)
  LINE2=$(head -3 "$f" 2>/dev/null | tail -1)
  if [ "$LINE1" = "---" ]; then
    # find closing ---
    CLOSING=$(tail -n +2 "$f" | grep -n "^---" | head -1 | cut -d: -f1)
    if [ -n "$CLOSING" ]; then
      echo "  ✅ $REL (YAML front matter: $CLOSING 行)"
    else
      echo "  ⚠️  $REL — 有开 --- 无闭 ---"
      WARNINGS=$((WARNINGS + 1))
    fi
  else
    echo "  ⚠️  $REL — 无 YAML front matter"
    WARNINGS=$((WARNINGS + 1))
  fi
done

# ---- 4. 引用完整性检查 ----
echo ""
echo "--- 引用完整性 ---"
# 检查 scripts 表中引用的文件是否存在
REF_FILES=(
  ".opencode/scripts/check-arch.sh"
  ".opencode/scripts/check-arch-compliance.sh"
  ".opencode/scripts/check-audit.sh"
  ".opencode/scripts/check-code.sh"
  ".opencode/scripts/check-detailed.sh"
  ".opencode/scripts/check-drift.sh"
  ".opencode/scripts/check-integration.sh"
  ".opencode/scripts/check-prd.sh"
  ".opencode/scripts/check-review.sh"
  ".opencode/scripts/check-test.sh"
  ".opencode/scripts/check-testcase.sh"
  ".opencode/scripts/log-skill.sh"
)
MISSING=0
for f in "${REF_FILES[@]}"; do
  if [ -f "$PROJECT_DIR/$f" ]; then
    echo "  ✅ $f"
  else
    echo "  ❌ $f — 引用文件不存在"
    ERRORS=$((ERRORS + 1))
    MISSING=$((MISSING + 1))
  fi
done
[ "$MISSING" -eq 0 ] && echo "  所有引用文件存在 ✅"

# ---- 5. opencode.json 中 agent 名称与 SKILL.md 一致性 ----
echo ""
echo "--- Agent/SKILL 一致性 ---"
python3 -c "
import json, os, sys
with open('$PROJECT_DIR/opencode.json') as f:
    d = json.load(f)
agents = d.get('agent', {})
skills_dir = '$PROJECT_DIR/.opencode/skills'
all_good = True
for name in agents:
    skill_path = os.path.join(skills_dir, name, 'SKILL.md')
    if agents[name].get('mode') == 'primary':
        continue  # 主 agent 不走 file 加载
    if not os.path.exists(skill_path):
        print(f'  ❌ agent {name}: 对应的 .opencode/skills/{name}/SKILL.md 不存在')
        all_good = False
    else:
        print(f'  ✅ {name} → skills/{name}/SKILL.md')
if all_good:
    print('  所有 agent 有对应 SKILL.md ✅')
" 2>&1 || ERRORS=$((ERRORS + 1))

# ---- 汇总 ----
echo ""
echo "=== 自举检查汇总 ==="
echo "阻断: $ERRORS | 警告: $WARNINGS"
if [ "$ERRORS" -gt 0 ]; then
  echo "❌ 自举检查不通过，$ERRORS 个阻断问题"
  exit 2
elif [ "$WARNINGS" -gt 0 ]; then
  echo "⚠️  自举检查有条件通过，$WARNINGS 个警告"
  exit 1
else
  echo "✅ 自举检查通过"
  exit 0
fi
