# Etapa 1: Compilación de la aplicación (Se queda igual)
FROM maven:3.8.5-openjdk-17-slim AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Etapa 2: Imagen oficial y ultra-ligera basada en ALPINE LINUX
FROM eclipse-temurin:17-jdk-alpine
WORKDIR /app

# INSTALACIÓN DE NETCAT EN ALPINE
RUN apk add --no-cache netcat-openbsd

# Copiar el archivo JAR generado en la etapa anterior
COPY --from=build /app/target/*.jar app.jar

# Copiar y configurar el script entrypoint
COPY entrypoint.sh entrypoint.sh
RUN chmod +x entrypoint.sh

# Exponer el puerto del servicio Despacho
EXPOSE 8081

# Declarar el script como el punto de entrada oficial
ENTRYPOINT ["./entrypoint.sh"]