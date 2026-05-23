# Continuation Prompt

You are continuing development on the StudyPuls local MVP in `/Users/taein/Documents/mindcharry`.

Read these first:
- `docs/development-handoff.md`
- `docs/ai-cli-prompt.md`
- `README.md`
- `src/server.js`
- `src/store.js`
- `Apps/StudyPulsDashboard/Sources`
- `Apps/StudyPulsGhost`

Current architecture:
- macOS SwiftUI app: `Apps/StudyPulsDashboard`
- Local Node.js API server: `src/server.js`
- JSON-backed domain store: `src/store.js`
- iPhone HealthKit bridge app: `Apps/StudyPulsGhost`
- MySQL migration target: `schema/mysql.sql`, `docker-compose.yml`, `docker/mysql/02-users.sh`

Important current behavior:
- Mac app window max is `1000x700`; it can shrink but must not grow beyond that.
- Main dashboard should only show summary, focus chart, HRV/stress, and AirPods drowsiness.
- AI coaching, subject timer, and group features should remain in their own tabs.
- Do not restore manual HRV/stress input UI as a product feature.
- Real HRV should flow from Apple Watch to iPhone HealthKit, then from the iPhone Ghost app to Mac server endpoint `/api/health/hrv-bridge`.
- AirPods drowsiness uses macOS CoreMotion headphone motion and posts to `/api/motion/headphone-sample`.
- OpenAI coaching is in `src/aiCoach.js` and falls back locally if the provider fails.
- MySQL schema and Docker users exist, but the running server still uses JSON storage.

Verification commands:
- `node --check src/store.js`
- `node --check src/server.js`
- `npm test`
- `./scripts/build-mac-app.sh`

Next best tasks:
1. Create/verify the actual Xcode iOS target for `Apps/StudyPulsGhost`.
2. Test HealthKit permission, entitlement, and real Apple Watch HRV sample delivery on device.
3. Make the Mac settings server URL easier to copy into the iPhone Ghost app.
4. Decide whether to keep JSON for MVP or implement a MySQL adapter behind the current store function contracts.
5. Re-run the verification commands after every meaningful change.
