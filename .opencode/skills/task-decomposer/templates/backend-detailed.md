# 后端模块详细设计文档模板

> **内容**：后端模块详设文档完整模板（含伪代码、DDL、OpenAPI 3.0、质量清单）。
> **加载时机**：Step 3 生成后端详设前加载。
> 进度文档格式详见 `_PROGRESS.md` 文件模板。

每个模块对应一份详细设计文档，文件命名为 `{模块名}_{功能域}.md`，保存到 `doc/detailed/` 目录。
本模板旨在为开发人员（包括 AI）提供**精确、无歧义**的编码指导，确保可直接依据文档生成符合需求的代码。

---

## 模板正文

生成详细设计文档时，严格按照以下结构填写，所有字段必须用项目实际内容替换，禁止保留占位符。

---

```markdown
# {项目名称} — {模块名称} 详细设计文档

**文档编号**：DES-YYYYMMDD-NNN
**版本**：v1.0.0
**状态**：🟡 草稿
**创建日期**：YYYY-MM-DD
**最后更新**：YYYY-MM-DD
**作者**：[姓名]
**审核人**：[姓名 / 待定]
**所属层次**：Layer {0/1/2/3/4}（见 resources/layer-model.md 分层定义）
**关联文档**：{架构设计文档路径（SAD-YYYYMMDD-NNN）}

---

## 1. 功能描述

列出本模块负责的所有功能点：
- 功能1：{描述}
- 功能2：{描述}
- 功能3：{描述}

---

## 2. 业务规则

| 规则编号 | 规则描述 | 配置来源 |
|----------|----------|---------|
| {MOD}-REG-01 | {具体业务规则，精确到字段约束、取值范围、唯一性要求} | {硬编码/环境变量_KEY/config.{key}/注解参数} |
| {MOD}-REG-02 | {例：密码长度8-72，必须包含至少一个大写字母、一个小写字母和一个数字} | 硬编码 |
| {MOD}-BIZ-01 | {例：连续5次登录失败，账户锁定15分钟} | 硬编码（可配置），失败次数来源：Redis INCR |
| {MOD}-BIZ-02 | {例：默认注册用户拥有 ROLE_USER 角色} | 硬编码 |

> **配置来源取值规范**：
> - `硬编码` — 值不期望变更，写在常量/配置类中并加注释说明
> - `环境变量_{KEY}` — 从环境变量读取，如 `环境变量_PASSWORD_MIN_LENGTH`
> - `配置文件_{key}` — 从 yml/properties 读取，如 `配置文件_app.security.password.min-length`
> - `配置中心_{key}` — 从 Nacos/Apollo 等动态配置中心获取
> - `注解参数` — 值作为注解参数传入框架（如 `@RateLimiter(count=5)`）

---

## 3. 接口定义（OpenAPI 3.0）

**接口1：{接口名称}**
```yaml
{HTTP方法} {路径}
requestBody:
  required: true
  content:
    application/json:
      schema:
        type: object
        required: [{必填字段列表}]
        properties:
          {field1}:
            type: string
            minLength: {min}
            maxLength: {max}
            pattern: '{正则表达式}'
            description: {字段说明}
            example: {示例值}
          {field2}:
            type: integer
            minimum: {min}
            maximum: {max}
            description: {字段说明}
responses:
  '200':
    description: {成功描述}
    content:
      application/json:
        schema:
          type: object
          properties:
            {responseField}:
              type: {type}
              example: {示例值}
  '400':
    description: 请求参数错误
    content:
      application/json:
        schema:
          type: object
          properties:
            code:
              type: string
              example: {错误码，如 INVALID_PASSWORD}
            message:
              type: string
              example: {错误描述}
  '401':
    description: 未授权
  '409':
    description: 资源冲突（如重复注册）
  '500':
    description: 服务器内部错误
```

**接口2：{接口名称}**（类似结构）

---

## 4. 功能逻辑（详细步骤 + 生产级伪代码）

> **伪代码约定**：
> - Python 语法仅作为**逻辑结构描述工具**，与 LC-001 目标语言无关
> - 以下特殊注释为**编码约束标记**，code-developer 必须按标记约束翻译为目标语言实现
> - 若某步涉及目标语言特有模式，用 `# LANGUAGE_SPECIFIC: {语言} - {模式}` 标注

### 编码约束标记体系

