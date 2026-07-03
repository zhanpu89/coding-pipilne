# AGENTS.md

Skills: `.opencode/skills/{name}/SKILL.md` loaded as subagent `prompt` via `opencode.json`.

## Rules

| File | 绑定 | 说明 |
|------|------|------|
| `precise-location.md` | **code-developer** | 嵌入 SKILL.md 加载的规则，Step 0 定位用 |
| `endpoint-lock.md` | **code-developer + 编排器** | 嵌入 code-developer SKILL.md + 编排器 `instructions` |
| `code-discipline.md` | **code-developer** | 嵌入 SKILL.md 加载的规则，编码纪律 |
| `doc-alignment.md` | **code-developer** | 嵌入 SKILL.md 加载的规则，契约对齐 |

## Conventions

- **LC-001**: 语言 (Java/Python/Go/Node)
- **LC-FE-001**: 前端 (Vue3/React/none)
- **Status**: 🟡草稿 → 🟢确认
- **Memory**: init→search(Step 0统一)→_MEMORY_CACHE.md→decision(产出Phase后)→save(里程碑)
