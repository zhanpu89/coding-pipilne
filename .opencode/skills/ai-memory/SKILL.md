---
name: ai-memory
description: >
  AI 记忆持久化管理。在整个会话中主动维护工作笔记：
  翻历史、查记录、记决策、归档阶段成果。
  适用：持续性工程工作。不适用：纯技术问答、一次性代码、无上下文单轮请求。
---

# AI 记忆管理

本技能的所有 MCP 工具就是你的工作笔记本。请随时自然地使用它们。

## 什么时候用什么工具

### 翻笔记（开始或接续工作时）

主动调用 `ai_memory_memory_init_session(project_name, branch_name)`。有进行中任务则问用户要继续哪个，然后按需深入 `ai_memory_memory_get_summary(session_id=...)` 或 `ai_memory_memory_list_recent(limit=10)`。

### 查历史（遇到似曾相识的问题时）

先搜不要凭空开始：`ai_memory_memory_search_summaries(query=关键词)`。内部自动按语义→全文→关键词三级降级搜索。找到后告诉用户"之前做过类似的事"。

### 随手记（发现重要事情的当下）

`ai_memory_memory_add_decision(session_id, decision_type, description, reasoning)`。值得记：不明显的技术选择、绕过的坑、架构方向。不值得记：常规操作。

### 更新进度（状态变化时）

`ai_memory_memory_update_summary(session_id, new_status, updated_content)`。任务推进/阻塞/方向改变时调用。

### 整理归档（一段工作结束时）

用户说完成了或阶段目标达成→先问用户打算记什么，确认后 `ai_memory_memory_save_summary(session_id, task_title, summary_content, file_paths, project_name, status, next_steps, tags, module, branch_name)`。

### 其他

`ai_memory_memory_weekly_review(project_name)` — 用户说"本周总结"时；`ai_memory_memory_maintenance()` — 用户说"整理记忆库"时。

## 项目上下文识别

首次调用前确认 `project_name`（查 `.project_name` 文件最多2层父目录，找不到则提示创建）和 `branch_name`（读 `.git/HEAD`，无git则 `"no-vcs"`）。整个会话缓存复用。切换项目时重新识别。

## Session ID

格式：`session-{YYYYMMDD}-{task_slug}`。同一任务所有操作复用同一 ID。

## 状态值

`in_progress` / `completed` / `pending` / `blocked` / `abandoned`。只能用这五个。

## 工具响应处理

所有工具返回 `{"success": bool, "data": ..., "message": "..."}`。每次调用先查 `success`，失败时读 `message` 告知用户。

## 懒加载原则

本技能按操作场景按需加载参考文件，用完即释放：

| 场景 | 加载文件 | 释放时机 |
|------|---------|---------|
| 全流程 | `glossary.md`——术语/状态/工具定义 | — |
| 翻笔记/恢复上下文 | `memory-load.md` | 上下文恢复完成后 |
| 记决策/更新进度 | `memory-enrich.md` | 操作完成后 |
| 整理归档/保存摘要 | `memory-save.md` | 保存完成后 |
| 搜索历史 | `memory-search.md` | 检索完成后 |

## 合并原则

各场景文件生命周期互异（翻笔记→记决策→搜索→保存为独立操作路径），无需合并。每个文件按场景职责内聚：

- **`glossary.md`**（98行）：全流程通用，跨场景共享
- **`memory-load.md`**（70行）：会话恢复专用——项目识别 + init_session + 渐进加载
- **`memory-enrich.md`**（78行）：实时沉淀专用——add_decision + update_summary
- **`memory-save.md`**（161行）：归档专用——9步保存流程
- **`memory-search.md`**（104行）：检索专用——6种搜索策略

**去重说明**：原 `memory-enrich.md` 中的"决策类型参考值"表与 `glossary.md` 重复，已改为引用 `glossary.md`。

## 参考文件

| 文件 | 行数 | 场景 | 加载时机 | 释放时机 |
|------|------|------|---------|---------|
| `resources/glossary.md` | 98 | 全流程 | 首次触发——术语/状态/工具定义 | — |
| `resources/memory-load.md` | 70 | 翻笔记 | 需恢复上下文时 | 恢复完成后 |
| `resources/memory-enrich.md` | 78 | 记决策 | 需记录决策或更新状态时 | 操作完成后 |
| `resources/memory-save.md` | 161 | 保存摘要 | 需归档总结时 | 保存完成后 |
| `resources/memory-search.md` | 104 | 搜索历史 | 需检索记忆时 | 检索完成后 |
