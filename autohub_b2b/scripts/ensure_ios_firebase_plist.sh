#!/usr/bin/env bash
# Проверяет наличие GoogleService-Info.plist перед сборкой iOS.
# В CI: положите файл из секретов в ios/Runner/GoogleService-Info.plist до вызова скрипта.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$ROOT/ios/Runner/GoogleService-Info.plist"
EXAMPLE="$ROOT/ios/Runner/GoogleService-Info.plist.example"

if [[ -f "$PLIST" ]]; then
  echo "OK: $PLIST найден."
  exit 0
fi

echo "Ошибка: не найден $PLIST" >&2
echo "Варианты:" >&2
echo "  1) Скачайте GoogleService-Info.plist из Firebase Console → настройки проекта → приложение iOS." >&2
echo "  2) Локально: cp \"$EXAMPLE\" \"$PLIST\" и замените значения на реальные." >&2
echo "  3) CI: запишите содержимое секрета в $PLIST перед сборкой." >&2
exit 1
