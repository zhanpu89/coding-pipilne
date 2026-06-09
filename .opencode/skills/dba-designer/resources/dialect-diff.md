# 数据库方言差异对照

> MySQL / PostgreSQL / TiDB 方言差异与通用幂等脚本规范。**Step 4 按 LC-002 加载对应方言。**

### 3.1 MySQL 8.0 规范

**文件头模板**：
```sql
-- 数据库：MySQL 8.0+
-- 字符集：utf8mb4 / utf8mb4_unicode_ci
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
```

**建表关键字**：
- 自增主键：`BIGINT UNSIGNED NOT NULL AUTO_INCREMENT`
- 时间默认值：`DEFAULT CURRENT_TIMESTAMP(3)`
- 时间自动更新：`ON UPDATE CURRENT_TIMESTAMP(3)`
- 引擎：`ENGINE = InnoDB`
- 字符集：`DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci`
- 注释：`COMMENT = '{表注释}'`（表级）/ `COMMENT '{字段注释}'`（字段级）

**幂等建表**：`CREATE TABLE IF NOT EXISTS {表名} (...);`

**幂等建库**：`CREATE DATABASE IF NOT EXISTS {库名} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`

**结尾**：`SET FOREIGN_KEY_CHECKS = 1;`

### 3.2 PostgreSQL 14+ 规范

**文件头模板**：
```sql
-- 数据库：PostgreSQL 14+
-- 扩展：根据需要启用
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  -- 如使用 UUID
```

**建表关键字**：
- 自增主键：`id BIGSERIAL NOT NULL`，`PRIMARY KEY (id)`
- 时间默认值：`DEFAULT NOW()`
- 时间自动更新：需触发器（见 `table-rules.md`）
- 无 ENGINE / CHARSET 子句
- 注释：`COMMENT ON TABLE {表名} IS '{注释}';` / `COMMENT ON COLUMN {表名}.{字段} IS '{注释}';`（建表语句外单独写）

**幂等建表**：`CREATE TABLE IF NOT EXISTS {表名} (...);`

**幂等建库**：`CREATE DATABASE {库名} WITH ENCODING 'UTF8';`（不支持 IF NOT EXISTS，需事先检查）

**PG 特有类型**：
| MySQL 类型 | PostgreSQL 等价类型 |
|-----------|------------------|
| `TINYINT` | `SMALLINT` |
| `DATETIME(3)` | `TIMESTAMPTZ` |
| `LONGTEXT` | `TEXT` |
| `AUTO_INCREMENT` | `BIGSERIAL` / `GENERATED ALWAYS AS IDENTITY` |
| `TINYINT(1)` | `BOOLEAN` |

### 3.3 TiDB 规范

**基本兼容 MySQL 8.0 语法**，以下为关键差异：

| 场景 | MySQL 写法 | TiDB 推荐写法 |
|-----|-----------|------------|
| 分布式主键（多写场景） | `AUTO_INCREMENT` | `AUTO_RANDOM` 防止热点 |
| 大表分区 | RANGE/LIST PARTITION | 原生支持，语法相同 |
| 全文索引 | 有限支持 | 建议使用 Elasticsearch |
| 事务 | 默认 InnoDB | 分布式事务，大事务需拆分（< 100MB） |

**TiDB 文件头补充**：
```sql
-- 数据库：TiDB 5.x+
-- 注意：主键使用 AUTO_RANDOM 防止写热点
-- 注意：单事务不超过 100MB
```

### 3.4 通用幂等脚本规范

所有生成的 SQL 脚本必须满足**幂等性**，即重复执行不报错、不产生副作用：

| 操作 | 幂等写法 |
|-----|---------|
| 建库 | `CREATE DATABASE IF NOT EXISTS` |
| 建表 | `CREATE TABLE IF NOT EXISTS` |
| 建索引（MySQL） | `CREATE INDEX IF NOT EXISTS` 或 `ALTER TABLE ... ADD INDEX IF NOT EXISTS`（8.0+）|
| 插入种子数据 | `INSERT IGNORE INTO` 或 `INSERT ... ON DUPLICATE KEY UPDATE` |
| 删除索引 | 先判断存在再删：`DROP INDEX IF EXISTS` |
| 变更脚本 | 在文件头加 `-- 执行前请确认已备份数据` + 版本检查 |
