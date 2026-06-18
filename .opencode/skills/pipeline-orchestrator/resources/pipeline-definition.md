# Pipeline 全流程定义

> 完整编排指令见 `SKILL.md`。

## 标准流程（严格顺序）

```
Phase 1a(需求访谈) → Phase 1b(PRD撰写) → Phase 1c(PRD评审)
  → Phase 2a(架构设计) → Phase 2b(架构评审)
  → Phase 3a(详细设计) → Phase 3b(详设评审)
  → Phase 4a(DDL设计) → Phase 4b(DDL评审)
  → Phase 5a(编码实现) → Phase 5b(代码评审)
  → Phase 6a(测试用例) → Phase 6b(用例评审) → Phase 6c(测试执行)
  → Step 7(归档)
```

## 门禁规则

| Phase | 产出物 | 门禁脚本 | 退回到 |
|-------|--------|---------|--------|
| 1b | doc/prd/ | check-prd.sh | — |
| 1c | doc/review/ | check-review.sh | Phase 1b |
| 2a | doc/arch/ | check-arch.sh | — |
| 2b | doc/review/ | check-review.sh | Phase 2a |
| 3a | doc/detailed/ | check-detailed.sh | — |
| 3b | doc/review/ | check-review.sh | Phase 3a |
| 4a | doc/db/ | check-db.sh | — |
| 4b | doc/review/ | check-review.sh | Phase 4a |
| 5a | src/ | check-code.sh | — |
| 6a | doc/tester/ | check-testcase.sh | — |
| 6b | doc/review/ | check-review.sh | Phase 6a |
| 6c | src/test/ | check-test.sh | — |

- 每个产出后紧跟评审门禁，**跳过评审 = 流程违规**
- 评审门禁失败 → 退回上一产出阶段修改（最多 3 轮）
- 产出物路径: doc/prd/ → doc/arch/ → doc/detailed/ → doc/db/ + src/ → doc/tester/ + src/test/
- 评审报告: doc/review/
