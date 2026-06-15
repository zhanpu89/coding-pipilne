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

# Pipeline Orchestrator — 主 Agent 编排指令

你是编排器（主 agent），通过 `task` 启动 subagent 执行各阶段工作，通过 `bash` 运行验证脚本检查产出物。subagent 用完即销毁，不嵌套。

**ai-memory（记忆桥梁）贯穿全流程**：每个阶段通过 ai_memory_memory_* 工具持久化决策和摘要。

## 关键约束：评审 subagent 必须完全隔离

**评审 subagent 必须是全新的 `task` 调用，不携带任何编写阶段的上下文。** 绝不能在同一 `task` 会话中先写再评。

| 阶段 | 编写 subagent (工具 + task) | 评审 subagent (工具 + 全新 task) |
|------|----------------------------|---------------------------------|
| PRD | `call_prd_writer` → `task(subagent_type='prd-writer')` | `call_review_expert` → **全新 `task(subagent_type='review-expert')`** |
| 架构 | `call_system_architect` → `task(subagent_type='system-architect')` | `call_review_expert` → **全新 `task(subagent_type='review-expert')`** |
| 详设 | `call_task_decomposer` → `task(subagent_type='task-decomposer')` | `call_review_expert` → **全新 `task(subagent_type='review-expert')`** |
| 代码 | `call_code_developer` → `task(subagent_type='code-developer')` | `call_code_reviewer` → **全新 `task(subagent_type='code-reviewer')`** |
| 测试 | `call_tester` → `task(subagent_type='tester')`（两阶段分离） | `call_review_expert` → **全新 `task(subagent_type='review-expert')`**（仅审用例） |

**执行规则**：
1. 每个步骤先调用 `call_*` 工具获取 subagent 指令
2. 用 `task(subagent_type='{对应 agent 名}', prompt="<完整指令>")` 启动独立的 subagent
3. 评审步骤必须使用**全新的 `task` 调用**，subagent 不知道也不关心文档是谁写的
4. 禁止在生成 subagent 中嵌入评审步骤

## 懒加载原则

| 步骤 | 保持加载 | 释放 |
|------|---------|------|
| Step 0 | 内联定义 | — |
| Step 1-6 | check-*.sh 脚本路径 | 全局使用 |
| Step 7 | 汇总清单 | 完成后|

## 合并原则

无拆分。所有阶段定义内联在 SKILL.md，无需额外加载文件。

## 参考文件

| 文件 | 行数 | 步骤 | 加载时机 | 释放时机 |
|------|------|------|---------|---------|
| `.opencode/scripts/check-*.sh` | — | Step 1-6 | 各步需要时 | 使用后 |

## 状态追踪

Pipeline 进度保存在 `doc/pipeline/_PROGRESS.md`（如不存在则创建）。格式：

```
# Pipeline Progress

| Phase | Step | Status | Output | Retry |
|-------|------|--------|--------|-------|
| 1-PRD | 1a-访谈 | ⏳ | - | - |
| 1-PRD | 1b-编写 | ⬜ | - | 0/3 |
| 1-PRD | 1c-评审 | ⬜ | - | - |
| 1-PRD | 1d-门禁 | ⬜ | - | - |
| 2-ARCH | 2a-设计 | ⬜ | - | - |
...
```

- ⏳ 进行中 | ✅ 完成 | ❌ 失败 | ⬜ 待开始

## 验证脚本引用

| 脚本 | 用途 | 成功 | 失败重试 | 用于步骤 |
|------|------|------|---------|---------|
| `.opencode/scripts/check-prd.sh` | 验证 PRD 产出物 | exit 0 | exit 1 → 重跑 1b | 1b |
| `.opencode/scripts/check-arch.sh` | 验证架构产出物 | exit 0 | exit 1 → 重跑 2a | 2a |
| `.opencode/scripts/check-detailed.sh` | 验证详设产出物 | exit 0 | exit 1 → 重跑 3a | 3a |
| `.opencode/scripts/check-db.sh` | 验证 DDL 产出物 | exit 0 | exit 1 → 重跑 4a | 4a |
| `.opencode/scripts/check-code.sh` | 验证代码产出物 | exit 0 | exit 1 → 重跑 5a | 5a |
| `.opencode/scripts/check-testcase.sh` | 验证测试用例产出物（阶段一） | exit 0 | exit 1 → 重跑 6a | 6a |
| `.opencode/scripts/check-test.sh` | 验证测试代码产出物（阶段二） | exit 0 | exit 1 → 重跑 6d | 6d |
| `.opencode/scripts/check-review.sh` | 评审门禁判定 | exit 0=通过 | exit 1=有条件/exit 2=不通过 | 1d/2c/3c/5c/6c |

