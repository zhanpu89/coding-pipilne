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

echo "  ├─ 复制 scripts/..."
cp -r "$OPTSRC/scripts" "$OPTDST/"
ok "scripts/ ($(find "$OPTDST/scripts" -name '*.sh' | wc -l) scripts)"

echo "  ├─ 复制 rules/..."
cp -r "$OPTSRC/rules" "$OPTDST/"
ok "rules/ ($(find "$OPTDST/rules" -name '*.md' | wc -l) rules)"

# .gitignore
cp "$OPTSRC/.gitignore" "$OPTDST/" 2>/dev/null || true


# commands/（OpenCode 自动发现）
cp -r "$OPTSRC/commands" "$OPTDST/" 2>/dev/null || info "commands/ 不存在，跳过"

# ── 2. 创建 / 更新 package.json（强制覆盖）──
PKG="$OPTDST/package.json"
if [ -f "$OPTSRC/package.json" ]; then
  cp "$OPTSRC/package.json" "$PKG"
  ok "package.json 已同步（从源码强制覆盖）"
else
  echo '{"devDependencies":{"@types/node":"^25.9.3","typescript":"^5.8.0"}}' > "$PKG"
  ok "package.json 已创建（默认版本）"
fi

echo "  ├─ npm install..."
cd "$OPTDST" && npm install --silent 2>&1 | tail -1
cd "$SCRIPT_DIR"
ok "npm 依赖安装完成"

# ── 3. 复制根目录文件 ──
# 注意：README.md 和 AGENTS.md 是项目说明/代理定义文件，对目标项目运行时无影响，
#       故意不复制到目标目录，避免覆盖用户自己的同名文件。
for f in opencode.json; do
  if [ -f "$SCRIPT_DIR/$f" ]; then
    cp "$SCRIPT_DIR/$f" "$TARGET/"
    ok "$f"
  fi
done
# README.md（不安装）
[ -f "$SCRIPT_DIR/README.md" ] && info "README.md 跳过（设计上不安装）" || true
# AGENTS.md（不安装）
[ -f "$SCRIPT_DIR/AGENTS.md" ] && info "AGENTS.md 跳过（设计上不安装）" || true

# ── 3.5 项目镜像引导（适配为该项目专职开发者）──
echo ""
echo -e "${CYAN}── 项目镜像引导 ──${NC}"
if [ -f "$OPTDST/scripts/project-init.sh" ]; then
  ( cd "$TARGET" && bash "$OPTDST/scripts/project-init.sh" )
else
  info "project-init.sh 未找到，跳过镜像引导"
fi

# ── 4. 验证 ──
echo ""
echo -e "${CYAN}── 验证 ──${NC}"
ERRORS=0

[ -f "$TARGET/opencode.json" ] && ok "opencode.json" || { fail "opencode.json 缺失"; ERRORS=$((ERRORS+1)); }
[ -d "$TARGET/.opencode/skills" ] && ok ".opencode/skills/" || { fail ".opencode/skills/ 缺失"; ERRORS=$((ERRORS+1)); }
[ -d "$TARGET/.opencode/scripts" ] && ok ".opencode/scripts/" || { fail ".opencode/scripts/ 缺失"; ERRORS=$((ERRORS+1)); }
[ -d "$TARGET/.opencode/rules" ] && ok ".opencode/rules/" || { fail ".opencode/rules/ 缺失"; ERRORS=$((ERRORS+1)); }

[ -d "$TARGET/.opencode/commands" ] && ok ".opencode/commands/ ($(find "$TARGET/.opencode/commands" -name '*.md' | wc -l) commands)" || info ".opencode/commands/ 不存在（可选）"

# 数量校验：以源码库为准动态推导（适配未来添砖加瓦新增脚本/规则）
EXPECT_SKILLS=$(find "$SCRIPT_DIR/.opencode/skills" -name SKILL.md | wc -l | tr -d ' ')
EXPECT_RULES=$(find "$SCRIPT_DIR/.opencode/rules" -name '*.md' | wc -l | tr -d ' ')
EXPECT_SCRIPTS=$(find "$SCRIPT_DIR/.opencode/scripts" -name '*.sh' | wc -l | tr -d ' ')

SKILL_COUNT=$(find "$TARGET/.opencode/skills" -name SKILL.md | wc -l)
[ "$SKILL_COUNT" -eq "$EXPECT_SKILLS" ] && ok "$SKILL_COUNT/$EXPECT_SKILLS skills" || info "skills: $SKILL_COUNT/$EXPECT_SKILLS（预期 $EXPECT_SKILLS）"

RULE_COUNT=$(find "$TARGET/.opencode/rules" -name '*.md' | wc -l)
[ "$RULE_COUNT" -eq "$EXPECT_RULES" ] && ok "$RULE_COUNT/$EXPECT_RULES rules" || info "rules: $RULE_COUNT/$EXPECT_RULES"

SCRIPT_COUNT=$(find "$TARGET/.opencode/scripts" -name '*.sh' | wc -l)
[ "$SCRIPT_COUNT" -eq "$EXPECT_SCRIPTS" ] && ok "$SCRIPT_COUNT/$EXPECT_SCRIPTS scripts" || info "scripts: $SCRIPT_COUNT/$EXPECT_SCRIPTS（预期 $EXPECT_SCRIPTS）"

# check-opencode.sh 必须可执行（自举门禁需要）
if [ -x "$TARGET/.opencode/scripts/check-opencode.sh" ]; then
  ok "check-opencode.sh 可执行"
else
  fail "check-opencode.sh 不可执行（chmod +x .opencode/scripts/check-opencode.sh）"
  ERRORS=$((ERRORS+1))
fi

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
echo ""
echo -e "${CYAN}── 项目适配提示 ──${NC}"
echo "  安装完成后，整个 .opencode/ 目录即成为你的【项目资产】："
echo "  · 可直接改写 .opencode/rules/ 与 skills 资源，沉淀团队/项目专属规范"
echo "  · 可在本项目 opencode.json 的 instructions 中增删规则条目"
echo "  · 项目架构/规范等专属资产由你持续优化，工具即你的专业开发人员"
echo ""
echo "  快速验证 — 在 OpenCode 中输入:"
echo '    可用的自定义工具有哪些？'
echo "  预期看到 call_prd_writer, call_review_expert, call_pipeline_orchestrator 等 9 个自定义工具"
echo ""
