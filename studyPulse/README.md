# StudyPulse

AI 기반 통합 학습 분석 플랫폼 — 캡스톤 디자인 프로젝트

Apple Watch HRV 데이터를 실시간으로 수집·분석하여 공부 효율을 측정하고, 게임화된 성장 시스템과 그룹 학습 기능으로 학습 동기를 부여하는 macOS 데스크톱 앱 + 웹 대시보드입니다.

---

## 시스템 아키텍처

```
Apple Watch
    │ HRV · 심박수 (HealthKit)
    ▼
iPhone StudyPulsGhost 앱
    │ POST /api/health/hrv-bridge
    ▼
Node.js 서버 (Express) ──── MySQL 8.0 (Docker)
    │                  └──── OpenAI API (gpt-4o-mini)
    ├── macOS SwiftUI 앱 (NavigationSplitView)
    └── 웹 브라우저 SPA (Vanilla JS)
```

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| 백엔드 | Node.js 20, Express 4, Socket.IO 4 |
| 데이터베이스 | MySQL 8.0 (Docker) |
| 인증 | Google OAuth 2.0, JWT (30일 만료) |
| AI | OpenAI API `gpt-4o-mini` |
| macOS 앱 | SwiftUI (macOS 13+), Swift Charts, ASWebAuthenticationSession |
| 웹 프론트엔드 | Vanilla JS, Canvas API (차트) |

---

## 핵심 기능

- **과목별 타이머** — 최대 10개 과목, 랩 방식 공부 시간 기록
- **PX(경험치) 시스템** — 360초(6분)당 1 PX, 100 PX마다 레벨업
- **식물 성장 게임화** — 레벨에 따라 🌱 → 🌿 → 🌳 → 🌲
- **HRV 기반 분석** — 스트레스 지수, 집중도, 시간대별 분포
- **그룹 학습** — 최대 8인 그룹, 실시간 채팅(Socket.IO)
- **랭킹** — 개인(PX 기준) / 그룹(미션 클리어 수 기준) Top 100
- **일일 미션** — 개인·그룹 미션 완료 시 PX 보상
- **연속 접속 스트릭** — 매일 접속 시 스트릭 카운트 증가
- **AI 학습 코치** — 오늘 공부 데이터 + HRV 기반 맞춤 분석 리포트
- **AI 챗봇** — 학습 전략, 집중력 향상 등 실시간 대화

---

## 시작하기

### 사전 준비

- Node.js 20+
- Docker & Docker Compose
- Xcode 15+ (macOS 앱 빌드 시)
- Google Cloud 프로젝트 (OAuth 2.0 클라이언트 ID)
- OpenAI API 키 (AI 기능 사용 시, 없어도 서버 실행 가능)

---

### 1. 환경 변수 설정

```bash
cd server
cp .env.example .env
```

`.env` 파일을 편집합니다:

| 변수 | 설명 | 예시 |
|------|------|------|
| `PORT` | 서버 포트 | `3000` |
| `DB_HOST` | MySQL 호스트 | `localhost` |
| `DB_PORT` | MySQL 포트 | `3306` |
| `DB_USER` | MySQL 사용자 | `studypulse` |
| `DB_PASSWORD` | MySQL 비밀번호 | `studypulse_pw` |
| `DB_NAME` | 데이터베이스 이름 | `studypulse` |
| `JWT_SECRET` | JWT 서명 비밀키 | 32자 이상 무작위 문자열 |
| `GOOGLE_CLIENT_ID` | Google OAuth 클라이언트 ID | Google Cloud Console |
| `GOOGLE_CLIENT_SECRET` | Google OAuth 클라이언트 Secret | Google Cloud Console |
| `OPENAI_API_KEY` | OpenAI API 키 | 없으면 AI 기능 비활성화 |

---

### 2. MySQL 실행 (Docker)

```bash
cd server
docker-compose up -d
```

`schema.sql`은 Docker 볼륨 마운트로 자동 실행됩니다. 초기화 완료까지 약 30초 대기 후 서버를 시작하세요.

