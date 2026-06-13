# coding-pipeline — OpenCode AI 软件工程全流程流水线

一套基于 OpenCode 的 AI 软件工程流水线系统。包含 **10 个专用技能 agent** 和一个 **全流程编排器**，覆盖从需求分析到测试评审的完整开发生命周期。

## 快速安装

### 前置条件

- [OpenCode](https://opencode.ai) 已安装并可用
- 已配置可用的 AI provider（如 Claude API）
- Node.js >= 18

### 一键安装

```bash
# 在目标项目目录中执行
bash path/to/coding-pipeline/install.sh

# 或指定目标目录
bash path/to/coding-pipeline/install.sh /path/to/your-project
```

安装脚本会自动完成：
1. 复制 `.opencode/`（skills/plugins/scripts/rules）
2. 创建 `package.json` + `npm install`
3. 复制根目录配置文件（opencode.json, AGENTS.md, README.md）
4. 验证完整性（10 skills, 8 scripts, 2 rules）

### 验证安装

在项目目录中启动 OpenCode，输入以下命令验证工具可用：

```
可用的自定义工具有哪些？
```

预期应看到 `call_prd_writer`、`call_review_expert`、`call_code_developer`、`call_pipeline_orchestrator` 等 10 个工具。

---

## 使用方式

### 方式一：全流程流水线（推荐）

一句话启动完整的软件工程流水线：

```
/agent pipeline-orchestrator
```

或在任意 agent 中调用 `call_pipeline_orchestrator` 工具，系统会自动依次执行 6 个阶段：

```
Phase 1:  PRD 编写 → 需求评审              产出: doc/prd/
Phase 2:  架构设计 → 架构评审              产出: doc/arch/ + tech-stack.json
Phase 3:  详细设计 → 详设评审              产出: doc/detailed/
Phase 4:  数据库设计                      产出: doc/db/
Phase 5:  编码开发 → 代码评审              产出: src/
Phase 6a: 测试用例设计 → 用例评审          产出: doc/tester/
Phase 6d: 测试代码生成与执行              产出: src/test/ + 测试报告
```

关键特性：
- **创作与评审严格分离** — 每个阶段的评审由独立的 subagent 在全新 `task` 会话中完成，不携带编写阶段的任何上下文，保证客观性
- 每个评审门禁自动判定 `✅/⚠️/❌`，失败自动回退修复（最多 3 次）
- ai-memory 贯穿全流程，自动记录关键决策和阶段摘要
- 进度保存在 `doc/pipeline/_PROGRESS.md`，支持断点续传

### 方式二：单独调用某个技能

只需要流水线中的某一步时，可以单独调用对应的自定义工具：

| 场景 | 操作 |
|------|------|
| 写 PRD | `call_prd_writer(task="为一个在线教育平台编写 PRD")` → `task` |
| 评审文档 | `call_review_expert(task="评审 doc/prd/ 下的 PRD，模式=需求评审")` → `task` |
| 架构设计 | `call_system_architect(task="基于 PRD 设计系统架构")` → `task` |
| 详设拆分 | `call_task_decomposer(task="基于 SAD 生成详设")` → `task` |
| 编码实现 | `call_code_developer(task="基于详设实现代码")` → `task` |
| 代码评审 | `call_code_reviewer(task="评审 src/ 下的代码")` → `task` |
| 测试用例设计 | `call_tester(task="阶段一：基于详设生成测试用例文档")` → `task` |
| 测试代码生成 | `call_tester(task="阶段二：基于已确认用例生成测试代码")` → **全新 `task`** |
| DDL 设计 | `call_dba_designer(task="基于详设生成 DDL")` → `task` |

> **注意**：每个 `call_*` 工具只返回 SKILL.md（工作流指令），需要用 `task` 工具启动 subagent 才能真正执行。

### 方式三：直接切换 agent

在 OpenCode 中可以直接切换到某个 agent：

```
/agent prd-writer
```

或通过 `task` 工具启动 agent 作为 subagent：

```
请用 task 启动 prd-writer agent，任务是为电商系统写 PRD
```

---

## 技能详解

### 10 个技能一览

| 技能 | agent 名 | 工具名 | 角色 | 产出目录 |
|------|----------|--------|------|---------|
| PRD Writer | `prd-writer` | `call_prd_writer` | 需求分析 → PRD 文档 | `doc/prd/` |
| Review Expert | `review-expert` | `call_review_expert` | 全流程评审（需求/架构/详设/测试） | `doc/review/` |
| System Architect | `system-architect` | `call_system_architect` | 架构设计 + 技术栈选型 | `doc/arch/` |
| Task Decomposer | `task-decomposer` | `call_task_decomposer` | 详设拆分 + 项目规则 | `doc/detailed/` |
| DB Designer | `dba-designer` | `call_dba_designer` | DDL 脚本生成 | `doc/db/` |
| Code Developer | `code-developer` | `call_code_developer` | 编码实现 | `src/` |
| Code Reviewer | `code-reviewer` | `call_code_reviewer` | 代码质量评审 | `doc/review/` |
| Tester | `tester` | `call_tester` | 两阶段：用例设计 → 代码生成 | `doc/tester/` + `src/test/` |
| AI Memory | `ai-memory` | `call_ai_memory` | 记忆持久化（桥梁） | — |
| Pipeline Orchestrator | `pipeline-orchestrator` | `call_pipeline_orchestrator` | 全流程编排 | `doc/pipeline/` |

### 懒加载机制

每个技能遵循严格的**懒加载原则**：

- `call_xxx` 工具**只加载 SKILL.md**（工作流指令 + 懒加载表）
- subagent 启动后，**按工作流步骤用 `read` 工具按需读取**具体的 `resources/` 和 `templates/` 文件
- 对应步骤完成后**释放文件**，不再保留在上下文中

---

## 流水线架构

### 核心原则：创作与评审严格分离

| 阶段 | 编写 subagent | 评审 subagent（全新 task） |
|------|--------------|---------------------------|
| PRD | `call_prd_writer` → `task` | `call_review_expert` → **全新 `task`** |
| 架构 | `call_system_architect` → `task` | `call_review_expert` → **全新 `task`** |
| 详设 | `call_task_decomposer` → `task` | `call_review_expert` → **全新 `task`** |
| 代码 | `call_code_developer` → `task` | `call_code_reviewer` → **全新 `task`** |
| 测试 | `call_tester` → `task`（两阶段分离） | `call_review_expert` → **全新 `task`**（仅审用例） |

评审 subagent 在**全新的 `task` 会话**中启动，不知道也不关心文档是谁写的，保证评审客观性。

### 质量门禁

每个阶段的评审结论从 `check-review.sh` 读取 `| 评审结论 | ✅/⚠️/❌ |`：

```
产出物 → 评审 subagent（全新 task）→ check-review.sh
  ✅ 通过 / ⚠️ 有条件 → 下一阶段
  ❌ 不通过 → 返回修复（≤3次），每次读取 P0/P1 问题列表定向修复
```

除了评审门禁，每个技能还有自身内部的**写入前检查**（格式校验、占位符检查等），这些属于技能自身的质量控制，与外部评审无关。

### 验证脚本

| 脚本 | 用途 | 阶段 |
|------|------|------|
| `.opencode/scripts/check-prd.sh` | 验证 PRD 文档完整性 | 1a |
| `.opencode/scripts/check-arch.sh` | 验证 SAD + tech-stack.json | 2a |
| `.opencode/scripts/check-detailed.sh` | 验证详设文档章节完整性 | 3a |
| `.opencode/scripts/check-db.sh` | 验证 DDL SQL 语法 | 4a |
| `.opencode/scripts/check-code.sh` | 验证 src/ 非空 | 5a |
| `.opencode/scripts/check-testcase.sh` | 验证测试用例文档（阶段一） | 6a |
| `.opencode/scripts/check-test.sh` | 验证测试代码 + 报告（阶段二） | 6d |
| `.opencode/scripts/check-review.sh` | 评审门禁判定（exit 0/1/2） | 各评审门禁 |

---

## 项目规则（Project Rules）

针对**增量需求 / Bug 修复**场景，系统内置两条 AI 行为约束规则，通过 `opencode.json` 的 `instructions` 字段自动加载：

| 规则 | 文件 | 作用 |
|------|------|------|
| 精准定位规则 | `.opencode/rules/precise-location.md` | 禁止 AI 不经定位直接扫描代码，按模块→层级→文件三步定位 |
| 端锁定规则 | `.opencode/rules/endpoint-lock.md` | 禁止 AI 擅自修改 API/数据库契约，发现不对齐时 STOP→READ→REPORT→WAIT |

> 全量新建项目走 pipeline-orchestrator 流程，不触发这些规则。

## 配置说明

### opencode.json

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [".opencode/rules/*.md"],
  "plugin": [
    "./.opencode/plugins/skill-agent.ts"
  ],
  "agent": {
    "prd-writer":           { "mode": "subagent", ... },
    "review-expert":        { "mode": "subagent", ... },
    "system-architect":     { "mode": "subagent", ... },
    "task-decomposer":      { "mode": "subagent", ... },
    "code-developer":       { "mode": "subagent", ... },
    "code-reviewer":        { "mode": "subagent", ... },
    "tester":               { "mode": "subagent", ... },
    "dba-designer":         { "mode": "subagent", ... },
    "ai-memory":            { "mode": "subagent", ... },
    "pipeline-orchestrator": { "mode": "primary" }
  }
}
```

- **instructions**: 加载 AI 行为约束规则文件（支持 glob 通配符）
- **plugin**: 注册自定义工具插件
- **agent**: 9 个 `mode: "subagent"` 供 `task` 启动，1 个 `mode: "primary"`（编排器）

### 目录结构

```
your-project/
├── install.sh                       # 一键安装脚本（来自本仓库）
├── opencode.json                    # 项目配置
├── AGENTS.md                        # 技能文档
├── README.md                        # 本文件
├── doc/                             # 文档产出目录（自动生成）
│   ├── prd/                         # PRD 文档
│   ├── arch/                        # 架构设计 + tech-stack.json
│   ├── detailed/                    # 详细设计
│   ├── db/                          # DDL 脚本
│   ├── tester/                      # 测试用例 + 测试报告
│   ├── review/                      # 评审报告
│   └── pipeline/                    # Pipeline 进度跟踪
├── src/                             # 代码产出
│   └── test/                        # 测试代码
└── .opencode/
    ├── skills/                      # 10 个技能定义
    │   ├── prd-writer/
    │   ├── review-expert/
    │   ├── system-architect/
    │   ├── task-decomposer/
    │   ├── code-developer/
    │   ├── code-reviewer/
    │   ├── tester/
    │   ├── dba-designer/
    │   ├── ai-memory/
    │   └── pipeline-orchestrator/
    ├── plugins/
    │   └── skill-agent.ts           # 插件：暴露 10 个 call_* 工具
    ├── rules/                       # AI 行为约束规则（增量/Bug修复场景）
    │   ├── precise-location.md      # 精准定位规则，禁止不经定位扫描代码
    │   └── endpoint-lock.md         # 端锁定规则，禁止擅自修改契约接口
    ├── scripts/                     # 验证脚本（8 个 bash 脚本）
    │   ├── check-prd.sh
    │   ├── check-arch.sh
    │   ├── check-detailed.sh
    │   ├── check-db.sh
    │   ├── check-code.sh
    │   ├── check-test.sh
    │   ├── check-testcase.sh
    │   └── check-review.sh
    ├── package.json
    └── node_modules/
