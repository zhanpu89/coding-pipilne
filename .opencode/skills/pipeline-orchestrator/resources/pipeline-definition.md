# Pipeline 全流程定义

> 完整阶段定义见 `.opencode/skills/pipeline-orchestrator/SKILL.md`。本文件仅包含流程图。

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
Phase 4 ──→ 数据库设计（详设后、编码前）
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

## 产出物

| Phase | 产出物 | 路径 |
|-------|--------|------|
| 1 | PRD 文档 | `doc/prd/{项目}_PRD.md` |
| 2 | SAD + tech-stack.json | `doc/arch/` |
| 3 | 详细设计 + 项目规则 | `doc/detailed/` |
| 4 | DDL 脚本 | `doc/db/` |
| 5 | 实现代码 | `src/` |
| 6 | 测试用例 + 测试代码 + 报告 | `doc/tester/` + `src/test/` |
| 评审 | 评审报告 | `doc/review/` |
| 进度 | Pipeline 进度 | `doc/pipeline/_PROGRESS.md` |
