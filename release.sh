#!/bin/bash
# Gera o .dmg assinado (Developer ID) e notarizado pela Apple, pronto para o GitHub Releases.
#
# Preparação (uma vez só):
#  1. Certificado "Developer ID Application":
#     Xcode › Settings › Accounts › (sua conta) › Manage Certificates… › + › Developer ID Application
#  2. Credenciais do notarytool (gere uma senha de app em https://account.apple.com › Senhas de app):
#     xcrun notarytool store-credentials force-tm-notary --apple-id SEU_APPLE_ID --team-id S59329THZP
#
# Uso:  ./release.sh
set -e
cd "$(dirname "$0")"
NAME="Force TM"
VERSION=$(cat VERSION)
APP="build/$NAME.app"
DMG="dist/Force-TM-$VERSION.dmg"
PROFILE="${NOTARY_PROFILE:-force-tm-notary}"

ID=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/{print $2; exit}')
if [ -z "$ID" ]; then
  echo "❌ Certificado 'Developer ID Application' não encontrado. Veja a preparação no topo deste script."; exit 1
fi
echo "Assinando com: $ID"

SKIP_INSTALL=1 ./build.sh

echo "Reassinando com Hardened Runtime..."
codesign --force --deep --options runtime --timestamp -s "$ID" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Montando o DMG..."
rm -rf dist build/dmg; mkdir -p dist build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname "$NAME $VERSION" -srcfolder build/dmg -ov -format UDZO "$DMG" >/dev/null
codesign --force --timestamp -s "$ID" "$DMG"

echo "Enviando para notarização da Apple (leva alguns minutos)..."
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -v "$DMG" && echo "Gatekeeper: OK"

shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo
echo "✅ Pronto: $DMG"
echo "Publique com:  gh release create v$VERSION \"$DMG\" --title \"Force TM $VERSION\" --generate-notes"
