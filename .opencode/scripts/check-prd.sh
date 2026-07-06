#!/usr/bin/env bash
# 检查 PRD 产出物
# 返回: 0=通过, 1=失败

PRD_DIR="doc/prd"
ERRORS=0

if [ ! -d "$PRD_DIR" ]; then
  echo "❌ PRD 目录不存在: $PRD_DIR"
  exit 1
fi

# 收集文件列表
FILES=()
while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(find "$PRD_DIR" -name "*.md" -print0 2>/dev/null)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "❌ PRD 目录下没有 .md 文件"
  exit 1
fi

for f in "${FILES[@]}"; do
  SIZE=$(wc -c < "$f")
  if [ "$SIZE" -lt 100 ]; then
    echo "⚠️ 文件过小(＜100B): $f"
    ERRORS=$((ERRORS + 1))
  else
    echo "✅ $(basename "$f") ($SIZE bytes)"
  fi
done

# 检查关键章节（仅 Markdown 标题）
REQUIRED_SECTIONS=("背景" "目标" "功能" "验收标准\|AC\|Acceptance")
for f in "${FILES[@]}"; do
  # 文件基本结构
  if ! grep -q "^## " "$f" 2>/dev/null; then
    echo "⚠️ 缺少 Markdown 章节标题: $f"
    ERRORS=$((ERRORS + 1))
  fi

  # 必备内容节（跳过概览文档，它结构不同）
  BASENAME=$(basename "$f")
  if [[ "$BASENAME" != _* ]] && [ "$SIZE" -gt 500 ]; then
    for section in "${REQUIRED_SECTIONS[@]}"; do
      if ! grep -Eq "^## .*($section)" "$f" 2>/dev/null; then
        echo "⚠️  $BASENAME 缺少 $section 节"
        ERRORS=$((ERRORS + 1))
      fi
    done
  fi

  # 检查技术术语侵入（PRD 不应含实现细节）
  TECH_PATTERNS="SELECT |INSERT |DELETE |CREATE TABLE|ALTER TABLE|\.py$|\.java$|npm |pip |maven|gradle"
  TECH_HITS=$(grep -cE "$TECH_PATTERNS" "$f" 2>/dev/null || echo 0)
  if [ "$TECH_HITS" -gt 0 ]; then
    echo "⚠️  $BASENAME 含 $TECH_HITS 处疑似技术术语（PRD 应避免实现细节）"
  fi
done

[ "$ERRORS" -eq 0 ] && echo "✅ PRD 检查通过" || echo "⚠️ PRD 检查完成，$ERRORS 个问题"
exit $([ "$ERRORS" -eq 0 ] && echo 0 || echo 1)
