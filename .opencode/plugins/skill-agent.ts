import { tool, type ToolDefinition } from "@opencode-ai/plugin"
import { readFile } from "node:fs/promises"
import { join } from "node:path"

interface SkillDef {
  id: string
  description: string
}

interface SkillFrontmatter {
  name: string
  description?: string
}

const SKILLS: SkillDef[] = [
  { id: "prd-writer", description: "需求分析与 PRD 文档撰写。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于从粗略想法生成正式 PRD。" },
  { id: "review-expert", description: "全流程评审专家。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于需求评审、架构评审、详细设计评审、测试用例评审。" },
  { id: "system-architect", description: "系统架构设计。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于将 PRD 转化为架构建档（SAD）和技术栈清单。" },
  { id: "task-decomposer", description: "软件模块详细设计。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于将 SAD 拆解为模块级详设文档。" },
  { id: "code-reviewer", description: "代码质量门禁。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于代码评审、契约一致性检查。" },
  { id: "tester", description: "两阶段测试。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于根据详设生成测试用例和测试代码。" },
  { id: "dba-designer", description: "数据库设计。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于根据后端详设生成 DDL 脚本。" },
  { id: "ai-memory", description: "AI 记忆持久化管理。按需加载 SKILL.md 后通过 task 启动 subagent 执行。适用于翻历史、查记录、记决策、归档阶段成果。" },
  { id: "code-developer", description: "编码实现。加载 Code Developer 的 SKILL.md 后通过 task 启动 subagent 执行。适用于根据详细设计文档生成可运行代码。" },
  { id: "pipeline-orchestrator", description: "全流程软件工程编排器（主 agent 模式）。加载 SKILL.md 获取编排指令：主 agent 通过 task 启动 subagent 执行各阶段，通过 bash 验证脚本检查产出物，通过 check-review.sh 判定评审门禁。完整 6 阶段流水线：PRD→架构→详设→DB设计→编码→测试。" },
]

const SKILL_FILE_DIR = ".opencode/skills"
const MIN_TASK_LENGTH = 10

// ---- Cache ----

const skillMdCache = new Map<string, string>()
const disciplineCache = new Map<string, string>()

function clearCaches(): void {
  skillMdCache.clear()
  disciplineCache.clear()
}

// ---- Helpers ----

function toolId(id: string): string {
  return `call_${id.replace(/-/g, "_")}`
}

function cacheKey(projectDir: string, skillId: string): string {
  return `${projectDir}:${skillId}`
}

// ---- File loading ----

async function readSkillMd(projectDir: string, skillId: string): Promise<string | null> {
  const key = cacheKey(projectDir, skillId)
  if (skillMdCache.has(key)) return skillMdCache.get(key)!

  const path = join(projectDir, SKILL_FILE_DIR, skillId, "SKILL.md")
  try {
    const content = await readFile(path, "utf-8")
    skillMdCache.set(key, content)
    return content
  } catch {
    return null
  }
}

