---
name: self-evolve
description: |
  半自动工具自我进化。读取调用历史日志，让 AI 自我分析
  并输出 Evolution Proposal（EP），由用户确认后改进工具。
  适用场景：
  - 定期审视工具效果，发现模式缺陷
  - 根据历史失败/用户纠偏，自动建议优化
  不适用场景（勿触发）：
  - 实时编码（code-developer）
  - 代码评审（code-reviewer）
  - 纯技术问答
---
## 工作流

**Step 1：** 读 `~/.opencode/history/*.jsonl`，按 skill 分组。关注失败重复模式、task 模糊、问题集中的技能。

**Step 2：** 对照各 subagent 的 SKILL.md 和 opencode.json 权限配置分析：失败是否指向缺失前置检查、调用是否偏离声明场景、用户是否反复修正同一类输出、是否反复触发 endpoint-lock/precise-location 规则

**Step 3：** 输出 EP：

```
╔════════════════════════════════════════════╗
║ 🔧 进化提案 #[N]      针对: {tool/skill}   ║
║ 发现: {模式}  建议: {改什么地方/怎么改}      ║
║ 影响: {范围}                                 ║
║ 目标:  {[opencode.json | SKILL.md | scripts | rules]}
║ [Y] 应用  [N] 忽略  [E] 编辑后应用         ║
╚════════════════════════════════════════════╝
```

用户确认 Y 后：
- 目标为 `opencode.json` / AGENTS.md → 编排器统一执行更新
- 目标为 `SKILL.md` → 直接修改
- 目标为 scripts / rules → 修改后重新运行 `check-opencode.sh` 验证

**Step 4：** 无发现则输出"当前所有工具运行正常，无需进化。"

## 规则

- 零分析代码，纯 AI 归纳
- 不改只问（除非 [Y] 应用）
- 关注模式而非单次失败
- EP 必须明确目标文件，不允许"建议改进某个地方"这种模糊提案
