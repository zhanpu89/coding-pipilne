---
name: pipeline-orchestrator
description: >
  全流程软件工程编排器。主 agent 按此指令集协调 PRD→架构→详设→DB设计→编码→测试 的完整流水线。
  适用场景：
  - 从零开始的全流程软件开发
  - 从某个阶段中断后继续执行
  - 质量门禁失败后的自动重试
  不适用场景（勿触发）：
  - 只需要某个单一技能
  - 纯技术问答
  - 已有产出物仅需增量修改
---
## 模式

每个 Phase 调用 `call_{skill}` → `task(subagent_type='{agent}')` → `bash check-{phase}.sh`（失败 ≤3 次）→ `ai_memory_add_decision()`。评审 subagent 必须全新 `task` 隔离。

**Step 0：** `ai_memory_init_session()` → 读 `doc/pipeline/_PROGRESS.md`（⏳恢复 | ❌修复 | 无则全新）。

**Phase 1a：** 主 agent 读 `prd-writer/resources/interview-framework.md` → `question` 工具访谈 → 输出 `doc/prd/_requirements_summary.md`

**Phase 1b：** `call_prd_writer` + task(prd-writer) + `check-prd.sh`

**Phase 1c/2b/3b/6b：** 评审：`call_review_expert` + task(review-expert, 全新) + `check-review.sh`

**Phase 2a：** `call_system_architect` + task(system-architect) + `check-arch.sh`

**Phase 3a：** `call_task_decomposer` + task(task-decomposer) + `check-detailed.sh`

**Phase 4a：** `call_dba_designer` + task(dba-designer) + `check-db.sh`

**Phase 5a：** `call_code_developer` + task(code-developer) + `check-code.sh`（写入完成后读 `.opencode/rules/doc-alignment.md` 同步文档）

**Phase 5b/6e：** `call_code_reviewer` + task(code-reviewer, 全新)

**Phase 6a：** `call_tester(阶段一)` + task(tester) + `check-testcase.sh`

**Phase 6c：** `call_tester(阶段二)` + task(tester) + `check-test.sh`

6b 不通过 → 回退 6a ≤3 次。

**Step 7：** `ai_memory_save_summary(...)` 归档。输出 ✅ **Pipeline 完成** + 产出物汇总。

## 熔断

subagent 启动失败重试 1 次 / 同一门禁连续失败 3 次暂停 / 缺必需输入停止 / ai-memory 失败则记录后继续
