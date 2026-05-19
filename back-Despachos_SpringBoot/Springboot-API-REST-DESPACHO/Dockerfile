FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build
COPY pom.xml .                  
COPY src ./src                   
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jdk AS runner
WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar
COPY entrypoint.sh /entrypoint.sh
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]