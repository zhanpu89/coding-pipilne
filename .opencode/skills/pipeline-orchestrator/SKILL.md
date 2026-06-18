---
name: pipeline-orchestrator
description: >
  全流程软件工程编排器。主 agent 按此指令集协调 PRD→架构→详设→DB设计→编码→测试 的完整流水线。
  适用场景：
  - 从零开始的全流程软件开发
  - 从某个阶段中断后继续执行
  - 质量门禁失败后的自动重试
  - 已有项目增量开发（新功能/模块）
  - Bug 修复 / 小改动（短路模式）
  不适用场景（勿触发）：
  - 只需要某个单一技能（直接调 `call_*`）
  - 纯技术问答
---
## 模式

每个 Phase 调用 `call_{skill}` + `task(subagent_type='{agent}')` → `bash .opencode/skills/pipeline-orchestrator/scripts/check-{phase}.sh`（失败 ≤3 次）→ `ai_memory_add_decision()`。

**评审门禁（不可跳过）：** 每个文档产出阶段（PRD/架构/详设/DDL/测试用例）**必须**强制跟随对应的评审 Phase。编排器必须先执行产出阶段，再执行评审 Phase，评审通过后方可进入下一产出阶段。跳过任一评审 = 流程违规。

**JSON 写入安全：** 出现 `JSON parsing failed` 时，说明工具调用 payload 格式有误。写入大文件时分多次 `write` 调用，每次不超过 2000 字符。

### 评审隔离铁则（杜绝自审自判）

创建 agent 结束后立即结束其 subagent 会话。**评审必须启动全新 subagent，入参只能包含被评审文档的文件路径 + 参考契约文档路径（架构/PRD），严禁传递任何创作意图、设计推理、已做步骤、作者信息。** 评审 agent 拿到的是"陌生人写的文档"，不知创作链路上的任何上下文。

### 记忆注入规则

每个 Phase 启动 subagent **前**，先 `ai_memory_search_summaries(query={模块/阶段相关关键词})` 检索历史经验。若有结果，打包为以下格式注入 subagent prompt：

```
【历史经验参考（来自项目记忆）】
以下是与本任务相关的历史记录，可能包含过去的设计决策、踩坑教训、评审失败原因等。
这些不属于当前任务的直接需求，仅作为参考，避免重复犯错：
1. {摘要1}
2. {摘要2}
...
```

### 文档同步机制

code-developer 输出 `>>DOC_SYNC: {文件路径} → {改动说明}` 标示需同步的契约文档。**主 agent（编排器）负责按清单修改文档，code-developer 不直接触碰契约。** code-reviewer 评审时同时审查代码和更新后的文档，确保端对齐。

---

**Step 0：** `ai_memory_init_session()` → 扫描项目结构确定起跑模式：

| 扫描结果 | 模式 | 起点 |
|----------|------|------|
| 无 `doc/` 无 `src/` | 🆕 全新项目 | Phase 1a |
| 有 `doc/prd/` 无 `doc/arch/` | 🆕 PRD 完成 | Phase 2a |
| 有 `doc/arch/` 无 `doc/detailed/` | 🆕 架构完成 | Phase 3a |
| 有 `doc/detailed/` 无 `src/` 或无目标模块代码 | 🆕 详设完成 | Phase 4a |
| 有 `src/` 有 `doc/detailed/`（已有项目新增功能） | 🔄 增量开发 | 见下方增量模式 |
| Bug 报告 / 异常堆栈 / 需求明确的小改动 | 🐛 Bug 修复 | 见下方 Bug 修复模式 |

**已有项目增量模式（🔄）：**
- 不重建架构和详设，复用现有 `doc/arch/`、`doc/detailed/`、`项目规则.md`
- 只对新增模块走设计 → 评审 → 编码 → 评审 → 测试
- Phase 1a/1b → 只对新功能输出 mini-PRD（对话确认需求，不生成完整 PRD 文档）
- Phase 2a/2b → **跳过**（架构已存在，不重建）
- Phase 3a → 只对新模块输出详设文档（追加到 `doc/detailed/`）
- Phase 3b → 评审新模块详设（check-review.sh 门禁），同时检查是否与现有模块契约冲突（端对齐）
- Phase 4a → 只输出增量 DDL（`ALTER TABLE` 或新建表），追加到 `doc/db/`
- Phase 4b → 评审增量 DDL（check-review.sh 门禁）
- Phase 5a → 只实现新模块代码，**禁止修改现有模块代码**
- Phase 5b → 评审新模块代码 + 端对齐检查（接口是否与现有模块兼容）
- Phase 6a/6b/6c → 只覆盖新模块的测试用例（用例评审 + 执行）