스키마를 수동으로 재적용하려면:

```bash
docker exec -i studypulse-db mysql -u studypulse -pstudypulse_pw studypulse < server/schema.sql
```

---

### 3. 서버 실행

```bash
cd server
npm install
npm run dev    # 개발 (nodemon, 코드 변경 시 자동 재시작)
npm start      # 프로덕션
```

서버가 시작되면 웹 대시보드는 `http://localhost:3000`에서 바로 접근 가능합니다.

---

### 4. macOS SwiftUI 앱 설정 (Xcode)

1. Xcode에서 **새 macOS App** 프로젝트 생성
   - Product Name: `StudyPulsDashboard`
   - Interface: SwiftUI / Language: Swift

2. `StudyPulsDashboard/` 폴더의 모든 `.swift` 파일을 프로젝트 네비게이터에 드래그하여 추가

3. **Info.plist** 에 키 추가:
   ```xml
   <key>GOOGLE_CLIENT_ID</key>
   <string>YOUR_CLIENT_ID.apps.googleusercontent.com</string>
   <key>GOOGLE_CLIENT_SECRET</key>
   <string>YOUR_CLIENT_SECRET</string>
   ```

4. **URL Scheme** 추가 (Target → Info → URL Types):
   - URL Schemes: `com.studypulse.dashboard`

5. 앱 실행 후 **프로필 탭 → 서버 URL** 에서 접속할 서버 주소 설정
   - 로컬: `http://localhost:3000`
   - Wi-Fi 연동: `http://192.168.X.X:3000`

---

### 5. Google OAuth 설정

