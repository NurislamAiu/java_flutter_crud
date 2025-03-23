# Java + Flutter Web + Firebase CRUD

Полноценное CRUD-приложение с:
- 🧠 Backend на Java (Spring Boot + Firebase Admin SDK)
- 🌐 Frontend на Flutter Web
- 🐳 Запуском через Docker + docker-compose

---

## 🚀 Быстрый старт

### 1. Клонируй репозиторий
```bash
git clone https://github.com/<your-username>/java_flutter_crud.git
cd java_flutter_crud
```

### 2. Собери Flutter Web
```bash
cd frontend
flutter build web --dart-define=API_URL=http://backend:8080/api/tasks
cd ..
```

### 3. Собери backend (Spring Boot)
```bash
cd backend
mvn clean package
cd ..
```

### 4. Подключи Firebase Admin SDK
1. Перейди в [Firebase Console](https://console.firebase.google.com)
2. Создай или выбери проект
3. Перейди в "Настройки проекта" → "Сервисные аккаунты"
4. Сгенерируй новый закрытый ключ
5. Помести файл `firebase-admin-key.json` в:
```
backend/src/main/resources/firebase-admin-key.json
```

> ⚠️ Важно: этот файл должен быть **в `.gitignore`** и не должен попадать в публичный репозиторий!

---

## 🐳 Запуск через Docker

```bash
docker-compose up --build
```

### 📂 После запуска:
- Flutter Web UI: [http://localhost:8081](http://localhost:8081)
- Java Backend API: [http://localhost:8080/api/tasks](http://localhost:8080/api/tasks)

---

## 📁 Структура проекта

```
java_flutter_crud/
├── backend/          # Java Spring Boot + Firebase
│   ├── src/
│   ├── pom.xml
│   └── Dockerfile
├── frontend/         # Flutter Web
│   ├── lib/
│   ├── web/
│   ├── pubspec.yaml
│   └── Dockerfile
├── docker-compose.yml
└── README.md
```

---

## 📦 Возможности

- [x] Добавление задач в Firestore через backend
- [x] Получение и отображение списка задач
- [x] Удаление задач
- [x] Подключение к Firebase через Admin SDK

---

## 🛠 Планы на будущее
- [ ] Авторизация через Firebase Auth
- [ ] Обновление задач (PUT)
- [ ] Хранение пользователей
- [ ] Продакшн-деплой

---

## 📬 Обратная связь

> Сделано Nurislam Ilyasov 🙌

Если есть идеи, баги или предложения — создавай issue или пиши в Telegram 😄