**Bug 修复模式（🐛）：**
- 按 `.opencode/rules/precise-location.md` 精确定位 → 读对应契约文档验证预期行为 →
  `ai_memory_search_summaries(query=模块+"修复"+"Bug")` → `call_code_developer`（fix，prompt 含历史经验）→
  解析输出中的 `>>DOC_SYNC:`，**主 agent 按清单修改对应契约文档** →
  `call_code_reviewer`（全新，评审代码+更新后的文档）→ `call_tester(阶段二)`（只跑关联测试）
- 跳过 PRD / 架构 / 详设 / DDL 全部 phases
- 修复单文件可免定位，直接改

**全新项目模式 / 中断恢复 / 评审修复模式：** 标准流程 — 严格按以下顺序执行，**每个评审 Phase 必须通过后才能进入下一产出 Phase**。

```
Phase 1a → Phase 1b → Phase 1c(PRD评审) → 
Phase 2a → Phase 2b(架构评审) → 
Phase 3a → Phase 3b(详设评审) → 
Phase 4a → Phase 4b(DDL评审) → 
Phase 5a → Phase 5b(代码评审) → 
Phase 6a → Phase 6b(用例评审) → Phase 6c(执行)
```

---

**Phase 1a（需求访谈）：** 主 agent 读 `prd-writer/resources/interview-framework.md` → `question` 工具访谈 → 输出 `doc/prd/_requirements_summary.md`

**Phase 1b（PRD 撰写）：** `ai_memory_search_summaries(query=项目名+"PRD"+"需求")` → `call_prd_writer` + task(prd-writer, prompt 含历史经验) → `bash .opencode/skills/pipeline-orchestrator/scripts/check-prd.sh`（失败 ≤3 次）→ `ai_memory_add_decision()` → 结束后结束 subagent

**Phase 1c（PRD 评审 — 门禁）：** `ai_memory_search_summaries(query=项目名+"评审失败"+"阻断")` → 启动**全新** task(review-expert) + prompt **"评审 doc/prd/ PRD 文档，参考 doc/arch/ 架构约束（如存在），检查需求完整性与逻辑闭环"** + 历史经验 → 输出 `doc/review/` → `bash .opencode/skills/pipeline-orchestrator/scripts/check-review.sh`（失败 ≤3 轮阻断）→ `ai_memory_add_decision()`。⛔ 未通过则退回 Phase 1b 修改。

---

**Phase 2a（架构设计）：** `ai_memory_search_summaries(query=项目名+"架构"+"技术选型")` → `call_system_architect` + task(system-architect, prompt 含历史经验) → `bash .opencode/skills/pipeline-orchestrator/scripts/check-arch.sh`（失败 ≤3 次）→ `ai_memory_add_decision()` → 结束后结束 subagent

**Phase 2b（架构评审 — 门禁）：** `ai_memory_search_summaries(query=项目名+"评审失败"+"阻断")` → 启动**全新** task(review-expert) + prompt **"评审 doc/arch/ 架构文档，参考 doc/prd/ 需求范围，检查非功能属性、技术选型合理性与单点故障"** + 历史经验 → `bash .opencode/skills/pipeline-orchestrator/scripts/check-review.sh`（失败 ≤3 轮阻断）→ `ai_memory_add_decision()`。⛔ 未通过则退回 Phase 2a 修改。

---

**Phase 3a（详细设计）：** `ai_memory_search_summaries(query=模块+"详设"+"接口")` → `call_task_decomposer` + task(task-decomposer, prompt 含历史经验) → `bash .opencode/skills/pipeline-orchestrator/scripts/check-detailed.sh`（失败 ≤3 次）→ `ai_memory_add_decision()` → 结束后结束 subagent

