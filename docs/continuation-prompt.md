# Continuation Prompt

You are continuing development on the StudyPuls local MVP in `/Users/taein/Documents/mindcharry`.

Context:
- The Notion source of truth is only the `정신체리 > 캡스톤 StudyPuls (1)` tree.
- The user explicitly asked not to write a review report and to start development.
- A dependency-free Node.js local MVP was scaffolded.
- Main files:
  - `src/server.js`: HTTP server and API routing
  - `src/store.js`: JSON-backed datastore and domain logic
  - `public/index.html`, `public/styles.css`, `public/app.js`: dashboard UI
  - `schema/mysql.sql`: MySQL migration target
- Implemented API areas:
  - auth, profile, study timer, health sample ingestion, dashboard, AI report/recommend/chat mock, groups/ranking, missions, notification settings
- Added `.env` loading through `src/config.js`.
- Added OpenAI-backed coaching through `src/aiCoach.js`; if `AI_PROVIDER=openai` and `OPENAI_API_KEY` exist, `/api/ai/coach`, `/api/ai/report`, `/api/ai/recommend`, and `/api/ai/chat` attempt OpenAI Responses API and fall back to local coaching on failure.
- Added MySQL Docker setup:
  - `docker-compose.yml`
  - `schema/mysql.sql`
  - `docker/mysql/02-users.sh`
  - DB users are `studypuls_admin` with schema/admin privileges and `studypuls_app` with table CRUD only.
- Development goal:
  - Make the app run locally on MacBook first.
  - Keep AWS out for now.
  - Keep Swift/HealthKit as a later integration point sending data to `/api/health/heart-rate`.

Next best tasks:
1. Run `npm test` and `npm run dev`.
2. Add node tests for stress/focus calculations and API behavior.
3. Improve UI for missions and settings.
4. Add a MySQL adapter behind the same store interface.
5. Add a minimal Swift/HealthKit sample client only after the Node MVP is stable.
