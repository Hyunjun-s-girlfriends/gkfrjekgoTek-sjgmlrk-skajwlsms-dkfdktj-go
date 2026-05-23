# StudyPuls AI CLI Prompt

아래 내용을 다른 AI CLI에 그대로 붙여 넣으면 됩니다.

```text
너는 StudyPuls 프로젝트를 이어받는 시니어 개발 AI다.

프로젝트 경로는 /Users/taein/Documents/mindcharry 이다.

먼저 다음 파일과 폴더를 읽고 현재 구현을 파악해라.
- README.md
- docs/development-handoff.md
- package.json
- src/server.js
- src/store.js
- src/aiCoach.js
- Apps/StudyPulsDashboard/Sources
- Apps/StudyPulsGhost
- schema/mysql.sql
- docker-compose.yml

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

실제 Apple Watch HRV 연동을 볼 때 핵심 파일:
- Apps/StudyPulsGhost/HealthKitBridge.swift
- Apps/StudyPulsGhost/StudyPulsBridgeClient.swift
- Apps/StudyPulsGhost/GhostBridgeView.swift
- Apps/StudyPulsGhost/StudyPulsGhost.entitlements
- Apps/StudyPulsGhost/Info.plist
- src/server.js 의 /api/health/hrv-bridge
- src/store.js 의 receiveHealthSample, stressFromSample, focusFromStress
- Apps/StudyPulsDashboard/Sources/DashboardView.swift 의 설정 탭과 생체 지표 표시

실제 프로비저닝에서 확인해야 할 점:
- iPhone 앱 타겟에 HealthKit Capability를 추가한다.
- Apple Developer 계정에서 HealthKit entitlement가 포함된 프로비저닝 프로파일을 사용한다.
- iPhone 앱 Info.plist에 HealthKit 사용 설명이 있어야 한다.
- iPhone과 Mac은 같은 Wi-Fi에 있어야 한다.
- Mac 방화벽이 3000번 포트를 막으면 iPhone 전송이 실패한다.
- HealthKit HRV는 초 단위 실시간 값이 아니므로 샘플 지연 UX를 고려한다.
- AirPods head tracking은 지원 AirPods가 실제 연결되어 있어야 한다.
- macOS 앱에는 NSMotionUsageDescription이 있어야 한다.

검증 명령:
- node --check src/store.js
- node --check src/server.js
- npm test
- ./scripts/build-mac-app.sh

작업 원칙:
- 기존 사용자 변경을 되돌리지 마라.
- .env, data/, .build/, dist/, node_modules/는 커밋 대상으로 다루지 마라.
- UI를 바꿀 때는 1000x700 창 안에서 확인하라.
- HealthKit/Apple Watch 관련 작업은 Apps/StudyPulsGhost를 중심으로 진행하라.
- Mac 대시보드의 실제 수신/표시는 Apps/StudyPulsDashboard/Sources/DashboardView.swift, APIClient.swift, Models.swift를 중심으로 진행하라.
- 서버 데이터 처리와 계산은 src/store.js, 라우팅은 src/server.js를 중심으로 진행하라.

다음으로 해야 할 가능성이 높은 작업:
1. iPhone Ghost 앱을 Xcode iOS 타겟으로 실제 빌드할 수 있게 프로젝트/타겟 구성을 보완한다.
2. HealthKit 권한, entitlements, Info.plist, local network permission을 실기기에서 확인한다.
3. Mac 앱 설정 탭의 iPhone 서버 주소를 사용자가 복사하기 쉽게 만든다.
4. JSON 저장소를 MySQL adapter로 교체할지 결정하고, 교체한다면 src/store.js의 함수 단위 계약을 유지하며 DB 계층을 분리한다.
5. 실제 기기 테스트 후 HRV가 늦게 들어오는 UX를 보완한다.

절대 하지 말 것:
- 사용자가 직접 HRV/스트레스 값을 입력하는 테스트 UI를 다시 메인 기능으로 넣지 말 것.
- Apple Watch가 Mac에 직접 연결된 것처럼 허위로 실제 센서 데이터를 받는다고 표현하지 말 것. 데이터는 iPhone HealthKit Ghost 앱 경유라고 명확히 유지할 것.
- API 키, DB 비밀번호, .env 내용을 출력하지 말 것.
```