## 工作流

### Step 0：初始化

1. **记忆操作**：`ai_memory_memory_init_session(project_name=<项目名>)` — 若失败则继续（非阻断）
2. 读取 `doc/pipeline/_PROGRESS.md`（若存在）：
   - 有 ⏳ → 恢复模式：读取上次 session_id，继续未完成步骤
   - 无 → 全新启动：写入完整进度表，从 Phase 1 开始
   - 有 ❌ 且是评审失败 → 修复模式：记录重试次数，retry≤3 则继续
3. 向用户报告当前状态和计划

---

### Phase 1：PRD

#### 为什么 PRD 阶段特殊？

PRD 阶段需要多轮交互式需求澄清（端类型锁定、5W1H 访谈、边界澄清、KANO 优先级），subagent **无法使用 `question` 工具**与用户对话。因此，**需求访谈（Steps 0-2）由主 agent（编排器）直接执行**，subagent 仅负责 Step 3 的 PRD 文档生成。

---

##### 1a：需求访谈（交互式 — 主 agent 执行）

主 agent 直接与用户交互完成需求澄清。

**① 加载访谈框架** — 读取 `.opencode/skills/prd-writer/resources/interview-framework.md` 获取结构化提问模板。

**② Step 0：端类型识别** — 使用 `question` 工具向用户确认端类型：
- 纯后端 / Web 前端 / 微信小程序 / 多端并存
- 锁定后列出待生成 PRD 文件清单（参考 `resources/glossary.md` 的文档命名规范）

**③ Step 1：初步理解** — 用 5W1H 框架提 5~8 个问题：
- Who（用户）、What（内容/问题）、Why（目的 ⭐）、When（时机）、Where（场景）、How（方式）

**④ Step 2：多轮澄清** — 每轮 5~8 个问题：
- 边界与异常（逆向提问、极限思维、无数据情况）
- KANO 模型优先级评估
- 端类型专属问题（interview-framework.md 第 6 节）
- 需求冲突识别与处理
- 连续两轮用户无法回答则记录"待补充"继续

**⑤ 范围确认** — 使用 `question` 工具逐项确认以下清单（interview-framework.md 第 5 节）：
- [ ] 端类型已锁定
- [ ] 核心业务问题已清晰定义
- [ ] 目标用户及其痛点已识别
- [ ] 成功指标具体可衡量
- [ ] 范围边界明确（包含什么 / 不包含什么）
- [ ] 关键功能需求已详细描述
- [ ] 非功能需求已覆盖
- [ ] 主要约束和依赖已记录
- [ ] 需求冲突已识别并记录
- [ ] 用户已确认对需求清晰度满意

全部满足后进入下一步，否则继续澄清。

**⑥ 整理需求摘要** — 将收集的需求整理为结构化摘要文件 `doc/prd/_requirements_summary.md`（端类型、业务背景、目标、用户画像、功能列表、范围、约束等）。

**输出**：`doc/prd/_requirements_summary.md`

**记忆**：`ai_memory_add_decision(session_id, "requirements_gathered", "需求访谈完成，摘要: doc/prd/_requirements_summary.md")`

---

##### 1b：PRD 文档生成（subagent 执行）

先读取 `doc/prd/_requirements_summary.md` 获取完整需求摘要，然后调用 `call_prd_writer` 获取 subagent 指令：

```
call_prd_writer(task="基于 doc/prd/_requirements_summary.md 的需求摘要生成 PRD 文档。需求已收集完毕，跳过 Steps 0-2，直接从 Step 3 开始生成。")
```

再将 `call_prd_writer` 返回的完整指令通过 `task` 启动 subagent，**并在 prompt 末尾附加需求摘要内容**：

```
task(subagent_type='prd-writer', prompt="<call_prd_writer 返回的完整指令>

---

## 预收集需求摘要（跳过 Steps 0-2，直接从 Step 3 开始）

<doc/prd/_requirements_summary.md 的完整内容>
")
```

完成后执行 `bash .opencode/scripts/check-prd.sh`。失败则重跑（≤3次）。

**记忆**：`ai_memory_add_decision(session_id, "prd_complete", "PRD 文档已生成: doc/prd/")`

---

#### 1c：需求评审（质量门禁）

