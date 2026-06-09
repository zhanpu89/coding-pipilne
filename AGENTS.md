# AGENTS.md — my-skills

## What this is

A monorepo of 10 OpenCode AI **skills** that guide an AI agent through software development phases. Each skill is an instruction set (not executable code).

Skills are located under `.opencode/skills/{skill-name}/` and are exposed as custom tools via the plugin at `.opencode/plugins/skill-agent.ts`. Each tool loads the full skill context and you should use the `task` tool to launch a subagent with that context as the prompt.

## Skills

| Skill | Role | Documents | Tool Name |
|-------|------|-----------|-----------|
| prd-writer | 需求分析 → PRD | `doc/prd/` | `call_prd_writer` |
| review-expert | 文档/用例评审 | `doc/review/` | `call_review_expert` |
| system-architect | 架构设计 (SAD) | `doc/arch/` | `call_system_architect` |
| task-decomposer | 详设拆分 + 项目规则 | `doc/detailed/` | `call_task_decomposer` |
| code-developer | 编码实现 | `src/` | `call_code_developer` |
| code-reviewer | 代码评审 | `doc/review/` | `call_code_reviewer` |
| tester | 测试用例 + 测试代码 | `doc/tester/` | `call_tester` |
| dba-designer | 数据库 DDL 设计 | `doc/db/` | `call_dba_designer` |
| ai-memory | AI 记忆持久化（贯穿全流程桥梁） | — | `call_ai_memory` |
| pipeline-orchestrator | 全流程编排器 | `doc/pipeline/` | `call_pipeline_orchestrator` |

## Skill directory layout

```
.opencode/skills/{skill-name}/
├── SKILL.md          # YAML front-matter + workflow
├── resources/        # Reference docs (glossary, patterns, checklists)
└── templates/        # Output templates
```

Every `SKILL.md` has 5 front-matter fields: `name`, `description`, `inputs`, `outputs`, `allowed-tools`. Description includes "适用场景:" and "不适用场景（勿触发）:" bullet lists.

## Key conventions

- **LC-001**: Primary backend language (Java/Python/Go/Node.js)
- **LC-FE-001**: Frontend framework (Vue3/React/无)
- **P0/P1/P2**: Problem severity. P0 blocks everything.
- **Status emojis**: `🟡 草稿` → `🟢 已确认`
- **Single-item pacing**: One module at a time, pause for "继续"
- **Checklist-driven**: Pre-write checklist on every output
- **Progress files**: `_PROGRESS.md` tracks multi-module progress

## Memory protocol (required)

From `.workspace/project_rules.md`:
- Every session starts with `init_session`
- Save summaries at milestones with `save_summary`
- Record decisions immediately with `add_decision`
- Search history with `search_summaries` / `search_summaries_fts` before repeating work
- Before each response, emit `<memory_plan>{...}</memory_plan>` with planned memory operations

## SKILL.md 优化方法论（两原则）

对所有 skill 进行结构优化时遵循以下两条原则：

### 原则 1：按需加载（Lazy Loading）

参考文件的加载时机必须与工作流步骤严格对齐，仅在需要时加载，完成后释放。

**判断标准**：
- 如果一个文件中包含在不同步骤加载的内容 → **拆分**
- 如果文件行数 > 200 且包含多个独立生命周期 → **优先拆分**
- 如果文件 < 30 行且生命周期独立 → 保持独立（无需拆分）
- 释放时机在 SKILL.md 中必须显式定义（懒加载表 + 参考表）

**SKILL.md 必含 3 个表**：
- `懒加载原则` 表：步骤 | 保持加载 | 释放
- `合并原则` 表/说明：解释 merge/split 决策
- `参考文件` 表：文件 | 行数 | 步骤 | 加载时机 | 释放时机

### 原则 2：合并原则（Merge）

相同生命周期的内容必须合并在同一个文件中，用 `##` 标题导航。

**判断标准**：
- 多个文件在同一步骤被加载且互斥使用（如不同语言的代码模板）→ **合并到一个文件，用 `## {语言名}` 导航**
- 多个文件内容属于同一操作流程 → **不要拆分**
- 内容重复 → 统一到一个文件，其余改为引用

### 文件命名与引用规范

- 资源文件：`resources/{功能描述}.md`（用连字符分隔词）
- 模板文件：`templates/{功能描述}-template.md`
- 拆分后文件名用描述性名称（不用 `-p1`、`-part1` 等序号）
- 跨文件引用使用路径：如 `见 \`table-rules.md\``
- SKILL.md 保留原始文件名（不含路径），参考表使用完整路径（`resources/`、`templates/`）

### 优化验证清单

- [ ] 懒加载表加载/释放时机与工作流步骤对齐
- [ ] 参考表行数与实际 `wc -l` 一致
- [ ] 无死引用（指向已删除或重命名文件的引用）
- [ ] 无内容重复（同一份数据定义只出现在一个文件）
- [ ] 合并原则中有分拆说明（原文件名 + 行数 + 理由）
