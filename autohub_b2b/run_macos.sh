#!/bin/bash
# Обход для macOS: Flutter не передаёт -allowProvisioningUpdates в xcodebuild.
# Используйте если: flutter run -d macos падает с "No profiles for 'com.example.autohubB2b'"
#
# Решение: собрать один раз из Xcode — он создаст provisioning profile.
# После этого flutter run -d macos должен заработать.

cd "$(dirname "$0")"
open macos/Runner.xcworkspace
echo "Xcode открыт. Нажмите Cmd+R для сборки и запуска."
echo "После успешной сборки в Xcode попробуйте снова: flutter run -d macos"