async function loadDisciplineRules(projectDir: string): Promise<string> {
  const key = `discipline:${projectDir}`
  if (disciplineCache.has(key)) return disciplineCache.get(key)!

  try {
    const content = await readFile(join(projectDir, ".opencode/rules/code-discipline.md"), "utf-8")
    const lines = content.split("\n")
    const out: string[] = []
    let capture = false
    for (const line of lines) {
      if (/^## 原则/.test(line)) { capture = true; continue }
      if (capture && /^## /.test(line)) break
      if (capture) { const t = line.trim(); if (t) out.push(t) }
    }
    const result = out.join("\n") || "- 先思考再编码 — 陈述假设，摊开权衡。不确定就问。\n- 简洁优先 — 最少代码/文档解决问题。\n- 手术式修改 — 只触碰必须改的。\n- 目标驱动 — 转化为可验证的成功标准。"
    disciplineCache.set(key, result)
    return result
  } catch {
    const fallback = "- **先思考再编码** — 陈述假设，摊开权衡。不确定就问。\n- **简洁优先** — 最少代码/文档解决问题。\n- **手术式修改** — 只触碰必须改的。\n- **目标驱动** — 转化为可验证的成功标准。"
    disciplineCache.set(key, fallback)
    return fallback
  }
}

// ---- Front-matter parsing ----

function parseFrontmatter(skillMd: string): SkillFrontmatter | null {
  const match = skillMd.match(/^---\n([\s\S]*?)\n---/)
  if (!match) return null

  const body = match[1]
  const name = body.match(/^name:\s*(.+)$/m)?.[1]?.trim()
  if (!name) return null

  const descMatch = body.match(/^description:\s+[|>]\s*\n([\s\S]*?)(?=\n\S|\n---|$)/)
  const description = descMatch
    ? descMatch[1].split("\n").map(l => l.replace(/^  /, "").trim()).filter(Boolean).join("\n")
    : body.match(/^description:\s*(.+)$/m)?.[1]?.trim()

  return { name, description }
}

// ---- Lazy-load table ----

function buildLazyLoadTable(skillId: string, skillMd: string): string {
  const lines = skillMd.split("\n")

  const headerIdx = lines.findIndex(l => /^##\s+参考/.test(l))
  if (headerIdx === -1) return ""

  // Collect all data rows after the header
  const dataRows: string[] = []
  let foundSep = false
  for (let i = headerIdx + 1; i < lines.length; i++) {
    const line = lines[i].trim()
    if (!line) continue
    if (line.startsWith("|")) {
      if (!foundSep) {
        if (line.includes("---")) { foundSep = true }
        continue
      }
      dataRows.push(line)
    } else if (foundSep) {
      break
    }
  }

  if (dataRows.length === 0) return ""

  // Find header row (the row before the separator)
  let headerRow = ""
  for (let i = headerIdx + 1; i < lines.length; i++) {
    const line = lines[i].trim()
    if (!line.startsWith("|")) continue
    if (line.includes("---")) break
    if (/\w/.test(line)) { headerRow = line; break }
  }
  if (!headerRow) return ""

  const headerCols = headerRow.split("|").map(c => c.trim())
  const fileIdx = headerCols.findIndex(c => /文件/.test(c))
  const stepIdx = headerCols.findIndex(c => /(步骤|场景|加载时机)/.test(c))
  if (fileIdx === -1) return ""

  const tablePath = `${SKILL_FILE_DIR}/${skillId}`
  const entries: string[] = []

  for (const row of dataRows) {
    const cols = row.split("|").map(c => c.trim().replace(/^`|`$/g, ""))
    const file = cols[fileIdx]?.trim() || ""
    if (!file.startsWith("resources/") && !file.startsWith("templates/")) continue
    const step = stepIdx !== -1 ? (cols[stepIdx]?.trim() || "") : ""
    entries.push(`  - **\`${file}\`** → ${step}（路径：\`${tablePath}/${file}\`）`)
  }

  if (entries.length === 0) return ""
  return `\n### 按需加载清单\n\n${entries.join("\n")}\n`
}

// ---- Validation ----

function validateTask(skillId: string, task: string): string | null {
  const trimmed = task?.trim() ?? ""
  if (!trimmed) {
    return `❌ 参数 \`task\` 为空。请提供需要 ${skillId} 技能处理的具体任务描述（输入文档路径、输出要求等）。`
  }
  if (trimmed.length < MIN_TASK_LENGTH) {
    return `⚠️ 参数 \`task\` 过短（${trimmed.length} 字符），请提供更详细的任务描述。`
  }
  return null
}

// ---- Prompt builder ----

function buildPrompt(
  skillId: string,
  task: string,
  skillMd: string,
  lazyTable: string,
  disciplineRules: string,
): string {
  return `# Skill: ${skillId}

## 用户任务

${task.trim()}

---

## 工作流指令（SKILL.md）

${skillMd}${lazyTable}

---

## 执行规则

### 通用纪律

${disciplineRules}

### 技能执行规则

1. **懒加载** — 你只拥有 SKILL.md（工作流指令）。不要一次性加载全部资源！
2. **按需读取** — 严格按照 SKILL.md 中"参考文件"表的"加载时机"列，在对应步骤用 \`read\` 工具读取文件。路径前缀为 \`${SKILL_FILE_DIR}/${skillId}/\`。
3. **用完即释放** — 每个文件对应步骤完成后，不再保留在上下文中。
4. **产物写入** — 所有输出产物写入 \`doc/\` 对应子目录。
5. **单模块节奏** — 一次只生成一份文档/代码，更新进度后等待用户确认再继续。
6. **生成完成后输出** — \`✅ ${skillId} 任务完成\` 并汇总产出物清单。`
}

// ---- Plugin ----

export default async function plugin() {
  // Clear caches on reload (dev mode)
  if (process.env.NODE_ENV === "development") clearCaches()

  const tools: Record<string, ToolDefinition> = {}

  for (const skill of SKILLS) {
    const id = toolId(skill.id)

    tools[id] = tool({
      description: skill.description,
      args: {
        task: tool.schema.string().describe(`需要 ${skill.id} 技能处理的具体任务描述。详细说明用户需求、输入文档路径、输出要求等。`),
      },
      async execute(args, context) {
        const projectDir = context.directory || process.cwd()

        const validationError = validateTask(skill.id, args.task)
        if (validationError) {
          return { output: validationError, metadata: { skill: skill.id, error: true } }
        }

        const [skillMd, disciplineRules] = await Promise.all([
          readSkillMd(projectDir, skill.id),
          loadDisciplineRules(projectDir),
        ])

        if (!skillMd) {
          return {
            output: `错误：未找到 ${skill.id} 的 SKILL.md 文件（路径 ${SKILL_FILE_DIR}/${skill.id}/SKILL.md）。请确认技能目录是否存在。`,
            metadata: { skill: skill.id, error: true },
          }
        }

        const frontmatter = parseFrontmatter(skillMd)
        const lazyTable = buildLazyLoadTable(skill.id, skillMd)
        const prompt = buildPrompt(skill.id, args.task, skillMd, lazyTable, disciplineRules)

        return {
          output: prompt,
          metadata: {
            skill: skill.id,
            name: frontmatter?.name ?? skill.id,
          },
        }
      },
    })
  }

  return { tool: tools }
}
