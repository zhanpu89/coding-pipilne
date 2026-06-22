---
name: pipeline-orchestrator
description: 全流程软件工程编排器。协调 PRD→架构→详设→DB→编码→测试。适用：全流程/增量/Bug修复。不适：单一技能/纯问答
---

## 执行规则

每个 Phase 调用 `task(subagent_type='{agent}')` → `bash .opencode/scripts/check-{phase}.sh`（失败 ≤3 次）→ `ai_memory_add_decision()`。首个产出 Phase 额外调 `ai_memory_save_summary(status=in_progress)`，后续调 `update_summary`。

**评审门禁（不可跳过）：** 每个文档产出阶段（PRD/架构/详设/DDL/测试用例）**必须**强制跟随对应的评审 Phase。编排器必须先执行产出阶段，再执行评审 Phase，评审通过后方可进入下一产出阶段。跳过任一评审 = 流程违规。

> 📐 遵循 `.opencode/rules/json-write-safety.md`

### 评审隔离铁则（杜绝自审自判）

创建 agent 结束后立即结束其 subagent 会话。**评审必须启动全新 subagent，入参只能包含被评审文档的文件路径 + 参考契约文档路径（架构/PRD），严禁传递任何创作意图、设计推理、已做步骤、作者信息。** 评审 agent 拿到的是"陌生人写的文档"，不知创作链路上的任何上下文。

### 记忆注入规则

Step 0 统一检索一次，结果写入 `_MEMORY_CACHE.md`。各 Phase 中编排器读取该文件，将相关内容打包进 `task()` 的 prompt。不再每 Phase 单独检索。

格式：
```
【历史经验参考（来自项目记忆）】
以下是与本任务相关的历史记录：
{摘要列表}
```

### 文档同步机制

code-developer 输出 `>>DOC_SYNC: {文件路径} → {改动说明}` 标示需同步的契约文档。**主 agent（编排器）负责按清单修改文档，code-developer 不直接触碰契约。** code-reviewer 评审时同时审查代码和更新后的文档，确保端对齐。

### 上下文管理

每 Phase 完成后丢弃该 Phase 的中间输出（task 返回值、门禁检查结果、用户确认内容）。只保留：当前 Phase 编号、产出物路径清单、关键决策。

**记忆持久化节奏（确保中途中断不丢失记录）：**

| 时机 | 调用 | 说明 |
|------|------|------|
| 首个产出 Phase (1b) | `ai_memory_save_summary(status=in_progress)` | 创建会话记录 |
| 后续每个产出 Phase 末尾 | `ai_memory_add_decision()` + `ai_memory_update_summary(status=in_progress)` | 追加新决策，更新摘要 |
| Step 7 | `ai_memory_update_summary(status=completed)` | 标记完成 |

不做 Phase 间上下文传递。

---

**Step 0：** `ai_memory_init_session()` → `ai_memory_search_summaries(query=项目名, limit=15)` → 结果写入 `_MEMORY_CACHE.md` → 扫描项目结构确定起跑模式：

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
- Phase 3b → 评审新模块详设，同时检查是否与现有模块契约冲突（端对齐）
- Phase 4a → 只输出增量 DDL（`ALTER TABLE` 或新建表），追加到 `doc/db/`
- Phase 4b → 评审增量 DDL
- Phase 5a → 只实现新模块代码，**禁止修改现有模块代码**
- Phase 5b → 评审新模块代码 + 端对齐检查（接口是否与现有模块兼容）
- Phase 6a/6b/6c → 只覆盖新模块的测试用例（用例评审 + 执行）

**Bug 修复模式（🐛）：**
- 按 `.opencode/rules/precise-location.md` 精确定位 → 读对应契约文档验证预期行为 →
  `ai_memory_search_summaries(query=项目名+模块+"修复", limit=10)` → 结果写入 `_MEMORY_CACHE.md` →
  `task(code-developer, prompt="修复模式：{任务描述}。\n\n【历史经验】见 _MEMORY_CACHE.md")` →
  解析 `>>DOC_SYNC:` → 主 agent 按清单修改对应契约文档 →
  `task(code-reviewer, prompt="评审修复代码+更新后的文档")` →
  `task(tester, prompt="阶段二：只跑关联测试")`
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

**Phase 5a（编码实现）：** 除通用模式外，还须：
1. 解析 `>>DOC_SYNC:` 清单→主 agent 按清单修改契约文档
2. 有偏差清单（代码与契约不符）→转 Phase 3b 评审偏差→更新契约后重做 Phase 5a
3. **全栈模式额外步骤 — 前后端契约对齐校验**：Phase 5a 结束后，主 agent 扫描 `src/` 提取前端 API 调用文件（`api/` 层或 `services/`）和后端路由定义文件（controller/route），逐条对比接口路径、HTTP 方法、参数字段。输出 `_contract_check.md` 偏差报告。有 P0 偏差（路径/方法不匹配、字段名不一致）→阻断并转 repair

### Phase 执行表

| Phase | 角色 | task agent | 门禁脚本 | 评审 prompt |
|-------|------|-----------|---------|-------------|
| 1b 需求产出 | PRD撰写 | `prd-writer` | check-prd.sh | — |
| 1c PRD评审 | 门禁 | `review-expert` | check-review.sh | 评审 doc/prd/，参考 doc/arch/ |
| 2a 架构产出 | 架构设计 | `system-architect` | check-arch.sh | — |
| 2b 架构评审 | 门禁 | `review-expert` | check-review.sh | 评审 doc/arch/，参考 doc/prd/ |
| 3a 详设产出 | 详细设计 | `task-decomposer` | check-detailed.sh | — |
| 3b 详设评审 | 门禁 | `review-expert` | check-review.sh | 评审 doc/detailed/，参考 doc/arch/ |
| 4a DDL产出 | DB设计 | `dba-designer` | check-db.sh | — |
| 4b DDL评审 | 门禁 | `review-expert` | check-review.sh | 评审 doc/db/，参考 doc/detailed/ |
| 5a 编码产出 | 编码实现 | `code-developer` | check-code.sh | — |
| 5b 代码评审 | 门禁 | `code-reviewer` | check-review.sh | 评审 src/，对照 doc/arch/, doc/detailed/ |
| 6a 用例产出 | 测试用例 | `tester(阶段一)` | check-testcase.sh | — |
| 6b 用例评审 | 门禁 | `review-expert` | check-review.sh | 评审 doc/tester/，参考 doc/detailed/ |
| 6c 测试执行 | 测试执行 | `tester(阶段二)` | check-test.sh | — |

> 产出 Phase 结束后结束 subagent。门禁失败 ≤3 次。每 Phase 完成后丢弃中间输出。

**Step 7：** `ai_memory_update_summary(status=completed)` 归档 → 删除 `_MEMORY_CACHE.md`、`_contract_check.md` 等临时文件 → 输出 ✅ **Pipeline 完成** + 产出物汇总。

## 熔断

subagent 启动失败重试 1 次 / 同一门禁连续失败 3 次暂停 / 缺必需输入停止 / 记忆 (ai_memory_*) 失败则记录后继续
