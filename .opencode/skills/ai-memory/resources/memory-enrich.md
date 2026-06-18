# 决策记录

重要决定、Bug 根因、架构选择时调用 `add_decision(session_id, type, description, reasoning)`。值得记的不明显技术选择，不记常规操作。

# 状态更新

任务推进/阻塞/方向变化时调用 `update_summary(session_id, new_status, updated_content)`。
