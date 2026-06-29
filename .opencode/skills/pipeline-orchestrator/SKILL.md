---
name: pipeline-orchestrator
description: 全流程软件工程编排器。协调 PRD→架构→详设→DB→编码→测试。五级强度自适配：🐛轻量/🟢-light轻标准/🟢标准/🟡增量/🔴全量。OODA 元认知驱动 | 自适应恢复 | 置信度策略 | 跨 Phase 回溯 | 运行后自进化。不适：单一技能/纯问答
---

## 执行规则

每个 Phase 以前后元认知（OODA）包裹调用 `task(subagent_type='{agent}')` → `bash .opencode/scripts/check-{phase}.sh`（失败按自适应恢复矩阵处理）→ `ai_memory_memory_add_decision()`（遵循"决策存取质量规则"的写决策模板和 taxonomy）。首个产出 Phase 额外调 `ai_memory_memory_save_summary(status=in_progress, tags=模块名)`，后续调 `ai_memory_memory_update_summary()`。

> ✨ **编排器思维模式：** 你是一个有自主思考能力的高级工程师，不是脚本执行器。每个动作前先理解上下文、评估风险、选择最佳方案。遇到不确定时主动探索，遇到失败时分析根因，遇到新信息时调整计划。输出决策时附上推理过程，让人能理解你的思路。

**评审门禁（不可跳过）：** 每个文档产出阶段（PRD/架构/详设/DDL/测试用例）**必须**强制跟随对应的评审 Phase。编排器必须先执行产出阶段，再执行评审 Phase，评审通过后方可进入下一产出阶段。跳过任一评审 = 流程违规。

> 📐 遵循 `.opencode/rules/json-write-safety.md`

### 元认知协议（OODA 决策循环）

编排器以 OODA 循环（观察→判断→决策→行动→反思）作为核心心智模型。**每个 Phase 执行前后各执行一次 OODA 检查**，确保每个动作都是经过情境感知和理性判断的，而非机械执行脚本。

**前置 OODA（Phase 执行前）：**
1. **Observe（观察）** — 确认：前序 Phase 产出的文件存在吗？`_MEMORY_CACHE.md` 中有足够的上下文吗？任务描述中的关键信息是否已落实？
2. **Orient（判断）** — 评估：当前 Phase 的输入是否完整？有什么风险？任务描述中是否有歧义需要解读？基于历史经验，这个 Phase 可能遇到什么坑？
3. **Decide（决策）** — 确定：选哪个 subagent？prompt 需要哪些精准参数？期望的产出标准是什么？如果失败，备选方案是什么？
4. **Act（行动）** — 执行 Phase + 门禁脚本

**后置 OODA（Phase 执行后）：**
1. **Observe（观察）** — 读取产出物，对比前置 OODA 的预期：结果符合吗？门禁通过了吗？
2. **Orient（判断）** — 分析偏差：如果有偏差，是理解问题、执行问题、还是预期错了？产出物中是否有意外的信息值得注意？
3. **Decide（决策）** — 决定下一步：继续按原计划走？需要调整后续 Phase？发现了需要回溯的问题（转跨 Phase 反馈）？
4. **Act（行动）** — Phase 终了协议 → 进入下一 Phase

> 前置 OODA 的推理过程写入 `_MEMORY_CACHE.md` [当前决策依据] 段，后置 OODA 的结论写入 [Phase 上下文] 段。这样每步决策都有据可查，失败时可追溯当时的判断逻辑。

**OODA 输出模板：** 每个 OODA 步骤按以下格式输出，确保一致性：
```
【OODA Phase {编号} 前置/后置】
Observe: {一句话描述当前观察到的状态}
Orient: {风险评估 / 不确定性 / 历史关联}
Decide: {方案选择 / 策略调整}
备选: {被否决的选项及原因}
Act: {将要执行的行动}
```

### 评审隔离铁则（杜绝自审自判）

