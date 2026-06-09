# 建表规范

> 通用建表规则定义，包括必备字段、字段设计规范、表级设计规范。**Step 2 建表分析前必须加载。**

### 1.1 必备字段清单

> ⛔ 每张业务表必须包含以下字段，缺少则自动补充。系统表/配置表/中间表可按说明豁免。

| 字段名 | 类型（MySQL） | 类型（PostgreSQL） | 约束 | 豁免条件 |
|-------|------------|----------------|------|---------|
| `id` | `BIGINT UNSIGNED NOT NULL AUTO_INCREMENT` | `BIGSERIAL NOT NULL` | PRIMARY KEY | 中间表使用联合主键时可豁免 |
| `created_at` | `DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)` | `TIMESTAMPTZ NOT NULL DEFAULT NOW()` | — | 无 |
| `updated_at` | `DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)` | `TIMESTAMPTZ NOT NULL DEFAULT NOW()` | — | 无（PG 需触发器维护） |
| `deleted_at` | `DATETIME(3) NULL DEFAULT NULL` | `TIMESTAMPTZ NULL` | — | 明确说明硬删除或无删除场景 |
| `created_by` | `BIGINT UNSIGNED NOT NULL` | `BIGINT NOT NULL` | — | 系统表、配置表、枚举字典表 |
| `updated_by` | `BIGINT UNSIGNED NOT NULL` | `BIGINT NOT NULL` | — | 同上 |

**PostgreSQL 特别说明**：`updated_at` 自动更新需创建触发器，全量脚本中必须附带：
```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;
-- 每张需要自动更新的表添加：
CREATE TRIGGER trg_{表名}_updated_at
  BEFORE UPDATE ON {表名}
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### 1.2 字段设计规范

**金额字段（强制）**：
- 必须使用 `BIGINT` 存储，单位为**分**（人民币）或最小货币单位
- 字段名以 `_amount`、`_price`、`_fee`、`_cost` 结尾时自动触发此规则
- COMMENT 中必须注明单位：`COMMENT '金额，单位：分'`

**枚举/状态字段（强制）**：
- 使用 `TINYINT NOT NULL DEFAULT 0`（无符号可用 `TINYINT UNSIGNED`）
- COMMENT 必须列出所有枚举值：`COMMENT '状态：0-待处理,1-处理中,2-已完成,3-已取消'`
- 字段名以 `_status`、`_type`、`_state`、`_level` 结尾时自动触发此规则

**布尔字段（强制）**：
- 使用 `TINYINT(1) NOT NULL DEFAULT 0`（MySQL）或 `BOOLEAN NOT NULL DEFAULT FALSE`（PG）
- COMMENT 格式：`COMMENT '是否XXX：0-否,1-是'`

**字符串字段（强制）**：
- 所有字符串字段必须指定合理的最大长度，禁止无差别使用 `VARCHAR(255)`
- 参考长度标准：手机号 `VARCHAR(20)`、身份证 `VARCHAR(18)`、URL `VARCHAR(512)`、描述类文本 `VARCHAR(500)`、名称类 `VARCHAR(100)`

**时间字段（强制）**：
- 存储业务时间戳：`DATETIME(3)` / `TIMESTAMPTZ`（精确到毫秒）
- 存储日期（无时间）：`DATE`
- 禁止使用无精度的 `DATETIME`（防止并发时序问题）

**主键设计（强制）**：
- 单表主键：`id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT`
- 分布式场景（TiDB 或多写）：`id BIGINT NOT NULL` + 应用层雪花算法生成
- 联合主键（中间表）：`PRIMARY KEY (table_a_id, table_b_id)` + 两字段各建单独索引

### 1.3 表级设计规范

**表名规范**：
- `snake_case` 复数名词，全小写，不加 `tbl_`/`t_` 前缀
- 中间表：`{表A}_{表B}_rel`（按字典序排列表名，如 `role_permission_rel`）
- 历史归档表：`{原表名}_archive`

**表注释规范（强制）**：
- MySQL：`COMMENT = '{模块名}：{表的业务含义}'`
- 格式示例：`COMMENT = '订单模块：订单主表，记录用户下单信息'`
- 禁止留空注释或写无意义注释（如 `COMMENT = '表1'`）

**软删除规范**：
- 所有需要软删除的表必须包含 `deleted_at` 字段
- 查询时必须添加 `WHERE deleted_at IS NULL` 条件（应用层控制，不做数据库过滤视图）
- `deleted_at` 字段通常需与其他查询条件建联合索引（如 `idx_status_deleted`）

**字符集规范（MySQL 专属）**：
- 统一使用 `CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
- 禁止单表使用 `utf8`（不支持4字节emoji）
- 禁止混用字符集
