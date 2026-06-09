# 语言特化检查项

> 以下各节在对应语言（`LC-001`）时加载，与通用层（维度1~5）搭配使用。按 LC-001 值跳转对应 `##` 节。

---

## Java / Spring Boot（LC-001 = java）

> 框架：Spring Boot 3.x + MyBatis / MyBatis-Plus

### J-1 Java 命名规范（补充）
- [ ] 类名使用 UpperCamelCase（如 `UserServiceImpl`）
- [ ] 方法名、变量名使用 lowerCamelCase（如 `getUserById`）
- [ ] 常量使用 UPPER_SNAKE_CASE（如 `MAX_RETRY_COUNT`）
- [ ] 包名全小写，无下划线（如 `com.example.user.service`）
- [ ] 接口名不加 `I` 前缀；实现类加 `Impl` 后缀
- [ ] 布尔字段避免 `isXxx` 命名（Lombok `@Data` + Jackson 序列化会去掉 `is` 前缀导致字段名不一致，建议使用 `active` 字段名）

### J-2 注解规范
- [ ] Service 实现类：`@Slf4j` + `@Service` + `@RequiredArgsConstructor`
- [ ] Controller：`@RestController` + `@RequestMapping` + `@Tag(name="...")`
- [ ] Entity：`@Data` + `@TableName` + `@NoArgsConstructor` + `@AllArgsConstructor`
- [ ] DTO：`@Data` + `@Schema(description="...")`
- [ ] 写操作 Service 方法：`@Transactional(rollbackFor = Exception.class)`
- [ ] 读操作 Service 方法（高并发场景）：`@Transactional(readOnly = true)`
- [ ] Controller 方法：`@Operation(summary="...")` + 参数加 `@Valid`

### J-3 工具库使用（Hutool 优先）
- [ ] 日期时间：`LocalDateTime` + `DateUtil`（Hutool），禁止 `SimpleDateFormat`（线程不安全）
- [ ] 字符串：`StrUtil`（Hutool），禁止手写 null 判断 + isEmpty
- [ ] 集合：`CollUtil`（Hutool），禁止手写 null 判断 + size()==0
- [ ] Bean 拷贝：`BeanUtil.copyProperties`（Hutool），禁止手写 getter/setter 拷贝
- [ ] HTTP 请求：`HttpUtil`（Hutool）或 `RestTemplate`/`OpenFeign`，禁止手写 `HttpURLConnection`

### J-4 SQL 注入防护（MyBatis 专项）
- [ ] MyBatis XML 中无 `${}` 拼接用户输入（ORDER BY 除外）
- [ ] ORDER BY 字段使用白名单校验
- [ ] 动态查询使用 MyBatis `<if>` 标签或 MyBatis-Plus `QueryWrapper`，禁止字符串拼接

### J-5 Spring 事务与性能
- [ ] `@Transactional` 方法内无 HTTP 请求、RPC 调用、MQ 发送、文件 I/O
- [ ] MyBatis `<collection>/<association>` 使用 `select` 属性时无 N+1 问题
- [ ] 无在循环内调用 Mapper 的情况

### J-6 可测试性与异常处理
- [ ] Service 依赖通过构造函数注入（`@RequiredArgsConstructor`），禁止 `@Autowired` 字段注入
- [ ] 全局异常处理器使用 `@RestControllerAdvice`
- [ ] 软删除使用 `deleted` 字段；创建/更新时间由 `@TableField(fill=...)` 自动填充
- [ ] 乐观锁字段（`version`）使用 `@Version` 注解正确处理

---

## Python / FastAPI / Django（LC-001 = python）

> 框架：FastAPI 或 Django REST Framework

### P-1 Python 命名规范（补充）
- [ ] 函数名、变量名使用 snake_case；类名使用 UpperCamelCase；常量使用 UPPER_SNAKE_CASE
- [ ] 模块名使用 snake_case（如 `user_service.py`）；私有方法以单下划线开头
- [ ] Pydantic Schema 类加 `Request`/`Response`/`Schema` 后缀

