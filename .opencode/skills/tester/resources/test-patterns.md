# 测试模式与质量标准参考

> **文件定位**：本文件是**所有语言通用**的测试模式参考，包含通用测试原则、测试执行命令速查、用例质量标准、覆盖率目标、降级处理方案和缺陷 ID 规范。**阶段一 Step 1 开始前必须加载，无论 LC-001 是何语言。**
>
> **语言路由表**（LC-001 值匹配时**大小写不敏感**）：
>
> | LC-001 | 测试框架 | 加载文件 |
> |--------|---------|---------|
> | `java` | JUnit 5 + Mockito + MockMvc | `lang-test-patterns.md#java` |
> | `python` | pytest + unittest.mock + httpx | `lang-test-patterns.md#python` |
> | `go` | testing + testify/mock + httptest | `lang-test-patterns.md#go` |
> | `nodejs` / `node.js` | Jest + Supertest + NestJS Testing | `lang-test-patterns.md#nodejs` |
>
> **选择规则**：阶段一（用例设计）无需语言专属模式，本文件已覆盖所有通用内容。阶段二 Step 2 时根据 LC-001 加载对应语言部分。
>
> **通用测试原则**（所有语言适用）：
> - 单元测试：隔离外部依赖（Mock/Stub），只测业务逻辑
> - 集成测试：使用测试数据库/内存数据库，验证完整流程
> - 测试用例命名：`{方法名}_{场景描述}_{预期结果}`（各语言命名风格见对应文件）
> - 每个业务规则至少1个正向 + 1个反向测试用例
> - 边界值测试：最小值、最大值、边界±1

---

## 1. 测试执行命令速查

根据 LC-005 包管理工具选择对应命令：

### Java / Maven
```bash
# 执行指定测试类
mvn test -pl {模块} -Dtest="{测试类名}" -q

# 执行全部测试并生成覆盖率报告
mvn test jacoco:report -pl {模块} -q

# 执行指定测试方法
mvn test -Dtest="{测试类名}#{方法名}" -q
```

### Python / pytest
```bash
# 执行指定模块测试
pytest tests/{module}/ -v --tb=short

# 执行并生成覆盖率报告
pytest tests/{module}/ --cov=src/{module} --cov-report=term-missing

# 执行指定测试函数
pytest tests/{module}/test_xxx.py::test_function_name -v
```

### Go / testing
```bash
# 执行指定包测试
go test ./internal/{module}/... -v -run TestXxx

# 执行并生成覆盖率报告
go test ./internal/{module}/... -coverprofile=coverage.out && go tool cover -html=coverage.out

# 执行指定测试函数
go test ./internal/{module}/... -run TestXxx/SubTestName -v
```

### Node.js / Jest
```bash
# 执行指定模块测试
npx jest src/{module}/ --verbose

# 执行并生成覆盖率报告
npx jest src/{module}/ --coverage --coverageDirectory=coverage

# 执行指定测试文件
npx jest src/{module}/xxx.test.ts --verbose
```

### 前端 / Vue3 + Vitest
```bash
# 执行全部前端单元测试
npx vitest run --reporter=verbose

# 执行指定组件测试
npx vitest run src/components/{ComponentName}.test.ts

# 执行并生成覆盖率报告
npx vitest run --coverage
```

### 前端 / React + Jest
```bash
# 执行全部前端单元测试
npx jest --testPathPattern="src/" --verbose

# 执行指定组件测试
npx jest src/components/{ComponentName}.test.tsx --verbose
```

---

## 2. 测试用例质量标准

每个测试用例必须满足：

| 标准 | 说明 |
|------|------|
| **可重复** | 相同输入每次产生相同结果，不依赖外部状态或时间 |
| **独立** | 不依赖其他测试用例的执行顺序，每个用例自行准备和清理数据 |
| **原子** | 每个用例只验证一个行为，失败时能精确定位问题 |
| **可读** | 用例 ID + 功能点描述能让人立即理解测试意图（命名格式：`{方法名}_{场景}_{预期}`） |
| **完整** | 输入、预期输出、实际输出、结果四项缺一不可 |

---

## 3. 测试覆盖率目标

| 测试类型 | 覆盖率目标 | 重点关注 |
|---------|-----------|---------|
| 单元测试 | Service 层行覆盖率 ≥ 80% | 业务规则、异常分支 |
| 集成测试 | API 接口覆盖率 100% | 正常流程 + 主要错误场景 |
| 边界测试 | 每个有约束的字段 ≥ 3 个边界用例 | 数值边界、字符串长度 |
| 安全测试 | 认证/授权场景 100% | 越权访问、注入攻击 |
| 前端单元测试 | 组件分支覆盖率 ≥ 70% | 条件渲染、用户交互、表单校验 |
| 前端集成测试 | 核心页面流程 100% | 登录→操作→登出完整链路 |

---

## 4. 文档不完整降级处理

| 情况 | 处理方式 |
|------|---------|
| 只有 PRD，没有详细设计 | 基于 PRD 的功能描述和验收标准生成黑盒测试用例 |
| 只有详细设计，没有 PRD | 基于接口定义和业务规则生成白盒测试用例 |
| 有代码但无文档 | 通过代码逆向分析生成测试用例，并标注"逆向分析，需人工确认" |
| 测试环境不可用 | 生成测试用例和代码骨架，标注所有用例为"待执行"，在报告中说明 |
| 性能指标未定义 | 使用行业通用基准（P95 < 500ms，TPS > 100），并在报告中注明 |
| 无代码评审报告 | 继续执行，在报告中注明"未找到代码评审报告，建议先运行 code-reviewer" |
| 无项目规则文档 | 在报告中注明"未找到项目规则文档，建议先运行 task-decomposer；**将默认使用 JUnit 5 生成测试代码，如需其他测试框架请明确告知**" |

---

## 5. 缺陷 ID 体系与评审问题对应关系

### 缺陷 ID 格式

```
BUG-{模块缩写}-{序号}
示例：BUG-USR-001（用户模块第1个缺陷）
```

### 与 code-reviewer 评审问题的对应关系

| code-reviewer 问题 | tester 缺陷 | 说明 |
|-------------------|------------|------|
| `REVIEW-SEC-001`（安全问题） | `BUG-{模块}-{序号}`（安全类） | 评审发现的安全问题，在测试报告中以 BUG ID 追踪修复状态 |
| `REVIEW-PERF-001`（性能问题） | `BUG-{模块}-{序号}`（性能类） | 评审发现的性能问题，对应性能测试用例 |
| `REVIEW-LOGIC-001`（逻辑问题） | `BUG-{模块}-{序号}`（逻辑类） | 评审发现的业务逻辑问题，对应专项测试用例 |

**追溯规则**：
- 测试用例中标注 `[评审专项]` 的用例，其缺陷 ID 应在备注中关联对应的 `REVIEW-XXX-NNN` 编号
- bug-fixer 修复报告中同时记录 BUG ID 和 REVIEW ID，形成完整的问题追溯链
- 示例：`BUG-USR-001（关联 REVIEW-SEC-003：未校验越权访问）`
