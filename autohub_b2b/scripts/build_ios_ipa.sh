#!/usr/bin/env bash
# Релизная IPA для App Store (после настройки подписи и ios/ExportOptions.plist).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/ensure_ios_firebase_plist.sh"

EXPORT_PLIST="$ROOT/ios/ExportOptions.plist"
if [[ ! -f "$EXPORT_PLIST" ]]; then
  echo "Предупреждение: нет $EXPORT_PLIST — сборка без --export-options-plist (подпись из Xcode)." >&2
  echo "Скопируйте ios/ExportOptions.plist.example → ios/ExportOptions.plist и укажите teamID." >&2
  flutter build ipa --release
else
  flutter build ipa --release --export-options-plist="$EXPORT_PLIST"
fi

echo ""
echo "Дальше: Xcode → Organizer → Validate App → Distribute App."
echo "Или проверка из терминала (подставьте путь к .ipa и ключи API):"
echo "  xcrun altool --validate-app -f build/ios/ipa/*.ipa -t ios --apiKey YOURKEY --apiIssuer YOURISSUER"
