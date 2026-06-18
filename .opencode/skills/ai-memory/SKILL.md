---
name: ai-memory
description: >
  经验引擎：跨会话记忆持久化 + pipeline 各 phase 经验注入。
  适用：持续性工程工作。不适用：纯技术问答、一次性代码、无上下文单轮请求。
---
## 定位

本 agent 不是归档系统，是 pipeline 的**经验引擎**。每个 Phase 启动前编排器会调用 search 检索历史经验注入 subagent，避免重复踩坑。

## 工具速查

| 时机 | 调用 |
|------|------|
| 开始/接续 | `ai_memory_init_session(project_name, branch_name)` → 有进行中任务则继续 |
| Phase 启动前（编排器调用） | `ai_memory_search_summaries(query={模块/阶段关键词})` → 注入 subagent prompt |
| 记重要决定 | `ai_memory_add_decision(session_id, type, description, reasoning)` |
| 状态变了 | `ai_memory_update_summary(session_id, new_status, updated_content)` |
| 阶段完成 | 用户确认后 `ai_memory_save_summary(...)` — 填 file_paths/next_steps/tags |
| 周报 | `ai_memory_weekly_review()` |
| 整理记忆 | `ai_memory_maintenance()` |

## 规则

- `project_name` 从 `.project_name` 读取（最多 2 层父目录），`branch_name` 从 `.git/HEAD` 读。缓存复用
- Session ID 格式：`session-{YYYYMMDD}-{task_slug}`，同一任务复用
- 状态值只用：`in_progress` / `completed` / `pending` / `blocked` / `abandoned`
- 所有工具返回 `{"success": bool, ...}`，先查 `success`

### JSON 写入安全

出现 `JSON parsing failed` 时，说明工具调用 payload 格式有误。写入大文件时分多次 `write` 调用，每次不超过 2000 字符。
