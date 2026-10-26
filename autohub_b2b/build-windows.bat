@echo off
REM Скрипт для сборки B2B приложения для Windows
REM Запускать на Windows машине с установленным Flutter

echo 🔨 Building Vinly Business for Windows...

REM Проверяем Flutter
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter не найден. Установите Flutter: https://flutter.dev/docs/get-started/install/windows
    exit /b 1
)

REM Проверяем, что мы в правильной директории
if not exist "pubspec.yaml" (
    echo ❌ Файл pubspec.yaml не найден. Запустите скрипт из корня проекта autohub_b2b
    exit /b 1
)

REM Получаем зависимости
echo 📦 Получение зависимостей...
call flutter pub get

REM Проверяем, что Windows платформа включена
echo 🔍 Проверка поддержки Windows...
call flutter config --enable-windows-desktop

REM Создаем Windows структуру если её нет
if not exist "windows" (
    echo 📁 Создание Windows структуры...
    call flutter create --platforms=windows .
)

REM Собираем release версию
echo 🏗️  Сборка release версии для Windows...
call flutter build windows --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Сборка завершена успешно!
    echo 📁 Исполняемый файл находится в: build\windows\x64\runner\Release\
    echo 🚀 Запустите: build\windows\x64\runner\Release\autohub_b2b.exe
) else (
    echo ❌ Ошибка при сборке
    exit /b 1
)

pause

