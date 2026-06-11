# jackal-java-server

Java 21 + Spring Boot 3 多模块后端框架。由共享核心库与两个可独立部署的服务组成：

- `service-core`：共享核心库（通用配置、统一响应、异常处理、MyBatis Plus、缓存、OSS、工具类、用户域）。
- `service-admin`：管理后台服务（auth/RBAC，路由 `/admin/**`），默认本地端口 **8081**。
- `service-client`：C 端服务（用户、缓存接口，路由 `/web/**`），默认本地端口 **8080**。

`service-admin` 与 `service-client` 各自打包为可执行 jar、独立容器运行，共同依赖 `service-core`。

## 技术栈

| 类型 | 说明 |
|------|------|
| JDK | Java 21 |
| Web 框架 | Spring Boot 3 |
| 构建工具 | Maven（多模块） |
| 持久层 | MyBatis Plus |
| 数据库 | MySQL |
| 容器化 | Docker、Docker Compose |

## 模块结构

```text
jackal-java-server/                 # 父模块（packaging=pom，聚合 + 依赖/插件管理）
├── service-core/                   # 共享库（无主类）
│   └── src/main/java/com/tech/
│       ├── common/                 # 通用注解、常量、枚举
│       ├── component/              # OSS、缓存等组件封装
│       ├── config/                 # Spring、MyBatis、响应、CORS、线程池等配置
│       ├── repository/             # 用户域 Entity/DAO/Mapper/Model + BaseEntity
│       ├── service/user/           # 用户域业务逻辑
│       └── util/                   # 工具类
├── service-admin/                  # 管理后台服务（AdminApplication）
│   └── src/main/java/com/tech/
│       ├── controller/admin/       # /admin/** 接口
│       ├── config/                 # AdminWebConfig + 登录/权限拦截器
│       ├── common/                 # Permission 注解、权限枚举
│       ├── repository/.../auth/    # auth/RBAC 域
│       └── service/auth/           # 权限业务逻辑
├── service-client/                 # C 端服务（ClientApplication）
│   └── src/main/java/com/tech/
│       ├── controller/             # /web/** 接口
│       └── config/                 # ClientWebConfig + 用户登录拦截器
├── document/
│   ├── deploy/                     # 部署脚本、部署方案与中间件配置
│   └── sql/                        # 初始化 SQL
├── pom.xml
└── readme.md
```

公共基础设施（统一响应包装、全局异常、MyBatis 分页、`@MapperScan("com.tech")`、CORS、`@UserId` 解析等）集中在 `service-core`，两个服务通过组件扫描自动加载；各自的登录/权限拦截器由各模块的 `WebMvcConfigurer` 注册。

## 环境与配置

| Profile | 用途 | 数据库 |
|---------|------|--------|
| `local` | 本地开发 | `template` |
| `dev` | 测试环境 | `template` |
| `prod` | 生产环境 | `template` |

各服务的配置文件：

```text
service-core/src/main/resources/application-core.yml   # 共享基础配置（被各服务 import）
service-admin/src/main/resources/application.yml + application-{local,dev,prod}.yml
service-client/src/main/resources/application.yml + application-{local,dev,prod}.yml
```

各服务的 `application.yml` 通过 `spring.config.import: classpath:application-core.yml` 复用核心配置，再按 profile 覆盖数据源、端口、OSS bucket 等。上线前请替换数据库连接、OSS 密钥等敏感配置。

## 本地开发

启动管理后台（端口 8081）：

```bash
mvn -pl service-admin -am spring-boot:run -Dspring-boot.run.profiles=local
```

启动 C 端（端口 8080）：

```bash
mvn -pl service-client -am spring-boot:run -Dspring-boot.run.profiles=local
```

编译检查（全部模块）：

```bash
mvn -q -DskipTests compile
```

打包单个可部署模块：

```bash
mvn -pl service-admin -am -DskipTests package
mvn -pl service-client -am -DskipTests package
```

本地调试前请确认：MySQL 已创建 `template` 数据库、`application-local.yml` 中连接可用、依赖的 OSS/缓存等外部服务已配置。

## 数据库脚本

```text
document/sql/
├── production/
│   ├── ddl/    # 表结构（auth.sql、user.sql）
│   └── dml/    # 初始化数据（auth.sql：超管账号、角色、权限及绑定）
└── versioned/  # 增量变更占位（ddl.sql、dml.sql）
```

## 部署

部署方案与中间件配置统一维护在 `document/deploy/`：

```text
document/deploy/
├── deployment-plan/
│   ├── online/     # 联网部署（拉代码 + 多阶段构建），按模块发布
│   └── offline/    # 内网部署（上传 jar + 基础镜像），按模块发布
├── docker/         # Docker 缓存清理、离线镜像加载
├── maven/          # 构建用 Maven settings 示例（占位凭据）
├── mysql/          # MySQL Docker 部署与备份
├── nginx/          # Nginx 配置参考
└── software/       # 服务器基础软件安装指南
```

部署以模块为单位执行，例如联网部署：

```bash
cd document/deploy/deployment-plan/online
bash start.sh service-admin     # 部署管理后台
bash start.sh service-client    # 部署 C 端
```

默认端口：`service-client` -> `18881`，`service-admin` -> `18882`。详见：

- `document/deploy/deployment-plan/online/联网部署文档.md`
- `document/deploy/deployment-plan/offline/内网部署文档.md`

前端页面与接口路由约定如下：

- 管理后台页面：`/admin/`
- 管理后台接口：`/admin/api/**`，由 Nginx 去掉 `/admin/api` 前缀后转发到 `service-admin` 的 `/admin/**` 接口
- C 端页面：`/`
- C 端接口：`/api/**`
