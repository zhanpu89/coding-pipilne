# Pipeline 全流程定义

> 完整编排指令见 `.opencode/skills/pipeline-orchestrator/SKILL.md`。

## 流程概览

```
╔══════════════════════════════════════════════╗
║         ai-memory（贯穿全流程）               ║
╚══════════════════════════════════════════════╝
         │
         ▼
Phase 1 ──→ 1b PRD 生成 ──→ 1c 评审 ──❌阻断(≤3)──→ 重做
         │      ✅
         ▼
Phase 2 ──→ 2a 架构设计 ──→ 2b 评审 ──❌阻断(≤3)──→ 重做
         │      ✅
         ▼
Phase 3 ──→ 3a 详设拆分 ──→ 3b 评审 ──❌阻断(≤3)──→ 重做
         │      ✅
         ▼
Phase 4 ──→ 4a DDL 生成 ──→ 验证(check-db.sh)
         │      ✅
         ▼
Phase 5 ──→ 5a 编码实现 ──→ 5b 评审(code-reviewer)
         │      ✅
         ▼
Phase 6 ──→ 6a 用例设计 ──→ 6b 评审 ──❌阻断(≤3)──→ 6c 测试代码
                           ✅
                           └──→ ✅ Pipeline 完成
```

## 产出物

| Phase | 产出物 | 路径 |
|-------|--------|------|
| 1 | PRD 文档 | `doc/prd/` |
| 2 | SAD + tech-stack.json | `doc/arch/` |
| 3 | 详细设计 + 项目规则 | `doc/detailed/` |
| 4 | DDL 脚本 | `doc/db/` |
| 5 | 实现代码 | `src/` |
| 6 | 测试用例 + 测试代码 + 报告 | `doc/tester/` + `src/test/` |
| — | 评审报告 | `doc/review/` |
| — | Pipeline 进度 | `doc/pipeline/_PROGRESS.md` |
