---
name: task-decomposer
description: |
  软件模块详细设计。将 SAD 拆解为模块级详设文档（含业务规则、OpenAPI、伪代码、DDL）。
  适用场景：
  - 有 SAD，需生成模块详设
  - 生成编码规范、项目规则文档
  - 需要精确接口契约和测试用例设计
  不适用场景（勿触发）：
  - 纯技术问答
  - 无架构文档的情况下直接写代码
  - 已有详设，只需编码（code-developer）
---

# Task Decomposer

将 SAD 拆解为完整详设文档体系。输出：`doc/detailed/`。

## 懒加载原则（Lazy Loading）

1. **必须按需加载**：未到使用阶段的文件不得提前加载
2. **用完即释放**：某文件不再需要后，不再作为后续上下文保留
3. **阶段文件**：design-guides 按阶段拆分，各在对应阶段加载

## 合并原则（Merge, don't split）

1. **端模板合并为一个文件**：前端/小程序模板合并为 `frontend-template.md`，编码/项目规则合并为 `rules-template.md`
2. **按 `##` 节跳转**：合并文件内用 `##` 节区分不同端，加载后跳转到对应节即可

## 参考文件（按需加载）

| 文件 | 加载时机 | 释放时机 | 行数 |
|------|---------|---------|------|
| `resources/glossary.md` | *首次触发时*——核心术语、LC规则体系 | *全部分段生成结束后* | 146 |
| `templates/progress-format.md` | Step 1 创建进度文档前 | *进度文档创建后* | 56 |
| `resources/layer-model.md` | Step 2 依赖排序时 | *Step 3 生成后端详设前* | 84 |
| `resources/chain-derivation.md` | Step 2.5 功能链推导时 | *Step 3 生成后端详设前* | 140 |
| `templates/backend-detailed.md` | Step 3 生成后端详设前 | *全部分段生成结束后* | 393 |
| `templates/frontend-template.md` | Step 4 前——前端/小程序模板（按端跳转对应 `##` 节） | *全部分段生成结束后* | 513 |
| `resources/frontend-guide.md` | Step 4 前——前端/小程序设计指南（按端跳转对应 `##` 节） | *全部分段生成结束后* | 259 |
| `templates/rules-template.md` | Step 5 前——编码/项目规则模板（按需跳转 `##` 节） | *生成完成后* | 303 |
| `resources/lang-engineering.md` | Step 5 生成项目规则时——语言工程规则（按 LC-001 跳转对应节） | *项目规则生成完成后* | 152 |

## 工作流

### Step 0：启动检测
恢复模式（检查 `_PROGRESS.md` 有 ⏳ 条目）→ 端类型探测（SAD 概览 → PRD → 目录 → 询问用户）→ 确定执行路径

端类型→执行：纯后端 0→1→2→2.5→3→5→6；+前端则加 Step 4（前端）；+小程序则加 Step 4（小程序）

### Step 1：架构分析 + 创建进度文档
解析 SAD，识别模块/API/数据模型。**含前端/小程序时必须执行接口需求正向比对**：提取需求侧期望接口清单 vs 后端已规划接口，发现缺口记为「规则零」。
加载 `templates/progress-format.md`，立即写入 `_PROGRESS.md`——**这是第一个文件写入，完成后才允许 Step 2**。

> 释放提示：`progress-format.md` 仅在创建进度文档时需要，创建后释放。

### Step 2：依赖排序
加载 `resources/layer-model.md`。按 LC-001 分配层次（Layer 0-4），建立构建顺序。

### Step 2.5：功能链完整性推导（不可跳过）
加载 `resources/chain-derivation.md`。**7条规则全部扫描，逐模块执行**：

