# StudyPuls 개발 인수인계

이 문서는 다음 개발자 또는 다른 AI CLI가 프로젝트를 이어받을 때 어디를 만져야 하는지, 현재 무엇이 완성되어 있는지, 실제 프로비저닝 때 무엇을 고쳐야 하는지 설명하기 위한 문서입니다.

## 1. 어디를 건드려야 하는가

### Apple Watch HRV 실제 연동

목표는 사용자가 직접 HRV/스트레스 값을 입력하는 방식이 아니라, Apple Watch가 iPhone HealthKit에 기록한 HRV 값을 iPhone 앱이 읽고 Mac 앱 서버로 보내는 구조입니다.

현재 구현 위치:

- iPhone 유령 앱: `Apps/StudyPulsGhost`
- HealthKit 읽기: `Apps/StudyPulsGhost/HealthKitBridge.swift`
- Mac 서버 전송: `Apps/StudyPulsGhost/StudyPulsBridgeClient.swift`
- Mac 서버 수신 API: `src/server.js`의 `/api/health/hrv-bridge`
- 스트레스/집중도 계산: `src/store.js`의 `receiveHealthSample`, `stressFromSample`, `focusFromStress`
- Mac 앱에서 iPhone에 넣을 서버 주소 표시: `Apps/StudyPulsDashboard/Sources/LocalNetworkInfo.swift`, `DashboardView.swift`

실제 프로비저닝 때 확인할 점:

- iPhone 앱 타겟에 HealthKit Capability 추가
- `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` 포함
- Apple Developer 계정에서 HealthKit entitlement 포함한 프로비저닝 프로파일 사용
- iPhone과 Mac이 같은 Wi-Fi에 있어야 함
- Ghost 앱 서버 URL은 `http://127.0.0.1:3000`이 아니라 Mac 앱 설정 탭에 표시되는 `http://맥북IP:3000`이어야 함
- Mac 방화벽이 3000번 포트를 막고 있으면 iPhone에서 전송 실패
- Apple Watch HRV는 초 단위 실시간 값이 아니라 HealthKit에 샘플이 생길 때 들어옴

주의:

- Mac 앱에 있던 수동 HRV/심박 슬라이더는 제거됨
- 테스트용 수동 주입 API `/api/health/heart-rate`는 서버에 남아 있지만, 실제 앱 UI에서는 사용하지 않음
- 실제 스트레스 값은 `hrv`와 `heartRate`를 받아 `src/store.js`에서 계산됨

### AirPods 졸림 감지

목표는 AirPods head tracking/CoreMotion으로 고개가 오래 숙여진 상태를 감지해서 졸림 시간대를 대시보드에 보여주는 것입니다.

현재 구현 위치:

- Mac CoreMotion 수신: `Apps/StudyPulsDashboard/Sources/AirPodsMotionMonitor.swift`
- 졸림 이벤트 API: `src/server.js`의 `/api/motion/headphone-sample`
- 졸림 집계: `src/store.js`의 `receiveHeadMotionSample`, `getDrowsinessTimeline`
- 대시보드 표시: `DashboardView.swift`의 `DrowsinessPanel`

실제 프로비저닝 때 확인할 점:

- macOS 앱 `Info.plist`에 `NSMotionUsageDescription` 필요
- `scripts/build-mac-app.sh`에는 이미 `NSMotionUsageDescription`이 들어가 있음
- CoreMotion head tracking은 지원 AirPods가 실제 연결되어 있어야 동작
- 연결된 AirPods가 없으면 앱이 죽으면 안 되고 “대기/지원 AirPods 필요” 상태로 남아야 함

### Mac 앱 배포/실행

현재 앱은 로컬 실행용 macOS SwiftUI 앱입니다.

현재 구현 위치:

- Mac 앱 엔트리: `Apps/StudyPulsDashboard/Sources/StudyPulsDashboardApp.swift`
- 화면: `Apps/StudyPulsDashboard/Sources/DashboardView.swift`
- 창 크기 제한: `Apps/StudyPulsDashboard/Sources/WindowSizeLimiter.swift`
- 자동 로컬 서버 실행: `Apps/StudyPulsDashboard/Sources/LocalServerManager.swift`
- 앱 번들 빌드: `scripts/build-mac-app.sh`

현재 창 크기:

- 기본/최대 `1000x700`
- 더 작아질 수 있음
- 더 커질 수 없게 `NSWindow.maxSize`와 resize clamp 적용

프로비저닝/배포 전 고쳐야 할 점:

