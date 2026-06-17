# MCP Skill Loader — 按需加载设计文档

## 问题

当前 Skills 系统的 Token 消耗模型：

```
subagent = 系统 prompt + SKILL.md(~150行) + 资源1(~300行) + 资源2(~200行) + 模板1(~400行)
                                                             ↑ 无论用多少，整文件进上下文
```

一次典型的 subagent 调用消耗 **1000-2500 行上下文**，全流水线 6+ Phase 重复消耗，token 压力巨大。

## 方案

将 resources/ 和 templates/ 从**被动加载到上下文**改为**通过 MCP 按需查询**：

```
subagent = 系统 prompt + SKILL.md(精简至~50行)
              ↓ 需要时主动查询
MCP: resource('prd-writer', 'filling-guide', '## 性能指标')
  → 仅返回 20 行
```

---

## 架构

```
.opencode/
├── mcp-skill-loader/              # MCP 服务（新增）
│   ├── package.json
│   └── index.ts                   # 工具实现
├── skills/{name}/
│   ├── SKILL.md                   # 精简版（引用改成 MCP 调用）
│   ├── resources/                 # 文件不变，MCP 直接读取
│   └── templates/                 # 文件不变，MCP 直接读取
├── plugins/skill-agent.ts         # 微调：在返回中加入 MCP 提示
└── docs/mcp-skill-loader-design.md
```

---

## MCP 工具定义

### 工具 1：`resource`

读取 resources/ 文件。

```
resource(skill: string, file: string, section?: string)
```

| 参数 | 必填 | 说明 |
|------|------|------|
| `skill` | 是 | 技能名，如 `prd-writer` |
| `file` | 是 | 文件名（不含路径），如 `filling-guide.md` |
| `section` | 否 | Markdown 标题，如 `## 性能指标`。不传返回全文 |

**返回**：文件内容或指定节的内容（含子节）。找不到返回错误信息。

**路径规则**：`{project}/.opencode/skills/{skill}/resources/{file}`

---

### 工具 2：`template`

读取 templates/ 文件。

```
template(skill: string, file: string, section?: string)
```

参数与 `resource` 相同，路径指向 `templates/` 目录。

---

### 工具 3：`skill_section`

读取 SKILL.md 的指定章节。

```
skill_section(skill: string, section: string)
```

| 参数 | 必填 | 说明 |
|------|------|------|
| `skill` | 是 | 技能名 |
| `section` | 是 | Markdown 标题，如 `## 工作流`。支持二级 `## Step 3：PRD 生成` |

**返回**：SKILL.md 中从该标题到下一个同级标题之间的内容。

---

### 工具 4：`skill_inventory`

列出技能可用的资源和模板。

```
skill_inventory(skill: string)
```

**返回**：该技能下 resources/ 和 templates/ 的文件列表（含行数估算），以及每份文件的章节标题列表。subagent 可据此决定需要加载哪些文件、哪些章节。

---

## SKILL.md 改造示例

### 改造前（prd-writer/SKILL.md）

```markdown
## 参考文件（按需加载）

| 文件 | 加载时机 |
|------|---------|
| `resources/filling-guide.md` | Step 3 前 |

## Step 3：PRD 生成

加载以下文件：
- `resources/filling-guide.md`
- `resources/glossary.md`
- `templates/common.md`
```

### 改造后

```markdown
## Step 3：PRD 生成

调用 MCP 按需查询各节：

1. `resource('prd-writer', 'glossary.md')` 获取术语约束
2. `template('prd-writer', 'common.md', '## PRD 文档骨架')` 获取文档结构
3. `resource('prd-writer', 'filling-guide.md', '## 需求描述')` 获取填写指引
```

---

## 节级别分割规则

MCP 按 Markdown 标题进行节分割：

| 标题级别 | 边界规则 |
|---------|---------|
| `## 标题` | 分割点。匹配时返回从此 `##` 到下一个 `##`（或文件尾） |
| `### 子标题` | 包含在父节内，不单独作为分割边界（除非 `section` 精确匹配 `###`） |

**实现思路**：

```typescript
function extractSection(content: string, heading: string): string {
  // 1. 构建正则：^## 标题(\s*\n)
  // 2. 找到匹配行
  // 3. 找到下一个同级别标题（^## 非#）或文件尾
  // 4. 返回中间内容
}
```

---

## skill-agent.ts 改动

在返回信息中加入 MCP 工具提示：

```typescript
return {
  output: `[SKILL: ${skill.id}]
→ 启动 task(subagent_type='${skill.id}')
→ 可用 MCP 工具：resource(), template(), skill_section(), skill_inventory()
   按需查询，勿一次性加载全部文件`,
  metadata: { /* ... */ },
}
```

---

## subagent 工作流变化

### 改造前

```
1. read SKILL.md（全文件进上下文）
2. read resources/filling-guide.md（全文件进上下文）
3. read templates/common.md（全文件进上下文）
4. 生成产出物
```

### 改造后

```
1. read SKILL.md（仅核心指令）
2. 调用 skill_inventory('prd-writer') 了解可用资源
3. 调用 template('prd-writer', 'common.md', '## PRD 文档骨架') 获取结构
4. 调用 resource('prd-writer', 'filling-guide.md', '## 需求描述') 获取指引
5. 生成产出物
```

每个 MCP 调用返回 20-50 行，而非 200-500 行。

---

## 文件清单

### 新增文件

| 文件 | 行数估算 | 说明 |
|------|---------|------|
| `.opencode/mcp-skill-loader/package.json` | 15 | MCP 服务依赖 |
| `.opencode/mcp-skill-loader/index.ts` | 120-150 | 4 个工具实现 + Markdown 分割 |

### 修改文件

| 文件 | 改动量 | 说明 |
|------|--------|------|
| 10 个 `SKILL.md` | 各改 20-40 行 | 文件引用 → MCP 调用 |
| `.opencode/plugins/skill-agent.ts` | 改 5 行 | 返回中加入 MCP 提示 |

### 无需修改

| 文件 | 原因 |
|------|------|
| 36 个 `resources/*.md` | MCP 直接读取，文件格式不变 |
| 15 个 `templates/*.md` | 同上 |
| 8 个 `check-*.sh` | 验证逻辑不受影响 |

---

## 收益估算

| 指标 | 改造前 | 改造后 | 节省 |
|------|--------|--------|------|
| 每 subagent 上下文负载 | 1000-2500 行 | 50-150 行 | **90-95%** |
| 全流水线总消耗 | 6000-15000 行 | 300-900 行 | **~95%** |
| MCP 调用次数 | 0 | 3-5 次/技能 | — |

MCP 调用每次返回纯文本片段，token 开销 ≈ 调用结果的 1-3%，可忽略不计。

---

## 边界情况

| 场景 | 处理 |
|------|------|
| `section` 未找到 | 返回错误信息 + `skill_inventory` 查询建议 |
| 文件不存在 | 返回清晰错误 |
| `section` 匹配多个 | 返回第一个匹配，提示有多个 |
| 文件被修改 | MCP 实时读取文件系统，无需缓存同步 |

---

## 后续步骤

1. 实现 `mcp-skill-loader/` MCP 服务
2. 注册 MCP 服务到 opencode 配置
3. 逐个改造 10 个 SKILL.md
4. 微调 `skill-agent.ts`
5. 测试验证

---

*本文档作为实现蓝本，实际交付时应确保线程安全、路径安全（防止目录遍历）和错误容错。*
