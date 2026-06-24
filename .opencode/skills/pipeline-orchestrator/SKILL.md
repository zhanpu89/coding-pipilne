---
name: pipeline-orchestrator
description: 全流程软件工程编排器。协调 PRD→架构→详设→DB→编码→测试。四级强度自适配：🐛轻量/🟢标准/🟡增量/🔴全量，不依赖 Git。不适：单一技能/纯问答
---

## 执行规则

每个 Phase 调用 `task(subagent_type='{agent}')` → `bash .opencode/scripts/check-{phase}.sh`（失败 ≤3 次）→ `ai_memory_add_decision()`。首个产出 Phase 额外调 `ai_memory_save_summary(status=in_progress)`，后续调 `update_summary`。

**评审门禁（不可跳过）：** 每个文档产出阶段（PRD/架构/详设/DDL/测试用例）**必须**强制跟随对应的评审 Phase。编排器必须先执行产出阶段，再执行评审 Phase，评审通过后方可进入下一产出阶段。跳过任一评审 = 流程违规。

> 📐 遵循 `.opencode/rules/json-write-safety.md`

### 评审隔离铁则（杜绝自审自判）

创建 agent 结束后立即结束其 subagent 会话。**评审必须启动全新 subagent，入参只能包含被评审文档的文件路径 + 参考契约文档路径（架构/PRD），严禁传递任何创作意图、设计推理、已做步骤、作者信息。** 评审 agent 拿到的是"陌生人写的文档"，不知创作链路上的任何上下文。

### 记忆注入规则

Step 0 统一检索一次，结果写入 `_MEMORY_CACHE.md`。各 Phase 中编排器打包 prompt 时注入两类信息：

| 来源 | 内容 | 时机 |
|------|------|------|
| `_MEMORY_CACHE.md` | 本次运行前的历史经验（跨 pipeline 复用） | 所有 Phase |
| 编排器上下文 | 本次运行已完成的 Phase 的关键决策 | 首个产出 Phase 之后 |

`_MEMORY_CACHE.md` 在 Step 0 写入后不再刷新。**同轮运行中已记录的决策由编排器直接从上下文补入 prompt**，无需重新检索。

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
| 首个产出 Phase（按匹配模式的起点） | `ai_memory_save_summary(status=in_progress)` | 创建会话记录 |
| 后续每个产出 Phase 末尾 | `ai_memory_add_decision()` + `ai_memory_update_summary(status=in_progress)` | 追加新决策，更新摘要 |
| Step 7 | `ai_memory_update_summary(status=completed)` | 标记完成 |

不做 Phase 间上下文传递。

---
**Step 0：** `ai_memory_init_session()` → `ai_memory_search_summaries(query=项目名, limit=15)` → 结果写入 `_MEMORY_CACHE.md` → 扫描项目结构 + 分析任务影响域 → 自动匹配流程强度。

### 影响域分析（不依赖 Git）

编排器先检测项目技术栈（按 LC-001/LC-FE-001 规则，扫描语言特征文件和构建配置），再根据任务描述 + 静态文件扫描推断改动触及的层级。不依赖 `git diff`。

**技术栈检测依据：**

| 维度 | 检测方式 |
|------|---------|
| LC-001 后端语言 | 扫描 `pom.xml`/`build.gradle` → Java；`go.mod` → Go；`package.json`+`server/` → Node；`requirements.txt`/`pyproject.toml` → Python |
| LC-FE-001 前端框架 | 扫描 `package.json` 中 `vue`/`react`/`nuxt`/`next` 依赖 |
| 小程序端 | 检测 `miniprogram/`、`weapp/`、`uni-app` 等目录结构 |

**症状类型推断（任务描述关键词 → 可能根因层）：**

编排器扫描任务描述，按关键词推测症状在哪个层面、根因可能跨到哪层。**推断结果用于决定探测优先级，不直接锁定影响域。**

| 症状关键词 | 表面层 | 可能根因层 | 快速验证手段 |
|-----------|--------|-----------|-------------|
| "点击没反应/按钮无效/没反应" | 前端视图层 | 前端事件层 / **后端验证层** / 前端状态层 | 检查 console 错误 → API 直达测试 → 检查事件绑定/路由 |
| "创建失败/新建点不了" | 前端视图层 | **后端验证逻辑** / 前端错误处理 | `POST` API 直测 → 检查前端 catch 分支 |
| "保存后页面错/跳转不对" | 前端导航层 | 后端响应格式 / 前端状态覆盖 | API 响应检查 → navigate 调用追踪 |
| "列表不更新/数据不刷新" | 前端视图层 | API 响应结构 / 前端 loadFiles 调用时机 | API list 响应格式检查 → 调用链追踪 |
| "页面空白/加载中卡住" | 前端渲染层 | API 挂起 / 前端取数失败 | console 错误 / 网络面板 → API 健康检查 |
| "样式不对/布局错乱" | 前端视图层 | 仅前端 CSS/组件 | 仅前端扫描，不跨层 |
| 描述明确提及"后端/接口/API" | 显式后端 | 后端路由/业务/数据 | 直接定位后端 |

