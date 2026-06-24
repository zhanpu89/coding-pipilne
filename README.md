# coding-pipeline — OpenCode AI 软件工程流水线

一套基于 [OpenCode](https://opencode.ai) 的 AI 软件工程流水线系统。包含 **10 个专用技能 agent** 和一个 **四级强度自适配的全流程编排器**，覆盖从需求分析到测试执行的完整开发生命周期。

> 🏆 **里程碑版本** — 经两轮实地项目验证，编排器已完成从"固定流程"到"症状驱动、跨层探测、运行时验证"的进化，能自动适配从单行 Bug 修复到全栈新项目开发的任意场景。

---

## 核心能力

### 四级强度自适配

编排器根据任务影响域自动匹配强度，无需用户选择：

| 强度 | 触发条件 | 执行流程 | 典型场景 |
|------|---------|---------|---------|
| 🐛 **轻量** | 单文件/单层改动，无接口无数据变更 | P5a(静态定位) → P5a-r(运行时探测) → P5b(快速审) | 改文案 / 修样式 / 按钮交互修复 |
| 🟢 **标准** | 同模块前后端改动，无 DDL | P3a(简设) → P3b → P5a → P5b → P6c | 加列表筛选 / 改业务逻辑不涉及 DB |
| 🟡 **增量** | 有 DDL 变更或新增子模块 | P3a → P3b → P4a → P4b → P5a → P5b → P6a→P6b→P6c | 新增模块 / 加表 / 加字段 |
| 🔴 **全量** | 全新项目 / 跨模块重构 | Phase 1→2→3→4→5→6 全流程 | 从零开始的完整项目 |

### 症状驱动的智能排错

编排器不再仅按"文件在哪个层"判断影响域，而是通过任务描述的关键词推断**可能根因层**：

| 症状 | 管道内动作 |
|------|-----------|
| "点击没反应/按钮无效" | 先查前端事件 → **API 直达测试**查后端验证层 |
| "创建失败/新建点不了" | `POST` API 直测 → 查前端 catch 分支 |
| "保存后页面错/跳转不对" | API 响应格式检查 → navigate 调用追踪 |
| "页面空白/加载中卡住" | 网络请求检查 → 错误边界检查 |

**核心原则：** 前端症状 ≠ 前端根因。涉及数据操作的症状，必须排除后端验证层才能定论为纯前端 Bug。

### 运行时探测（P5a-r）

轻量模式的故障排查瓶颈突破——**禁止在静态代码中反复空转**：

```
P5a(静态定位)
  ├─ 找到 Bug → 修 → P5b
  └─ 静态无果 → P5a-r(运行时探测)
       ├─ 数据操作异常 → API 直达测试 (curl)
       ├─ 点击/导航异常 → console + 路由检查
       ├─ 渲染/空白异常 → 网络请求 + 错误边界
       ├─ 样式异常 → 仅前端检查
       └─ 仍无果 → 标记已排除项 → 向用户澄清
```

**跨层探测规则：** 涉及创建/保存/删除/搜索的前端症状，不先做 API 直达测试排除后端根因前，不允许锁定为纯前端 Bug。

### 不依赖 Git 的影响域分析

扫描项目文件结构直接推断技术栈和影响范围：

```python
# 检测语言
pom.xml / build.gradle → Java
go.mod               → Go
requirements.txt     → Python
package.json+server/ → Node

# 检测前端
package.json 中 vue 依赖 → Vue3
package.json 中 react 依赖 → React

# 检测小程序
miniprogram/ / weapp/ / uni-app/
```

---

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
3. 复制根目录配置文件（opencode.json）
4. 验证完整性（11 skills, 8 scripts, 4 rules）

### 验证安装

在项目目录中启动 OpenCode，输入：

```
可用的自定义工具有哪些？
```

预期应看到 `call_pipeline_orchestrator`、`call_prd_writer`、`call_review_expert` 等 11 个自定义工具。

---

## 使用方式

### 方式一：全流程流水线（推荐）

一句话启动，编排器自动分析任务并选择强度：

```
/agent pipeline-orchestrator
```

或直接调用工具：

```
请用 call_pipeline_orchestrator 启动，任务是为这个电商项目写一个完整的软件工程流水线
```

全流程各阶段产出：

```
Phase 1a→1b→1c:  PRD 编写 → 需求评审              doc/prd/
Phase 2a→2b:      架构设计 → 架构评审              doc/arch/
Phase 3a→3b:      详细设计 → 详设评审              doc/detailed/
Phase 4a→4b:      数据库 DDL 设计 → 评审            doc/db/
Phase 5a→5b:      编码实现 → 代码评审              src/
Phase 6a→6b→6c:   测试用例设计 → 用例评审 → 执行    doc/tester/ + 测试报告
```

### 方式二：单独调用某个技能

| 场景 | 操作 |
|------|------|
| 写 PRD | `call_prd_writer(task="为一个在线教育平台编写 PRD")` |
| 评审文档 | `call_review_expert(task="评审 doc/prd/ 下的 PRD")` |
| 架构设计 | `call_system_architect(task="基于 PRD 设计系统架构")` |
| 详设拆分 | `call_task_decomposer(task="基于 SAD 生成详设")` |
| 编码实现 | `call_code_developer(task="基于详设实现代码")` |
| 代码评审 | `call_code_reviewer(task="评审 src/ 下的代码")` |
| 测试设计 | `call_tester(task="阶段一：基于详设生成测试用例")` |
| 测试执行 | `call_tester(task="阶段二：基于已确认用例生成测试代码并执行")` |
| DDL 设计 | `call_dba_designer(task="基于详设生成 DDL")` |

---

## 技能一览

| 技能 | agent | 角色 |
|------|-------|------|
| PRD Writer | `prd-writer` | 需求分析 → PRD 文档 |
| Review Expert | `review-expert` | 全流程评审（需求/架构/详设/测试） |
| System Architect | `system-architect` | 架构设计 + 技术栈选型 |
| Task Decomposer | `task-decomposer` | 详设拆分 + 项目规则 |
| DB Designer | `dba-designer` | DDL 脚本生成 |
| Code Developer | `code-developer` | 编码实现 |
| Code Reviewer | `code-reviewer` | 代码质量评审 |
| Tester | `tester` | 两阶段：用例设计 → 代码生成与执行 |
| Self Evolve | `self-evolve` | 工具自我进化 |
| AI Memory | `ai-memory` | 经验持久化 |
| Pipeline Orchestrator | `pipeline-orchestrator` | **全流程编排（主 agent）** |

---

## 架构设计原则

### 评审隔离（杜绝自审自判）

每个产出阶段后的评审在**全新 subagent 会话**中完成，入参仅含文件路径 + 参考契约路径，不携带任何创作意图、设计推理、作者信息。评审 agent 拿到的是"陌生人写的文档"。

```
产出物 → 评审 subagent（全新 task）→ check-review.sh
  ✅ 通过 / ⚠️ 有条件 → 下一阶段
  ❌ 不通过 → 返回修复（≤3次）
```

### 记忆持久化

- **Step 0 统一检索**：`ai_memory_init_session()` + `search_summaries()` 结果写入 `_MEMORY_CACHE.md`
- **各 Phase 消费**：打包 prompt 时注入历史经验，跨 pipeline 复用
- **节奏**：首 Phase `save_summary(in_progress)`，后续 `add_decision` + `update_summary`，Step 7 标记完成
- **中途不丢失**：每个产出 Phase 末尾都会持久化进度 + 决策

### 文档同步机制

`code-developer` 输出 `>>DOC_SYNC: {文件路径} → {改动说明}` 标记需同步的契约文档。**编排器（主 agent）负责按清单修改文档**，code-developer 不直接触碰契约。code-reviewer 评审时同时审查代码和更新后的文档，确保端对齐。

### 熔断机制

| 条件 | 行为 |
|------|------|
| subagent 启动失败 | 重试 1 次 |
| 同一门禁连续失败 3 次 | **暂停**，等待人工介入 |
| 缺必需输入 | 停止当前 Phase |
| 记忆 (ai_memory_*) 失败 | 记录警告后继续，不阻断 |

---

## 项目规则

| 规则 | 文件 | 作用 |
|------|------|------|
| 精准定位规则 | `precise-location.md` | 禁止不经定位直接全局扫描，模块→层级→候选文件三步定位 |
| 端锁定规则 | `endpoint-lock.md` | 发现 API/DB 契约不对齐时 STOP→READ→REPORT→WAIT |
| 编码纪律 | `code-discipline.md` | 先思考再编码/简洁优先/手术式修改 |
| 文档对齐 | `doc-alignment.md` | 编码期间禁止改契约，走 doc sync 流程 |

---

## 目录结构

```
your-project/
├── install.sh
├── opencode.json
├── AGENTS.md
├── README.md
├── doc/
│   ├── prd/            # PRD 文档
│   ├── arch/           # 架构设计
│   ├── detailed/       # 详细设计
│   ├── db/             # DDL 脚本
│   ├── tester/         # 测试用例 + 报告
│   └── review/         # 评审报告
├── src/                # 源码产出
└── .opencode/
    ├── skills/         # 11 个技能定义
    │   ├── prd-writer/
    │   ├── review-expert/
    │   ├── system-architect/
    │   ├── task-decomposer/
    │   ├── code-developer/
    │   ├── code-reviewer/
    │   ├── tester/
    │   ├── dba-designer/
    │   ├── ai-memory/
    │   ├── self-evolve/
    │   └── pipeline-orchestrator/
    ├── plugins/        # skill-agent.ts + skill-loader.ts
    ├── commands/       # /check-doc-drift 等
    ├── rules/          # AI 行为约束
    └── scripts/        # 8 个验证脚本
```

---

## 关键约定

- **LC-001**: 主语言（Java/Python/Go/Node.js）
- **LC-FE-001**: 前端框架（Vue3/React/无）
- **P0/P1/P2**: 问题严重等级。P0 阻断一切
- **状态标记**: `🟡 草稿` → `🟢 已确认`
- **单模块节奏**: 一次只生成一份文档/模块，等待确认后继续

---

## 常见问题

**Q: 中断后如何继续？**
A: 每 Phase 末尾通过 `ai_memory` 持久化进度和决策。下次启动 `init_session` 可恢复上下文。

**Q: 评审失败怎么办？**
A: 自动重试最多 3 次，每次读取上一次的 P0/P1 问题清单定向修复。3 次仍失败则暂停等待人工介入。

**Q: 如何只做某个阶段？**
A: 直接调用对应的 `call_*` 工具，无需启动编排器。

**Q: ai-memory 起什么作用？**
A: 不仅是记忆持久化工具，更是 pipeline 的**经验引擎**。Step 0 统一检索历史经验，各 Phase 消费，让后续阶段从过去的决策和踩坑中学习。

**Q: 测试流程是怎样的？**
A: 两阶段独立：
- **阶段一**（6a）：基于详设生成测试用例文档 → 评审（6b）
- **阶段二**（6c）：基于已确认用例生成测试代码并执行 → 出测试报告

**Q: 没有 Git 的项目能用吗？**
A: 可以。影响域分析通过静态文件扫描完成，不依赖 `git diff`。🐛 轻量模式在无 Git 项目上已验证有效。
