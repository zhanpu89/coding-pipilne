---
name: dba-designer
description: |
  数据库设计。根据后端详设生成 DDL 脚本（MySQL / PostgreSQL / TiDB）。
  适用场景：
  - 从详设第6节 DDL 草稿生成完整建表脚本
  - 增量 ALTER TABLE 变更
  - 验证三范式、索引策略、数据安全
  不适用场景（勿触发）：
  - 生成业务代码（code-developer）
  - 生成详设文档（task-decomposer）
  - 已有 DDL 只需要执行
  - 纯 SQL 语法问答
---

# DBA Designer

根据后端详设设计表结构与索引，输出可执行的 SQL 脚本。输入：`doc/detailed/`；输出：`doc/db/`。

## 懒加载原则

本技能遵守"按需加载"原则，每次只加载当前步骤需要的参考文件，完成后立即释放：

| 步骤 | 保持加载 | 释放 |
|------|---------|------|
| Step 1 表清单生成 | `glossary.md`（全流程保留） | — |
| Step 2 建表分析 | `table-rules.md` | Step 2 → Step 3 前释放 |
| Step 3 索引设计 | `index-rules.md` | Step 3 → Step 4 前释放 |
| Step 4 DDL 生成 | `dialect-diff.md`(按LC-002) + `table-ddl-template.md`(按LC-002) | Step 4 → Step 5 前释放 |
| Step 5 全量脚本合并 | `full-script-template.md` | Step 6 结束后释放 |

## 合并原则

本技能将**相同生命周期**的内容合并在一个文件中，通过 `##` 标题导航：

- **`table-ddl-template.md`**（126行，3种方言一体）：MySQL、PostgreSQL、中间表三种单体 DDL 模板合并在同一文件，按 $LC-002 路由到对应方言模板。三者生命周期相同（Step 4）且互斥加载。

**分拆说明**：
- 原 `design-rules.md`（251行，3个 Part × 3个生命周期）→ 按 Step 2/3/4 分别加载拆分为 `table-rules.md`（80行）、`index-rules.md`（78行）、`dialect-diff.md`（87行）。
- 原 `ddl-template.md`（288行，2个 Part × 2个生命周期 + _PROGRESS.md 周期不匹配）→ 按 Step 4/5 拆分为 `table-ddl-template.md`（126行）、`full-script-template.md`（133行）。_PROGRESS.md 模板改为工作流内联描述（Step 1），消除生命周期错位。

## 参考文件

| 文件 | 行数 | 步骤 | 加载时机 | 释放时机 |
|------|------|------|---------|---------|
| `resources/glossary.md` | 109 | 全流程 | 首次触发——DBA 术语、数据类型映射 | — |
| `resources/table-rules.md` | 80 | Step 2 | Step 2 建表分析前——建表规范 | Step 3 前 |
| `resources/index-rules.md` | 78 | Step 3 | Step 3 索引设计前——索引规则 | Step 4 前 |
| `resources/dialect-diff.md` | 87 | Step 4 | Step 4 按 LC-002 加载——方言差异 | Step 5 前 |
| `templates/table-ddl-template.md` | 126 | Step 4 | Step 4 逐表生成——建表模板 | Step 5 前 |
| `templates/full-script-template.md` | 133 | Step 5 | Step 5 全量脚本合并前——脚本结构 | Step 6 后 |

## 工作流

### Step 0：启动检测
恢复模式（`_PROGRESS.md` 有 ⏳）→ 数据库类型探测（项目规则 LC-002 → SAD → 询问用户）→ 全量/增量模式识别

### Step 1：解析详设 + 表清单生成
逐一读取 `doc/detailed/{模块}_{功能域}.md`，提取第2节（约束）、第5节（特殊结构）、第6节（DDL 草稿，主要输入）、第9节（性能要求）。
无 DDL 草稿则从接口定义逆推，标注「逆推生成」。识别共享表和中间表。展示后写入 `_PROGRESS.md`（表格格式：状态⏳/✅ + 表名 + 归属模块 + 字段数 + 来源文档 + 备注）。

### Step 2：表结构完整性分析
加载 `table-rules.md`。
**必备字段**：`id`(PK)、`created_at`、`updated_at`、`deleted_at`(软删除)、`created_by`、`updated_by`
**字段类型规范**：金额用 BIGINT 非 DECIMAL/FLOAT；VARCHAR 按实际长度；TEXT 不存可查询字段；DATETIME(3) 含毫秒；ENUM 改用 TINYINT + 注释；禁止物理 FOREIGN KEY（改为注释 `-- FK`）

### Step 3：索引设计
加载 `index-rules.md`。收集查询场景（GET 参数 + 性能要求）→ 按选择性/覆盖索引/最左前缀设计。
**禁止**：低选择性字段独立索引、索引字段>5、重复索引、TEXT 全列索引。展示方案后确认。

### Step 4：DDL 脚本生成（逐表）
加载 `dialect-diff.md` + `table-ddl-template.md`。
**单表节奏**：一次只生成一张，更新 `_PROGRESS.md` 后用户确认再继续。
**规范**：`CREATE TABLE IF NOT EXISTS`（幂等）、每字段 `COMMENT`、索引建在表内、无 FOREIGN KEY、无占位符。
**增量模式**（Step 4.5）：生成 `ALTER TABLE` 语句。

### Step 5：全量脚本合并
加载 `full-script-template.md`。按依赖顺序合并。**自检**：全部✅、无 FOREIGN KEY、无占位符、幂等。
**增量模式**（Step 5.5）：输出 `{项目名}_v{版本号}_migration.sql`，含回滚方案。

### Step 6：数据库设计说明文档
输出 `doc/db/{项目名}_数据库设计说明.md`：表清单 → ER 图(Mermaid) → 索引清单 → 设计决策记录 → 变更记录

## 每个 DDL 写入前强制检查

- [ ] `_PROGRESS.md` 已存在
- [ ] `CREATE TABLE IF NOT EXISTS`（幂等）
- [ ] 含 `id`/`created_at`/`updated_at` 等必备字段
- [ ] 每字段有 `COMMENT`，枚举含值定义
- [ ] 含全部索引定义
- [ ] 无 FOREIGN KEY
- [ ] 无保留字字段名
- [ ] 无 `{占位符}`/`TODO`
- [ ] 无 DECIMAL/FLOAT/DOUBLE 存金额
- [ ] 无 ENUM
- [ ] 写入后更新 `_PROGRESS.md`，用户确认前未写入下一张

## 全局熔断规则

- 🔴 `_PROGRESS.md` 未创建就开始生成 DDL
- 🔴 `doc/detailed/` 无后端详设文档
- 🔴 数据库类型未知（LC-002 未确认）且用户未回复
- 🔴 DDL 写入失败
- 🔴 **连续生成多张表而未用户确认**（非批量授权）
- 🔴 自检发现占位符或 FOREIGN KEY