[Google Cloud Console](https://console.cloud.google.com) → API 및 서비스 → 사용자 인증 정보 → OAuth 2.0 클라이언트 ID 생성:

- 애플리케이션 유형: **데스크톱 앱**
- 승인된 리디렉션 URI: `com.studypulse.dashboard:/oauth2callback`

---

### 6. iPhone ↔ 맥북 HRV 연동

1. 맥북과 iPhone을 **같은 Wi-Fi 네트워크**에 연결
2. 맥북 IP 확인: `ipconfig getifaddr en0`
3. iPhone StudyPulsGhost 앱에서 서버 주소 입력: `http://192.168.X.X:3000`
4. macOS 앱 프로필 탭에서도 동일한 주소로 설정

HRV 데이터는 `POST /api/health/hrv-bridge`로 전송됩니다.

---

## API 레퍼런스

모든 인증 필요 엔드포인트는 `Authorization: Bearer <JWT>` 헤더가 필요합니다.

### 인증

| 메서드 | 경로 | 인증 | 설명 |
|--------|------|------|------|
| POST | `/api/auth/google` | ✗ | Google ID Token 검증 후 JWT 발급 |
| POST | `/api/auth/dev-login` | ✗ | 개발용 로그인 (프로덕션 비활성화) |
| GET | `/api/auth/me` | ✓ | 내 정보 조회 |
| PUT | `/api/auth/me` | ✓ | 프로필 수정 (name, description, organization) |

### 과목

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/api/subjects` | 과목 목록 (sort_order 순) |
| POST | `/api/subjects` | 과목 생성 (최대 10개) |
| PUT | `/api/subjects/:id` | 과목 수정 |
| DELETE | `/api/subjects/:id` | 과목 삭제 |

### 타이머

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/api/timers/start` | 타이머 시작 → session_id 반환 |
| PUT | `/api/timers/:id/stop` | 타이머 종료 + PX 계산 (360초당 1px) |
| GET | `/api/timers/today` | 오늘 세션 목록 (과목 정보 포함) |
| GET | `/api/timers/today/summary` | 과목별 오늘 총 공부시간 |

### HRV / 건강

| 메서드 | 경로 | 인증 | 설명 |
|--------|------|------|------|
| POST | `/api/health/hrv-bridge` | 선택 | iPhone에서 HRV 데이터 수신 |
| GET | `/api/health/hrv-latest` | ✓ | 최신 HRV 데이터 1건 |
| GET | `/api/health/hrv-today` | ✓ | 오늘 HRV 전체 목록 |

`hrv-bridge` 요청 바디:
```json
{
  "userId": 1,
  "token": "JWT (선택)",
  "hrvSdnn": 45.2,
  "heartRate": 72,
  "stressIndex": 38.5,
  "recordedAt": "2025-05-24T10:30:00Z"
}
```

### 그룹

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/api/groups/my` | 내 그룹 목록 |
| GET | `/api/groups/recommended` | 추천 그룹 (랜덤 6개) |
| GET | `/api/groups/search?q=` | 이름으로 그룹 검색 |
| POST | `/api/groups` | 그룹 생성 |
| POST | `/api/groups/join` | 초대코드로 참가 `{ inviteCode }` |
| POST | `/api/groups/:id/join` | ID로 직접 참가 |
| DELETE | `/api/groups/:id/leave` | 그룹 나가기 |
| GET | `/api/groups/:id/members` | 멤버 목록 + 오늘 공부시간 |
| GET | `/api/groups/:id/messages` | 채팅 기록 (최근 100개) |
| POST | `/api/groups/:id/messages` | 메시지 전송 + Socket.IO 브로드캐스트 |

### 랭킹

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/api/rankings/personal` | 개인 랭킹 Top 100 (PX 기준) |
| GET | `/api/rankings/groups` | 그룹 랭킹 Top 100 (미션 클리어 수 기준) |
| POST | `/api/rankings/reward` | 주간 랭킹 PX 보상 지급 (관리자용) |

### 미션

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/api/missions/personal` | 개인 일일 미션 목록 (오늘 완료 여부 포함) |
| GET | `/api/missions/group/:groupId` | 그룹 일일 미션 목록 |
| POST | `/api/missions/:id/complete` | 미션 완료 (하루 1회 제한) |

### 분석

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/api/analytics/weekly-stress` | 최근 7일 일별 스트레스/HRV 평균 |
| GET | `/api/analytics/hrv-by-hour` | 특정 날짜 시간대별 HRV + 세션 (`?date=YYYY-MM-DD`) |
| GET | `/api/analytics/subjects-monthly` | 월별 과목별 총 공부시간 (`?year=&month=`) |
| GET | `/api/analytics/daily-monthly` | 월별 일별 총 공부시간 (잔디 캘린더용) |

### AI

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/api/ai/analyze` | 오늘 데이터 기반 학습 분석 리포트 |
| POST | `/api/ai/chat` | AI 챗봇 `{ message, history[] }` |

### 호환 레이어 (기존 SwiftUI 앱용)

구 MVP 앱과의 하위 호환을 위한 엔드포인트입니다.

| 메서드 | 경로 |
|--------|------|
| GET | `/api/dashboard` |
| GET | `/api/dashboard/focus` |
| GET | `/api/dashboard/stress` |
| GET | `/api/ai/coach` |
| POST | `/api/study/start` |
| POST | `/api/study/end` |
| GET | `/api/study/current` |

---

## 데이터베이스 스키마

```
users
  id · google_id · email · name · profile_image
  level · px · streak_days · max_streak_days · last_login_date

subjects
  id · user_id(FK) · name · color · sort_order

timer_sessions
  id · user_id(FK) · subject_id(FK→NULL) · start_time · end_time
  duration_seconds · session_date

hrv_data
  id · user_id(FK) · hrv_sdnn · heart_rate · stress_index · recorded_at

groups
  id · name · description · icon · invite_code(UNIQUE)
  owner_id(FK) · max_members · total_px · mission_clear_count

group_members
  group_id(FK) · user_id(FK)  [UNIQUE KEY]

group_messages
  id · group_id(FK) · user_id(FK) · message · created_at

missions
  id · title · description · type(personal|group)
  mission_type · target_value · px_reward · is_daily

mission_logs
  id · mission_id(FK) · user_id(FK) · group_id · px_earned · completed_at
```

---

## PX (경험치) 시스템

| 행동 | 획득 PX |
|------|---------|
| 타이머 공부 | 360초(6분)당 1 PX |
| 미션 완료 (1시간 공부) | 30 PX |
| 미션 완료 (2시간 공부) | 60 PX |
| 스트레스 낮추기 미션 | 40 PX |
| 3일 연속 접속 미션 | 100 PX |
| 그룹 함께 공부 미션 | 200 PX |

**레벨 공식**: `level = FLOOR(px / 100) + 1`

**식물 성장 단계**:
- 🌱 새싹 (Lv. 1–2)
- 🌿 성장 중 (Lv. 3–6)
- 🌳 나무 (Lv. 7–14)
- 🌲 울창한 숲 (Lv. 15+)

---

## 프로젝트 구조

```
studyPulse/
├── server/                         # Node.js 백엔드
│   ├── src/
│   │   ├── app.js                  # Express 서버 진입점
│   │   ├── config/
│   │   │   └── database.js         # MySQL 커넥션 풀
│   │   ├── middleware/
│   │   │   └── auth.js             # JWT Bearer 인증 미들웨어
│   │   └── routes/
│   │       ├── auth.js             # Google OAuth + JWT 발급
│   │       ├── users.js            # 프로필 수정
│   │       ├── subjects.js         # 과목 CRUD
│   │       ├── timers.js           # 타이머 세션 + PX 계산
│   │       ├── health.js           # HRV 데이터 수신/조회
│   │       ├── groups.js           # 그룹 관리 + 채팅
│   │       ├── missions.js         # 미션 완료 처리
│   │       ├── rankings.js         # 개인/그룹 랭킹
│   │       ├── analytics.js        # 학습 분석 집계 쿼리
│   │       ├── ai.js               # OpenAI 분석 리포트 + 챗봇
│   │       └── compat.js           # 구 SwiftUI 앱 호환 레이어
│   ├── schema.sql                  # DB 스키마 + 기본 미션 데이터
│   ├── docker-compose.yml          # MySQL 8.0 Docker 설정
│   ├── Dockerfile                  # 서버 컨테이너 이미지
│   ├── .env.example                # 환경 변수 템플릿
│   └── package.json
├── public/                         # 웹 프론트엔드 (SPA)
│   ├── index.html                  # macOS 스타일 UI
│   ├── app.js                      # 메인 앱 로직
│   └── style.css
└── StudyPulsDashboard/             # macOS SwiftUI 앱
    ├── StudyPulsDashboardApp.swift  # 앱 진입점
    ├── ContentView.swift           # NavigationSplitView 레이아웃
    ├── Models/
    │   └── Models.swift            # Codable 데이터 모델
    ├── Services/
    │   ├── APIClient.swift         # HTTP 클라이언트 (async/await)
    │   └── AuthManager.swift       # Google OAuth + JWT 관리
    └── Views/
        ├── LoginView.swift         # 로그인 화면
        ├── MainView.swift          # 타이머 + 미션
        ├── GroupView.swift         # 그룹 관리 + 채팅
        ├── RankingView.swift       # 개인/그룹 랭킹
        ├── AnalyticsView.swift     # Swift Charts 기반 분석
        ├── AIView.swift            # AI 분석 + 챗봇
        └── ProfileView.swift       # 프로필 + 서버 설정
```

---

## Socket.IO 이벤트

그룹 채팅에 Socket.IO를 사용합니다. SwiftUI 앱은 폴링(5초) 방식을, 웹 클라이언트는 서버에서 직접 이벤트를 수신합니다.

| 이벤트 | 방향 | 설명 |
|--------|------|------|
| `join-group` | client → server | 그룹 룸 참가 |
| `leave-group` | client → server | 그룹 룸 퇴장 |
| `new-message` | server → client | 새 메시지 브로드캐스트 |