| 标记 | 含义 | 开发者的处理方式 |
|------|------|----------------|
| `# TRANSACTION_BEGIN` | 开启数据库事务 | Java→`@Transactional(rollbackFor=Exception.class)` / Go→`db.Transaction()` / Python→`async with db.begin()` |
| `# TRANSACTION_COMMIT` | 提交事务（仅显式管理时需要） | 框架自动管理时标记为框架行为 |
| `# TRANSACTION_ROLLBACK` | 回滚条件 | 对应语言的 rollback 机制 |
| `# COMPENSATION:` | 若后续步骤失败需进行的补偿操作 | 翻译为 try-catch 或 Saga 补偿调用 |
| `# FINALLY:` | 无论如何都必须执行的资源清理 | 对应语言的 try-finally / defer / using |
| `# LOCK: {类型} {资源}` | 并发控制，如悲观锁、分布式锁 | `SELECT ... FOR UPDATE` / Redis `SET NX` / ZooKeeper |
| `# OPTIMISTIC_LOCK: {version字段}` | 乐观锁控制 | `UPDATE ... WHERE version=oldVersion`，重试策略 |
| `# RETRY: 最多{N}次，间隔{N}ms` | 失败重试策略 | 对应语言的 retry 库或循环 |
| `# LANGUAGE_SPECIFIC: {语言} - {提示}` | 目标语言特有模式，不容忽略 | 直接按提示实现，如 `Java - 使用 Optional.ofNullable()` |
| `# TIMEOUT: {N}ms` | 操作超时设定 | 设置客户端超时/上下文超时 |

**功能：{功能名称}**
```python
def {function_name}({params}):
    # TRANSACTION_BEGIN
    # LOCK: 悲观锁 {table_name}.{lock_key}（仅高并发场景）

    # 步骤1: 参数格式校验
    if not validate_{field}({field_value}):
        raise ValidationError("{ERROR_CODE}", "{错误描述}")

    # 步骤2: 业务前置检查（唯一性、状态校验等）
    if repo.exists_by_{field}({value}):
        raise ConflictError("{CONFLICT_CODE}", "{冲突描述}")
    # OPTIMISTIC_LOCK: version字段 — 第N步执行 UPDATE ... WHERE version={oldVersion}

    # 步骤3: 核心业务逻辑（数据转换、计算、加密等）
    processed = {处理逻辑}
    # LANGUAGE_SPECIFIC: Java - 使用 Optional.ofNullable(processed).orElseThrow(...)
    # LANGUAGE_SPECIFIC: Go - if processed == nil { return nil, errors.New("...") }

    # 步骤4: 持久化
    entity = {Entity}(
        {field1}={value1},
        {field2}={value2}
    )
    # COMPENSATION: 若步骤5失败，步骤4需要回退 undo_save(entity.id)
    repo.save(entity)

    # 步骤5: 后置处理（发消息、更新缓存、生成Token等）
    # TIMEOUT: 5000ms — 外部调用需设置超时
    # RETRY: 最多3次，间隔 200ms — 网络抖动场景
    {post_processing}

    # FINALLY: 关闭资源、清除上下文
    #   1. 关闭 {ExternalResource}
    #   2. 清除 ThreadLocal / context 中的临时数据

    # 步骤6: 返回结果
    # TRANSACTION_COMMIT
    return {result}
```

---

## 5. 状态机与状态流转

> 仅当模块包含状态化实体（如订单、审批单、任务）时需要。纯CRUD模块可跳过。

### 5.1 状态枚举

```python
class {Entity}Status(enum):
    {STATE_A} = {值}  # 初始状态
    {STATE_B} = {值}  # 描述
    {STATE_C} = {值}  # 终止状态
```

### 5.2 合法状态转换表

| 当前状态 | 目标状态 | 触发操作 | 前置条件（guard） | 副作用（side effect） |
|---------|---------|---------|-----------------|---------------------|
| {STATE_A} | {STATE_B} | `PUT /{resource}/{id}/submit` | 必填字段完整 | 发送审批通知 |
| {STATE_B} | {STATE_C} | `PUT /{resource}/{id}/approve` | 当前用户有审批权限 | 发送审批结果邮件 |
| {STATE_B} | {STATE_A} | `PUT /{resource}/{id}/reject` | 当前用户有审批权限 | 发送驳回通知 |
| {STATE_A} | — | `DELETE /{resource}/{id}` | 仅初始状态可删除 | 无 |

### 5.3 状态变更伪代码

