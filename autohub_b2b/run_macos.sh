#!/bin/bash

# AutoHub B2B - Quick Launch Script for macOS

echo "🚀 AutoHub B2B - Запуск приложения на macOS"
echo "============================================"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter не установлен. Установите Flutter: https://flutter.dev"
    exit 1
fi

echo "✅ Flutter установлен"
flutter --version
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Запустите скрипт из корня проекта autohub_b2b"
    exit 1
fi

echo "📦 Установка зависимостей..."
flutter pub get

echo ""
echo "🔨 Генерация кода для Drift..."
dart run build_runner build --delete-conflicting-outputs

echo ""
echo "🧹 Очистка предыдущих сборок..."
flutter clean

echo ""
echo "🏗️ Запуск приложения на macOS..."
echo ""
echo "Приложение откроется через несколько секунд..."
echo ""

# Run the app
flutter run -d macos

echo ""
echo "✅ Готово!"