创建 agent 结束后立即结束其 subagent 会话。**评审必须启动全新 subagent，入参只能包含被评审文档的文件路径 + 参考契约文档路径（架构/PRD），严禁传递任何创作意图、设计推理、已做步骤、作者信息。** 评审 agent 拿到的是"陌生人写的文档"，不知创作链路上的任何上下文。

> ⚠️ **调用方式：** 评审必须用 `task(subagent_type='review-expert')` 或 `task(subagent_type='code-reviewer')` 启动独立 subagent，**禁止在编排器自身上下文内自审自判**。

### 记忆注入规则

Step 0 统一检索一次，结果写入 `_MEMORY_CACHE.md`。编排器在每 Phase 开始时从 `_MEMORY_CACHE.md` 读取上下文（不中断流程时直接读取最新缓存）：

| 来源 | 内容 | 写入时机 |
|------|------|---------|
| `_MEMORY_CACHE.md` [历史经验] | 本次运行前的历史经验（跨 pipeline 复用） | Step 0（只写一次） |
| `_MEMORY_CACHE.md` [当前决策依据] | 前置 OODA 的推理过程（为什么选这个方案） | 每 Phase 前置 OODA 后写入 |
| `_MEMORY_CACHE.md` [Phase 上下文] | 当前 Phase 编号、产出物路径、关键决策 | 每 Phase 末尾重写 |
| `_MEMORY_CACHE.md` [跨 Phase 反馈] | 后置 Phase 发现的前置问题 | 后置 OODA 发现问题时追加 |
| `ai_memory` 记忆库 | 完整追溯，供读 `ai_memory_memory_get_summary` 使用 | 持久层，不写入缓存 |

格式：
```
【历史经验参考（来自项目记忆）】
以下是与本任务相关的历史记录：
{摘要列表}

【当前 Phase 上下文】
Phase: {编号} / {总 Phase 数}
进度: [■■■■■■□□□□] {百分比}（{已完成} / {共需}）
前序产出: {路径清单}
关键决策:
  - {决策1}
  - {决策2}
下一步: {下一 Phase 描述}
```

### 文档同步机制

code-developer 输出 `>>DOC_SYNC: {文件路径} → {改动说明}` 标示需同步的契约文档。**主 agent（编排器）负责按清单修改文档，code-developer 不直接触碰契约。** code-reviewer 评审时同时审查代码和更新后的文档，确保端对齐。

### 上下文管理与 Phase 断点协议

**问题：** 编排器会话随 Phase 递增而膨胀，后置 Phase 被前置 Phase 的历史噪声淹没（"交互轮次越多 → 工具能力越差"）。

**解决方案 — Phase 终了协议：** 每个 Phase 执行完毕后，编排器执行 2 步持久化后直接进入下一 Phase，**不中断流程**：

| 步骤 | 动作 | 说明 |
|------|------|------|
| ① 持久化 | `ai_memory_memory_add_decision()` + `ai_memory_memory_update_summary()` | 记录当前 Phase 的关键决策到记忆库 |
| ② 写缓存 | 重写 `_MEMORY_CACHE.md`，覆盖 [Phase 上下文] 段 | 只保留下一 Phase 需要的：编号、产出路径、3~5 条决策 |

> 不中断原则：不输出终止信号，不等待用户回复"继续"。①+② 执行完毕后直接进入下一 Phase。
>
> **Phase 转换标记：** 输出 `━━━ Phase {n} 完成 → 进入 Phase {n+1} ━━━` 作为视觉分隔。保持清晰但不中断。

**持久化节奏：**

| 时机 | 调用 | 说明 |
|------|------|------|
| 首个产出 Phase（按匹配模式的起点） | `ai_memory_memory_save_summary(session_id=..., task_title=..., summary_content=..., file_paths=..., project_name=..., status=in_progress)` | 创建会话记录（session_id 来自 init_session 返回值） |
| 后续每个 Phase 末尾 | Phase 终了协议 ①→② | 持久化 + 写缓存，不中断流程 |
| Step 7 | `ai_memory_memory_update_summary(status=completed)` | 标记完成 + 清理临时文件 |

