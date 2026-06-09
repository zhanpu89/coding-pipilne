# 语言专属测试代码模式参考

> 按 LC-001 跳转对应语言章节，只加载当前语言部分即可。

## 目录（快速跳转）
- [Java（JUnit 5 + Mockito + MockMvc）](#java)
- [Python（pytest + httpx）](#python)
- [Node.js / TypeScript（Jest + Supertest）](#nodejs)
- [Go（testing + testify）](#go)

---
<!-- Java 开始 -->

## Java

> **适用**：LC-001 = Java，LC-006 = JUnit 5。栈：Spring Boot + JUnit 5 + Mockito + MockMvc。

### A-1. 项目测试依赖（pom.xml）

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>com.h2database</groupId>
    <artifactId>h2</artifactId>
    <scope>test</scope>
</dependency>
```

### A-2. 单元测试骨架（Service 层）

```java
@ExtendWith(MockitoExtension.class)
@DisplayName("用户服务单元测试")
class UserServiceTest {
    @Mock private UserMapper userMapper;
    @InjectMocks private UserServiceImpl userService;

    @Test
    @DisplayName("TC-USR-UNIT-001 | 正常注册成功")
    void register_whenValidInput_shouldReturnUserId() {
        given(userMapper.selectByUsername("testuser")).willReturn(null);
        given(userMapper.insert(any(User.class))).willReturn(1);
        RegisterRequest req = new RegisterRequest("testuser", "Abc12345", "test@example.com");
        Long userId = userService.register(req);
        assertThat(userId).isNotNull().isPositive();
        then(userMapper).should().insert(any(User.class));
    }

    @Test
    @DisplayName("TC-USR-UNIT-002 | 用户名已存在应抛出异常")
    void register_whenUsernameExists_shouldThrowException() {
        given(userMapper.selectByUsername("existinguser")).willReturn(new User());
        assertThatThrownBy(() -> userService.register(new RegisterRequest("existinguser", "Abc12345", null)))
            .isInstanceOf(BusinessException.class)
            .hasFieldOrPropertyWithValue("code", "USER_ALREADY_EXISTS");
    }

    @ParameterizedTest
    @DisplayName("TC-USR-UNIT-003 | 弱密码应全部失败")
    @ValueSource(strings = {"12345678", "abcdefgh", "ABCDEFGH"})
    void validatePassword_whenWeakPassword_shouldFail(String weak) {
        assertThatThrownBy(() -> userService.validatePassword(weak))
            .isInstanceOf(BusinessException.class);
    }
}
```

### A-3. Mock 策略速查

```java
given(mapper.selectById(1L)).willReturn(entity);
given(mapper.insert(any())).willThrow(new DataAccessException("err") {});
willDoNothing().given(redisTemplate).delete(anyString());
then(mapper).should(times(1)).insert(any());
then(mapper).should(never()).delete(anyLong());
ArgumentCaptor<User> cap = ArgumentCaptor.forClass(User.class);
then(mapper).should().insert(cap.capture());
assertThat(cap.getValue().getUsername()).isEqualTo("testuser");
```

### A-4. 集成测试骨架（Controller 层）

```java
@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test") @Transactional
class UserControllerIntegrationTest {
    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;

    @Test @Sql("/test-data/clean-users.sql")
    @DisplayName("TC-USR-INTG-001 | POST /api/users/register | 正常返回201")
    void register_success() throws Exception {
        mockMvc.perform(post("/api/users/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                    new RegisterRequest("newuser", "Abc12345", "new@example.com"))))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.code").value("SUCCESS"));
    }

    @Test @DisplayName("TC-USR-INTG-002 | GET /api/users/profile | 无Token返回401")
    void getProfile_withoutToken_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/users/profile")).andExpect(status().isUnauthorized());
    }
}
```

### A-5. 幂等 / 安全 / 缓存场景

```java
// 幂等性
void submit_whenDuplicateRequestId() {
    String rid = UUID.randomUUID().toString();
    OrderResponse r1 = orderService.createOrder(req, rid);
    OrderResponse r2 = orderService.createOrder(req, rid);
    assertThat(r2.getOrderId()).isEqualTo(r1.getOrderId());
    then(orderMapper).should(times(1)).insert(any());
}

// SQL注入
void login_withSqlInjection_shouldBeRejected() throws Exception {
    mockMvc.perform(post("/api/users/login").contentType(APPLICATION_JSON)
            .content("{\"username\":\"admin' OR '1'='1\",\"password\":\"pwd\"}"))
        .andExpect(status().isBadRequest());
}
```

### A-6. 覆盖率目标

- Service 层行覆盖 ≥ 80%，分支覆盖 ≥ 70%；Entity/DTO/Config 排除
- 执行：`./mvnw test -pl {模块} -Dtest={TestClass}`

---

## Python

> **适用**：LC-001 = Python，LC-006 = pytest。栈：FastAPI + pytest + httpx。

### B-1. 测试依赖（requirements-test.txt）

```
pytest>=8.2.0
pytest-asyncio>=0.23.0
pytest-cov>=5.0.0
httpx>=0.27.0
anyio>=4.4.0
factory-boy>=3.3.0
faker>=25.0.0
```

```toml
# pyproject.toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
addopts = ["--cov=src", "--cov-report=term-missing", "--cov-fail-under=80"]
```

### B-2. 单元测试骨架（Service 层）

```python
import pytest
from unittest.mock import AsyncMock

@pytest.fixture
def mock_repo(): return AsyncMock()

@pytest.fixture
def service(mock_repo): return {Module}Service(repo=mock_repo)

class Test{Module}Service:
    @pytest.mark.asyncio
    async def test_{method}_success(self, service, mock_repo):
        """TC-{MOD}-UNIT-001 | 正常流程成功"""
        mock_repo.find_by_{field}.return_value = None
        mock_repo.create.return_value = {EntityName}(id=1)
        result = await service.{method}(request)
        assert result is not None
        mock_repo.create.assert_called_once()

    @pytest.mark.asyncio
    async def test_{method}_duplicate_raises(self, service, mock_repo):
        """TC-{MOD}-UNIT-002 | 重复时抛出异常"""
        mock_repo.find_by_{field}.return_value = {EntityName}(id=99)
        with pytest.raises(BusinessException) as exc:
            await service.{method}(request)
        assert exc.value.code == ErrorCode.{MOD}_DUPLICATE.code

    @pytest.mark.asyncio
    @pytest.mark.parametrize("{field},err", [("", "不能为空"), ("a"*201, "超限")])
    async def test_{method}_boundary(self, service, {field}, err):
        """TC-{MOD}-UNIT-003 | 边界值"""
        pass  # Pydantic 在 Schema 层校验；Service 层只测业务规则边界
```

### B-3. Mock 策略速查

```python
mock_repo.find_by_id.return_value = entity
mock_repo.create.side_effect = Exception("DB error")
mock_repo.create.assert_called_once()
actual = mock_repo.create.call_args[0][0]
assert actual.{field} == "{预期值}"
```

### B-4. 集成测试骨架（FastAPI Router）

```python
@pytest.fixture
async def async_client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c

class Test{Module}Router:
    @pytest.mark.asyncio
    async def test_create_success(self, async_client, auth_headers):
        """TC-{MOD}-INTG-001 | POST /api/v1/{resources} | 正常创建返回201"""
        with patch("src.{module}.router.get_{module}_service") as m:
            m.return_value.{method}.return_value = {Function}Response(id=1)
            resp = await async_client.post("/api/v1/{resources}",
                json={{"{field}": "{值}"}}, headers=auth_headers)
        assert resp.status_code == 201 and resp.json()["data"]["id"] == 1

    @pytest.mark.asyncio
    async def test_unauthorized(self, async_client):
        """TC-{MOD}-INTG-002 | 无Token返回401"""
        resp = await async_client.get("/api/v1/{resources}/1")
        assert resp.status_code == 401
```

### B-5. 测试数据库（SQLite 内存）

```python
TEST_DB = "sqlite+aiosqlite:///:memory:"

@pytest.fixture(scope="session")
async def engine():
    eng = create_async_engine(TEST_DB)
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield eng
    await eng.dispose()

@pytest.fixture
async def db_session(engine):
    async_session = async_sessionmaker(engine, expire_on_commit=False)
    async with async_session() as s:
        async with s.begin():
            yield s
            await s.rollback()
```

### B-6. 覆盖率目标

- 整体行覆盖 ≥ 80%；排除 migrations/config/main
- 执行：`pytest src/test/{模块}/ -v --tb=short`

---

## Node.js

> **适用**：LC-001 = Node.js/TypeScript，LC-006 = Jest。栈：NestJS + Jest + Supertest。

### C-1. 依赖配置（package.json devDependencies）

```json
{
  "jest": "^29.7.0",
  "@types/jest": "^29.5.12",
  "ts-jest": "^29.1.4",
  "@nestjs/testing": "^10.3.0",
  "supertest": "^7.0.0",
  "sqlite3": "^5.1.7"
}
```

### C-2. jest.config.ts（覆盖率门槛）

```typescript
const config: Config = {
  moduleFileExtensions: ['js', 'json', 'ts'], rootDir: 'src',
  testRegex: '.*\\.spec\\.ts$', transform: { '^.+\\.(t|j)s$': 'ts-jest' },
  testEnvironment: 'node',
  coverageThreshold: {
    global: { branches: 70, functions: 80, lines: 80, statements: 80 },
    './src/**/*.service.ts': { branches: 80, functions: 90, lines: 90, statements: 90 },
  },
};
export default config;
```

### C-3. 单元测试骨架（Service 层）

```typescript
describe('{Module}Service', () => {
  let service: {Module}Service;
  let repo: jest.Mocked<{EntityName}Repository>;

  beforeEach(async () => {
    const mockRepo = {
      findById: jest.fn(), findBy{Field}: jest.fn(),
      create: jest.fn(), update: jest.fn(), softDelete: jest.fn(),
    } as any;
    const m = await Test.createTestingModule({
      providers: [{Module}Service, { provide: {EntityName}Repository, useValue: mockRepo }],
    }).compile();
    service = m.get({Module}Service);
    repo    = m.get({EntityName}Repository);
  });

  it('TC-{MOD}-UNIT-001 | 正常流程成功', async () => {
    repo.findBy{Field}.mockResolvedValue(null);
    repo.create.mockResolvedValue({ id: 1 } as any);
    const result = await service.{methodName}(dto);
    expect(result.id).toBe(1);
    expect(repo.create).toHaveBeenCalledTimes(1);
  });

  it('TC-{MOD}-UNIT-002 | 重复时抛出 BusinessException', async () => {
    repo.findBy{Field}.mockResolvedValue({ id: 99 } as any);
    await expect(service.{methodName}(dto)).rejects.toMatchObject({
      errorCode: ErrorCode.{MOD}_DUPLICATE,
    });
  });
});
```

### C-4. Mock 策略速查

```typescript
repo.findById.mockResolvedValue(entity);
repo.create.mockRejectedValue(new Error('DB error'));
repo.create.mockImplementation(async (d) => ({ id: 1, ...d }));
expect(repo.create).toHaveBeenCalledWith(expect.objectContaining({ {field}: '{值}' }));
beforeEach(() => jest.clearAllMocks());
```

### C-5. 集成测试骨架（Controller 层）

```typescript
describe('{Module}Controller (e2e)', () => {
  let app: INestApplication;
  let svc: jest.Mocked<{Module}Service>;

  beforeEach(async () => {
    const mockSvc = { {methodName}: jest.fn(), get{Resource}ById: jest.fn() } as any;
    const m = await Test.createTestingModule({
      controllers: [{Module}Controller],
      providers: [{ provide: {Module}Service, useValue: mockSvc }],
    }).compile();
    app = m.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    app.useGlobalFilters(new GlobalExceptionFilter());
    await app.init();
    svc = m.get({Module}Service);
  });
  afterEach(() => app.close());

  it('TC-{MOD}-INTG-001 | POST | 正常创建返回201', async () => {
    svc.{methodName}.mockResolvedValue({ id: 1 } as any);
    const resp = await request(app.getHttpServer())
      .post('/api/v1/{resources}').send({ {field}: '{值}' })
      .set('Authorization', 'Bearer test-token').expect(201);
    expect(resp.body.code).toBe(0);
  });

  it('TC-{MOD}-INTG-002 | 无Token返回401', async () => {
    await request(app.getHttpServer()).get('/api/v1/{resources}/1').expect(401);
  });
});
```

### C-6. 覆盖率目标

- 整体 ≥ 80%；Service 层 ≥ 90%；排除 module/dto/entity/main
- 执行：`npx jest --testPathPattern={模块} --verbose`
- npm 脚本：`test:cov`（`jest --coverage`）、`test:ci`（`jest --coverage --ci --forceExit`）

---

## Go

> **适用**：LC-001 = Go，LC-006 = testing。栈：Gin + testing + testify/mock + httptest。

### D-1. 依赖（go.mod）

```go
require (
    github.com/stretchr/testify v1.9.0
    github.com/stretchr/mock   v1.6.0
    github.com/DATA-DOG/go-sqlmock v1.5.0
    github.com/alicebob/miniredis/v2 v2.33.0
)
```

### D-2. 单元测试骨架（Service 层）

```go
package {module}_test

type Mock{EntityName}Repository struct{ mock.Mock }

func (m *Mock{EntityName}Repository) FindByID(ctx context.Context, id uint) (*{module}.{EntityName}, error) {
    args := m.Called(ctx, id)
    if args.Get(0) == nil { return nil, args.Error(1) }
    return args.Get(0).(*{module}.{EntityName}), args.Error(1)
}
func (m *Mock{EntityName}Repository) Create(ctx context.Context, e *{module}.{EntityName}) error {
    return m.Called(ctx, e).Error(0)
}

func setup() (*Mock{EntityName}Repository, {module}.{Module}Service) {
    r := new(Mock{EntityName}Repository)
    logger, _ := zap.NewDevelopment()
    return r, {module}.New{Module}Service(r, logger)
}

// TestCreate{Resource}_Success TC-{MOD}-UNIT-001 | 正常流程成功
func TestCreate{Resource}_Success(t *testing.T) {
    mockRepo, svc := setup()
    req := &{module}.{Function}Request{{Field1}: "{值}"}
    mockRepo.On("FindBy{Field}", mock.Anything, req.{Field1}).Return(nil, nil)
    mockRepo.On("Create", mock.Anything, mock.AnythingOfType("*{module}.{EntityName}")).
        Return(nil).Run(func(args mock.Arguments) {
            args.Get(1).(*{module}.{EntityName}).ID = 1
        })
    result, err := svc.{MethodName}(context.Background(), req)
    assert.NoError(t, err)
    assert.Equal(t, uint(1), result.ID)
    mockRepo.AssertExpectations(t)
}

// TestCreate{Resource}_Duplicate TC-{MOD}-UNIT-002 | 重复时返回错误
func TestCreate{Resource}_Duplicate(t *testing.T) {
    mockRepo, svc := setup()
    mockRepo.On("FindBy{Field}", mock.Anything, mock.Anything).
        Return(&{module}.{EntityName}{ID: 99}, nil)
    _, err := svc.{MethodName}(context.Background(), &{module}.{Function}Request{{Field1}: "{冲突值}"}})
    bizErr, ok := err.(*errors.BusinessError)
    assert.True(t, ok)
    assert.Equal(t, errors.Err{Mod}Duplicate.Code, bizErr.Code)
}
```

### D-3. Mock 策略速查

```go
mockRepo.On("FindByID", mock.Anything, uint(1)).Return(entity, nil)
mockRepo.On("Create", mock.Anything, mock.Anything).Return(errors.New("DB error"))
mockRepo.On("Create", mock.Anything, mock.Anything).Return(nil).
    Run(func(args mock.Arguments) { args.Get(1).(*Entity).ID = 1 })
mockRepo.AssertExpectations(t)
```

### D-4. 集成测试骨架（Handler 层）

```go
func TestCreate{Resource}_Handler_Success(t *testing.T) {
    gin.SetMode(gin.TestMode)
    mockSvc := new(Mock{Module}Service)
    mockSvc.On("{MethodName}", mock.Anything, mock.Anything).
        Return(&{module}.{Function}Response{ID: 1}, nil)
    handler := {module}.New{Module}Handler(mockSvc, zap.NewNop())
    r := gin.New()
    handler.RegisterRoutes(r.Group("/api/v1"))

    body, _ := json.Marshal(map[string]string{{"{field1}": "{值}"}})
    req := httptest.NewRequest(http.MethodPost, "/api/v1/{resources}", bytes.NewBuffer(body))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()
    r.ServeHTTP(w, req)
    assert.Equal(t, http.StatusCreated, w.Code)
}

func TestGet{Resource}_Handler_NotFound(t *testing.T) {
    gin.SetMode(gin.TestMode)
    mockSvc := new(Mock{Module}Service)
    mockSvc.On("Get{Resource}ByID", mock.Anything, uint(999)).
        Return(nil, errors.NewBusinessError(errors.Err{Mod}NotFound))
    handler := {module}.New{Module}Handler(mockSvc, zap.NewNop())
    r := gin.New()
    handler.RegisterRoutes(r.Group("/api/v1"))
    req := httptest.NewRequest(http.MethodGet, "/api/v1/{resources}/999", nil)
    w := httptest.NewRecorder()
    r.ServeHTTP(w, req)
    assert.Equal(t, http.StatusBadRequest, w.Code)
}
```

### D-5. 覆盖率目标

```bash
go test ./internal/{模块}/... -v -race -coverprofile=coverage.out -covermode=atomic
go tool cover -html=coverage.out -o coverage.html
# CI 门禁：覆盖率 < 80% 时退出
go tool cover -func=coverage.out | grep total | awk '{if ($3+0 < 80) exit 1}'
```

- 执行：`go test ./internal/{模块}/... -v -count=1`