> **关键原则：** 前端症状 ≠ 前端根因。涉及创建/保存/删除/搜索等数据操作的前端症状，**必须排除后端验证层**才能定论为纯前端 Bug。

**影响域层级（语言无关）：**

| 层级 | 推断依据 | 文件模式（按检测到的栈映射） |
|------|---------|--------------------------|
| 前端视图层 | 任务提及页面/组件/UI 调整 | Vue: `views/*.vue, components/*.vue`；React: `pages/*.tsx, components/*.tsx` |
| 前端 API/数据层 | 任务提及接口调用/数据请求 | `api/*.{js,ts}`, `services/*.{js,ts}`, stores |
| 小程序端 | 任务提及小程序/weapp/uni-app | `miniprogram/`, `weapp/`, `uni-app/` 下对应文件 |
| 后端路由/控制器 | 任务提及新端点/接口 | Java: `*Controller.java`；Go: `handler/*.go`；Node: `routes/*.js`；Python: `main.py`, `controllers/*.py` |
| 后端业务/数据层 | 任务提及数据模型/业务规则 | Java: `*Service.java`, `*Repository.java`；Go: `service/*.go`；Node: `services/*.js`；Python: `models.py`, `database.py` |
| DDL/数据模型 | 任务提及字段/表/数据库 | `schema.sql`, 迁移文件, ORM 实体定义 |
| 跨模块/新模块 | 文件分布在多个目录 | 无固定模式，按实际涉及目录判断 |

### 流程强度匹配

编排器根据影响域自动选择强度，无需询问用户：

| 影响范围 | 强度 | 执行的 Phase | 典型场景 |
|----------|------|-------------|---------|
| 单文件/单层改动，无接口无数据变更 | 🐛 **轻量** | P5a → 自检 → P5b(快速审) | 改文案 / 修样式 / 修显式 Bug / 按钮交互修复 |
| 同模块前后端改动，无 DDL | 🟢 **标准** | P3a(简设) → P3b → P5a → P5b → P6c | 加列表筛选 / 新增查询参数 / 改业务逻辑不涉及 DB |
| 有 DDL 变更或新增子模块 | 🟡 **增量** | P3a → P3b → P4a → P4b → P5a → P5b → P6a→P6b→P6c | 新增模块 / 加表 / 加字段 |
| 全新项目/跨模块重构/中断恢复 | 🔴 **全量** | P1a→P1b→P1c → P2a→P2b → P3a→P3b → P4a→P4b → P5a→P5b → P6a→P6b→P6c | 从零开始 / 大的架构调整 |

**跨层探测规则（防前端症状 → 前端锁定陷阱）：**

按症状类型推断命中以下场景时，即使任务描述只提到前端，也必须跨层探测：

| 触发条件 | 探测动作 | 匹配升档 |
|---------|---------|---------|
| 涉及"创建/保存/删除/搜索"等数据操作 | 后端 API 直达测试（不依赖前端），检查响应格式和验证逻辑 | 不清除跨层根因前，🐛 不降级到纯前端范围 |
| 症状匹配"点击没反应"但前端事件绑定正常 | 后端验证层检查（路由、service 层逻辑时序） | 确认后端 Bug → 按实际影响域定强度 |
| 前端 `console` 无错误 | 后端 API 响应结构 vs 前端类型定义对比 | 至少 🟢 标准 |
| 跨层探测发现后端逻辑缺陷 | 按后端实际改动层选择强度 | 至少 🟢 标准 |

> 跨层探测的目的是**快速排除或确认后端根因**，避免在前端代码中空转。如果扫描发现缺少关键文档（如无 `doc/arch/` 但选择了 🟡 增量以上强度），自动降级到 🔴 全量补全缺失环节。

---

### 🐛 轻量模式

适用：单文件/单层改动，不涉及接口变更和数据模型。

```
定位(.opencode/rules/precise-location.md) → 读契约验证预期行为 →
P5a(静态定位+修复)          ← 读代码找 Bug，找到就修
  ├─ 找到 Bug → 修 → P5b
  └─ 静态无果 → P5a-r(运行时探测)
       ├─ 按症状类型选探测手段
       │  ├─ 数据操作相关(创建/保存/删除) → API 直达测试
       │  ├─ 点击/导航相关 → console + 路由 + 事件检查
       │  ├─ 渲染/空白相关 → 网络请求 + 错误边界检查
       │  └─ 样式相关 → 仅前端检查
       ├─ 找到 Bug → 修 → P5b
       └─ 仍无果 → 标记症状+已排除项 → 升级到用户澄清
P5b(快速代码评审) →
有 >>DOC_SYNC: 则更新契约 → 完成
```

