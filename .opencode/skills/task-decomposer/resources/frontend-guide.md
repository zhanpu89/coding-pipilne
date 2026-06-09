# 前端 / 小程序设计指南

> Step 4 生成前端/小程序详设前加载。设计指南按端合并于同一文件，按 `##` 节跳转。

## Web 前端设计指南

### 框架选择依据

根据 `项目规则.md` 中的 `LC-FE-001` 值决定使用哪套模式：

| LC-FE-001 值 | 使用模式 |
|------------|---------|
| `Vue3` | Vue3 Composition API + Pinia |
| `React` | React Hooks + Zustand |

## 第一章：Vue3 设计模式

### 1.1 组件结构规范

```vue
<script setup lang="ts">
// 1. 导入
import { ref, reactive, computed, onMounted } from 'vue'
import { useXxxStore } from '@/stores/xxx'
import { useXxx } from '@/composables/useXxx'

// 2. Store
const xxxStore = useXxxStore()
// 3. Composable
const { loading, list, fetchList } = useXxx()
// 4. 本地状态
const visible = ref(false)
const formData = reactive<XxxType>({ ... })
// 5. 计算属性
const isValid = computed(() => ...)
// 6. 方法
async function handleSubmit() { ... }
// 7. 生命周期
onMounted(() => { fetchList() })
</script>
```

### 1.2 状态管理（Pinia）

- 每个业务域对应一个 Store（`stores/useXxxStore.ts`）
- 使用 Composition API 风格（`defineStore(id, setup函数)`），不用 Options 风格
- Store 中的 Action 负责调用 API 并更新 State；跨组件共享的数据放 Store，页面内部临时状态用 `ref/reactive`

### 1.3 Composable 设计规范

```typescript
export function useXxx(options?: XxxOptions) {
  const loading = ref(false)
  async function fetchData() { ... }
  onMounted(fetchData)
  return { loading, fetchData }
}
```

命名规范：`use` + 业务名（驼峰），如 `useUserList`、`useOrderForm`

### 1.4 路由（Vue Router 4）

```typescript
// 路由懒加载（必须）
component: () => import('@/views/xxx/XxxPage.vue')

// 路由 meta 标准字段
meta: {
  title: '页面标题',
  requiresAuth: true,
  roles: ['ROLE_ADMIN'],
  keepAlive: false,
}
```

## 第二章：React 设计模式

### 2.1 组件结构规范

```tsx
export default function XxxPage({ ...props }: XxxPageProps) {
  // 1. Store
  const { data, fetchData } = useXxxStore()
  // 2. Custom Hook
  const { loading, list } = useXxx()
  // 3. 本地状态
  const [visible, setVisible] = useState(false)
  // 4. 派生状态（useMemo）
  const isValid = useMemo(() => ..., [formData])
  // 5. 回调（useCallback）
  const handleSubmit = useCallback(async () => { ... }, [formData])
  // 6. 副作用
  useEffect(() => { fetchData() }, [])
  return ( <div>...</div> )
}
```

### 2.2 状态管理（Zustand）

- 每个业务域对应一个 Store（`stores/xxxStore.ts`）
- 使用 `immer` 中间件处理嵌套对象更新
- 避免在 Store 中存储派生数据，用 `useMemo` 在组件中计算

### 2.3 Custom Hook 设计规范

```typescript
export function useXxx(options?: XxxOptions) {
  const [loading, setLoading] = useState(false)
  const fetchData = useCallback(async () => {
    setLoading(true)
    try { ... } finally { setLoading(false) }
  }, [/* 依赖项 */])
  useEffect(() => { fetchData(); return () => { /* 清理 */ } }, [fetchData])
  return { loading, fetchData }
}
```

### 2.4 路由（React Router 6）

```tsx
const XxxPage = lazy(() => import('@/pages/xxx/XxxPage'))
<Suspense fallback={<PageSkeleton />}><XxxPage /></Suspense>
<ProtectedRoute roles={['ROLE_ADMIN']}><XxxPage /></ProtectedRoute>
```

## 第三章：共同规范（Vue3 和 React 均适用）

### API 层封装

所有 API 调用必须封装在独立的 API 模块中，不在组件/页面中直接写 `axios.get`：

```typescript
// api/xxxApi.ts
export const xxxApi = {
  getList: (params: XxxListParams) => request.get<XxxListResponse>('/api/xxx', { params }),
  create: (data: CreateXxxDto) => request.post<{ id: string }>('/api/xxx', data),
  update: (id: string, data: Partial<CreateXxxDto>) => request.put(`/api/xxx/${id}`, data),
  delete: (id: string) => request.delete(`/api/xxx/${id}`),
}
```