```python
def transition_{entity}_status(entity_id, new_status, operator):
    # 1. 加载实体
    entity = repo.get_by_id(entity_id)
    if not entity:
        raise NotFoundError(...)

    # 2. 校验当前状态 → 目标状态是否合法（查 5.2 转换表）
    if (entity.status, new_status) not in ALLOWED_TRANSITIONS:
        raise ConflictError("ILLEGAL_STATUS", "不允许从 {entity.status} 转换到 {new_status}")

    # 3. 执行前置条件（guard）
    if not check_guard(entity, new_status, operator):
        raise ForbiddenError(...)

    # 4. 执行状态变更
    # OPTIMISTIC_LOCK: version
    updated = repo.update_status(entity_id, new_status, entity.version)

    # 5. 执行副作用
    # COMPENSATION: 若副作用失败，状态不回滚，记入 dead_letter 队列
    execute_side_effects(entity, new_status)

    return updated
```

---

## 6. 使用的算法

- **{算法名称}**：{算法描述}，参数：{参数说明}，输出格式：{格式说明}
- **{算法名称2}**：{算法描述}，密钥来源：{来源}，payload包含：{字段列表}
- **{限流/计数算法}**：使用 {存储介质}，key = `{key_pattern}`，TTL = {时间}

---

## 7. 数据库表结构（完整DDL）

```sql
-- {表说明}
CREATE TABLE {table_name} (
    id          BIGINT          AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
    {field1}    {TYPE}({len})   NOT NULL                   COMMENT '{字段说明}',
    {field2}    {TYPE}          NOT NULL DEFAULT {default}  COMMENT '{字段说明}',
    status      VARCHAR(32)     NOT NULL DEFAULT '{INIT_STATE}' COMMENT '状态（枚举见 §5.1）',
    version     INT             NOT NULL DEFAULT 0          COMMENT '乐观锁版本号',
    created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted     TINYINT(1)      NOT NULL DEFAULT 0          COMMENT '逻辑删除：0-未删除，1-已删除',
    UNIQUE KEY  uk_{table}_{field} ({field1}),
    INDEX       idx_{table}_{field} ({field2})
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='{表说明}';
```
> 注意：状态化实体建议包含 `status` 和 `version` 字段（乐观锁），DDL 中必须有索引覆盖状态查询。

---

## 8. 外部接口（本模块调用的外部系统）

| 接口名称 | 调用方 | 协议/URL | 请求/响应格式 | 说明 |
|----------|--------|----------|---------------|------|
| {接口名} | 本模块 | {协议+URL} | {格式} | {用途} |
| （无外部依赖时填"无"）| - | - | - | - |

---

## 9. 内部接口（供其他模块调用）

**接口：`{HTTP方法} {路径}`**
- **用途**：{供哪些模块调用，用于什么目的}
- **认证**：{认证方式，如内部API Key，Header名称，密钥来源}
- **成功响应** (200 OK)：
```json
{
  "{field1}": {示例值},
  "{field2}": "{示例值}"
}
```
- **调用约定**：超时 {X}s，重试最多 {N} 次，连续失败 {N} 次后熔断 {X}s

---

## 10. 性能要求

| 接口 | 响应时间（P95） | TPS目标 | 缓存策略 | 缓存失效触发 |
|------|----------------|---------|---------|-------------|
| {接口1} | ≤ {X}ms | ≥ {N} | key=`{key_pattern}`，TTL={X}分钟 | 写操作 {PUT方法路径} 执行后立即失效 |
| {接口2} | ≤ {X}ms | ≥ {N} | 无缓存 | — |

> **缓存失效规则**：明确哪些写操作触发哪些缓存的失效。不填写则 code-developer 默认写后全量失效（保守方案），可能造成不必要缓存抖动。

---

## 11. 安全要求

- **传输安全**：{HTTPS/内网/加密方式}
- **认证方式**：{JWT/OAuth2/API Key/4A}，有效期：{X}小时
- **敏感数据处理**：{密码哈希算法/脱敏规则}
- **防暴力破解**：{限流策略，如Redis计数，N次失败锁定X分钟}
- **SQL注入防护**：{ORM参数绑定/PreparedStatement}

---

## 12. 测试要点

