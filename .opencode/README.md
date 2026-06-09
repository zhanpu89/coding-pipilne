# my-skills

OpenCode AI 技能集合 —— 10 个指导 AI 代理完成软件工程各阶段的指令集。

> 完整文档和安装指南请见项目根目录 [README.md](../README.md)

## 技能一览

| 技能 | 角色 | 工具名 |
|------|------|--------|
| **prd-writer** | 需求分析 → PRD | `call_prd_writer` |
| **review-expert** | 文档/用例评审 | `call_review_expert` |
| **system-architect** | 架构设计 + 技术栈 | `call_system_architect` |
| **task-decomposer** | 详设拆分 + 项目规则 | `call_task_decomposer` |
| **code-developer** | 编码实现 | `call_code_developer` |
| **code-reviewer** | 代码评审 | `call_code_reviewer` |
| **tester** | 测试用例 + 测试代码 | `call_tester` |
| **dba-designer** | 数据库 DDL 设计 | `call_dba_designer` |
| **ai-memory** | AI 记忆持久化（桥梁） | `call_ai_memory` |
| **pipeline-orchestrator** | 全流程编排器 | `call_pipeline_orchestrator` |

## 目录结构

```
skills/{skill}/
├── SKILL.md          # 技能指令（YAML + 工作流）
├── resources/        # 参考文档（术语表、检查清单、模式参考）
└── templates/        # 输出模板
```

## 插件

`.opencode/plugins/skill-agent.ts` 插件将 10 个技能暴露为自定义工具，加载方式均为"仅 SKILL.md，按需 read"。
