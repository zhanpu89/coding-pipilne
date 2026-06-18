# AGENTS.md — my-skills

Skills under `.opencode/skills/{name}/` exposed as custom tools via `.opencode/plugins/skill-agent.ts`.

## Rules

| File | Strategy |
|------|----------|
| `precise-location.md` | ⚡ always loaded |
| `endpoint-lock.md` | ⚡ always loaded |
| `code-discipline.md` | 🌀 on-demand (skill-agent plugin injects into subagent) |
| `doc-alignment.md` | 🌀 on-demand (pipeline-orchestrator doc-sync) |

## Conventions

- **LC-001**: Backend language (Java/Python/Go/Node.js)
- **LC-FE-001**: Frontend (Vue3/React/none)
- **Status**: 🟡 草稿 → 🟢 已确认
- **Memory**: init_session → search_summaries before each phase (inject history) → add_decision immediately → save_summary at milestones
