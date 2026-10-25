#!/usr/bin/env bash
#
# 本地一键打包脚本（需在 macOS 上运行，Xcode + xcodegen）
#
# 用法：
#   bash scripts/build.sh                       # 零证书 ad-hoc 签名 IPA
#   bash scripts/build.sh --team-id XXXXXXXXXX  # 用免费/付费 Apple ID 签名
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

TEAM_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id) TEAM_ID="$2"; shift 2 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

echo "==> 生成 Xcode 工程 (xcodegen)"
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi
xcodegen generate

rm -rf build Payload
mkdir -p build

echo "==> 构建 App（关闭签名，仅 arm64）"
xcodebuild -project wb-checkin-ios.xcodeproj -scheme wb-checkin-ios \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" ARCHS=arm64 \
  build CONFIGURATION_BUILD_DIR="$ROOT/build/app"

APP="$ROOT/build/app/wb-checkin-ios.app"
[ -d "$APP" ] || { echo "错误：未找到 $APP"; exit 1; }

if [[ -n "$TEAM_ID" ]]; then
  echo "==> 使用开发证书签名"
  xcodebuild -exportArchive -archivePath "$ROOT/build/app.xcarchive" \
    -exportOptionsPlist <(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>development</string>
  <key>teamID</key><string>$TEAM_ID</string>
</dict></plist>
EOF
) -exportPath "$ROOT/build"
  IPA=$(find "$ROOT/build" -name "*.ipa" | head -n1)
else
  echo "==> Ad-hoc 签名（TrollStore 可装）"
  codesign -s - --entitlements wb-checkin-ios.entitlements "$APP"
  mkdir -p Payload
  cp -R "$APP" Payload/
  zip -qry wb-checkin-ios.ipa Payload
  rm -rf Payload
  IPA="$ROOT/wb-checkin-ios.ipa"
fi

echo ""
echo "✅ 完成：$IPA"
