# AGENTS.md

Skills: `.opencode/skills/{name}/SKILL.md` exposed as `call_*` via `plugins/skill-agent.ts`.

## Rules

| File | Load |
|------|------|
| `precise-location.md` | ⚡ always |
| `endpoint-lock.md` | ⚡ always |
| `code-discipline.md` | 🌀 on-demand |
| `doc-alignment.md` | 🌀 on-demand |

## Conventions

- **LC-001**: 语言 (Java/Python/Go/Node)
- **LC-FE-001**: 前端 (Vue3/React/none)
- **Status**: 🟡草稿 → 🟢确认
- **Memory**: init→search(各phase前)→decision(立即)→save(里程碑)
