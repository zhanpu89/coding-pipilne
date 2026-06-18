# 记忆保存

任务结束或里程碑时，组织并保存摘要。

## 流程

1. 获取 project_name / branch_name（缓存）
2. 确认 session_id（`session-{YYYYMMDD}-{task_slug}`）
3. 整理决定/文件/标签 → 展示预览 → 用户确认 → `save_summary(...)`

## 关键字段

- `file_paths`: 逗号分隔，如 "src/a.java,doc/b.md"
- `status: in_progress`(里程碑) / `completed`(完成) / `blocked`(阻塞) / `pending`(暂缓) / `abandoned`(放弃)
- `tags`: "auth,jwt,backend"
- `next_steps`: 按优先级列出