**Phase 3b（详设评审 — 门禁）：** `ai_memory_search_summaries(query=模块+"评审失败"+"阻断")` → 启动**全新** task(review-expert) + prompt **"评审 doc/detailed/ 详细设计文档，参考 doc/arch/ 和 doc/prd/，检查并发安全、事务边界、接口契约完整性"** + 历史经验 → `bash .opencode/skills/pipeline-orchestrator/scripts/check-review.sh`（失败 ≤3 轮阻断）→ `ai_memory_add_decision()`。⛔ 未通过则退回 Phase 3a 修改。

---

**Phase 4a（DDL 设计）：** `ai_memory_search_summaries(query=模块+"DDL"+"表结构")` → `call_dba_designer` + task(dba-designer, prompt 含历史经验) → `bash .opencode/skills/pipeline-orchestrator/scripts/check-db.sh`（失败 ≤3 次）→ `ai_memory_add_decision()` → 结束后结束 subagent

**Phase 4b（DDL 评审 — 门禁）：** `ai_memory_search_summaries(query=模块+"DDL评审"+"表结构")` → 启动**全新** task(review-expert) + prompt **"评审 doc/db/ DDL 脚本，参考 doc/detailed/ 数据模型，检查三范式、索引策略、命名规范"** + 历史经验 → `bash .opencode/skills/pipeline-orchestrator/scripts/check-review.sh`（失败 ≤3 次）→ `ai_memory_add_decision()`。⛔ 未通过则退回 Phase 4a 修改。

---

**Phase 5a（编码实现）：** `ai_memory_search_summaries(query=模块+"代码评审"+"P0")` → `call_code_developer` + task(code-developer, prompt 含历史经验) → `bash .opencode/skills/pipeline-orchestrator/scripts/check-code.sh`（失败 ≤3 次）→ 结束后结束 subagent。解析输出中的 `>>DOC_SYNC:` 清单，**主 agent 按清单修改对应契约文档**。如有偏差清单（代码与契约不符）→ 转 Phase 3b 评审偏差，通过后更新契约文档再重做 Phase 5a

**Phase 5b（代码评审）：** `ai_memory_search_summaries(query=模块+"缺陷"+"安全")` → 启动**全新** task(code-reviewer) + prompt **"评审 src/ 代码，对照 doc/arch/, doc/detailed/，检查安全漏洞、契约一致性、性能反模式"** + 历史经验

---

**Phase 6a（测试用例设计）：** `ai_memory_search_summaries(query=模块+"测试覆盖"+"遗漏")` → `call_tester(阶段一)` + task(tester, prompt 含历史经验) → `bash .opencode/skills/pipeline-orchestrator/scripts/check-testcase.sh`（失败 ≤3 次）→ `ai_memory_add_decision()` → 结束 subagent

**Phase 6b（测试用例评审 — 门禁）：** `ai_memory_search_summaries(query=模块+"评审失败"+"阻断")` → 启动**全新** task(review-expert) + prompt **"评审 doc/tester/ 测试用例，参考 doc/detailed/ 业务规则，检查覆盖度、边界值、需求追溯"** + 历史经验 → `bash .opencode/skills/pipeline-orchestrator/scripts/check-review.sh`（失败 ≤3 轮阻断）→ `ai_memory_add_decision()`。⛔ 未通过则退回 Phase 6a 修改（最多 3 轮）。

**Phase 6c（测试执行）：** `ai_memory_search_summaries(query=模块+"测试失败")` → `call_tester(阶段二)` + task(tester, prompt 含历史经验) → `bash .opencode/skills/pipeline-orchestrator/scripts/check-test.sh`（失败 ≤3 次）→ `ai_memory_add_decision()` → 结束 subagent

**Step 7：** `ai_memory_save_summary(...)` 归档。输出 ✅ **Pipeline 完成** + 产出物汇总。

## 熔断

subagent 启动失败重试 1 次 / 同一门禁连续失败 3 次暂停 / 缺必需输入停止 / ai-memory 失败则记录后继续
