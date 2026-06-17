# AGENTS.md — my-skills

10 OpenCode AI skills for software development phases. Skills under `.opencode/skills/{name}/` exposed as custom tools via `.opencode/plugins/skill-agent.ts`.

## Skills

| Skill | Tool Name |
|-------|-----------|
| prd-writer | `call_prd_writer` |
| review-expert | `call_review_expert` |
| system-architect | `call_system_architect` |
| task-decomposer | `call_task_decomposer` |
| code-developer | `call_code_developer` |
| code-reviewer | `call_code_reviewer` |
| tester | `call_tester` |
| dba-designer | `call_dba_designer` |
| ai-memory | `call_ai_memory` |
| pipeline-orchestrator | `call_pipeline_orchestrator` |

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