### P-2 装饰器与框架规范（FastAPI）
- [ ] 路由函数有 `summary` 和 `response_model` 参数（OpenAPI 文档）
- [ ] 依赖注入使用 `Depends()`，禁止在路由函数内直接实例化 Service
- [ ] 写操作 Service 在 `get_db()` 返回的 session 上操作（`get_db()` 已通过 `async with session.begin()` 启动事务，Service 层**不得**再嵌套 `async with db.begin()`，会报"A transaction is already begun"；嵌套事务用 `begin_nested()`）
- [ ] 读操作路由**无需**显式开启事务（直接使用 session 查询即可）
- [ ] 异步路由使用 `async def`；同步 CPU 密集型任务使用 `run_in_executor`

### P-3 工具库使用（Python）
- [ ] 日期时间：`datetime` 标准库或 `pendulum`，禁止手写时区转换
- [ ] 数据校验：Pydantic v2（FastAPI）或 DRF Serializer（Django），禁止手写正则校验
- [ ] 加密：`passlib`（bcrypt）或 `hashlib`，禁止手写 MD5/SHA 密码哈希
- [ ] 环境变量：`pydantic-settings` 或 `python-dotenv`，禁止 `os.environ.get` 散落各处

### P-4 SQL 注入防护（SQLAlchemy / Django ORM）
- [ ] SQLAlchemy：使用 ORM 查询或 `text()` + 参数绑定，禁止字符串拼接 SQL
- [ ] Django ORM：使用 `filter()`/`exclude()` 参数化，禁止 `raw()` 拼接用户输入
- [ ] 动态排序字段使用白名单校验；富文本输入使用 `bleach` 过滤 XSS

### P-5 异步安全与性能
- [ ] 异步函数中无阻塞 I/O（`time.sleep`/同步数据库调用）
- [ ] 共享状态使用 `asyncio.Lock` 保护
- [ ] SQLAlchemy 关联查询使用 `joinedload()`/`selectinload()` 预加载，避免 N+1
- [ ] 事务块内无 HTTP 请求、长时间等待

### P-6 可测试性与异常处理
- [ ] Service 层函数依赖通过参数注入（FastAPI `Depends`），禁止模块级全局实例
- [ ] 全局异常使用 `@app.exception_handler()` 或中间件；禁止裸 `except:` 吞掉异常
- [ ] 所有公开函数有完整类型注解；禁止 `Any` 类型滥用

---

## Go / Gin / Echo（LC-001 = go）

> 框架：Gin 或 Echo

### G-1 Go 命名规范（补充）
- [ ] 导出符号用 UpperCamelCase；未导出符号用 lowerCamelCase；包名全小写单词
- [ ] 常量使用 UpperCamelCase（导出）或 lowerCamelCase（未导出），禁止 UPPER_SNAKE_CASE
- [ ] 错误变量以 `Err` 前缀命名（如 `ErrUserNotFound`）；缩写词全大写（如 `userID`、`apiURL`）
- [ ] 接口名以行为命名，单方法接口用 `-er` 后缀

### G-2 框架规范（Gin/Echo）
- [ ] 路由注册在 `router/` 或 `handler/` 层，禁止在 `main.go` 注册业务路由
- [ ] Handler 只做参数绑定和响应，业务逻辑委托给 Service 层
- [ ] 参数绑定使用 `c.ShouldBindJSON()`/`c.ShouldBindQuery()`，禁止手动解析 `c.Request.Body`
- [ ] 认证、日志、限流中间件在路由组级别注册

### G-3 工具库使用（Go）
- [ ] 日志：`zap`（uber-go）或 `logrus`，禁止裸 `fmt.Println`/`log.Println`；禁止 `panic` 用于业务错误
- [ ] UUID：`github.com/google/uuid`；加密：`golang.org/x/crypto/bcrypt`
- [ ] 配置：`viper` 或 `envconfig`，禁止 `os.Getenv` 散落各处
- [ ] 错误必须处理，禁止 `_ = someFunc()` 忽略错误（除非有明确注释说明原因）

### G-4 SQL 注入防护（GORM / sqlx）
- [ ] GORM：使用 `Where("id = ?", id)` 参数化，禁止 `Where("id = " + id)` 字符串拼接
- [ ] GORM 更新：使用 `Updates(map[string]interface{}{...})` 部分更新，**禁止** `db.Save(entity)` 全字段更新（会将零值字段覆盖数据库原有数据）
- [ ] Repository 的 `Update` 方法签名应接收 `map[string]interface{}` 而非整个 entity struct

