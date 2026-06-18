# AGENTS.md — my-skills

Skills under `.opencode/skills/{name}/` exposed as custom tools via `.opencode/plugins/skill-agent.ts`.

## Rules

| File | Strategy |
|------|----------|
| `precise-location.md` | ⚡ always loaded |
| `endpoint-lock.md` | ⚡ always loaded |
| `code-discipline.md` | ⚡ always loaded |
| `doc-alignment.md` | 🌀 on-demand (code-developer/pipeline-orchestrator) |

## Conventions

- **LC-001**: Backend language (Java/Python/Go/Node.js)
- **LC-FE-001**: Frontend (Vue3/React/none)
- **Status**: 🟡 草稿 → 🟢 已确认
- **Memory**: init_session → save_summary at milestones → add_decision immediately → search before repeat
