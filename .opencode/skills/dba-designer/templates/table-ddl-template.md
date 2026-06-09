# 单表 DDL 模板

> 单表 DDL 模板，按 LC-002 选择对应方言（MySQL / PostgreSQL / 中间表）。**Step 4 逐表生成时加载。**

### MySQL 8.0 单表模板

```sql
-- ============================================================
-- 表名：{表名}
-- 业务含义：{表的业务说明}
-- 来源文档：doc/detailed/{模块}_{功能域}.md § 第6节
-- 创建时间：{YYYY-MM-DD}
-- 版本：v1.0.0
-- ============================================================

CREATE TABLE IF NOT EXISTS `{表名}` (
  -- 主键
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',

  -- 业务字段（按逻辑分组，组内空行分隔）
  `{字段名}`    {类型} NOT NULL DEFAULT {默认值} COMMENT '{字段描述}',
  -- FK: 关联 {关联表名}.id（逻辑外键，应用层维护）
  `{外键字段名}` BIGINT UNSIGNED NOT NULL COMMENT '{字段描述}，关联 {关联表名}.id',

  -- 金额字段示例（单位：分）
  -- `amount`  BIGINT NOT NULL DEFAULT 0 COMMENT '金额，单位：分',

  -- 枚举/状态字段示例
  -- `status`  TINYINT NOT NULL DEFAULT 0 COMMENT '状态：0-待处理,1-处理中,2-已完成,3-已取消',

  -- 审计字段（必备，顺序固定）
  `created_by`  BIGINT UNSIGNED NOT NULL COMMENT '创建人ID，关联 users.id',
  `updated_by`  BIGINT UNSIGNED NOT NULL COMMENT '最后修改人ID，关联 users.id',
  `created_at`  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at`  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '最后更新时间',
  `deleted_at`  DATETIME(3) NULL DEFAULT NULL COMMENT '软删除时间，NULL表示未删除',

  -- 主键约束
  PRIMARY KEY (`id`),

  -- 唯一约束（业务唯一性）
  UNIQUE KEY `uk_{表名缩写}_{字段}` (`{唯一字段}`),

  -- 业务查询索引（每个索引附注释说明用途）
  INDEX `idx_{表名缩写}_{字段组合}` (`{字段1}`, `{字段2}`) COMMENT '支持接口：{接口路径}',

  -- 软删除联合索引
  INDEX `idx_{表名缩写}_deleted_status` (`deleted_at`, `{状态字段}`)

) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = '{模块名}：{表的业务含义，约20字以内}';
```

### PostgreSQL 单表模板

```sql
-- ============================================================
-- 表名：{表名}
-- 业务含义：{表的业务说明}
-- 来源文档：doc/detailed/{模块}_{功能域}.md § 第6节
-- 创建时间：{YYYY-MM-DD}
-- ============================================================

CREATE TABLE IF NOT EXISTS {表名} (
  -- 主键
  id            BIGSERIAL     NOT NULL,

  -- 业务字段
  {字段名}      {类型}        NOT NULL DEFAULT {默认值},
  -- 逻辑外键：关联 {关联表名}.id
  {外键字段名}  BIGINT        NOT NULL,

  -- 审计字段
  created_by    BIGINT        NOT NULL,
  updated_by    BIGINT        NOT NULL,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ   NULL,

  -- 约束
  CONSTRAINT pk_{表名} PRIMARY KEY (id),
  CONSTRAINT uk_{表名}_{字段} UNIQUE ({唯一字段})
);

-- 索引（PG 建索引在建表语句外）
CREATE INDEX IF NOT EXISTS idx_{表名}_{字段组合} ON {表名} ({字段1}, {字段2});

-- 字段注释（PG 注释在建表语句外）
COMMENT ON TABLE {表名} IS '{模块名}：{表的业务含义}';
COMMENT ON COLUMN {表名}.id IS '主键ID';
COMMENT ON COLUMN {表名}.{字段名} IS '{字段描述}';
COMMENT ON COLUMN {表名}.created_at IS '创建时间';
COMMENT ON COLUMN {表名}.updated_at IS '最后更新时间';
COMMENT ON COLUMN {表名}.deleted_at IS '软删除时间，NULL表示未删除';

-- updated_at 自动更新触发器
CREATE TRIGGER trg_{表名}_updated_at
  BEFORE UPDATE ON {表名}
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### 中间表模板（多对多关联）

```sql
-- ============================================================
-- 中间表：{表A}_{表B}_rel
-- 业务含义：{表A} 与 {表B} 的多对多关联关系
-- ============================================================

CREATE TABLE IF NOT EXISTS `{表A}_{表B}_rel` (
  `{表A}_id`    BIGINT UNSIGNED NOT NULL COMMENT '{表A描述}ID，关联 {表A}.id',
  `{表B}_id`    BIGINT UNSIGNED NOT NULL COMMENT '{表B描述}ID，关联 {表B}.id',
  `created_by`  BIGINT UNSIGNED NOT NULL COMMENT '创建人ID',
  `created_at`  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '关联创建时间',

  PRIMARY KEY (`{表A}_id`, `{表B}_id`),
  INDEX `idx_{表A}_{表B}_rel_{表B}_id` (`{表B}_id`) COMMENT '反向查询加速'

) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = '{表A}与{表B}多对多关联表';
```
