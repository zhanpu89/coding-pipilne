import { tool, type ToolDefinition } from "@opencode-ai/plugin"
import { readFile } from "node:fs/promises"
import { join } from "node:path"

const SKILLS = [
  {
    id: "prd-writer",
    description: "需求分析与 PRD 文档撰写。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于从粗略想法生成正式 PRD。",
  },
  {
    id: "review-expert",
    description: "全流程评审专家。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于需求评审、架构评审、详细设计评审、测试用例评审。",
  },
  {
    id: "system-architect",
    description: "系统架构设计。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于将 PRD 转化为架构建档（SAD）和技术栈清单。",
  },
  {
    id: "task-decomposer",
    description: "软件模块详细设计。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于将 SAD 拆解为模块级详设文档。",
  },
  {
    id: "code-reviewer",
    description: "代码质量门禁。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于代码评审、契约一致性检查。",
  },
  {
    id: "tester",
    description: "两阶段测试。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于根据详设生成测试用例和测试代码。",
  },
  {
    id: "dba-designer",
    description: "数据库设计。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于根据后端详设生成 DDL 脚本。",
  },
  {
    id: "ai-memory",
    description: "AI 记忆持久化管理。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于翻历史、查记录、记决策、归档阶段成果。",
  },
  {
    id: "code-developer",
    description: "编码实现。加载 Code Developer 的 SKILL.md 后通过 task 启动 subagent 执行。适用于根据详细设计文档生成可运行代码。",
  },
  {
    id: "pipeline-orchestrator",
    description: "全流程软件工程编排器（主 agent 模式）。加载 SKILL.md 获取编排指令：主 agent 通过 task 启动 subagent 执行各阶段，通过 bash 验证脚本检查产出物，通过 check-review.sh 判定评审门禁。完整 6 阶段流水线：PRD→架构→详设→DB设计→编码→测试。",
  },
]

const SKILL_FILE_DIR = ".opencode/skills"

function toolId(skillId: string): string {
  return `call_${skillId.replace(/-/g, "_")}`
}

async function readSkillMd(projectDir: string, skillId: string): Promise<string | null> {
  const path = join(projectDir, SKILL_FILE_DIR, skillId, "SKILL.md")
  try {
    return await readFile(path, "utf-8")
  } catch {
    return null
  }
}

function buildLazyLoadTable(skillId: string, skillMd: string): string {
  const lines = skillMd.split("\n")

  // Find "## 参考文件" header position
  const headerIdx = lines.findIndex(l => /^##\s+参考文件/.test(l))
  if (headerIdx === -1) return ""

  // Collect table rows after the header
  const tableRows: string[] = []
  let inSep = false
  for (let i = headerIdx + 1; i < lines.length; i++) {
    const line = lines[i].trim()
    if (!line) continue
    // Markdown table: first row after header is separator (| --- | --- |)
    // Content rows start with |
    if (line.startsWith("|") && line.includes("---")) {
      inSep = true
      continue
    }
    if (inSep && line.startsWith("|")) {
      tableRows.push(line)
    } else if (inSep && !line.startsWith("|")) {
      break // table ended
    }
  }

  if (tableRows.length === 0) return ""

  // Find column indices from header row
  const headerRow = lines.slice(headerIdx + 1).find(l => l.trim().startsWith("|") && !l.includes("---"))
  if (!headerRow) return ""

  const headerCols = headerRow.split("|").map(c => c.trim())
  const fileIdx = headerCols.findIndex(c => /文件/.test(c))
  const stepIdx = headerCols.findIndex(c => /(步骤|场景|加载时机)/.test(c))
  if (fileIdx === -1) return ""

  const tablePath = `${SKILL_FILE_DIR}/${skillId}`
  const entries: string[] = []

  for (const row of tableRows) {
    const cols = row.split("|").map(c => c.trim().replace(/^`|`$/g, ""))
    const file = cols[fileIdx] || ""
    // Only include resources/ and templates/ files (not doc/ or script paths)
    if (!file.startsWith("resources/") && !file.startsWith("templates/")) continue
    const step = stepIdx !== -1 ? (cols[stepIdx] || "") : ""
    entries.push(`  - **\`${file}\`** → ${step}（路径：\`${tablePath}/${file}\`）`)
  }

  if (entries.length === 0) return ""

  return `\n### 按需加载清单\n\n${entries.join("\n")}\n`
}

export default async function plugin() {
  const tools: Record<string, ToolDefinition> = {}

  for (const skill of SKILLS) {
    tools[toolId(skill.id)] = tool({
      description: skill.description,
      args: {
        task: tool.schema.string().describe(`需要 ${skill.id} 技能处理的具体任务描述。详细说明用户需求、输入文档路径、输出要求等。`),
      },
      async execute(args, context) {
        const projectDir = context.directory || process.cwd()
        const skillMd = await readSkillMd(projectDir, skill.id)

        if (!skillMd) {
          return {
            output: `错误：未找到 ${skill.id} 的 SKILL.md 文件（路径 ${SKILL_FILE_DIR}/${skill.id}/SKILL.md）`,
            metadata: { skill: skill.id, error: true },
          }
        }

        const lazyTable = buildLazyLoadTable(skill.id, skillMd)

        const prompt = `# Skill: ${skill.id}

## 用户任务

${args.task}

---

## 工作流指令（SKILL.md）

${skillMd}${lazyTable}

---

## 执行规则

### 通用纪律（来自 code-discipline.md）

- **先思考再编码** — 陈述假设，摊开权衡。不确定就问。不默默选一个。
- **简洁优先** — 最少代码/文档解决问题。不做未要求的抽象、灵活性或配置。
- **手术式修改** — 只触碰必须改的。不"改进"无关代码，不重构没坏的东西。
- **目标驱动** — 把任务转化为可验证的成功标准，"让它工作"不够具体。

### 技能执行规则

1. **懒加载** — 你只拥有 SKILL.md（工作流指令）。不要一次性加载全部资源！
2. **按需读取** — 严格按照 SKILL.md 中"参考文件"表的"加载时机"列，在对应步骤用 \`read\` 工具读取文件。路径前缀为 \`${SKILL_FILE_DIR}/${skill.id}/\`。
3. **用完即释放** — 每个文件对应步骤完成后，不再保留在上下文中。
4. **产物写入** — 所有输出产物写入 \`doc/\` 对应子目录。
5. **单模块节奏** — 一次只生成一份文档/代码，更新进度后等待用户确认再继续。
6. **生成完成后输出** — \`✅ ${skill.id} 任务完成\` 并汇总产出物清单。`

        return {
          output: prompt,
          metadata: {
            skill: skill.id,
          },
        }
      },
    })
  }

  return { tool: tools }
}
