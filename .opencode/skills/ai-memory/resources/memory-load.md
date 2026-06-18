# 记忆加载

会话启动或项目切换时。流程：

1. 从 `.project_name` 读 project_name（最多 2 层父目录），从 `.git/HEAD` 读 branch_name
2. 调用 `init_session(project_name, branch_name)` → 有进行中任务则问用户要继续哪个
3. 按需 `get_summary_by_id()` / `list_recent_sessions()` / `search_summaries(keyword)`
