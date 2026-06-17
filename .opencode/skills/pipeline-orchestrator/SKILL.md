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

你是编排器（主 agent），通过 `task` 启动 subagent 执行各阶段，通过 `bash` 运行检查脚本。subagent 用完即销毁，不嵌套。

**关键变更：subagent 自读 SKILL.md** — `call_*` 工具返回简短引用，subagent 自行 read 自身 SKILL.md 获取工作流指令。

**ai-memory 贯穿全流程**：每个 Phase 完成后记录决策。`resources/pipeline-definition.md` 含全局视图。

## 编排模式

每个 Phase 遵循统一模式，评审 subagent 必须**全新 `task`** 隔离：

```
① call_{skill}(task="<任务描述>")
② task(subagent_type='{agent}', prompt="{引用}\n---\n你先 read 自身 SKILL.md，再按步骤执行。\n{额外输入}")
③ bash .opencode/scripts/check-{phase}.sh（失败重试 ≤3 次）
④ ai_memory_add_decision(session_id, "{phase}_result", "{结论}")
```

评审子流程：
```
① call_review_expert(task="评审 {目录}，模式={评审类型}")
② task(subagent_type='review-expert', prompt="{引用}\n---\n你先 read 自身 SKILL.md，再按步骤执行。")
③ bash .opencode/scripts/check-review.sh（0=通过 | 1=有条件 | 2=不通过→重试 ≤3 次）
```

## 参考文件

| 文件 | 加载时机 |
|------|---------|
| `resources/pipeline-definition.md` | 全局 |
| `.opencode/scripts/check-*.sh` | 对应步骤 |

## 工作流

### Step 0：初始化
1. `ai_memory_init_session(project_name=<项目名>)` — 非阻断
2. 读 `doc/pipeline/_PROGRESS.md`：有 ⏳ 恢复 | 无 全新 | 有 ❌ 修复（retry≤3）
3. 向用户报告状态

---

### Phase 1：PRD

PRD 需求访谈由主 agent 直接执行（subagent 无 `question` 工具）。

**1a：需求访谈（主 agent 执行）**
读 `.opencode/skills/prd-writer/resources/interview-framework.md` → 用 `question` 完成端类型识别、5W1H、多轮澄清、范围确认 → 输出 `doc/prd/_requirements_summary.md`

**1b：PRD 生成**
```
call_prd_writer(task="基于 doc/prd/_requirements_summary.md 生成 PRD。跳过 Steps 0-2，从 Step 3 开始。")
task(subagent_type='prd-writer', prompt="<call_prd_writer 返回>
---
你先 read 自身 SKILL.md，再按步骤执行。

## 需求摘要
<doc/prd/_requirements_summary.md 完整内容>")
```
`bash .opencode/scripts/check-prd.sh`（失败 ≤3 次）

**1c：评审** → `call_review_expert` → **全新 task** → `bash .opencode/scripts/check-review.sh`

---

### Phase 2：架构

**2a：架构设计**
```
call_system_architect(task="基于 doc/prd/ 的 PRD 设计系统架构")
task(subagent_type='system-architect', prompt="<call_system_architect 返回>
---
你先 read 自身 SKILL.md，再按步骤执行。")
```
`bash .opencode/scripts/check-arch.sh`（失败 ≤3 次）

**2b：评审** → `call_review_expert` → **全新 task** → `bash .opencode/scripts/check-review.sh`

---

### Phase 3：详设

**3a：详设拆分**
```
call_task_decomposer(task="基于 doc/arch/ 的 SAD 生成模块详细设计")
task(subagent_type='task-decomposer', prompt="<call_task_decomposer 返回>
---
你先 read 自身 SKILL.md，再按步骤执行。")
```
`bash .opencode/scripts/check-detailed.sh`（失败 ≤3 次）

**3b：评审** → `call_review_expert` → **全新 task** → `bash .opencode/scripts/check-review.sh`

---

### Phase 4：数据库