```

---

## 产出物说明

| 阶段 | 产出物 | 格式 | 说明 |
|------|--------|------|------|
| PRD | `doc/prd/{项目}_PRD.md` | Markdown | 含用户画像、业务流程、功能/非功能需求、AC |
| 架构 | `doc/arch/{项目}_SAD.md` | Markdown | 含系统上下文、分层架构、技术选型论证 |
| 架构 | `doc/arch/tech-stack.json` | JSON | 技术栈结构化清单 |
| 详设 | `doc/detailed/{模块}_{功能域}.md` | Markdown | 13 节完整详设（含 OpenAPI 3.0 YAML、伪代码、DDL 草稿）|
| 详设 | `doc/detailed/项目规则.md` | Markdown | LC 约束、编码规范、项目规则 |
| DDL | `doc/db/{项目}_DDL.sql` | SQL | 幂等建表脚本 |
| 代码 | `src/` | 按语言 | 实体、DAO、Service、Controller、测试骨架 |
| 测试用例 | `doc/tester/{模块}_测试用例.md` | Markdown | 结构化用例（含评审标记） |
| 测试报告 | `doc/tester/{模块}_测试报告.md` | Markdown | 执行结果 + 缺陷清单 |
| 评审报告 | `doc/review/{类型}_评审报告.md` | Markdown | 含结论、问题清单、修复建议 |
| 流水线 | `doc/pipeline/_PROGRESS.md` | Markdown | Pipeline 进度跟踪 |

---

## 关键约定

- **LC-001**: 主语言（Java/Python/Go/Node.js）
- **LC-FE-001**: 前端框架（Vue3/React/无）
- **P0/P1/P2**: 问题严重等级。P0 阻断一切
- **状态标记**: `🟡 草稿` → `🟢 已确认`
- **单模块节奏**: 一次只生成一份文档/模块，等待用户确认后继续

---

## 常见问题

**Q: 如何中断后继续？**
A: Pipeline 会自动检查 `doc/pipeline/_PROGRESS.md`，有 ⏳ 状态时会自动进入恢复模式。

**Q: review 失败了怎么办？**
A: 自动重试最多 3 次，每次修复会读取上一次的 P0/P1 问题列表。3 次仍失败则暂停等待人工介入。

**Q: 如何只做某个阶段？**
A: 直接调用对应的 `call_*` 工具，不需要使用 pipeline-orchestrator。

**Q: ai-memory 起什么作用？**
A: 它通过 MCP 工具（`ai_memory_memory_init_session`/`ai_memory_memory_add_decision`/`ai_memory_memory_save_summary`/`ai_memory_memory_search_summaries`）将全流程的关键决策和阶段产出持久化，确保长周期开发中上下文不丢失。作为"记忆脊椎"贯穿所有阶段。

**Q: 评审客观性如何保证？**
A: 每个阶段的评审 subagent 都在**全新的 `task` 会话**中启动，不携带编写阶段的任何上下文。编写 subagent 不知道后续会有人评审，评审 subagent 不知道文档是谁写的，保证评审客观公正。

**Q: 测试流程是怎样的？**
A: 测试分两阶段独立执行：
- **阶段一**（6a）：基于详设生成测试用例文档 → 评审（6b-c，独立 `task`）
- **阶段二**（6d）：基于已确认的测试用例生成测试代码并执行 → 出测试报告
