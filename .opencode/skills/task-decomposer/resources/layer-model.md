# 后端分层模型参考

> Step 2 依赖排序时加载。包含通用分层原则和各语言层次编号分配规则。

## 通用分层原则

后端代码分为5层，层间依赖方向严格单向（上层依赖下层，禁止反向）：

```
Layer 4（集成层）
    ↓ 依赖
Layer 3（接口层）
    ↓ 依赖
Layer 2（业务逻辑层）
    ↓ 依赖
Layer 1（数据访问层）
    ↓ 依赖
Layer 0（基础层）
```

每份详设文档的第13节（依赖关系）必须标注所属层次，并精确到接口路径，不得只写模块名。

## Java（Spring Boot + MyBatis）

| 层次 | 职责 | 典型类/文件 | 命名约定 |
|-----|-----|-----------|---------|
| Layer 0 | 数据模型、枚举、常量、配置 | `Entity`、`Enum`、`@Configuration` | `XxxEntity`、`XxxEnum`、`XxxConfig` |
| Layer 1 | 数据访问 | `Mapper` 接口 + MyBatis XML | `XxxMapper`、`XxxMapper.xml` |
| Layer 2 | 业务逻辑 | `Service` 接口 + `ServiceImpl` | `XxxService`、`XxxServiceImpl` |
| Layer 3 | 对外接口 | `Controller`、`@KafkaListener`、`@Scheduled` | `XxxController`、`XxxConsumer` |
| Layer 4 | 跨模块编排、外部集成 | Feign Client、外部 API 客户端 | `XxxClient`、`XxxGateway` |

关键约束：`Controller` 不得直接调用 `Mapper`；`@Transactional` 只加在 `ServiceImpl` 上；DTO 不出 `Service` 层。

## Python（FastAPI + SQLAlchemy）

| 层次 | 职责 | 典型类/文件 | 命名约定 |
|-----|-----|-----------|---------|
| Layer 0 | 数据模型、Schema、配置 | SQLAlchemy `Model`、Pydantic `Schema`、`config.py` | `XxxModel`、`XxxCreate`、`XxxResponse` |
| Layer 1 | 数据访问 | `Repository` 类（封装 SQLAlchemy Session） | `XxxRepository` |
| Layer 2 | 业务逻辑 | `Service` 类 | `XxxService` |
| Layer 3 | 对外接口 | FastAPI `Router`、Celery `Task` | `xxx_router`、`xxx_task` |
| Layer 4 | 跨模块编排、外部集成 | HTTP Client（httpx）、外部 API 封装 | `XxxClient`、`XxxGateway` |

关键约束：Pydantic Schema 分 `XxxCreate`/`XxxUpdate`/`XxxResponse` 三类，不混用；`Model` 不直接暴露给 `Router`。

## Go（Gin + GORM）

| 层次 | 职责 | 典型类/文件 | 命名约定 |
|-----|-----|-----------|---------|
| Layer 0 | 数据模型、配置 | GORM `Model` struct、`config` 包 | `Xxx` struct（model 包） |
| Layer 1 | 数据访问 | `Repository` 接口 + 实现 struct | `XxxRepository` 接口、`xxxRepository` 实现 |
| Layer 2 | 业务逻辑 | `Service` 接口 + 实现 struct | `XxxService` 接口、`xxxService` 实现 |
| Layer 3 | 对外接口 | Gin `Handler` 函数、定时任务 | `XxxHandler`、`RegisterXxxRoutes` |
| Layer 4 | 跨模块编排、外部集成 | HTTP Client、外部 API 封装 | `XxxClient`、`XxxGateway` |

关键约束：接口（interface）定义在调用方包中；`Handler` 只做参数绑定 + 调用 `Service` + 返回响应；不使用 panic（除初始化）。

## Node.js（NestJS + TypeORM / Prisma）

| 层次 | 职责 | 典型类/文件 | 命名约定 |
|-----|-----|-----------|---------|
| Layer 0 | 数据模型、DTO、配置 | TypeORM `Entity`、`CreateXxxDto`、`@Module` | `XxxEntity`、`CreateXxxDto` |
| Layer 1 | 数据访问 | TypeORM `Repository` 封装 / Prisma Client | `XxxRepository`（`@Injectable`） |
| Layer 2 | 业务逻辑 | `Service` 类 | `XxxService`（`@Injectable`） |
| Layer 3 | 对外接口 | `Controller`、`@MessagePattern` | `XxxController`（`@Controller`） |
| Layer 4 | 跨模块编排、外部集成 | HTTP Module、外部 API 封装 | `XxxClient`、`XxxGateway` |

关键约束：每个功能域对应一个 `Module`；DTO 使用 `class-validator`；`Controller` 不得直接注入 `Repository`。

## 层次编号分配规则

| 文档内容 | 层次 |
|---------|-----|
| DDL、Entity/Model、枚举、常量、配置类 | Layer 0 |
| Mapper/Repository（数据访问接口和实现） | Layer 1 |
| Service 接口和实现（业务逻辑） | Layer 2 |
| Controller/Router/Handler（对外接口） | Layer 3 |
| 跨模块编排、外部系统集成 | Layer 4 |

> 一份文档可能跨多个层次时，标注**最高层次**，并在第13节说明各层的具体依赖。

---