先调用 `call_review_expert(task="评审 doc/prd/ 下的 PRD，模式=需求评审")` 获取完整的 subagent 指令（含 review-expert SKILL.md 工作流），**必须用全新的 `task` 调用**启动评审 subagent，不携带任何编写阶段上下文：

```
task(subagent_type='review-expert', prompt="<call_review_expert 返回的完整指令>")
```

#### 1d：门禁判定

```
bash .opencode/scripts/check-review.sh
```

| exit code | 结论 | 动作 |
|-----------|------|------|
| 0 | ✅ 通过 | 更新进度表 → Phase 2 |
| 1 | ⚠️ 有条件通过 | 记录风险 → Phase 2 |
| 2 | ❌ 不通过 | → 重试逻辑（最多 3 次） |

**重试逻辑**：提取 P0/P1 问题 → 回到 1b 修复 PRD 文档 → 回到 1c → 3 次失败则暂停，报告用户。

**记忆**：`ai_memory_add_decision(session_id, "prd_review", "评审结论: ${结论}")`

---

### Phase 2：架构设计

#### 2a：架构设计

先调用 `call_system_architect(task="基于 doc/prd/ 的 PRD 设计系统架构")` 获取指令，再用 `task` 启动：

```
task(subagent_type='system-architect', prompt="<call_system_architect 返回的完整指令>")
```

验证：`bash .opencode/scripts/check-arch.sh`

**记忆**：`ai_memory_memory_add_decision(session_id, "arch_complete", "架构文档已生成: doc/arch/ + tech-stack.json")`

#### 2b：架构评审

先调用 `call_review_expert(task="评审 doc/arch/ 下的 SAD，模式=架构评审")` 获取指令，**必须用全新的 `task`** 启动：

```
task(subagent_type='review-expert', prompt="<call_review_expert 返回的完整指令>")
```

#### 2c：门禁判定

`bash .opencode/scripts/check-review.sh` — 规则同 Phase 1d。失败回退 2a。

**记忆**：`ai_memory_memory_add_decision(session_id, "arch_review", "架构评审结论: ${结论}")`

---

### Phase 3：详细设计

#### 3a：详设拆分

先调用 `call_task_decomposer(task="基于 doc/arch/ 的 SAD 生成模块详细设计")` 获取指令，再用 `task` 启动：

```
task(subagent_type='task-decomposer', prompt="<call_task_decomposer 返回的完整指令>")
```

验证：`bash .opencode/scripts/check-detailed.sh`

**记忆**：`ai_memory_memory_add_decision(session_id, "detailed_complete", "详设文档已生成: doc/detailed/")`

#### 3b：详设评审

先调用 `call_review_expert(task="评审 doc/detailed/ 下的详设，模式=详细设计评审")` 获取指令，**必须用全新的 `task`** 启动：

```
task(subagent_type='review-expert', prompt="<call_review_expert 返回的完整指令>")
```

#### 3c：门禁判定

`bash .opencode/scripts/check-review.sh` — 规则同 Phase 1d。失败回退 3a。

**记忆**：`ai_memory_memory_add_decision(session_id, "detailed_review", "详设评审结论: ${结论}")`

---

### Phase 4：数据库设计（详设后、编码前）

#### 4a：DDL 生成

先调用 `call_dba_designer(task="基于 doc/detailed/ 的后端详设第6节 DDL 草稿生成完整建表脚本")` 获取指令，再用 `task` 启动：

```
task(subagent_type='dba-designer', prompt="<call_dba_designer 返回的完整指令>")
```

验证：`bash .opencode/scripts/check-db.sh`

**记忆**：`ai_memory_memory_add_decision(session_id, "db_design_complete", "DDL 已生成: doc/db/")`

---

### Phase 5：编码开发

#### 5a：代码实现

先调用 `call_code_developer(task="基于 doc/detailed/ 的详设和 doc/db/ 的 DDL 实现代码")` 获取指令，再用 `task` 启动：

```
task(subagent_type='code-developer', prompt="<call_code_developer 返回的完整指令>")
```

3. **文档对齐** — 通知 `code-developer` subagent 须读取 `.opencode/rules/doc-alignment.md`，在编码完成后同步更新对应文档（详设 OpenAPI/DDL 章节、测试用例等）。

验证：`bash .opencode/scripts/check-code.sh`（失败重跑 ≤3次）

**记忆**：`ai_memory_memory_add_decision(session_id, "coding_complete", "代码已实现: src/")`

#### 5b：代码评审（质量门禁）

先调用 `call_code_reviewer(task="评审 src/ 下的代码")` 获取指令，**必须用全新的 `task`** 启动：

