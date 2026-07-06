FROM maven:3.9.11-eclipse-temurin-21 AS builder

# 要构建的可部署模块：service-admin / service-client
ARG MODULE

WORKDIR /app

# 先复制父 POM 与各模块 POM，利用 Docker 缓存层预下载依赖
COPY pom.xml .
COPY .mvn/settings.xml /app/.mvn/settings.xml
COPY service-core/pom.xml service-core/
COPY service-admin/pom.xml service-admin/
COPY service-client/pom.xml service-client/

# 只为目标模块及其依赖(-am)预拉取依赖
RUN mvn -s /app/.mvn/settings.xml -pl ${MODULE} -am dependency:go-offline -q

COPY . .

# 仅构建目标模块及其依赖模块
RUN mvn -s /app/.mvn/settings.xml -pl ${MODULE} -am package -DskipTests -q

FROM eclipse-temurin:21-jre

ARG MODULE
ARG APP_UID=1000
ARG APP_GID=1000

WORKDIR /app

RUN if ! getent group ${APP_GID} >/dev/null; then groupadd -g ${APP_GID} app; fi \
    && if ! getent passwd ${APP_UID} >/dev/null; then useradd --no-log-init -u ${APP_UID} -g ${APP_GID} -d /app -s /usr/sbin/nologin app; fi \
    && mkdir -p /app/logs \
    && chown -R ${APP_UID}:${APP_GID} /app

COPY --chown=${APP_UID}:${APP_GID} --from=builder /app/${MODULE}/target/*.jar app.jar

USER ${APP_UID}:${APP_GID}

ENTRYPOINT ["java", "-XX:+UseG1GC", "-XX:+UseContainerSupport", "-XX:InitialRAMPercentage=75.0", "-XX:MaxRAMPercentage=75.0", "-XX:+ExitOnOutOfMemoryError", "-XX:+HeapDumpOnOutOfMemoryError", "-XX:HeapDumpPath=/app/logs", "-jar", "app.jar"]
