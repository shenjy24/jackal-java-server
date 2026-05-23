FROM eclipse-temurin:21-jdk AS builder

ARG MODULE

WORKDIR /app

COPY pom.xml .
COPY service-core/pom.xml service-core/
COPY service-client/pom.xml service-client/
COPY service-admin/pom.xml service-admin/

# 预下载依赖（利用缓存层）
RUN mvn dependency:go-offline -pl ${MODULE} -am -q

COPY . .

RUN mvn -pl ${MODULE} -am package -DskipTests -q

FROM eclipse-temurin:21-jre

ARG MODULE

WORKDIR /app

COPY --from=builder /app/${MODULE}/target/*.jar app.jar

ENTRYPOINT ["java", "-jar", "app.jar"]