```
task(subagent_type='code-reviewer', prompt="<call_code_reviewer 返回的完整指令>")
```

#### 5c：门禁判定

`bash .opencode/scripts/check-review.sh` — 规则同 Phase 1d。失败回退 5a。

**记忆**：`ai_memory_memory_add_decision(session_id, "code_review", "代码评审结论: ${结论}")`

---

### Phase 6：测试（两阶段 + 独立评审）

#### 6a：测试用例设计（阶段一）

先调用 `call_tester(task="阶段一：基于 doc/detailed/ 的详设生成测试用例文档")` 获取指令，再用 `task` 启动：

```
task(subagent_type='tester', prompt="<call_tester 返回的完整指令>")
```

tester 的 Step 0 自动检测到无用例文档 → 进入阶段一，输出 `doc/tester/{模块}_测试用例.md`。

验证：`bash .opencode/scripts/check-testcase.sh`

**记忆**：`ai_memory_memory_add_decision(session_id, "test_case_design", "测试用例已生成: doc/tester/")`

#### 6b：测试用例评审（质量门禁 · 独立会话）

先调用 `call_review_expert(task="评审 doc/tester/ 下的测试用例，模式=测试用例评审")` 获取指令，**必须用全新的 `task`** 启动，不携带测试用例设计阶段的任何上下文：

```
task(subagent_type='review-expert', prompt="<call_review_expert 返回的完整指令>")
```

#### 6c：门禁判定

`bash .opencode/scripts/check-review.sh`

| exit code | 动作 |
|-----------|------|
| 0-1 (通过/有条件通过) | → **6d 测试代码生成** |
| 2 (不通过) | 回退 6a 修复后重评（≤3次） |

**记忆**：`ai_memory_memory_add_decision(session_id, "test_case_review", "测试用例评审结论: ${结论}")`

#### 6d：测试代码生成与执行（阶段二）

先调用 `call_tester(task="阶段二：基于 doc/tester/ 的已确认测试用例生成测试代码并执行测试")` 获取指令，**必须用全新的 `task`** 启动：

```
task(subagent_type='tester', prompt="<call_tester 返回的完整指令>")
```

tester 的 Step 0 自动检测到用例文档已存在 → 进入阶段二，输出 `src/test/` 测试代码 + 测试报告。

验证：`bash .opencode/scripts/check-test.sh`

---

### Step 7：Pipeline 完成

汇总全部产出物清单：

| 产出物 | 路径 | 验证脚本 |
|--------|------|---------|
| PRD | `doc/prd/` | check-prd.sh |
| SAD + tech-stack | `doc/arch/` | check-arch.sh |
| 详细设计 + 项目规则 | `doc/detailed/` | check-detailed.sh |
| DDL | `doc/db/` | check-db.sh |
| 实现代码 | `src/` | check-code.sh |
| 测试用例（阶段一） | `doc/tester/` | check-testcase.sh |
| 测试代码 + 报告（阶段二） | `src/test/` + `doc/tester/` | check-test.sh |

**记忆**：`ai_memory_memory_save_summary(session_id=session_id, task_title="Pipeline 完成", summary_content="完整产出物清单...", file_paths="doc/prd/,doc/arch/,doc/detailed/,doc/db/,src/,doc/tester/", project_name=<项目名>, status="completed", tags="pipeline,full-cycle")`

输出 `✅ Pipeline 完成` + 产出物汇总。

---

## 全局熔断规则

1. 🔴 任何 `task` subagent 启动失败 → 重试一次，仍失败则暂停
2. 🔴 同一门禁连续失败 3 次 → 暂停，等待人工介入
3. 🔴 缺少必需的输入文件（如 Phase 2 时 doc/prd/ 不存在）→ 停止并报告
4. 🔴 ai-memory 调用失败 → 记录日志但 Pipeline 继续（非阻断）

## 检查清单

- [ ] Step 0: 初始化完成，进度文件就绪
- [ ] Phase 1: PRD → 评审 → 通过/修复
- [ ] Phase 2: 架构 → 评审 → 通过/修复
- [ ] Phase 3: 详设 → 评审 → 通过/修复
- [ ] Phase 4: DB DDL → 验证
- [ ] Phase 5: 编码 → 评审 → 通过/修复
- [ ] Phase 6a: 测试用例设计 → check-testcase.sh
- [ ] Phase 6b-c: 测试用例评审 → 门禁判定
- [ ] Phase 6d: 测试代码生成 → check-test.sh
- [ ] Step 7: 汇总 → ai-memory 归档
