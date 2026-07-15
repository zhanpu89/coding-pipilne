#!/usr/bin/env bash
# 编排审计 — 检测主 agent 是否有未经 subagent 授权的直接文件修改
# 返回: 0=通过, 1=审计异常
#
# 使用方式:
#   快照:   bash check-audit.sh snapshot [phase_name]
#   校验:   bash check-audit.sh verify [phase_name]
#   清理:   bash check-audit.sh clean

ACTION="${1:-verify}"
PHASE="${2:-unknown}"
AUDIT_DIR="/tmp/opencode/audit"
AUDIT_FILE="$AUDIT_DIR/snapshot.json"
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MONITOR_DIRS=("src" "doc" "frontend" "api" "server" "app")

# 门禁脚本目录 — 这些目录的修改不算违规
SELF_DIRS=(".opencode/scripts" ".opencode/rules" ".opencode/skills/pipeline-orchestrator")

mkdir -p "$AUDIT_DIR"

# 判断路径是否在免检列表中
is_self_modification() {
  local path="$1"
  for sd in "${SELF_DIRS[@]}"; do
    if echo "$path" | grep -q "^$sd/"; then
      return 0
    fi
  done
  return 1
}

# 收集受监控文件的元数据
snapshot() {
  echo "{\"phase\":\"$PHASE\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"files\":[" > "$AUDIT_FILE"
  local first=true
  for dir in "${MONITOR_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
      continue
    fi
    while IFS= read -r -d '' f; do
      # 跳过审计文件自身
      echo "$f" | grep -q "/tmp/" && continue

      $first || echo "," >> "$AUDIT_FILE"
      first=false

      MTIME=$(stat -c '%Y' "$f" 2>/dev/null || echo 0)
      SIZE=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
      # 计算内容指纹（前 1000 字节的 md5，避免大文件影响性能）
      FINGERPRINT=$(head -c 1000 "$f" 2>/dev/null | md5sum 2>/dev/null | cut -d' ' -f1 || echo "0")

      # JSON 安全转义路径
      SAFE_PATH=$(echo "$f" | sed 's/"/\\"/g')
      echo -n "{\"path\":\"$SAFE_PATH\",\"mtime\":$MTIME,\"size\":$SIZE,\"hash\":\"$FINGERPRINT\"}" >> "$AUDIT_FILE"
    done < <(find "$dir" -type f -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/__pycache__/*' -print0 2>/dev/null)
  done
  echo "]}" >> "$AUDIT_FILE"
  echo "  📸 Phase $PHASE 快照已保存 ($(grep -c '"path"' "$AUDIT_FILE" 2>/dev/null || echo 0) 个文件)"
}

# 对比快照检测未授权修改
verify() {
  if [ ! -f "$AUDIT_FILE" ]; then
    echo "  ℹ️  无前置快照，跳过审计"
    exit 0
  fi

  local prev_phase
  prev_phase=$(grep '"phase"' "$AUDIT_FILE" | head -1 | sed 's/.*"phase":"\([^"]*\)".*/\1/')
  echo "  前置 Phase: $prev_phase"

  ERRORS=0
  MODIFIED_FILES=()

  while IFS= read -r -d '' f; do
    # 跳过免检目录
    REL_PATH="${f#$PROJECT_DIR/}"
    if is_self_modification "$REL_PATH"; then
      continue
    fi

    # 跳过审计文件自身
    echo "$f" | grep -q "/tmp/opencode/" && continue

    # 从快照中查找此文件
    MTIME=$(stat -c '%Y' "$f" 2>/dev/null || echo 0)
    SIZE=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
    FINGERPRINT=$(head -c 1000 "$f" 2>/dev/null | md5sum 2>/dev/null | cut -d' ' -f1 || echo "0")

    # JSON 转义路径用于 grep
    ESCAPED_PATH=$(echo "$REL_PATH" | sed 's/"/\\"/g')
    SNAPSHOT_LINE=$(grep "\"path\":\"$ESCAPED_PATH\"" "$AUDIT_FILE" 2>/dev/null | head -1)

    if [ -z "$SNAPSHOT_LINE" ]; then
      # 新文件（快照中不存在）
      echo "  🆕 新文件: $REL_PATH"
      MODIFIED_FILES+=("$REL_PATH")
      ERRORS=$((ERRORS + 1))
    else
      # 检查哈希是否变化
      OLD_HASH=$(echo "$SNAPSHOT_LINE" | sed 's/.*"hash":"\([^"]*\)".*/\1/')
      if [ "$FINGERPRINT" != "$OLD_HASH" ]; then
        echo "  ✏️  已修改: $REL_PATH"
        MODIFIED_FILES+=("$REL_PATH")
        ERRORS=$((ERRORS + 1))
      fi
    fi
  done < <(find "${MONITOR_DIRS[@]}" -type f -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/__pycache__/*' -print0 2>/dev/null)

  if [ ${#MODIFIED_FILES[@]} -gt 0 ]; then
    echo "  ⚠️  检测到 ${#MODIFIED_FILES[@]} 个文件变更"
    echo "  ℹ️  如果这些变更是 subagent 产生的，请记录 subagent 调用日志"
    echo "  ℹ️  如果不是 subagent 产生的，则违反零动手原则"
  else
    echo "  ✅ 无文件变更，审计通过"
  fi

  [ "$ERRORS" -eq 0 ] && exit 0 || exit 1
}

clean() {
  rm -f "$AUDIT_FILE"
  echo "  🧹 审计快照已清理"
}

case "$ACTION" in
  snapshot)
    snapshot
    ;;
  verify)
    verify
    ;;
  clean)
    clean
    ;;
  *)
    echo "用法: check-audit.sh {snapshot|verify|clean} [phase_name]"
    exit 1
    ;;
esac