**关键约束：** 由于不中断流程，上下文持续累积。若用户感觉编排器响应退化，可在对话中说"重启 pipeline"手动触发重置，编排器从 `_MEMORY_CACHE.md` + `ai_memory_memory_get_summary()` 恢复状态。

### 跨 Phase 反馈通道

**问题：** 单向流水线中，后置 Phase 发现前置产出有问题时只能停等人工。人类开发者会回溯修正。

**解决方案：** 在 `_MEMORY_CACHE.md` 中增设 [跨 Phase 反馈] 段，作为后置 → 前置的通信通道。

**分类评估：** 后置 Phase 的后置 OODA 发现前置问题时，按影响分三级：
| 严重度 | 含义 | 行为 |
|--------|------|------|
| 🔴 **阻断型** | 当前 Phase 的输入完全基于错误假设 | 立即停止，触发回溯修复 |
| 🟡 **影响型** | 当前 Phase 可继续，但最终产出需要修正 | 记录+继续，最终统一修复 |
| 🟢 **参考型** | 小问题，标记即可 | 仅记录，不改变流程 |

**写入格式：** 追加到 `_MEMORY_CACHE.md`：
```
【跨 Phase 反馈】
- 来源: Phase X（后置）
- 目标: Phase Y（前置）— {产出物路径}
- 问题: {具体问题描述}
- 严重: 🔴/🟡/🟢
- 建议修复: {如何修}
```

**回溯流程（仅 🔴 阻断型）：**
1. 执行 Phase 终了协议 ①②（持久化当前 Phase 进度，防止丢失工作）
2. 回退到目标 Phase，重做（入参携带反馈说明）
3. 重做完成后，重走受影响的中间 Phase
4. 回到当前 Phase 重新执行
5. 修复后 `add_decision(decision_type=refactor, description="[跨 Phase 修复] ...")` 记录模式

> 🟡 影响型的最终统一修复在全部 Phase 完成后、Step 7 之前执行。
> 🟢 参考型在 Step 7 自进化审查中汇总展示，不自动修复。

**Step 0：** `result = ai_memory_memory_init_session(project_name=项目名)` → 提取 result 中的 session_id 作为本次 pipeline 唯一标识 → **加载 `resources/retrieval-strategy.md`** → 按策略执行多角度搜索 → 产出 `_MEMORY_CACHE.md` [历史经验] 段 → 扫描项目结构 + 分析任务影响域 → 自动匹配流程强度。

**写决策：** 每次 `ai_memory_memory_add_decision()` 前先**加载 `resources/decision-quality.md`**，按模板和 taxonomy 填写。每个 `add_decision` 的 session_id 使用 Step 0 获取的 session_id，description 格式为 `[Phase X] 决策内容` 以便追溯。

*决策类型 taxonomy 速查（完整版在 resource 文件中）：`architecture | tech_choice | bug_fix | refactor | performance | security | api_design | process`*

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
| 同模块前后端改动，无DDL，无新增接口 | 🟢-light **轻标准** | P5a → P5b → P6c(关联测试+增量测试) | 加 parent_id 字段 / 改 UI 展示已存数据 / 纯前端样式+后端响应字段 |
| 同模块前后端改动，无 DDL | 🟢 **标准** | P3a(简设) → P3b → P5a → P5b → P6c | 加列表筛选 / 新增查询参数 / 改业务逻辑不涉及 DB |
| 有 DDL 变更或新增子模块 | 🟡 **增量** | P3a → P3b → P4a → P4b → P5a → P5b → P6a→P6b→P6c | 新增模块 / 加表 / 加字段 |
| 全新项目/跨模块重构/中断恢复 | 🔴 **全量** | P1a→P1b→P1c → P2a→P2b → P3a→P3b → P4a→P4b → P5a→P5b → P6a→P6b→P6c | 从零开始 / 大的架构调整 |

**🟢-light 与 🟢 的区分标准：**

| 判定条件 | 🟢-light | 🟢 |
|---------|----------|-----|
| 有无新增 API 端点 | 无（仅修改现有接口的参数/返回字段） | 可能有 |
| 有无数据模型变更 | 无 | 可能有 |
| 设计确定性 | 改动路径对开发者透明，无需设计确认 | 需设计确认 |
| 跳过 P3a/P3b | ✅ 跳过 | ❌ 必须执行 |

