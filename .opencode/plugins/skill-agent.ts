import { tool, type ToolDefinition } from "@opencode-ai/plugin"
import { readFile, appendFile } from "node:fs/promises"
import { join } from "node:path"
import { existsSync, mkdirSync } from "node:fs"

interface SkillDef {
  id: string
  description: string
}

interface SkillFrontmatter {
  name: string
  description?: string
}

const SKILLS: SkillDef[] = [
  { id: "prd-writer", description: "加载 PRD 技能并验证任务参数" },
  { id: "review-expert", description: "加载评审技能并验证任务参数" },
  { id: "system-architect", description: "加载架构技能并验证任务参数" },
  { id: "task-decomposer", description: "加载详设技能并验证任务参数" },
  { id: "code-reviewer", description: "加载代码评审技能并验证任务参数" },
  { id: "tester", description: "加载测试技能并验证任务参数" },
  { id: "dba-designer", description: "加载 DB 设计技能并验证任务参数" },

  { id: "code-developer", description: "加载编码技能并验证任务参数" },
  { id: "pipeline-orchestrator", description: "加载流水线编排技能并验证任务参数" },
  { id: "self-evolve", description: "加载自我进化技能并验证任务参数" },
]

const SKILL_FILE_DIR = ".opencode/skills"
const MIN_TASK_LENGTH = 10

const skillMdCache = new Map<string, string>()

function clearCaches(): void {
  skillMdCache.clear()
}

function toolId(id: string): string {
  return `call_${id.replace(/-/g, "_")}`
}

function cacheKey(projectDir: string, skillId: string): string {
  return `${projectDir}:${skillId}`
}

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

function parseFrontmatter(skillMd: string): SkillFrontmatter | null {
  const match = skillMd.match(/^---\n([\s\S]*?)\n---/)
  if (!match) return null

  const body = match[1]
  const name = body.match(/^name:\s*(.+)$/m)?.[1]?.trim()
  if (!name) return null

  const description = body.match(/^description:\s*(.+)$/m)?.[1]?.trim()
  return { name, description }
}

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

// ---- Logging (for self-evolve) ----

function historyDir(): string {
  return join(process.env.HOME || "/tmp", ".opencode", "history")
}

async function writeLog(_projectDir: string, sid: string, ok: boolean, task: string): Promise<void> {
  const dir = historyDir()
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  const line = JSON.stringify({ skill: sid, task: task.slice(0, 200), ok, ts: Date.now() }) + "\n"
  await appendFile(join(dir, `${sid}.jsonl`), line, "utf-8")
}

// ---- Plugin ----

export default async function plugin() {
  if (process.env.NODE_ENV === "development") clearCaches()

  const tools: Record<string, ToolDefinition> = {}

  for (const skill of SKILLS) {
    const id = toolId(skill.id)

    tools[id] = tool({
      description: skill.description,
      args: {
        task: tool.schema.string().describe(`${skill.id} 任务描述`),
      },
      async execute(args, context) {
        const projectDir = context.directory || process.cwd()
        const task = (args.task ?? "").trim()

        const validationError = validateTask(skill.id, task)
        if (validationError) {
          await writeLog(projectDir, skill.id, false, task)
          return { output: validationError, metadata: { skill: skill.id, error: true } }
        }

        const skillMd = await readSkillMd(projectDir, skill.id)

        if (!skillMd) {
          await writeLog(projectDir, skill.id, false, task)
          return {
            output: `错误：未找到 ${skill.id} 的 SKILL.md 文件（路径 ${SKILL_FILE_DIR}/${skill.id}/SKILL.md）。请确认技能目录是否存在。`,
            metadata: { skill: skill.id, error: true },
          }
        }

        const frontmatter = parseFrontmatter(skillMd)

        await writeLog(projectDir, skill.id, true, task)
        return {
          output: skillMd,
          metadata: {
            skill: skill.id,
            name: frontmatter?.name ?? skill.id,
            skillPath: `${SKILL_FILE_DIR}/${skill.id}/SKILL.md`,
          },
        }
      },
    })
  }

  return { tool: tools }
}
