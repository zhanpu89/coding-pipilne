# 术语表

> 定义 ai-memory 技能中使用的专业术语，供 AI 在记忆管理操作中保持术语一致性。

---

## 核心概念

| 术语 | 含义 | 使用场景 |
|------|------|---------|
| **记忆（Memory）** | 跨会话持久化的任务摘要、决策记录和上下文信息 | 会话恢复、历史检索 |
| **摘要（Summary）** | 对一次任务的结构化描述，含目标、决策、文件、下一步 | `save_summary` 保存的核心内容 |
| **决策记录（Decision）** | 任务中关键技术选型或方案选择，含理由和被放弃的替代方案 | `add_decision` 记录 |
| **项目上下文（Project Context）** | `project_name` + `branch_name` 的组合，用于隔离不同项目的记忆 | 所有 MCP 工具调用前必须识别 |
| **`.project_name` 文件** | 项目根目录下的纯文本文件，内容为项目名称（一行） | 公共前置：项目上下文识别流程 |

---

## Session 相关术语

| 术语 | 说明 | 示例 |
|------|------|------|
| **session_id** | 唯一会话标识符，格式 `session-{YYYYMMDD}-{task_slug}` | `session-20260525-audit-memory-skill` |
| **task_slug** | 从任务标题提取的核心关键词，连字符连接，不超过 30 字符 | `optimize-query-performance` |
| **里程碑保存** | 复杂任务中间阶段的保存，`status=in_progress`，复用同一 `session_id` | 任务分多次会话完成时使用 |
| **project_name** | 项目名称，从 `.project_name` 文件读取，同一会话内缓存复用 | `my-skills` |
| **branch_name** | Git 分支名，从 `.git/HEAD` 读取；无 Git 仓库时固定为 `"no-vcs"` | `main`、`feature/auth`、`no-vcs` |

---

## 状态值

> 所有 `status` 字段**必须且只能**使用以下五种值，禁止使用其他状态。

| 状态值 | 含义 | 典型使用场景 |
|--------|------|------------|
| `completed` | 任务已完成，所有目标达成 | 任务结束时的最终保存 |
| `in_progress` | 任务进行中 | 里程碑保存；会话中断后恢复 |
| `pending` | 任务已计划但尚未开始 | 规划阶段记录待处理任务 |
| `blocked` | 任务被阻塞，需外部依赖或决策才能继续 | 等待用户确认、依赖未就绪 |
| `abandoned` | 任务已放弃，不再继续 | 需求取消、方向调整 |

---

## 上下文层级（Token 预算）

| 层级 | 触发条件 | 加载内容 | 预估 Token |
|------|----------|----------|-----------|
| **L0** | 会话启动（默认） | `init_session` 返回的标题 + 下一步 | ~100–200 |
| **L1** | 用户选择继续某任务 | `get_summary_by_id` 完整摘要 | ~500–1000 |
| **L2** | 遇到复杂问题需历史参考 | `search_summaries(use_vector=True)` 3条 | ~1500–3000 |
| **L3** | 用户明确要求完整回顾 | `list_recent_sessions` + 逐条详情 | ~3000+ |

升级原则：每次升级前评估"加载的信息是否直接有助于当前任务"，避免无效 Token 消耗。

---

## 决策类型（decision_type）

| 类型值 | 说明 | 示例 |
|--------|------|------|
| `architecture` | 架构设计决策 | 选择微服务而非单体 |
| `tech-choice` | 技术选型 | 选择 SQLite 而非 PostgreSQL |
| `bug-fix` | Bug 修复策略 | 通过重建索引修复查询异常 |
| `refactor` | 重构方案 | 提取公共模块避免重复 |
| `performance` | 性能优化方案 | 使用连接池替代每次新建连接 |
| `security` | 安全相关决策 | 参数化查询防止 SQL 注入 |
| `trade-off` | 权衡取舍 | 牺牲实时性换取数据一致性 |
| `naming_convention` | 命名规范决策 | 统一审计字段为 snake_case |

---

## MCP 工具速查

| 工具名 | 用途 | 所属阶段 |
|--------|------|---------|
| `init_session` | 恢复最近 3 天内进行中的任务 | 记忆加载 |
| `get_summary_by_id` | 获取单条完整摘要 | 记忆加载 / 记忆检索 |
| `list_recent_sessions` | 列出最近会话（标题+状态） | 记忆加载 |
| `save_summary` | 保存新摘要到记忆库 | 记忆保存 |
| `update_summary` | 更新摘要状态或内容 | 记忆丰富 |
| `add_decision` | 记录关键技术决策 | 记忆丰富 / 记忆保存 |
| `search_summaries` | 多策略检索（LIKE/FTS/向量） | 记忆检索 |
| `search_summaries_fts` | FTS5 专用全文检索 | 记忆检索 |
| `weekly_review` | 生成本周项目周报 | 周期性操作 |
| `maintenance` | 重建索引、压缩数据库 | 周期性操作 |

---

## 禁用表达对照

| 禁用 | 规范替代 | 原因 |
|------|---------|------|
| `status: "done"` | `status: "completed"` | 状态值不在五种合法值内 |
| `status: "paused"` | `status: "in_progress"` + 内容说明暂停原因 | 同上 |
| `status: "waiting"` | `status: "blocked"` | 同上 |
| 不填 `branch_name` | 无 Git 仓库时填 `"no-vcs"` | 避免过滤时丢失记录 |
| 保存前不预览确认 | 必须展示摘要预览，用户确认后再调用 `save_summary` | 保证摘要质量 |
