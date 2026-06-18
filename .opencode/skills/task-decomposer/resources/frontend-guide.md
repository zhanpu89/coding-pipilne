# 前端 / 小程序设计指南（大纲）

Step 4 加载。按 `LC-FE-001` 选框架。标准框架设计模式 AI 已知。

## Web 前端

- LC-FE-001 = Vue3 → Composition API + Pinia
- LC-FE-001 = React → Hooks + Zustand
- 组件结构：按功能拆分，单一职责
- 状态管理：全局（store）+ 本地（ref/useState）
- API 层：统一 intercept 处理 token/错误
- 路由：懒加载，路由守卫鉴权

## 微信小程序

- 页面栈：Tab 页平铺，非 Tab 页层级控制 ≤ 5
- 登录流程：wx.login → code → 后端换取 token
- 分包策略：主包 ≤ 2MB，按模块分包
- 支付：wx.requestPayment
