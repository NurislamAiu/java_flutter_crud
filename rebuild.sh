#!/bin/bash

set -e

cd frontend
flutter build web --dart-define=API_URL=http://backend:8080/api/tasks
cd ..

cd backend
mvn clean package
cd ..


docker-compose up --build