- App Store 배포용이 아니라 로컬 MVP 번들임
- 실제 배포하려면 Developer ID 서명, notarization, entitlements 정리 필요
- `dist/StudyPulsDashboard.app`는 `.gitignore` 대상
- 앱이 내부에서 `node src/server.js`를 실행하므로 Node 런타임이 필요함
- 외부 배포 시 Node 서버를 앱에 번들링하거나 별도 백엔드로 분리해야 함

### MySQL/Docker

현재 로컬 서버는 JSON 파일 저장소(`data/studypuls.local.json`)를 주 저장소로 사용합니다. MySQL은 이관용 스키마와 Docker 환경이 준비되어 있습니다.

현재 구현 위치:

- Docker: `docker-compose.yml`
- MySQL 스키마: `schema/mysql.sql`
- DB 유저 생성/권한: `docker/mysql/02-users.sh`
- 설정 로딩: `src/config.js`

실제 운영/프로비저닝 때 고쳐야 할 점:

- `src/store.js`를 JSON 파일 저장소에서 MySQL adapter로 교체
- app user는 필요한 CRUD 권한만 유지
- admin user는 migration/schema 변경용으로만 사용
- `.env`는 절대 커밋하지 않음
- `.gitignore`에 `.env`, `data/`, `.build/`, `dist/`가 등록되어 있음

### AI 코칭

현재 OpenAI 연결은 되어 있고 실패 시 로컬 fallback으로 동작합니다.

현재 구현 위치:

- AI 코칭: `src/aiCoach.js`
- OpenAI 설정: `src/config.js`
- API: `/api/ai/coach`, `/api/ai/report`, `/api/ai/recommend`, `/api/ai/chat`

프로비저닝 때 확인할 점:

- `.env`에 `AI_PROVIDER=openai`, `OPENAI_API_KEY`, `OPENAI_MODEL`, `OPENAI_TIMEOUT_MS` 필요
- API 키는 절대 코드나 문서에 직접 넣지 말 것
- AI 응답 지연 시 UX가 멈추지 않도록 timeout/fallback 유지

## 2. 전체 개발 상황과 코드 설명

### 완성된 부분

- Node.js 로컬 API 서버
- macOS SwiftUI 대시보드 앱
- iPhone HealthKit Ghost 앱 코드
- Apple Watch HRV/심박 수신 API
- HRV/심박 기반 스트레스/집중도 계산
- AirPods CoreMotion 기반 졸림 이벤트 수신/집계
- AI 코칭 API와 OpenAI fallback 구조
- 과목별 타이머 API
- 그룹 랭킹/미션 API
- MySQL Docker 및 스키마 초안
- 앱 창 크기 제한 및 탭 분리

### 아직 MVP인 부분

- Mac 서버 저장소는 아직 JSON 파일 기반
- iPhone Ghost 앱은 Xcode iOS 타겟에 붙여 실기기에서 테스트해야 함
- HealthKit/Apple Watch HRV는 실제 기기 권한과 기록 상태에 따라 샘플이 늦게 들어올 수 있음
- App Store 배포용 서명/노터라이즈/아카이브는 아직 없음
- MySQL 스키마는 있지만 서버 코드가 MySQL을 직접 쓰지는 않음

### 주요 API

- `GET /api/dashboard`: 대시보드 요약
- `GET /api/dashboard/focus`: 시간대별 집중도
- `GET /api/dashboard/stress`: HRV/심박 기반 스트레스 시계열
- `GET /api/dashboard/drowsiness`: AirPods head motion 기반 졸림 시간대
- `POST /api/health/hrv-bridge`: iPhone Ghost 앱이 실제 HealthKit HRV/심박 전송
- `POST /api/motion/headphone-sample`: Mac 앱이 AirPods head motion 전송
- `POST /api/study/start`: 과목별 공부 시작
- `POST /api/study/end`: 공부 종료
- `GET /api/ai/coach`: AI 코칭
- `GET /api/groups/ranking`: 그룹 랭킹

### 앱 화면 구조

Mac 앱 탭은 `DashboardView.swift`의 `StudyPulsTab`에 정의되어 있습니다.

- `대시보드`: 요약 카드, 집중도, 생체 지표, 졸림 시간대만 표시
- `AI 코칭`: AI 분석/추천 실행
- `과목별 타이머`: 타이머, 과목별 공부 시간, 최근 세션
- `그룹`: 그룹 랭킹, 그룹 미션
- `설정`: 알림, AirPods CoreMotion 연결, Apple Watch Bridge 연결, 서버 상태

