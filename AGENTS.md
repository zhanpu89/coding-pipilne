# AGENTS.md

Skills: `.opencode/skills/{name}/SKILL.md` loaded as subagent `prompt` via `opencode.json`.

## Rules

| File | 绑定 | 说明 |
|------|------|------|
| `precise-location.md` | **code-developer + orchestrator** | 全局 `instructions` 加载；code-developer SKILL.md 中也有文本引用，Step 0 定位用 |
| `endpoint-lock.md` | **code-developer + orchestrator** | 全局 `instructions` 加载，端锁定规则；编排器走对齐流程时通知用户 |
| `code-discipline.md` | **code-developer + tester** | 全局 `instructions` 加载，编码纪律 |
| `doc-alignment.md` | **code-developer + code-reviewer** | 全局 `instructions` 加载，>DOC_SYNC 契约对齐 |
| `arch-thinking.md` | **code-developer** | 全局 `instructions` 加载，编码前三关检查（查已有/定位置/验影响） |
| `json-write-safety.md` | **所有写文件 agent** | 全局 `instructions` 加载 + SKILL.md 中按需引用；写入容错 |

## Scripts（`.opencode/scripts/`）

| 脚本 | 绑定 Phase | 说明 |
|------|:----------:|------|
| `check-arch.sh` | 2a | 架构产出：SAD 文件存在性 + tech-stack.json 校验 + NFR 量化检测 |
| `check-arch-compliance.sh` | 5a | 架构合规：层隔离 + 导入限制 + 命名规范 |
| `check-audit.sh` | 全部 | Phase 感知文件变更审计：快照/验证/清理 |
| `check-code.sh` | 5a | 代码产出：文件统计 + 编译/类型检查 + 空文件检测 + Lint |
| `check-detailed.sh` | 3a | 详设产出：文件大小 + 必备章节（^## 标题锚定）+ 规则文件检测 |
| `check-drift.sh` | P7 | 规范漂移检测：规则文件 + P7 进化记录 + Scope 跟踪 |
| `check-feedback.sh` | 全部 | 反馈闭环健康检查：user-feedback.jsonl 存在性 + 窗口内活跃检测；编排器最终清理前运行 |
| `check-integration.sh` | 6d | 集成验证：curl 端到端 + 稳定性检查 |
| `check-opencode.sh` | P5a/自举 | Pipeline 工具自验证：bash语法 + JSON格式 + SKILL结构 |
| `check-prd.sh` | 1b | PRD 产出：文件大小 + 必备章节 + 技术术语检测 |
| `check-review.sh` | 1c/2b/3b/5b/6b | 评审结论提取：支持表格/强调/纯文本/emoji 四种格式 |
| `check-test.sh` | 6c | 测试执行：文件存在性 + 断言计数 + 报告结论检测；**分级测试**：有 scope=T1 定向，无=T2 全量，同指纹缓存跳过 |
| `check-testcase.sh` | 6a | 测试用例：文件存在性 + TC-ID 格式验证 + 类型分布统计 |
| `log-skill.sh` | 全部 | Subagent 调用日志（JSON-Lines，ISO 时间戳）；编排器每 dispatch 后调用，供 self-evolve 分析 |
| `log-feedback.sh` | 全部 | 用户反馈日志（纠正/吐槽/改向 verbatim + 严重度）；编排器每次收到用户纠正时调用，供 self-evolve 分析 |

## Conventions

- **LC-001**: 语言 (Java/Python/Go/Node)
- **LC-FE-001**: 前端 (Vue3/React/none)
- **Status**: 🟡草稿 → 🟢确认
- **Memory**: init→search(Step 0统一)→_MEMORY_CACHE.md→decision(产出Phase后)→save(里程碑)
