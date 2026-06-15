#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then echo "请使用 bash 运行: bash install.sh" >&2; exit 1; fi
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✅${NC} $1"; }
info() { echo -e "  ${CYAN}ℹ️${NC}  $1"; }
fail() { echo -e "  ${RED}❌${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$(pwd)}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  coding-pipeline 一键安装                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  目标目录: $TARGET"
echo ""

# ── 0. 前置检查 ──
if ! command -v node &>/dev/null; then
  fail "需要 Node.js，请先安装: https://nodejs.org"
fi
if ! command -v npm &>/dev/null; then
  fail "需要 npm，请确保 Node.js 安装正确"
fi

# ── 1. 复制 .opencode 目录 ──
OPTSRC="$SCRIPT_DIR/.opencode"
OPTDST="$TARGET/.opencode"

mkdir -p "$OPTDST"
echo "  ├─ 复制 skills/..."
cp -r "$OPTSRC/skills" "$OPTDST/"
ok "skills/ ($(find "$OPTDST/skills" -name SKILL.md | wc -l) skills)"

echo "  ├─ 复制 plugins/..."
cp -r "$OPTSRC/plugins" "$OPTDST/"
ok "plugins/ ($(find "$OPTDST/plugins" -name '*.ts' | wc -l) plugins)"

echo "  ├─ 复制 tsconfig.json..."
cp "$OPTSRC/tsconfig.json" "$OPTDST/" 2>/dev/null || info "tsconfig.json 不存在，跳过"

echo "  ├─ 复制 scripts/..."
cp -r "$OPTSRC/scripts" "$OPTDST/"
ok "scripts/ ($(find "$OPTDST/scripts" -name '*.sh' | wc -l) scripts)"

echo "  ├─ 复制 rules/..."
cp -r "$OPTSRC/rules" "$OPTDST/"
ok "rules/ ($(find "$OPTDST/rules" -name '*.md' | wc -l) rules)"

# .gitignore
cp "$OPTSRC/.gitignore" "$OPTDST/" 2>/dev/null || true

# .opencode/README.md
cp "$OPTSRC/README.md" "$OPTDST/" 2>/dev/null || true

# token-saver.json
cp "$OPTSRC/token-saver.json" "$OPTDST/" 2>/dev/null || true
ok "token-saver.json"

# commands/
cp -r "$OPTSRC/commands" "$OPTDST/" 2>/dev/null || info "commands/ 不存在，跳过"

# ── 2. 创建 / 更新 package.json ──
PKG="$OPTDST/package.json"
if [ -f "$PKG" ]; then
  info "package.json 已存在"
elif [ -f "$OPTSRC/package.json" ]; then
  cp "$OPTSRC/package.json" "$PKG"
  ok "package.json 已创建（从源码同步）"
else
  echo '{"dependencies":{"@opencode-ai/plugin":"1.17.4"}}' > "$PKG"
  ok "package.json 已创建（默认版本）"
fi

echo "  ├─ npm install (生产依赖)..."
cd "$OPTDST" && npm install --silent --omit=dev 2>&1 | tail -1
cd "$SCRIPT_DIR"
ok "npm 依赖安装完成"

# ── 3. 复制根目录文件 ──
for f in opencode.json; do
  if [ -f "$SCRIPT_DIR/$f" ]; then
    cp "$SCRIPT_DIR/$f" "$TARGET/"
    ok "$f"
  fi
done


# ── 5. 验证 ──
echo ""
echo -e "${CYAN}── 验证 ──${NC}"
ERRORS=0

[ -f "$TARGET/opencode.json" ] && ok "opencode.json" || { fail "opencode.json 缺失"; ERRORS=$((ERRORS+1)); }
[ -d "$TARGET/.opencode/plugins" ] && ok ".opencode/plugins/" || { fail ".opencode/plugins/ 缺失"; ERRORS=$((ERRORS+1)); }
[ -d "$TARGET/.opencode/skills" ] && ok ".opencode/skills/" || { fail ".opencode/skills/ 缺失"; ERRORS=$((ERRORS+1)); }
[ -d "$TARGET/.opencode/scripts" ] && ok ".opencode/scripts/" || { fail ".opencode/scripts/ 缺失"; ERRORS=$((ERRORS+1)); }
[ -d "$TARGET/.opencode/rules" ] && ok ".opencode/rules/" || { fail ".opencode/rules/ 缺失"; ERRORS=$((ERRORS+1)); }
[ -f "$TARGET/.opencode/token-saver.json" ] && ok "token-saver.json" || info "token-saver.json 不存在（可选）"
[ -d "$TARGET/.opencode/commands" ] && ok ".opencode/commands/" || info ".opencode/commands/ 不存在（可选）"

SKILL_COUNT=$(find "$TARGET/.opencode/skills" -name SKILL.md | wc -l)
[ "$SKILL_COUNT" -eq 10 ] && ok "$SKILL_COUNT/10 skills" || info "skills: $SKILL_COUNT/10"

RULE_COUNT=$(find "$TARGET/.opencode/rules" -name '*.md' | wc -l)
[ "$RULE_COUNT" -eq 4 ] && ok "$RULE_COUNT/4 rules" || info "rules: $RULE_COUNT/4"

SCRIPT_COUNT=$(find "$TARGET/.opencode/scripts" -name '*.sh' | wc -l)
[ "$SCRIPT_COUNT" -eq 8 ] && ok "$SCRIPT_COUNT/8 scripts" || info "scripts: $SCRIPT_COUNT/8"

if [ "$ERRORS" -gt 0 ]; then
  fail "安装完成，但存在 $ERRORS 个问题，请检查"
fi

echo ""
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}  安装完成！${NC}"
echo -e "${GREEN}  现在可以在 $TARGET 中启动 OpenCode:${NC}"
echo -e "${GREEN}    opencode${NC}"
echo -e "${GREEN}  查看 opencode.json 获取配置说明${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo ""
echo "  快速验证 — 在 OpenCode 中输入:"
echo '    可用的自定义工具有哪些？'
echo "  预期看到 call_prd_writer, call_review_expert, ..."
echo ""
