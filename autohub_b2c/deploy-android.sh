#!/bin/bash

# Скрипт для сборки Android release версии AutoHub B2C

set -e

echo "🚀 Начинаем сборку Android release версии..."

# Переход в директорию проекта
cd "$(dirname "$0")"

# Проверка наличия Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter не найден. Установите Flutter и добавьте в PATH."
    exit 1
fi

# Очистка предыдущих сборок
echo "🧹 Очистка предыдущих сборок..."
flutter clean
flutter pub get

# Проверка keystore
KEYSTORE_PATH="android/autohub_b2c_release.keystore"
KEY_PROPS_PATH="android/key.properties"

if [ ! -f "$KEYSTORE_PATH" ]; then
    echo "⚠️  Keystore файл не найден!"
    echo "📝 Создайте keystore файл командой:"
    echo "   cd android && keytool -genkey -v -keystore autohub_b2c_release.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias autohub_b2c"
    echo ""
    read -p "Продолжить без keystore? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

if [ ! -f "$KEY_PROPS_PATH" ]; then
    echo "⚠️  Файл key.properties не найден!"
    echo "📝 Создайте файл android/key.properties с параметрами:"
    echo "   storePassword=YOUR_PASSWORD"
    echo "   keyPassword=YOUR_PASSWORD"
    echo "   keyAlias=autohub_b2c"
    echo "   storeFile=../autohub_b2c_release.keystore"
    exit 1
fi

# Проверка версии
echo "📱 Текущая версия из pubspec.yaml:"
grep "version:" pubspec.yaml

# Выбор типа сборки
echo ""
echo "Выберите тип сборки:"
echo "1) APK (для тестирования)"
echo "2) App Bundle (для Google Play)"
read -p "Ваш выбор (1 или 2): " choice

case $choice in
    1)
        echo "📦 Сборка APK..."
        flutter build apk --release
        APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
        echo "✅ APK собран: $APK_PATH"
        echo "📱 Размер файла:"
        ls -lh "$APK_PATH"
        ;;
    2)
        echo "📦 Сборка App Bundle..."
        flutter build appbundle --release
        BUNDLE_PATH="build/app/outputs/bundle/release/app-release.aab"
        echo "✅ App Bundle собран: $BUNDLE_PATH"
        echo "📱 Размер файла:"
        ls -lh "$BUNDLE_PATH"
        ;;
    *)
        echo "❌ Неверный выбор"
        exit 1
        ;;
esac

echo ""
echo "🎉 Сборка завершена успешно!"
echo "📂 Файлы находятся в директории build/app/outputs/"
echo ""
echo "Следующие шаги:"
echo "  - Протестируйте приложение на реальном устройстве"
echo "  - Проверьте подключение к API"
echo "  - Загрузите в Google Play Console (для App Bundle)"