### TypeScript 类型规范

- 与后端 DTO 字段名保持一致（来自后端详设第3节 OpenAPI 定义）
- `XxxVO`（后端返回视图对象）、`CreateXxxDto`（创建请求体）、`PageResult<T>`（分页结果）

### 错误处理统一拦截

在 `utils/request.ts` 的响应拦截器中统一处理 401/403/500，组件层只处理**业务特定错误**。

---


---

## 微信小程序设计指南

### 框架选择说明

| LC-MP-001 值 | 框架 | 说明 |
|---|-----|-----|
| `MiniApp-Native` | 原生小程序 | 使用微信官方 WXML/WXSS/JS/JSON，性能最优 |
| `MiniApp-Taro` | Taro 3.x | React 语法，编译为小程序 |
| `MiniApp-UniApp` | uni-app | Vue 语法，编译为小程序 |

## 目录结构规范（原生小程序）

```
miniprogram/
├── app.js / app.json / app.wxss
├── pages/{domain}/{page}/        # 主包页面
├── package{A}/pages/             # 分包
├── components/                   # 公共组件
└── utils/
    ├── request.js                # 网络请求封装
    ├── auth.js                   # 登录/token 管理
    └── cache.js                  # 缓存工具（含过期机制）
```

## 登录流程规范

```
App.onLaunch：wx.getStorageSync('token')
    ├─ token 存在 → 调用后端 /api/auth/verify 验证 token 有效性
    │       ├─ 有效 → 正常进入
    │       └─ 无效（401）→ 清除 token，进入静默登录流程
    └─ token 不存在 → 进入静默登录流程

静默登录流程：
    wx.login() → 获取 code
    → 调用后端 POST /api/auth/miniapp/login（body: { code }）
    → 后端返回 token + userInfo
    → wx.setStorageSync('token', token) + wx.setStorageSync('userInfo', userInfo)
```

## 页面跳转规范

| 场景 | API | 说明 |
|-----|-----|-----|
| 普通页面跳转（可返回） | `wx.navigateTo` | 保留当前页面，最多10层 |
| 替换当前页面（不可返回） | `wx.redirectTo` | 关闭当前页面 |
| 跳转 tabBar 页面 | `wx.switchTab` | 关闭所有非 tabBar 页面 |
| 返回上一页 | `wx.navigateBack` | `delta` 参数控制返回层数 |

**跨页面传参**：简单参数用 URL 拼接；复杂对象用 `EventChannel`；返回时传值用 `EventChannel.emit`，不用 `globalData`。

## 性能优化规范

**setData 使用约束**：
- 合并为一次 `setData`，禁止在循环中频繁调用
- 单次 `setData` 数据量不超过 **1MB**
- 更新列表单条数据用路径语法：`this.setData({ 'list[0].status': newStatus })`

**长列表优化**：超过 **50条** 的列表使用虚拟列表；每页不超过 **20条**。

## 微信支付设计规范

```
用户点击「支付」
    ↓
前端调用后端 POST /api/order/prepay（body: { orderId }）
    ↓
后端调用微信统一下单 API，返回支付参数
    ↓
前端调用 wx.requestPayment(payParams)
    ├─ 成功 → 调用后端 GET /api/order/{id}/status 查询最终状态（不信任前端回调）
    └─ 失败
        ├─ fail cancel → 用户取消，Toast 提示，不报错
        └─ 其他失败 → wx.showModal 显示原因，提供重试按钮
```

支付安全：支付结果以后端查询为准；支付参数（sign）由后端生成；订单金额在后端校验。

## 分包设计决策树

```
该页面是否在 tabBar 中？
    ├─ 是 → 必须放主包
    └─ 否 → 是否在首屏加载路径上？
                ├─ 是 → 放主包
                └─ 否 → 是否被多个分包共同依赖？
                            ├─ 是 → 放主包（避免分包间互相依赖）
                            └─ 否 → 放对应功能域的分包
```

主包目标：**< 1MB**（为后续迭代留出空间）。

## 错误边界与降级设计

| 场景 | 降级方案 |
|-----|---------|
| 接口请求失败 | 显示空状态组件 + 重试按钮，不白屏 |
| 图片加载失败 | `binderror` 事件替换为默认占位图 |
| 微信 API 不支持（低版本） | `wx.canIUse` 检测，不支持时隐藏功能入口 |
| 分包加载失败 | 捕获 `wx.navigateTo` 的 fail 回调，提示用户重试 |

---

