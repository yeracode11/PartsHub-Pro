#!/bin/bash

# Скрипт для сборки всех платформ AutoHub B2C

set -e

echo "🚀 Начинаем сборку для всех платформ..."

cd "$(dirname "$0")"

# Проверка Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter не найден. Установите Flutter и добавьте в PATH."
    exit 1
fi

# Очистка
echo "🧹 Очистка проекта..."
flutter clean
flutter pub get

# Проверка версии
echo ""
echo "📱 Информация о версии:"
flutter --version
echo ""
grep "version:" pubspec.yaml
echo ""

# Android сборка
echo "📱 Сборка Android..."
if [ -f "deploy-android.sh" ]; then
    bash deploy-android.sh
else
    flutter build apk --release
fi

# iOS сборка (только на macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    echo "📱 Сборка iOS..."
    if [ -f "deploy-ios.sh" ]; then
        bash deploy-ios.sh
    else
        cd ios
        pod install
        cd ..
        flutter build ios --release
    fi
else
    echo ""
    echo "⚠️  iOS сборка пропущена (требуется macOS)"
fi

echo ""
echo "🎉 Все сборки завершены!"
echo ""
echo "📂 Файлы Android: build/app/outputs/flutter-apk/"
echo "📂 Для iOS откройте Xcode и создайте Archive"

