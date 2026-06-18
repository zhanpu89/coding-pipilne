# 术语表（ai-memory）

## 上下文层级（L0-L3）
| 层级 | 触发 | 内容 |
|------|------|------|
| L0 | 会话启动 | `init_session` 标题+状态 |
| L1 | 继续某任务 | `get_summary` 完整摘要 |
| L2 | 复杂问题需参考 | `search_summaries` |
| L3 | 完整回顾 | `list_recent` + 逐条详情 |

## 禁用语
| 禁用 | 替代 |
|------|------|
| `done` / `paused` / `abandoned` | `completed` / `in_progress` / `blocked` |
| 不填 `branch_name` | 无 Git 仓库时填 `"no-vcs"` |
| 保存前不预览确认 | 必须展示预览，确认后再保存 |
