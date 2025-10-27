# Настройка мобильных приложений (B2B и B2C)

## После деплоя бэкенда на VPS

После того как вы задеплоили бэкенд на сервер, вам нужно обновить IP адреса в мобильных приложениях.

## 1. Обновите API URL в B2C приложении

**Файл:** `autohub_b2c/lib/services/api_client.dart`

Найдите строку:
```dart
static const String baseUrl = kDebugMode
    ? 'http://192.168.2.240:3000/api'  // Локальный IP для эмулятора
    : 'https://api.autohub.kz/api';   // Production URL
```

Замените на URL вашего сервера:
```dart
static const String baseUrl = kDebugMode
    ? 'http://192.168.2.240:3000/api'  // Локальный IP для разработки
    : 'https://YOUR-SERVER-IP/api';    // IP или домен вашего сервера
```

## 2. Обновите API URL в B2B приложении

**Файл:** `autohub_b2b/lib/services/api/api_client.dart`

Найдите строку:
```dart
baseUrl: 'http://localhost:3000',
```

Замените на:
```dart
baseUrl: 'https://YOUR-SERVER-IP',
```

Или используйте разные URL для dev/prod:
```dart
baseUrl: kDebugMode 
    ? 'http://localhost:3000'
    : 'https://YOUR-SERVER-IP',
```

## 3. Пересоберите приложения

```bash
# B2C приложение
cd autohub_b2c
flutter build apk --release
flutter build ios

# B2B приложение
cd autohub_b2b
flutter build apk --release
flutter build ios
```

## Важные заметки

1. **HTTPS**: Для production рекомендуется настроить SSL сертификат (Let's Encrypt бесплатный)
2. **CORS**: Убедитесь что в `.env` файле на сервере стоит `CORS_ORIGIN=*` для мобильных приложений
3. **Firebase**: Оба приложения используют Firebase, убедитесь что Firebase конфигурация актуальна

## Проверка подключения

После обновления URL, проверьте что приложения могут подключиться к серверу:

1. Запустите приложение
2. Попробуйте залогиниться или посмотреть товары
3. Проверьте логи: `flutter logs`

## Troubleshooting

### Ошибка подключения

Если приложение не может подключиться к серверу:

1. Проверьте что бэкенд запущен: `curl https://YOUR-SERVER-IP/api`
2. Проверьте firewall на сервере
3. Проверьте CORS настройки в `.env`

### Ошибка SSL

Если используется HTTPS без валидного сертификата:

1. Настройте SSL сертификат (Let's Encrypt)
2. Или временно отключите HTTPS проверку в приложении (только для dev)

