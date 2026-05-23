# StudyPulsGhost

Apple Watch의 HRV를 직접 서버가 가져올 수 없기 때문에, 이 앱은 iPhone HealthKit을 경유해서 StudyPuls 로컬 서버로 HRV/심박수 샘플을 보내는 브리지 앱입니다.

역할은 하나입니다.

- HealthKit 권한 요청
- HRV(SDNN)와 심박수 샘플 읽기
- 가장 가까운 심박수와 HRV를 묶어서 `/api/health/hrv-bridge`로 전송
- `실제 HRV 자동 전송 시작`을 누르면 앱이 켜져 있는 동안 1분마다 새 HRV 샘플을 확인해 전송
- 이미 전송한 샘플은 앱 내부 `lastSyncedAt` 기준으로 다시 보내지 않음

Xcode에서 iOS App 타겟을 만들고 아래 파일들을 추가하세요.

- `GhostApp.swift`
- `GhostBridgeView.swift`
- `HealthKitBridge.swift`
- `StudyPulsBridgeClient.swift`

필수 설정:

- Signing & Capabilities: HealthKit 추가
- `NSHealthShareUsageDescription`: StudyPuls가 HRV와 심박수로 학습 컨디션을 분석합니다.
- `NSHealthUpdateUsageDescription`: StudyPuls가 HealthKit 권한 상태를 관리합니다.
- Mac 앱 설정 탭의 `iPhone 앱 서버 주소` 값을 복사해서 Ghost 앱의 서버 URL에 입력
- 서버 URL 예시: `http://192.168.0.12:3000`

시뮬레이터는 실제 HealthKit/Apple Watch HRV 흐름 검증에 한계가 있으니 Apple Watch와 연동된 iPhone 실기기에서 테스트해야 합니다.
