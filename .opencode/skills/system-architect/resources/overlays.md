# 语言技术栈特化规则

按 LC-001 跳转。本项目的框架栈选型速查（Low-code 高复用项，编码阶段依此锁定，不重复选型）。"AI 已知"的标准框架知识不写这里——只写"本项目锁定用这套"。

## Java

- 认证：Spring Security + JWT（Access 15min + Refresh 7d），Redis 黑名单吊销
- 密码：BCryptPasswordEncoder（cost=12）
- ORM：Spring Data JPA / MyBatis-Plus
- API：RESTful，Swagger/OpenAPI 3.0

## Python

- 认证：FastAPI `Depends()` + `python-jose` JWT
- 密码：`passlib` + `bcrypt`
- ORM：SQLAlchemy 2.0 async
- API：FastAPI，Pydantic v2

## Go

- 认证：`gin` middleware + `golang-jwt`
- 密码：`golang.org/x/crypto/bcrypt`
- ORM：GORM
- API：Gin，`swaggo/swag`

## Node.js

- 认证：`passport` + `jsonwebtoken`
- 密码：`bcrypt`
- ORM：TypeORM / Prisma
- API：NestJS / Express，`@nestjs/swagger`
