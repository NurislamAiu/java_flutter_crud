FROM openjdk:17-jdk-slim

WORKDIR /app

# Скопируем собранный .jar
COPY target/*.jar app.jar

# Скопируем firebase-ключ (он будет подгружаться снаружи!)
COPY src/main/resources/firebase-admin-key.json firebase-admin-key.json

ENTRYPOINT ["java", "-jar", "app.jar"]

EXPOSE 8080