**跨层探测规则（防前端症状 → 前端锁定陷阱）：**

按症状类型推断命中以下场景时，即使任务描述只提到前端，也必须跨层探测：

| 触发条件 | 探测动作 | 匹配升档 |
|---------|---------|---------|
| 涉及"创建/保存/删除/搜索"等数据操作 | 后端 API 直达测试（不依赖前端），检查响应格式和验证逻辑 | 不清除跨层根因前，🐛 不降级到纯前端范围 |
| 症状匹配"点击没反应"但前端事件绑定正常 | 后端验证层检查（路由、service 层逻辑时序） | 确认后端 Bug → 按实际影响域定强度 |
| 前端 `console` 无错误 | 后端 API 响应结构 vs 前端类型定义对比 | 至少 🟢 标准 |
| 跨层探测发现后端逻辑缺陷 | 按后端实际改动层选择强度 | 至少 🟢 标准 |

> 跨层探测的目的是**快速排除或确认后端根因**，避免在前端代码中空转。如果扫描发现缺少关键文档（如无 `doc/arch/` 但选择了 🟡 增量以上强度），自动降级到 🔴 全量补全缺失环节。

### 置信度驱动的执行策略

编排器在 Step 0 的前置 OODA **Orient** 阶段，对当前上下文标注整体置信度。置信度影响后续 Phase 的执行策略，与流程强度正交叠加：

| 置信度 | 特征信号 | 策略调整 |
|--------|---------|---------|
| 🟢 **高** | 技术栈熟悉、需求明确、有 ≥2 条相关历史经验、文件结构清晰 | 标准流程，最小化中间验证 |
| 🟡 **中** | 部分技术栈不熟悉、需求有少量歧义、历史经验不足 2 条 | 增加中间验证步骤；产出后编排器自检再提交评审 |
| 🔴 **低** | 新技术栈、需求模糊、无历史参考、缺少关键文档 | 先跑探针（Spike）确认基础假设 → 再走标准流程 |

**探针（Spike）执行**（仅 🔴 低置信度时触发）：
- 在首个产出 Phase 前插入 Spike 子过程：创建极小原型验证关键假设（如"这个框架的 CRUD 怎么写""第三方库的 API 签名是什么"）
- Spike 产出 `_spike_note.md`，不经过评审
- Spike 解决关键不确定性后，置信度提升到 🟡 再继续

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

### 🟢-light 轻标准模式

适用：同模块前后端改动，无 DDL 变更，无新增 API 端点，仅修改现有接口参数/返回字段。

```
P5a(编码) → P5b(代码评审+端对齐) → P6c(关联测试+增量测试)
```

- 跳过 P3a/P3b（设计确定性高，无需设计确认）
- P5a/P5b/P6c：参照下方对应 Phase 描述执行
- P6c 必须为新增逻辑路径生成测试用例并执行（见下方 P6c 说明）

### 🟢 标准模式

适用：同模块前后端改动，无 DDL 变更，不需写完整详设但需确认设计。

```
P3a(简设) → P3b(评审简设) → P5a(编码) → P5b(代码评审+端对齐) → P6c(关联测试)
```

- P3a：编排器自主输出设计方案（不生成完整详设文档），输出 `doc/detailed/_design_note.md`
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

**Phase 6c（关联测试 + 增量测试）：** 所有含代码改动的模式（🐛轻量/🟢-light/🟢/🟡/🔴）必须执行 P6c。按模式分级：

| 模式 | P6c 要求 | 说明 |
|------|---------|------|
| 🐛 轻量 | 仅跑存量测试 | 改动极小，回归验证即可 |
| 🟢-light / 🟢 标准 | 存量测试 + **为新增/改动的逻辑路径生成测试用例并执行** | 覆盖新增逻辑，不要求全模块覆盖 |
| 🟡 增量 / 🔴 全量 | 按 P6a→P6b→P6c 走完整测试流程 | 全模块测试覆盖 |