| 规则 | 内容 | 不通过动作 |
|------|------|-----------|
| **规则零** | 需求驱动缺口（Step 1 比对结果） | 补充到接口清单 |
| **规则一** | PUT/DELETE/PATCH 是否有对应 GET | 补充缺失接口 |
| **规则二** | 状态机完整性（枚举+校验+逆向路径） | 补充 |
| **规则三** | 跨模块依赖（精确到接口路径） | 逐条列出 |
| **规则四** | 数据生命周期（解绑/恢复/查询） | 补充 |
| **规则五** | 异步流程（任务状态查询+死信处理） | 补充 |
| **规则六** | 权限与数据隔离（多租户/归属） | 标注到 Step 3 验证 |

输出推导报告 → 用户确认 → 锁定接口清单。**用户确认前禁止进入 Step 3**。

> 释放提示：Step 2.5 结束时 `layer-model.md` 和 `chain-derivation.md` 不再需要，可释放。

### Step 3：后端详设生成（逐文档）
加载 `templates/backend-detailed.md`。每份文档包含13节：功能描述/业务规则/OpenAPI 3.0 YAML/伪代码（含编码约束标记）/状态机与状态流转/算法/DDL/外部接口/内部接口/性能要求（含缓存失效规则）/安全要求/测试要点（含异常场景覆盖）/依赖关系。
**硬性规则**：第3节须为 `yaml` 代码块，含 requestBody/responses/错误码。禁止 Markdown 表格替代。
**单文档节奏**：一次只生成一份，写入并更新 `_PROGRESS.md` 后等待用户「继续」。

### Step 4：前端 / 小程序详设
加载 `templates/frontend-template.md` + `resources/frontend-guide.md`，按端跳转对应 `##` 节。
- Web 前端（LC-FE-001 有）：跳转 `## Web 前端详细设计文档模板` + `## Web 前端设计指南`
- 小程序（LC-MP-001 有）：跳转 `## 微信小程序详细设计文档模板` + `## 微信小程序设计指南`

**前置五步**：收集补充接口 → 读取后端详设第3节 OpenAPI YAML → 合并去重 → 填写 API 映射表格 → **字段级双向核对**（5A 正向：前端字段⊆后端；5B 反向：后端枚举/必填字段前端全部纳入）。不一致则停止报告。
**三端端间对齐**（三端架构时小程序写入前）：比对前端与小程序字段名一致性，不一致则停止报告。
**单文档节奏**同 Step 3。

### Step 5：编码规范 + 项目规则生成
加载 `templates/rules-template.md` + `resources/lang-engineering.md`，按需跳转对应 `##` 节。
**编码规范**：跳转 `## 编码规范模板`。保存为 `doc/detailed/编码规范.md`。
**项目规则**：跳转 `## 项目规则文档模板`。按 LC-001 跳转 `resources/lang-engineering.md` 对应语言节填充 ER 节。
填写顺序：LC节 → LC-FE节 → LC-MP节 → BR节 → ER节 → CC节。
**写入前自检**：LC 无占位符、BR 有来源标注且无通用废话、ER 每一条均为项目专属、全文无 `{例:`。

### Step 6：输出汇总
Mermaid 依赖图 + 文档表格（层次+预估工时）+ 定位说明

## 每份文档保存前强制检查

- [ ] `_PROGRESS.md` 已存在
- [ ] 头部含编号/版本(v1.0.0)/状态(🟡 草稿)/日期/作者
- [ ] 最后一节 `## 变更记录`
- [ ] 第3节为 `yaml` 代码块，含 requestBody/responses/错误码
- [ ] Step 2.5 补充接口已全部出现在第1节和第3节
- [ ] (前端/小程序)第3节已完成 5A/5B 核对
- [ ] (小程序,三端)端间对齐已核查
- [ ] 写入后更新 `_PROGRESS.md`，用户确认前未写入下一份

## 全局熔断规则

- 🔴 `_PROGRESS.md` 未创建就开始生成文档
- 🔴 Step 2.5 用户确认前进入 Step 3
- 🔴 `tech-stack.json` 不存在且架构文档无技术栈信息
- 🔴 文档写入失败
- 🔴 **连续生成多份文档而未等待用户"继续"确认**（非批量授权模式）
