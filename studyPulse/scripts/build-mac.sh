#!/usr/bin/env bash
# StudyPulse Mac 앱 빌드 + DMG 패키징 스크립트
# 사용법: ./scripts/build-mac.sh
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/StudyPulsDashboard.xcodeproj"
SCHEME="StudyPulsDashboard"
BUILD_DIR="$ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/StudyPulsDashboard.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/StudyPulse.dmg"
APP_NAME="StudyPulse.app"

echo "🔨 StudyPulse Mac 앱 빌드 시작"
echo "프로젝트: $PROJECT"
echo ""

# ── 1. xcodegen으로 프로젝트 재생성 (project.yml 변경 반영)
if command -v xcodegen &>/dev/null; then
  echo "⚙️  xcodegen으로 프로젝트 업데이트..."
  xcodegen generate --project "$ROOT" --spec "$ROOT/project.yml" --quiet
fi

# ── 2. 아카이브 빌드
echo "📦 아카이브 빌드 중..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  | grep -E "^(error:|warning:|Archive)" || true

# ── 3. .app 추출
echo "📁 .app 파일 추출 중..."
rm -rf "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"
APP_IN_ARCHIVE=$(find "$ARCHIVE_PATH" -name "*.app" | head -1)
if [ -z "$APP_IN_ARCHIVE" ]; then
  echo "❌ .app 파일을 찾을 수 없습니다"
  exit 1
fi
cp -R "$APP_IN_ARCHIVE" "$EXPORT_PATH/$APP_NAME"

# ── 4. DMG 생성
echo "💿 DMG 생성 중..."
rm -f "$DMG_PATH"

# 임시 DMG 작업 디렉토리
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$EXPORT_PATH/$APP_NAME" "$STAGING/$APP_NAME"
# Applications 심링크 (드래그 설치용)
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "StudyPulse" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" \
  > /dev/null

rm -rf "$STAGING"

echo ""
echo "✅ 완료!"
echo "   DMG: $DMG_PATH"
echo ""
echo "설치 방법: DMG를 열고 StudyPulse.app을 Applications로 드래그하세요."