| 测试点 | 输入 | 预期输出 | 备注 |
|--------|------|----------|------|
| {正常流程} | {具体输入值} | {HTTP状态码}，{响应字段说明} | {验证数据库/缓存状态} |
| {重复/冲突} | {触发冲突的输入} | {409/400}，错误码 {ERROR_CODE} | |
| {参数校验失败} | {不合法输入} | {400}，错误码 {ERROR_CODE} | |
| {认证失败} | {无效凭证} | {401} | |
| {限流/锁定} | {触发限流的操作序列} | {前N次401，第N+1次429} | 需Mock {Redis/计数器} |
| {状态机—非法跳转} | {当前状态S1下的非法操作} | {409}，错误码 ILLEGAL_STATUS | 验证 5.2 转换表约束 |
| {状态机—并发冲突} | 同时提交两个状态变更请求 | 第二个请求返回 {409}，错误码 CONCURRENT_MODIFY | 验证乐观锁 |
| {事务—部分失败} | 写操作中途抛出异常 | 数据库回滚，无脏数据 | |
| {补偿—外部调用失败} | 第N步（外部调用）失败 | 第N-1步回滚/补偿执行 | 验证 COMPENSATION 标记 |

---

## 13. 依赖关系

- **依赖其他模块**：{无 / 依赖 {module-x} 的 `{HTTP方法} {路径}` 接口，用于 {目的}}
- **被其他模块依赖**：{module-y}、{module-z} 依赖本模块的 `{接口路径}` 接口

---

## 文档质量检查清单

- [ ] **业务规则完整**：每条规则有编号，精确到字段约束和取值范围
- [ ] **配置来源已标注**：每个规则值标注了配置来源（硬编码/环境变量/配置文件/配置中心/注解参数）
- [ ] **接口契约完整**：每个接口有完整的 OpenAPI 3.0 定义，含所有错误响应
- [ ] **伪代码带编码约束标记**：事务边界、补偿逻辑、并发控制、finally 清理、语言特有模式均有对应标记
- [ ] **状态机完整（有状态实体模块）**：状态枚举+合法转换表+guard条件+副作用，伪代码含非法跳转校验和乐观锁
- [ ] **DDL 完整**：包含所有字段、注释、索引、外键约束；状态化实体含 status 和 version 字段
- [ ] **缓存失效规则已填写**：§10 缓存列含失效触发条件，不默认为"写后全量失效"
- [ ] **性能指标具体**：P95/P99 响应时间、TPS 目标均有数值
- [ ] **测试用例覆盖异常场景**：含状态机非法跳转、并发冲突、事务回滚、补偿执行
- [ ] **补充接口已纳入**：`_PROGRESS.md` 中本模块「补充接口（Step 2.5）」列表里的所有接口，均已出现在第1节和第3节中
- [ ] **无占位符残留**：所有 `{...}` 均已替换为项目实际内容
- [ ] **头部元数据完整**（文档编号、版本 v1.0.0、状态 🟡 草稿、创建日期、最后更新、作者、关联文档）
- [ ] **文档末尾有变更记录**，包含 v1.0.0 初始版本行

---

## 版本号变更规则

| 段位 | 触发条件 |
|------|---------|
| **MAJOR** | 模块职责根本性变化、文档推翻重写 |
| **MINOR** | 新增/删除接口，业务规则重大调整 |
| **PATCH** | 局部修正、评审意见小改、错别字 |

变更类型标记：🆕 新建 → v1.0.0 | 🐛 修正 → PATCH+1 | ✏️ 修改 → PATCH+1 | ➕ 新增 → MINOR+1 | 🗑️ 删除 → MINOR+1 | 🔄 重构 → MAJOR+1

**强绑定规则：** 头部"版本"= 变更记录最后一行版本；头部"最后更新"= 变更记录最后一行日期。

---

## 文档尾部（变更记录）

每份详细设计文档的**最后一节**必须是：

```markdown
## 变更记录

| 版本 | 日期 | 变更类型 | 变更内容摘要 | 变更人 |
|------|------|---------|------------|--------|
| v1.0.0 | YYYY-MM-DD | 🆕 新建 | 初始版本 | [作者] |
```

---

## 粒度判断标准

| 情况 | 判断 | 处理方式 |
|------|------|---------|
| 模块包含 > 5 个独立功能域 | 太大 | 按功能域拆分为多个文档 |
| 模块包含 2-5 个相关功能 | 合适 | 一个文档，多个功能节 |
| 单个功能点 | 太小 | 合并到相关模块文档中 |
| 预估工时 > 5 人天 | 建议拆分 | 按子功能拆分 |

---

