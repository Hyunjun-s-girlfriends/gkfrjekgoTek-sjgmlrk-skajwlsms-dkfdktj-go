#!/usr/bin/env bash
# Google OAuth 자격증명 설정 스크립트
# 사용법: ./scripts/setup-oauth.sh
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/server/.env"
PLIST="$ROOT/StudyPulsDashboard/Info.plist"
PROJECT_YML="$ROOT/project.yml"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  StudyPulse — Google OAuth 설정"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Google Cloud Console (https://console.cloud.google.com) 에서"
echo "OAuth 2.0 클라이언트 ID를 먼저 발급받아야 합니다."
echo ""
echo "발급 절차:"
echo "  1. 프로젝트 생성 (또는 기존 프로젝트 선택)"
echo "  2. API 및 서비스 → 사용자 인증 정보 → + 사용자 인증 정보 만들기"
echo "  3. OAuth 클라이언트 ID 선택 → 애플리케이션 유형: 데스크톱 앱"
echo "  4. 승인된 리디렉션 URI 추가:"
echo "       com.studypulse.dashboard:/oauth2callback"
echo "  5. 클라이언트 ID와 보안 비밀 복사"
echo ""

# 입력 받기
read -rp "GOOGLE_CLIENT_ID (예: 123456.apps.googleusercontent.com): " CLIENT_ID
read -rp "GOOGLE_CLIENT_SECRET: " CLIENT_SECRET

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "❌ Client ID와 Secret을 모두 입력해야 합니다."
  exit 1
fi

echo ""
echo "⚙️  server/.env 업데이트 중..."
# .env의 GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET 교체
sed -i '' "s|^GOOGLE_CLIENT_ID=.*|GOOGLE_CLIENT_ID=$CLIENT_ID|" "$ENV_FILE"
sed -i '' "s|^GOOGLE_CLIENT_SECRET=.*|GOOGLE_CLIENT_SECRET=$CLIENT_SECRET|" "$ENV_FILE"

echo "⚙️  Info.plist 업데이트 중..."
# plutil로 Info.plist의 GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET 값 교체
/usr/libexec/PlistBuddy -c "Set :GOOGLE_CLIENT_ID $CLIENT_ID" "$PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :GOOGLE_CLIENT_ID string $CLIENT_ID" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :GOOGLE_CLIENT_SECRET $CLIENT_SECRET" "$PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :GOOGLE_CLIENT_SECRET string $CLIENT_SECRET" "$PLIST"

echo "⚙️  project.yml 업데이트 중..."
# project.yml의 빈 문자열 교체
sed -i '' "s|GOOGLE_CLIENT_ID: \"\"|GOOGLE_CLIENT_ID: \"$CLIENT_ID\"|" "$PROJECT_YML"
sed -i '' "s|GOOGLE_CLIENT_SECRET: \"\"|GOOGLE_CLIENT_SECRET: \"$CLIENT_SECRET\"|" "$PROJECT_YML"

echo ""
echo "✅ 완료!"
echo ""
echo "다음 단계:"
echo "  Mac 앱: ./scripts/build-mac.sh  (재빌드 필요)"
echo "  서버:   docker compose restart app  (재시작 필요)"
