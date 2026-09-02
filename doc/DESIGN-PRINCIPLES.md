# coding-pipeline 分层设计原则（北极星）

> 本文件是工具架构改造的契约与北极星。所有后续改动（rules、opencode.json、install.sh、skills resources）都以此为准。

## 1. 一句话定位

coding-pipeline 是一个**通用且专业**的软件工程编排器。它被安装到项目后，整套 `.opencode/` 即成为该项目的资产；项目在此基础上改写规则、沉淀规范与架构，把工具适配成**项目独有的、专业的开发工具**。

## 2. 两种「态」：分发态 vs 资产态

本工具只有一份，但分两个阶段理解：

### 分发态（源仓库 / 安装包）—— 通用且专业
- **9 个 skills**：角色职责、流程编排、门禁 = 跨项目成立的通用软件工程方法论，不绑定任何具体技术栈
- **scripts**：通用门禁 / 审计 / 日志
- **rules（通用方法论库）**：code-discipline / arch-thinking / precise-location / endpoint-lock / doc-alignment / json-write-safety = 跨项目成立的专家标准，开箱即用（含 project-mirror，共 7 条）

### 资产态（安装进项目后）—— 项目独有，自成资产
- 安装动作 = **把「分发态」复制进项目目录**，从此 `.opencode/` 整体归属于该项目
- 项目可自由改写其中任何内容（rules、skills 资源、脚本），沉淀团队 / 项目专属规范
- 项目用 skills 产出的 `doc/prd`、`doc/arch`、`doc/detailed`、`doc/tester` 也是项目资产，由项目持续优化
- 工具即「项目专业的开发人员」

**关键点：不区分「工具规则目录」与「项目规则目录」。** 安装后没有「外部强加的规则」，因为规则已经属于项目自己。项目改它，就是在优化自己的资产。

## 3. 边界（不可逾越）

- 工具的**分发态**保持项目无关：rules / resources 只写通用方法论，不预设任何项目特有技术栈、团队约定、业务词汇
- 项目的**资产态**由项目自己决定：要不要改规则、改成什么、沉淀哪些规范与架构，全是项目的事
- 工具不替项目写专属规则，也不在运行时覆盖项目已改写的文件

## 4. 适配流程（install → adapt → evolve）

1. **install**：复制通用工具（skills / scripts / rules）到项目，整套成为项目资产
2. **adapt**：安装脚本自动运行 `project-init.sh` 探测项目语言/框架，生成 `.opencode/project/`（manifest.json + profile.md + conventions.md）供工具消费；项目在此基础上编辑 `.opencode/rules/` 与 skills 资源，把通用标准改写为项目专属；如需开关某条规则，改本项目 `opencode.json` 的 `instructions` 即可
3. **evolve**：项目持续用工具产出并优化 `doc/` 资产与规则，工具随之越来越「懂」这个项目

## 5. 对当前实现的改造清单

- [x] 本设计原则文档（北极星，按 B 方案：保留 6 条规则为默认、不分离目录）
- [x] rules 标注为「通用方法论 · 项目资产」（每个 rule 文件头部）
- [x] `install.sh`：安装完成提示「整套 .opencode/ 即项目资产，可直接改写」
- [x] `opencode.json`：B 方案下 6 条规则保持默认强制（开箱专业）；项目可在自己副本中增删
- [x] skills resources：复核蒸馏产出为项目无关通用方法论（已修正 overlays.md 项目特化措辞）

## 6. 判定标准（改完怎么验证）

- 分发态零项目特化内容；安装后项目对 `.opencode/` 拥有完全所有权，无被外部强制覆盖
- 同一工具装到 A、B 两个不同项目，分发物一致；差异只在各项目自己演化的资产
- 项目可独立新增 / 改写规则与 `doc/` 资产，且工具尊重这些改动

## 7. rules 层级参考（供项目决策是否覆盖）

| rule | 层级 | 项目建议 |
|------|------|----------|
| json-write-safety | 工具机制级 | 建议保留（关乎写文件容错，与项目无关） |
| code-discipline | 方法论级 | 可覆盖为团队编码纪律 |
| arch-thinking | 方法论级 | 可覆盖为项目架构核查清单 |
| precise-location | 方法论级 | 可覆盖为项目模块定位约定 |
| endpoint-lock | 方法论级 | 可覆盖为项目契约锁定级别 |
| doc-alignment | 方法论级 | 可覆盖为项目文档同步流程 |
| project-mirror | 机制级 | 建议保留（项目镜像消费/回写机制，与 project-init.sh 配合） |
