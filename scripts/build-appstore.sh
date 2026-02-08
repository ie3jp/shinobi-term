#!/bin/bash
# ============================================================
# App Store ビルド & アップロードスクリプト
#
# 使い方:
#   ./scripts/build-appstore.sh          # Archive + アップロード
#   ./scripts/build-appstore.sh archive  # Archive のみ
#   ./scripts/build-appstore.sh upload   # アップロードのみ（既存 Archive）
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../ShinobiTerm"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/ShinobiTerm.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
XCCONFIG="$PROJECT_DIR/local.xcconfig"
COMMAND="${1:-all}"

# ============================================================
# 前提チェック
# ============================================================

if [ ! -f "$XCCONFIG" ]; then
    echo "❌ local.xcconfig が見つかりません"
    echo ""
    echo "ShinobiTerm/local.xcconfig を作成してください:"
    echo ""
    echo "  // Local build settings (gitignored)"
    echo "  DEVELOPMENT_TEAM = YOUR_TEAM_ID"
    echo ""
    exit 1
fi

TEAM_ID=$(grep "DEVELOPMENT_TEAM" "$XCCONFIG" | sed 's/.*= *//' | tr -d ' ')
if [ -z "$TEAM_ID" ] || [ "$TEAM_ID" = "" ]; then
    echo "❌ local.xcconfig に DEVELOPMENT_TEAM が設定されていません"
    exit 1
fi

echo "========================================"
echo "Shinobi Term - App Store ビルド"
echo "Team ID: $TEAM_ID"
echo "========================================"

# ============================================================
# ExportOptions.plist 生成
# ============================================================

EXPORT_OPTIONS="$PROJECT_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
PLIST

# ============================================================
# XcodeGen
# ============================================================

echo ""
echo "[1/3] XcodeGen..."
cd "$PROJECT_DIR"
xcodegen generate

# ============================================================
# Archive
# ============================================================

if [ "$COMMAND" = "all" ] || [ "$COMMAND" = "archive" ]; then
    echo ""
    echo "[2/3] Archive..."
    rm -rf "$ARCHIVE_PATH"
    xcodebuild archive \
        -scheme ShinobiTerm \
        -archivePath "$ARCHIVE_PATH" \
        -destination 'generic/platform=iOS' \
        -xcconfig "$XCCONFIG" \
        -allowProvisioningUpdates \
        2>&1 | tail -3

    echo "✅ Archive 完了: $ARCHIVE_PATH"
fi

# ============================================================
# Upload
# ============================================================

if [ "$COMMAND" = "all" ] || [ "$COMMAND" = "upload" ]; then
    if [ ! -d "$ARCHIVE_PATH" ]; then
        echo "❌ Archive が見つかりません: $ARCHIVE_PATH"
        echo "   先に ./scripts/build-appstore.sh archive を実行してください"
        exit 1
    fi

    echo ""
    echo "[3/3] App Store Connect にアップロード..."
    rm -rf "$EXPORT_PATH"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        -allowProvisioningUpdates \
        2>&1 | tail -5

    echo ""
    echo "✅ アップロード完了！"
    echo "   App Store Connect でビルドを確認してください"
fi

echo ""
echo "========================================"
echo "✅ 完了"
echo "========================================"
