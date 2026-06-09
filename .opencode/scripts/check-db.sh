#!/usr/bin/env bash
# 检查数据库 DDL 产出物
# 返回: 0=通过, 1=失败

DB_DIR="doc/db"
ERRORS=0

if [ ! -d "$DB_DIR" ]; then
  echo "❌ DB 目录不存在: $DB_DIR"
  exit 1
fi

SQL_FILES=$(find "$DB_DIR" -name "*.sql" 2>/dev/null)
if [ -z "$SQL_FILES" ]; then
  echo "❌ 没有 .sql 文件"
  ERRORS=$((ERRORS + 1))
else
  for f in $SQL_FILES; do
    SIZE=$(wc -c < "$f")
    echo "  $(basename "$f") ($SIZE bytes)"
    [ "$SIZE" -lt 50 ] && echo "⚠️  文件过小" && ERRORS=$((ERRORS + 1))

    # 检查基本 SQL 语法
    if ! grep -qi "CREATE TABLE\|ALTER TABLE\|CREATE INDEX" "$f" 2>/dev/null; then
      echo "⚠️  没有 CREATE TABLE/INDEX 语句"
      ERRORS=$((ERRORS + 1))
    fi
  done
fi

# 检查 DDL 设计说明文档
DOC_FILES=$(find "$DB_DIR" -name "*.md" 2>/dev/null)
if [ -z "$DOC_FILES" ]; then
  echo "⚠️ 没有数据库设计说明文档"
  ERRORS=$((ERRORS + 1))
fi

[ "$ERRORS" -eq 0 ] && echo "✅ DB 检查通过" || echo "⚠️ DB 检查完成，$ERRORS 个问题"
exit $([ "$ERRORS" -eq 0 ] && echo 0 || echo 1)