### G-5 goroutine 安全与性能
- [ ] 共享状态使用 `sync.Mutex`/`sync.RWMutex` 保护；并发读写 map 使用 `sync.Map`
- [ ] goroutine 有明确退出条件或 `context.Done()` 监听，无 goroutine 泄漏
- [ ] 事务函数内无 HTTP 请求、`time.Sleep()`；批量写用 `db.CreateInBatches(&records, 500)`
- [ ] GORM 关联查询使用 `Preload()` 预加载，避免 N+1

### G-6 可测试性与错误处理
- [ ] Repository/Service 层定义接口，Handler 依赖接口而非具体实现
- [ ] 错误使用 `fmt.Errorf("...: %w", err)` 包装保留错误链；使用 `errors.Is/As` 判断类型
- [ ] 资源（文件、HTTP 响应体）使用 `defer f.Close()` 关闭；Context 传递链从 Handler 到 Repository 完整

---

## Node.js / NestJS / Express（LC-001 = nodejs）

> 框架：NestJS 或 Express（TypeScript 优先）

### N-1 TypeScript 命名规范（补充）
- [ ] 类名 UpperCamelCase；函数/变量 lowerCamelCase；常量 UPPER_SNAKE_CASE；文件名 kebab-case
- [ ] 接口名风格依项目规则文档（LC-003）为准，同一项目内保持一致即可
- [ ] DTO 加 `Dto` 后缀（如 `CreateUserDto`）；枚举值使用 UPPER_SNAKE_CASE

### N-2 装饰器与框架规范（NestJS）
- [ ] Controller：`@Controller` + `@ApiTags` + `@UseGuards(JwtAuthGuard)`
- [ ] Service：`@Injectable()` + 构造函数注入依赖
- [ ] 写操作 Service 方法：使用 `@Transactional()` 或手动事务
- [ ] 参数校验：`@Body()` + `ValidationPipe`；DTO 字段加 `class-validator` 注解（`whitelist: true` 过滤未声明字段，防批量赋值漏洞）
- [ ] 权限控制：`@Roles('admin')` + `RolesGuard`

### N-3 工具库使用（Node.js）
- [ ] 日期时间：`dayjs` 或 `date-fns`，禁止 `moment`（已废弃）
- [ ] 加密：`bcrypt`/`argon2`，禁止手写 MD5/SHA 密码哈希
- [ ] 日志：`winston` 或 `pino`，禁止裸 `console.log`；生产环境禁止 `debug` 级别输出
- [ ] 配置：`@nestjs/config` 或 `dotenv`，禁止 `process.env.XXX` 散落各处

### N-4 SQL 注入与认证（TypeORM / Prisma）
- [ ] TypeORM：使用 `createQueryBuilder().where("id = :id", { id })` 参数化，禁止字符串拼接
- [ ] Prisma：使用 ORM 查询，禁止 `$queryRaw` 拼接用户输入
- [ ] 需要认证的路由使用 `@UseGuards(JwtAuthGuard)`；管理员路由加 `@Roles('admin')` + `RolesGuard`
- [ ] 使用 httpOnly Cookie 存储 Token 时必须配置 CSRF 防护（`sameSite: 'strict'` 或 `'lax'`；跨站场景使用 `csurf` 中间件或 Double Submit Cookie 模式）

### N-5 异步安全与性能
- [ ] 所有 Promise 有 `.catch()` 或 `try-catch` 处理；无未处理的 Promise rejection
- [ ] 事件监听器在不需要时调用 `removeListener()` 移除，避免内存泄漏
- [ ] TypeORM/Prisma 关联查询使用 `relations/include` 预加载，避免 N+1
- [ ] CPU 密集型任务使用 `worker_threads`，避免阻塞事件循环；禁止同步 I/O 在请求路径中

### N-6 可测试性与异常处理
- [ ] Service 依赖通过构造函数注入（NestJS DI），禁止模块级全局实例
- [ ] 全局异常过滤器使用 `@Catch()` + `ExceptionFilter`；禁止裸 `try-catch` 吞掉异常后继续执行
- [ ] 无 `any` 类型滥用（使用 `unknown` 替代，再做类型收窄）；TypeScript 编译无 error
