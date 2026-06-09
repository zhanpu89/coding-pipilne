---
name: code-reviewer
description: |
  代码质量门禁。评审 src/ 和 frontend/ 代码，输出结构化评审报告和阻断性结论。
  适用场景：
  - 代码质量评审（安全漏洞、性能反模式、规范检查、可维护性）
  - 全栈模式下审查前后端 OpenAPI 契约一致性
  - bug-fixer 修复后自动触发多轮评审
  不适用场景（勿触发）：
  - 生成代码（code-developer）
  - 评审设计/需求文档（review-expert）
  - 纯技术问答
---

# Code Reviewer

对代码进行全面评审，输出报告和质量门禁结论。纯后端模式（五维度）或全栈模式（七维度）。

## 懒加载原则（Lazy Loading）

1. **语言特化项按 LC-001 加载**：`lang-ext.md` 包含 4 种语言检查项，只在对应 LC-001 时加载对应 `##` 节
2. **前端检查仅在全栈模式加载**：`frontend-review-checklist.md` 仅在维度 6 前加载
3. **用完即释放**：各文件在其对应阶段完成后释放

## 合并原则（Merge, don't split）

1. **语言特化检查项合并于 `lang-ext.md`**：4 种语言的特化项合并为一个文件，按 `##` 节跳转对应语言
2. **前后端检查清单独立**：后端（`review-checklist.md`）与前端（`frontend-review-checklist.md`）生命周期不同（后者仅全栈模式），保持独立
3. **报告模板保持合并**：`report-template.md` 含两种模式模板，按模式跳转对应节

## 参考文件（按需加载）

| 文件 | 加载时机 | 释放时机 | 行数 |
|------|---------|---------|------|
| `resources/glossary.md` | 首次触发——术语、等级定义、评审维度 | *全流程结束后* | 201 |
| `resources/review-checklist.md` | Step 1 前——后端维度1~5检查清单 | *Step 1 完成后* | 247 |
| `resources/lang-ext.md` | Step 1 前——语言特化检查项（按 LC-001 跳转对应 `##` 节） | *Step 1 完成后* | 170 |
| `resources/frontend-review-checklist.md` | 全栈模式维度6前——前端六维度检查清单 | *Step 1 完成后* | 330 |
| `templates/report-template.md` | Step 2 前——评审报告模板（按模式跳转对应节） | *报告生成完成后* | 407 |
| `doc/detailed/项目规则.md` | Step 0——读取 LC/ER 约束作为评审依据 | *Step 1 开始前* | - |

## 工作流

### Step 0：就绪检查与模式感知
读取 `doc/detailed/项目规则.md` 提取 LC / 项目专属 ER 约束。加载 `resources/glossary.md`。扫描 `src/` 和 `frontend/`。确认范围（纯后端/全栈）。

### Step 0.5：增量评审识别
检测多轮评审（`doc/review/` 已有本模块报告）→ 优先核查上轮问题修复情况。

### Step 1：评审执行

加载 `resources/review-checklist.md`（维度1~5通用层）+ 按 LC-001 加载 `resources/lang-ext.md` 对应 `##` 节。

**维度0：前后端契约一致性（全栈模式，最高优先级）**
以详设第3节 OpenAPI 为唯一来源：
- 0.A 后端覆盖率：每个接口在后端有对应实现 → 缺失 = P0
- 0.B 前端一致性：types/ 字段名/类型、api/ URL/方法、views/stores 直接引用字段 → P0 字段名双重不一致
- 0.C 小程序一致性：响应字段逐字段核对、枚举完整性 → P0 字段名不一致/必填字段缺失
- 0.D 端间字段一致性（三端架构）：前端 vs 小程序命名一致、枚举覆盖一致 → P0 命名裂变

**维度1~5（后端）：** 编码规范 / 业务逻辑一致性 / 安全漏洞 / 性能反模式 / 可维护性

**维度6（全栈模式）：** 加载 `resources/frontend-review-checklist.md`，执行前端专项审查（Vue3/React）

问题分级：P0（安全/数据丢失/契约断裂）→ 阻断；P1（性能/规则违反）→ 建议阻断；P2（可维护性）→ 建议

> 释放提示：Step 1 完成后检查清单和语言特化项不再需要，可释放。

### Step 1.5：问题分级与汇总
评审结论：✅ 通过（无P0，P1≤2）| ⚠️ 有条件通过（无P0，P1>2）| ❌ 不通过（存在P0）

### Step 2：评审报告生成
加载 `templates/report-template.md`，按评审模式跳转对应节。输出 `doc/review/{模块名}_代码评审报告{_RN}.md`。多轮含"上轮问题修复情况"节。

> 释放提示：报告生成完成后 `report-template.md` 可释放。

**保存前检查**：头部含编号/版本/状态，全栈模式含维度0和维度6节，多轮含回顾节

## 关键原则
1. **契约优先于实现** — 维度0最先执行
2. **代码是事实来源** — 代码没有的逻辑就是没有实现
3. **安全问题零容忍** — SQL注入/越权/P0
4. **对照设计文档评审** — 不凭经验判断
5. **每个 P0/P1 附带修复方案**
