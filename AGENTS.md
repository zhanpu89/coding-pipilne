# AGENTS.md

Skills: `.opencode/skills/{name}/SKILL.md` loaded as subagent `prompt` via `opencode.json`.

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
- **Memory**: init→search(Step 0统一)→_MEMORY_CACHE.md→decision(产出Phase后)→save(里程碑)
