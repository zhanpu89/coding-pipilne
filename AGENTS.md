# AGENTS.md

Skills: `.opencode/skills/{name}/SKILL.md` loaded as subagent `prompt` via `opencode.json`.

## Rules

| File | 绑定 | 说明 |
|------|------|------|
| `precise-location.md` | **code-developer** | 嵌入 SKILL.md 加载的规则，Step 0 定位用 |
| `endpoint-lock.md` | **code-developer + 编排器** | 嵌入 code-developer SKILL.md + 编排器 `instructions` |
| `code-discipline.md` | **code-developer** | 嵌入 SKILL.md 加载的规则，编码纪律 |
| `doc-alignment.md` | **code-developer** | 嵌入 SKILL.md 加载的规则，契约对齐 |

## Scripts（`.opencode/scripts/`）

| 脚本 | 绑定 Phase | 说明 |
|------|:----------:|------|
| `check-arch.sh` | 2a | 架构产出：SAD 文件存在性 + tech-stack.json 校验 + NFR 量化检测 |
| `check-prd.sh` | 1b | PRD 产出：文件大小 + 必备章节 + 技术术语检测 |
| `check-detailed.sh` | 3a | 详设产出：文件大小 + 必备章节（^## 标题锚定）+ 规则文件检测 |
| `check-code.sh` | 5a | 代码产出：文件统计 + 编译/类型检查 + 空文件检测 + Lint（ESLint/Ruff） |
| `check-review.sh` | 1c/2b/3b/5b/6b | 评审结论提取：支持表格/强调/纯文本/emoji 四种格式 |
| `check-testcase.sh` | 6a | 测试用例：文件存在性 + TC-ID 格式验证 + 类型分布统计 |
| `check-test.sh` | 6c | 测试执行：文件存在性 + 断言计数 + 报告结论检测 |
| `check-drift.sh` | P7 | 规范漂移检测：规则文件 + P7 进化记录 + Scope 跟踪 |
| `log-skill.sh` | 全部 | Subagent 调用日志（JSON-Lines，ISO 时间戳） |

## Conventions

- **LC-001**: 语言 (Java/Python/Go/Node)
- **LC-FE-001**: 前端 (Vue3/React/none)
- **Status**: 🟡草稿 → 🟢确认
- **Memory**: init→search(Step 0统一)→_MEMORY_CACHE.md→decision(产出Phase后)→save(里程碑)