> 🟢-light/🟢 模式下，编排器在 P5b 完成后，扫描改动文件的 diff 范围，为新增/修改的每条逻辑路径生成测试代码（直接使用 `task(subagent_type='tester')` 或手写），执行并确认通过。存量测试也必须一并运行。

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

> 产出 Phase 结束后结束 subagent。门禁失败按自适应恢复矩阵处理。每 Phase 末尾执行 Phase 终了协议（持久化 + 写缓存），不中断流程，直接进入下一 Phase。
>
> **强度适配说明：** 上表为各 Phase 的标准形式。🐛 轻量模式中的 P5b 为"快速审"（编排器自检，不强制起独立 `code-reviewer` agent）；🟢-light 模式跳过 P3a/P3b，P6c 含增量测试；🟢 标准模式中的 P3a 为"简设"（编排器自主输出设计方案，不调用 `task-decomposer`，不生成完整详设文档）。其他 Phase 按上表执行。

**Step 7（最终清理 + 自进化）：** `ai_memory_memory_update_summary(status=completed)` 归档 → **自进化审查**（见下文）→ 删除 `_MEMORY_CACHE.md`、`_contract_check.md` 等临时文件 → 输出 ✅ **Pipeline 完成** + 产出物汇总。

> 注意：Step 7 是全局最终清理。每个 Phase 的局部清理由 Phase 终了协议 ②（写缓存，覆盖旧内容）+ ①（持久化）完成。

### 运行后自进化审查

Pipeline 完成后，Step 7 自动执行轻量级自我审查，提取可复用经验：

1. **扫描决策** — 读取本次运行的全部 `add_decision` 记录（`ai_memory_memory_related_decisions(limit=50)`）
2. **识别模式** — 查找重复出现的决策类型、失败模式、跨 Phase 修复
3. **产出建议** — 输出自进化建议段：
   ```
   【自进化建议】
   本次运行观察:
   - 重复模式: {模式描述}
   - 失败汇总: {Phase X 遇到 Y 类型失败 Z 次}
   - 可复用建议: {具体改进建议，说明改进哪个文件/规则}
   ```
4. **展示** — 将自进化建议展示给用户，供决定是否落地

> 自进化审查不自动修改文件，只做观察和建议。落地由人工或 self-evolve 技能处理。

## 自适应恢复矩阵

当 Phase 失败时，编排器根据失败类型选择恢复策略，而非简单重试：

| 失败类型 | 特征 | 恢复策略 |
|---------|------|---------|
| 🅰 **subagent 崩溃** | task 返回错误，无产出文件 | ① 重试（更短更精确的 prompt，去掉不必要上下文）→ ② 拆分为更小粒度重试 → ③ 记录后标记跳过 |
| 🅱 **评审未通过** | review 返回 P0/P1 问题清单 | ① 按评审清单定向修复（优先 P0/P1，P2 自然修复不限制，但禁止新增未要求功能）→ ② 检查问题是否源于更早 Phase 的假设错误 → ③ 是则触发跨 Phase 反馈 → ④ 修复后重审（可指定仅重审改动行，加速迭代） |
| 🅲 **产出质量差** | 自行评估产出不满足需求（门禁虽过但明显有改进空间） | ① 重新理解需求（读回原始任务描述）→ ② 调整 prompt 增加具体约束 → ③ 重新执行 |
| 🅳 **死循环** | 连续 2 次修复后评审发现同样性质的问题 | ① 暂停当前路径 → ② 搜索记忆库找类似场景和解决方案 → ③ 如果记忆中有有效模式，切换策略 → ④ 仍无效则暂停，向用户报告上下文 |

**补充规则：**
- **计数独立**：每种失败类型各自计数，不混用
- **跨 Phase 重置**：进入新 Phase 后历史失败计数清零
- **用户可介入**：暂停时输出上下文 + 已尝试方案，用户可指令"继续重试"或"跳过"
- **修复后重审范围**：默认全量重审。如果改动范围明确（仅几行），可附加 `description="仅重审改动行"` 加速
