# 端锁定规则 (ENDPOINT LOCK RULES)

**适用范围：增量需求 / Bug 修复。全量新建项目请走 pipeline-orchestrator 流程。**

## ⚠️ 黄金法则
**发现端不对齐时，必须先读契约文档，禁止擅自修改任何端代码！**

## 端稳定分级
| 端 | 级别 | 修改权限 |
|----|------|---------|
| 对外API·签名变更 | 🔴 FROZEN | 禁止修改，需人工审批 |
| 对外API·新增（v2+版本化） | 🟠 STABLE | 需评估后向兼容 |
| 数据库Schema·增表/列 | 🟡 FLEXIBLE | 可修改，需同步文档 |
| 数据库Schema·改/删列 | 🔴 FROZEN | 禁止修改，需人工审批 |
| 第三方集成接口 | 🟠 STABLE | 需充分评估影响 |
| 后端内部接口 | 🟡 FLEXIBLE | 可修改，需同步文档 |
| 前端适配层 | 🟢 MUTABLE | 可自由修改 |

## 不对齐处理流程
```
STOP  →  READ  →  IDENTIFY  →  REPORT  →  WAIT
 ①       ②          ③           ④          ⑤
```
1. STOP — 停止修改
2. READ — 读 doc/detailed/ + OpenAPI/proto/migration 等契约文档
3. IDENTIFY — 确认违约的端及具体问题
4. REPORT — 报告：哪端 + 什么问题
5. WAIT — 等待决策；**同时准备影响分析报告（波及范围、建议迁移方案）**

## 契约查找优先级
doc/detailed/ → OpenAPI spec → migration 文件 → proto 定义