메인 대시보드에는 타이머/코칭/그룹 상세를 넣지 않아야 합니다. 해당 기능은 각 탭에서만 보여야 합니다.

## 3. 다른 AI CLI용 프롬프트

별도 파일 `docs/ai-cli-prompt.md`에도 같은 목적의 프롬프트를 만들어 두었습니다. 아래 프롬프트를 다른 AI CLI에 그대로 붙여 넣어도 됩니다.

```text
너는 StudyPuls 프로젝트를 이어받는 시니어 개발 AI다.

프로젝트 경로는 /Users/taein/Documents/mindcharry 이다.
먼저 README.md, docs/development-handoff.md, package.json, src/server.js, src/store.js, Apps/StudyPulsDashboard/Sources, Apps/StudyPulsGhost 를 읽고 현재 구현을 파악해라.

중요한 현재 상태:
- StudyPuls는 macOS SwiftUI 대시보드 앱 + Node.js 로컬 서버 + iPhone HealthKit Ghost 앱으로 구성되어 있다.
- Mac 앱은 dist/StudyPulsDashboard.app 으로 빌드된다.
- Mac 앱 창은 1000x700이 최대이며 더 작아질 수 있지만 더 커지면 안 된다.
- 대시보드 탭에는 요약 카드, 시간대별 집중도, 최근 생체 지표, AirPods 졸림 시간대만 표시해야 한다.
- 과목별 타이머, AI 코칭, 그룹 관련 상세 UI는 각각의 탭에서만 표시해야 한다.
- 수동 HRV/심박 슬라이더나 사용자가 스트레스 값을 직접 넣는 UI를 다시 추가하지 마라.
- 실제 HRV는 Apple Watch가 iPhone HealthKit에 기록한 값을 iPhone Ghost 앱이 읽어서 Mac 서버 /api/health/hrv-bridge 로 전송하는 구조다.
- iPhone에서 127.0.0.1은 Mac이 아니라 iPhone 자신이므로 Ghost 앱에는 Mac 앱 설정 탭에 표시되는 http://맥북IP:3000 주소를 입력해야 한다.
- AirPods 졸림 감지는 Mac 앱의 CoreMotion head tracking으로 처리한다.
- MySQL Docker와 schema/mysql.sql은 준비되어 있지만 현재 src/store.js는 JSON 파일 저장소를 사용한다.
- .env와 API 키는 절대 출력하거나 커밋하지 마라.

검증 명령:
- node --check src/store.js
- node --check src/server.js
- npm test
- ./scripts/build-mac-app.sh

작업 원칙:
- 기존 사용자 변경을 되돌리지 마라.
- .env, data/, .build/, dist/는 커밋 대상으로 다루지 마라.
- UI를 바꿀 때는 1000x700 창 안에서 확인하라.
- HealthKit/Apple Watch 관련 작업은 Apps/StudyPulsGhost를 중심으로 진행하라.
- Mac 대시보드의 실제 수신/표시는 Apps/StudyPulsDashboard/Sources/DashboardView.swift, APIClient.swift, Models.swift를 중심으로 진행하라.
- 서버 데이터 처리와 계산은 src/store.js, 라우팅은 src/server.js를 중심으로 진행하라.

다음으로 해야 할 가능성이 높은 작업:
1. iPhone Ghost 앱을 Xcode iOS 타겟으로 실제 빌드할 수 있게 프로젝트/타겟 구성을 보완한다.
2. HealthKit 권한, entitlements, Info.plist, local network permission을 확인한다.
3. Mac 앱 설정 탭의 iPhone 서버 주소를 사용자가 복사하기 쉽게 만든다.
4. JSON 저장소를 MySQL adapter로 교체할지 결정하고, 교체한다면 src/store.js의 함수 단위 계약을 유지하며 DB 계층을 분리한다.
5. 실제 기기 테스트 후 HRV가 늦게 들어오는 UX를 보완한다.

절대 하지 말 것:
- 사용자가 직접 HRV/스트레스 값을 입력하는 테스트 UI를 다시 메인 기능으로 넣지 말 것.
- Apple Watch가 Mac에 직접 연결된 것처럼 허위로 실제 센서 데이터를 받는다고 표현하지 말 것. 데이터는 iPhone HealthKit Ghost 앱 경유라고 명확히 유지할 것.
- API 키, DB 비밀번호, .env 내용을 출력하지 말 것.
```
