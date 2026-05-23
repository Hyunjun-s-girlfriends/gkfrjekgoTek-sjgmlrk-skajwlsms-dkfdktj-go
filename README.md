# StudyPuls Local MVP

StudyPuls 로컬 MVP입니다. Apple Watch/HealthKit 실연동 전 단계에서 HRV, 심박수, 공부 세션, 미션, 그룹 랭킹, AI 분석 흐름을 맥북 브라우저에서 확인할 수 있게 만든 대시보드입니다.

## 실행

```bash
npm run dev
```

브라우저에서 `http://localhost:3000`을 열면 됩니다.

SwiftUI 맥 앱은 Xcode에서 패키지를 열어 `StudyPulsDashboard`를 실행하면 됩니다. 서버는 계속 `npm run dev`로 켜두세요.

앱 번들 생성:

```bash
chmod +x scripts/build-mac-app.sh
./scripts/build-mac-app.sh
```

생성 위치는 `dist/StudyPulsDashboard.app`입니다.

## 현재 구현된 범위

- 로컬 Node.js 서버
- JSON 파일 기반 로컬 저장소
- 대시보드, HRV/스트레스/집중도 그래프
- 공부 타이머 시작/종료 API
- Apple Watch 유령 앱 연동을 대신하는 생체 데이터 수신 API
- AI 리포트/추천/챗봇 모의 API
- 그룹/랭킹/미션 API
- MySQL 이관용 스키마 초안

## OpenAI 코칭

`.env`의 `AI_PROVIDER=openai`와 `OPENAI_API_KEY`가 설정되어 있으면 `/api/ai/coach`, `/api/ai/report`, `/api/ai/chat`이 실제 OpenAI API를 호출합니다. API 호출에 실패하면 로컬 계산 기반 코칭으로 자동 대체됩니다.

## MySQL Docker

```bash
docker compose up -d mysql
```

접속 정보는 `.env`를 사용합니다. DB 유저는 두 종류입니다.

- admin 유저: 마이그레이션, 스키마 변경, 전체 관리용
- app 유저: StudyPuls 앱에서 필요한 CRUD 권한만 보유

## 다음 연결 지점

- iPhone 유령 앱에서 HealthKit의 Apple Watch HRV/심박 샘플을 읽어 `/api/health/hrv-bridge`로 `heartRate`, `hrv`, `timestamp` 전송
- Mac 앱 설정 탭의 `iPhone 앱 서버 주소`를 Ghost 앱에 입력해야 합니다. `127.0.0.1`은 iPhone 자신을 가리키므로 Mac 서버 주소로 사용할 수 없습니다.
- `Apps/StudyPulsGhost`는 실제 HealthKit HRV를 자동 전송하는 유령 앱 코드입니다.
- `Apps/StudyPulsDashboard`는 맥북에 설치해서 실행할 SwiftUI 대시보드입니다.
- 실제 OpenAI API 연결 시 `/api/ai/report`, `/api/ai/recommend`, `/api/ai/chat` 내부 로직 교체
- MySQL 사용 시 `schema/mysql.sql` 기준으로 테이블 생성 후 `src/store.js`를 DB 어댑터로 교체