**4a：DDL 生成**
```
call_dba_designer(task="基于 doc/detailed/ 第6节 DDL 草稿生成完整建表脚本")
task(subagent_type='dba-designer', prompt="<call_dba_designer 返回>
---
你先 read 自身 SKILL.md，再按步骤执行。")
```
`bash .opencode/scripts/check-db.sh`（失败 ≤3 次）

---

### Phase 5：编码

**5a：代码实现**
```
call_code_developer(task="基于 doc/detailed/ 的详设和 doc/db/ 的 DDL 实现代码。编码完成后读取 .opencode/rules/doc-alignment.md 同步更新相关文档。")
task(subagent_type='code-developer', prompt="<call_code_developer 返回>
---
你先 read 自身 SKILL.md，再按步骤执行。编码完成后读取 .opencode/rules/doc-alignment.md 同步更新文档。")
```
`bash .opencode/scripts/check-code.sh`（失败 ≤3 次）

**5b：评审** → `call_code_reviewer` → **全新 task**

---

### Phase 6：测试（两阶段）

**6a：测试用例设计**
```
call_tester(task="阶段一：基于 doc/detailed/ 详设生成测试用例文档")
task(subagent_type='tester', prompt="<call_tester 返回>
---
你先 read 自身 SKILL.md，再按步骤执行。")
```
`bash .opencode/scripts/check-testcase.sh`（失败 ≤3 次）

**6b：用例评审** → `call_review_expert` → **全新 task** → `bash .opencode/scripts/check-review.sh`
- 0-1（通过/有条件）→ 6c
- 2（不通过）→ 回退 6a ≤3 次

**6c：测试代码生成**
```
call_tester(task="阶段二：基于 doc/tester/ 已确认用例生成测试代码并执行")
task(subagent_type='tester', prompt="<call_tester 返回>
---
你先 read 自身 SKILL.md，再按步骤执行。")
```
`bash .opencode/scripts/check-test.sh`（失败 ≤3 次）

**6e：测试代码评审** → `call_code_reviewer` → **全新 task**

---

### Step 7：完成

| 产出物 | 路径 | 验证脚本 |
|--------|------|---------|
| PRD | `doc/prd/` | check-prd.sh |
| SAD + tech-stack | `doc/arch/` | check-arch.sh |
| 详细设计 + 项目规则 | `doc/detailed/` | check-detailed.sh |
| DDL | `doc/db/` | check-db.sh |
| 评审报告 | `doc/review/` | check-review.sh |
| 实现代码 | `src/` | check-code.sh |
| 测试用例 | `doc/tester/` | check-testcase.sh |
| 测试代码 + 报告 | `src/test/` + `doc/tester/` | check-test.sh |
| Pipeline 进度 | `doc/pipeline/_PROGRESS.md` | — |

`ai_memory_save_summary(session_id, "Pipeline 完成", summary_content="...", file_paths="doc/prd/,doc/arch/,doc/detailed/,doc/db/,doc/review/,src/,doc/tester/", project_name=<项目名>, status="completed", tags="pipeline,full-cycle")`

输出 ✅ **Pipeline 完成** + 产出物汇总。

---

## 全局熔断

1. 🔴 `task` subagent 启动失败 → 重试一次，仍失败则暂停
2. 🔴 同一门禁连续失败 3 次 → 暂停
3. 🔴 缺少必需输入文件 → 停止
4. 🔴 ai-memory 失败 → 记录日志，继续

```
⛔ PIPELINE BLOCKED
  原因: {具体原因}
  阶段: {当前 Phase}
  重试: {retry}/3
  session_id: {当前 session_id}
```

## 检查清单

- [ ] Step 0: 初始化
- [ ] Phase 1: PRD → 评审 → 门禁
- [ ] Phase 2: 架构 → 评审 → 门禁
- [ ] Phase 3: 详设 → 评审 → 门禁
- [ ] Phase 4: DB DDL → 验证
- [ ] Phase 5: 编码 → 评审
- [ ] Phase 6a: 测试用例 → 评审 → 门禁
- [ ] Phase 6c: 测试代码 → 验证
- [ ] Phase 6e: 测试代码评审
- [ ] Step 7: 汇总 → ai-memory 归档