- 跳过 PRD / 架构 / 详设 / DDL / 测试用例 全部 phases
- 代码评审可编排器自检（不强制起独立 reviewer agent），但涉及接口变更时必须起独立 reviewer
- 修复单文件可免定位，直接改
- **P5a(静态定位)**：遵循 `.opencode/rules/precise-location.md` 定位规则，读候选文件找 Bug。找到后修复，进入 P5b。
- **P5a-r(运行时探测)**：静态分析无法确定 Bug 时的兜底路径。**禁止在静态代码中反复空转**，按症状类型选择探测手段：
  - **数据操作异常**（创建/保存/删除/搜索）：直接 API 直达测试，跳过前端。用 `curl` 或 `httpie` 测试对应端点。如果 API 正常 → 问题在前端数据层/状态层；如果 API 异常 → 问题在后端。
  - **点击/导航异常**：先检查浏览器 console（JS 错误），再检查路由配置和 `navigate` 调用。如无前端错误 → 排查后端响应格式是否与前端类型定义一致。
  - **渲染异常/空白**：检查网络请求（API 是否 4xx/5xx），检查 React 错误边界，检查组件挂载条件。
  - **样式异常**：仅前端 CSS/组件检查，不跨层。
  - **通用兜底**：以上都无果 → 记下已排除的根因清单，向用户提供上下文并请求澄清。
- **P5b(快速代码评审)**：编排器自检修复代码（规范、安全风险、端对齐）。**如果修复涉及后端逻辑变更，必须检查对应前端错误处理分支**。
- 自检方式：确认改后输出符合预期，无异常。对于 P5a-r 路径，还需确认运行时探测中发现的证据链闭环（即修复后重测同一探测动作确认 Bug 消失）。

### 🟢 标准模式

适用：同模块前后端改动，无 DDL 变更，不需写完整详设但需确认设计。

```
P3a(简设确认) → P3b(评审简设) → P5a(编码) → P5b(代码评审+端对齐) → P6c(关联测试)
```

- P3a：编排器对话确认设计方案（不生成完整详设文档），输出 `doc/detailed/_design_note.md`
- P3b：起独立 `review-expert` 评审设计说明，参考 `doc/arch/`
- P5a/P5b/P6c：参照下方对应 Phase 描述执行
- 不经过 PRD / 架构 / DDL

### 🟡 增量模式

适用：有 DDL 变更或新增子模块。

```
P3a(详设) → P3b(详设评审+端对齐) → 
P4a(增量DDL) → P4b(DDL评审) → 
P5a(编码) → P5b(代码评审+端对齐) → 
P6a(用例) → P6b(用例评审) → P6c(执行)
```

- 不重建架构，复用现有 `doc/arch/`、`项目规则.md`
- P3a：只对新模块输出详设文档（追加到 `doc/detailed/`）
- P3b：评审新模块详设，同时检查是否与现有模块契约冲突
- P4a：只输出增量 DDL（`ALTER TABLE` 或新建表），追加到 `doc/db/`
- P4b：评审增量 DDL
- P5a：只实现新模块代码，**禁止修改现有模块代码**
- P5b：评审新模块代码 + 端对齐检查（接口是否与现有模块兼容）
- P6a/6b/6c：只覆盖新模块的测试用例（用例评审 + 执行）

### 🔴 全量模式

适用：全新项目 / 跨模块重构 / 中断恢复 — 严格按以下顺序执行，**每个评审 Phase 必须通过后才能进入下一产出 Phase**。

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
>
> **强度适配说明：** 上表为各 Phase 的标准形式。🐛 轻量模式中的 P5b 为"快速审"（编排器自检，不强制起独立 `code-reviewer` agent）；🟢 标准模式中的 P3a 为"简设确认"（对话确认，不调用 `task-decomposer`，不生成完整详设文档）。其他 Phase 按上表执行。

**Step 7：** `ai_memory_update_summary(status=completed)` 归档 → 删除 `_MEMORY_CACHE.md`、`_contract_check.md` 等临时文件 → 输出 ✅ **Pipeline 完成** + 产出物汇总。

## 熔断

subagent 启动失败重试 1 次 / 同一门禁连续失败 3 次暂停 / 缺必需输入停止 / 记忆 (ai_memory_*) 失败则记录后继续
