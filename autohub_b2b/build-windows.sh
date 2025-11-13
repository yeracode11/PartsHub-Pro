#!/bin/bash

# Скрипт для сборки B2B приложения для Windows
# Запускать на Windows машине с установленным Flutter

echo "🔨 Building AutoHub B2B for Windows..."

# Проверяем Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter не найден. Установите Flutter: https://flutter.dev/docs/get-started/install/windows"
    exit 1
fi

# Проверяем, что мы в правильной директории
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Файл pubspec.yaml не найден. Запустите скрипт из корня проекта autohub_b2b"
    exit 1
fi

# Получаем зависимости
echo "📦 Получение зависимостей..."
flutter pub get

# Проверяем, что Windows платформа включена
echo "🔍 Проверка поддержки Windows..."
flutter config --enable-windows-desktop

# Создаем Windows структуру если её нет
if [ ! -d "windows" ]; then
    echo "📁 Создание Windows структуры..."
    flutter create --platforms=windows .
fi

# Собираем release версию
echo "🏗️  Сборка release версии для Windows..."
flutter build windows --release

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Сборка завершена успешно!"
    echo "📁 Исполняемый файл находится в: build/windows/x64/runner/Release/"
    echo "🚀 Запустите: build/windows/x64/runner/Release/autohub_b2b.exe"
else
    echo "❌ Ошибка при сборке"
    exit 1
fi

