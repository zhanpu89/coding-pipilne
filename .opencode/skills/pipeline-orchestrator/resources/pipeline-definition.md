# Pipeline 全流程定义

## 总体架构

```
╔══════════════════════════════════════════════════════════════╗
║              ai-memory（记忆桥梁 · 贯穿全流程）               ║
║  init_session → add_decision → save_summary → search_sum... ║
╚══════════════════════════════════════════════════════════════╝
         │
         ▼
Phase 1 ──→ PRD 编写 ──→ 需求评审 ──❌ 阻断(≤3次) ──→ 修复后重评
                 │
                 ▼ ✅
Phase 2 ──→ 架构设计 ──→ 架构评审 ──❌ 阻断(≤3次) ──→ 修复后重评
                 │
                 ▼ ✅
Phase 3 ──→ 详细设计 ──→ 详设评审 ──❌ 阻断(≤3次) ──→ 修复后重评
                 │
                 ▼ ✅
Phase 4 ──→ 数据库设计（详设后、编码前） ← 调整至此
                 │
                 ▼ ✅
Phase 5 ──→ 编码开发 ──→ 代码评审 ──❌ 阻断(≤3次) ──→ 修复后重评
                 │
                 ▼ ✅
Phase 6 ──→ 测试设计 + 执行 ──→ 测试评审 ──❌ 阻断(≤3次) ──→ 修复后重评
                 │
                 ▼ ✅
           Pipeline 完成 ✅
```

## 阶段说明

### Phase 1：PRD

| 子步骤 | 操作 | 产出 |
|--------|------|------|
| 1a | 调用 `call_prd_writer` → 启动 subagent | `doc/prd/{项目}_PRD.md` |
| 1b | 调用 `call_review_expert` → 启动 subagent(需求评审) | `doc/review/{项目}_需求评审报告.md` |
| 1c | 读取评审报告，判断结论 | — |

**门禁规则**：读取报告 `## 一、评审概要` → `评审结论` 行
- `✅ 通过` → Phase 2
- `⚠️ 有条件通过` → 记录风险，进入 Phase 2
- `❌ 不通过` → 回到 1a（重试≤3次）

### Phase 2：架构设计

| 子步骤 | 操作 | 产出 |
|--------|------|------|
| 2a | 调用 `call_system_architect` → 启动 subagent | `doc/arch/{项目}_SAD.md` + `tech-stack.json` |
| 2b | 调用 `call_review_expert` → 启动 subagent(架构评审) | `doc/review/{项目}_架构评审报告.md` |
| 2c | 读取评审报告，判断结论 | — |

**门禁规则**：同 Phase 1

### Phase 3：详细设计

| 子步骤 | 操作 | 产出 |
|--------|------|------|
| 3a | 调用 `call_task_decomposer` → 启动 subagent | `doc/detailed/{模块}_详设.md` + 项目规则 |
| 3b | 调用 `call_review_expert` → 启动 subagent(详设评审) | `doc/review/{项目}_详设评审报告.md` |
| 3c | 读取评审报告，判断结论 | — |

**门禁规则**：同 Phase 1

### Phase 4：数据库设计 ← 新位置

| 子步骤 | 操作 | 产出 |
|--------|------|------|
| 4a | 调用 `call_dba_designer` → 启动 subagent | `doc/db/{项目}_DDL.sql` |

**说明**：详设评审通过后立即进行 DDL 设计，编码时可直接使用完整 DDL。

### Phase 5：编码开发

| 子步骤 | 操作 | 产出 |
|--------|------|------|
| 5a | 调用 `call_code_developer` → 启动 subagent | `src/` 实现代码 |
| 5b | 调用 `call_code_reviewer` → 启动 subagent | `doc/review/{模块}_代码评审报告.md` |
| 5c | 读取评审报告，判断结论 | — |

**门禁规则**：
- `✅ 通过` → Phase 6
- `⚠️ 有条件通过` → 记录待修复，进入 Phase 6
- `❌ 不通过` → 回到 5a（重试≤3次）

### Phase 6：测试

| 子步骤 | 操作 | 产出 |
|--------|------|------|
| 6a | 调用 `call_tester` → 启动 subagent | `doc/tester/` + `src/test/` |
| 6b | 调用 `call_review_expert` → 启动 subagent(测试评审) | `doc/review/{项目}_测试评审报告.md` |
| 6c | 读取评审报告，判断结论 | — |

**门禁规则**：同 Phase 1

## ai-memory 记忆桥梁

ai-memory 是整个流水线的"记忆脊椎"，确保长周期工程上下文的连续性：

| 时机 | 操作 | 目的 |
|------|------|------|
| Pipeline 启动 | `init_session(project_name, branch_name)` | 建立会话，恢复上下文 |
| 每个 Phase 的门禁通过 | `add_decision(...)` | 记录关键决策 |
| 编码阶段完成 | `save_summary(...)` | 归档编码阶段成果 |
| Phase 变更 | `search_summaries(query)` | 搜索历史相关经验 |
| Pipeline 完成 | `save_summary(...)` | 归档全流程产出 |

## 全局规则

### 进度追踪
- `doc/pipeline/_PROGRESS.md` 追踪当前状态
- 每步完成后更新：状态(⏳/✅/❌) + 产出物路径 + 重试次数

### 重试机制
- 每个门禁最多重试 3 次
- 重试前：读取上一轮评审报告中的 P0/P1 问题，告知 subagent 重点修复
- 3 次仍失败 → 暂停 Pipeline，报告用户人工介入

### 用户交互
- 每完成一个子步骤，输出摘要并等待用户确认
- 门禁阻断时，明确告知阻断原因和修复方向
- Pipeline 完成时，汇总全部产出物清单

### 恢复机制
- 启动时检查 `_PROGRESS.md`
- 有 ⏳ 状态 → 恢复模式，继续未完成步骤
- 无 → 全新启动
