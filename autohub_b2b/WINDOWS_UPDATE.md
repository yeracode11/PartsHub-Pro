# Автообновление Windows (WinSparkle)

## Важно: Code Signing (подпись кода)

**Без подписи кода:**
- Windows будет ругаться при запуске
- SmartScreen будет блокировать приложение

**Подписывать нужно через `signtool`** (из Windows SDK) **до** загрузки в GitHub Releases:

```cmd
signtool sign /f "путь\к\сертификату.pfx" /p "пароль" /tr http://timestamp.digicert.com /td sha256 /fd sha256 "dist\1.0.0+1\autohub_b2b-1.0.0+1-windows.exe"
```

Сертификат можно получить у CA (DigiCert, Sectigo и др.) или создать самоподписанный для тестов.

---

## Первоначальная настройка (один раз)

1. **Установите OpenSSL** (если ещё нет):
   ```bash
   choco install openssl
   ```

2. **Сгенерируйте DSA-ключи** в папке `autohub_b2b/`:

   **Вариант A** — через auto_updater:
   ```bash
   cd autohub_b2b
   dart run auto_updater:generate_keys
   ```

   **Вариант B** — если ошибка `FormatException: Unexpected extension byte` (кодировка консоли Windows):
   ```cmd
   cd autohub_b2b
   chcp 65001
   dart run auto_updater:generate_keys
   ```

   **Вариант C** — вручную через OpenSSL (если auto_updater падает):
   ```cmd
   cd autohub_b2b
   openssl genpkey -genparam -algorithm DSA -out dsaparam.pem -pkeyopt dsa_paramgen_bits:2048
   openssl genpkey -paramfile dsaparam.pem -out dsa_priv.pem
   openssl dsa -in dsa_priv.pem -pubout -out dsa_pub.pem
   del dsaparam.pem
   ```

   Создаются `dsa_priv.pem` и `dsa_pub.pem`. Приватный ключ храните в секрете (GitHub Secrets).

3. **Обновите feed URL** в `lib/main.dart` — замените `YOUR_ORG` на ваш GitHub org/user.

4. **Обновите appcast.xml** в корне репозитория — замените `YOUR_ORG` в URL.

## Сборка релиза

```bash
cd autohub_b2b
flutter pub global activate flutter_distributor
flutter_distributor release --name prod --jobs windows-exe
```

## Подпись и публикация

1. **Code signing** (signtool) — подпишите .exe для Windows/SmartScreen:
   ```cmd
   signtool sign /f cert.pfx /p PASSWORD /tr http://timestamp.digicert.com /td sha256 /fd sha256 dist\1.0.0+1\autohub_b2b-1.0.0+1-windows.exe
   ```

2. **DSA-подпись** (для WinSparkle) — подпишите обновление:
   ```bash
   dart run auto_updater:sign_update dist/1.0.0+1/autohub_b2b-1.0.0+1-windows.exe
   ```

3. Вставьте `sparkle:dsaSignature` и `length` из вывода в `appcast.xml`.

4. Создайте GitHub Release, загрузите подписанный .exe.

5. Закоммитьте обновлённый `appcast.xml`.
