---
name: ai-memory
description: >
  AI 记忆持久化管理。在整个会话中主动维护工作笔记：
  翻历史、查记录、记决策、归档阶段成果。
  适用：持续性工程工作。不适用：纯技术问答、一次性代码、无上下文单轮请求。
---
## 工具速查

| 时机 | 调用 |
|------|------|
| 开始/接续 | `ai_memory_init_session(project_name, branch_name)` → 有进行中任务则继续 |
| 似曾相识 | `ai_memory_search_summaries(query=关键词)` |
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
