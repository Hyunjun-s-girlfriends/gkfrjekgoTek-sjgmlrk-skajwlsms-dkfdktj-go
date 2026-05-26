const router = require('express').Router();
const db = require('../config/database');
const jwt = require('jsonwebtoken');

// 인메모리 최신 상태 캐시 — Socket.IO 브로드캐스트 + 폴링용
// 서버 재시작 시 초기화되지만 모바일 앱이 곧 재전송
const state = {
  connected: false,
  lastSeen: null,
  userId: null,
  deviceInfo: null,
  hrv: null,         // 최신 HRV 데이터
  session: null,     // 최신 타이머 이벤트
  events: [],        // 최근 이벤트 로그 (최대 50개)
};

// JWT 또는 userId 직접 전달 방식 모두 허용 (기존 hrv-bridge 방식 통일)
function resolveUserId(body) {
  const { token, userId } = body;
  if (token) {
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      return decoded.id;
    } catch { return null; }
  }
  return userId ? Number(userId) : null;
}

function pushEvent(type, payload) {
  state.events.unshift({ type, payload, ts: new Date().toISOString() });
  if (state.events.length > 50) state.events.pop();
}

function broadcast(io) {
  if (io) io.emit('bridge-update', sanitizedState());
}

// connected 판정: 마지막 수신 후 30초 이내
function sanitizedState() {
  const stale = state.lastSeen
    ? (Date.now() - new Date(state.lastSeen)) / 1000 > 30
    : true;
  return { ...state, connected: !stale };
}

// ── POST /api/bridge/hrv ────────────────────────
// Apple Watch HRV 데이터 수신 및 DB 저장
router.post('/hrv', async (req, res) => {
  const userId = resolveUserId(req.body);
  if (!userId) return res.status(400).json({ error: 'userId 또는 token 필요' });

  const { hrvSdnn, heartRate, stressIndex, recordedAt } = req.body;

  try {
    await db.execute(
      'INSERT INTO hrv_data (user_id, hrv_sdnn, heart_rate, stress_index, recorded_at) VALUES (?, ?, ?, ?, ?)',
      [userId, hrvSdnn ?? null, heartRate ?? null, stressIndex ?? null, recordedAt || new Date()]
    );

    state.connected = true;
    state.lastSeen = new Date().toISOString();
    state.userId = userId;
    state.hrv = { hrvSdnn, heartRate, stressIndex, recordedAt: recordedAt || state.lastSeen };
    pushEvent('hrv', { heartRate, stressIndex, hrvSdnn });

    broadcast(req.app.get('io'));
    res.json({ success: true });
  } catch (err) {
    console.error('[bridge/hrv]', err.message);
    res.status(500).json({ error: '저장 실패' });
  }
});

// ── POST /api/bridge/session ────────────────────
// 타이머 시작/종료 이벤트 수신
router.post('/session', async (req, res) => {
  const userId = resolveUserId(req.body);
  if (!userId) return res.status(400).json({ error: 'userId 또는 token 필요' });

  const { event, subjectId, subjectName, sessionId, durationSeconds } = req.body;
  // event: 'start' | 'stop'

  try {
    if (event === 'start') {
      const startTime = new Date();
      const [result] = await db.execute(
        'INSERT INTO timer_sessions (user_id, subject_id, start_time, session_date) VALUES (?, ?, ?, CURDATE())',
        [userId, subjectId || null, startTime]
      );
      state.session = { event: 'start', subjectId, subjectName, sessionId: result.insertId, startedAt: startTime.toISOString() };
      pushEvent('session_start', { subjectName, sessionId: result.insertId });
      res.json({ success: true, sessionId: result.insertId });
    } else if (event === 'stop' && sessionId) {
      const pxEarned = Math.floor((durationSeconds || 0) / 360);
      await db.execute(
        'UPDATE timer_sessions SET end_time = NOW(), duration_seconds = ? WHERE id = ?',
        [durationSeconds || 0, sessionId]
      );
      if (pxEarned > 0) {
        await db.execute(
          'UPDATE users SET px = px + ?, level = FLOOR((px + ?) / 100) + 1 WHERE id = ?',
          [pxEarned, pxEarned, userId]
        );
      }
      state.session = { event: 'stop', subjectName, durationSeconds, pxEarned };
      pushEvent('session_stop', { subjectName, durationSeconds, pxEarned });
      res.json({ success: true, pxEarned });
    } else {
      res.status(400).json({ error: '잘못된 event 값 (start | stop)' });
      return;
    }

    state.connected = true;
    state.lastSeen = new Date().toISOString();
    state.userId = userId;
    broadcast(req.app.get('io'));
  } catch (err) {
    console.error('[bridge/session]', err.message);
    res.status(500).json({ error: '처리 실패' });
  }
});

// ── POST /api/bridge/status ─────────────────────
// 기기 하트비트 / 상태 정보 수신
router.post('/status', (req, res) => {
  const userId = resolveUserId(req.body);
  const { deviceModel, osVersion, appVersion, batteryLevel } = req.body;

  state.connected = true;
  state.lastSeen = new Date().toISOString();
  if (userId) state.userId = userId;
  state.deviceInfo = { deviceModel, osVersion, appVersion, batteryLevel };
  pushEvent('heartbeat', { deviceModel, batteryLevel });

  broadcast(req.app.get('io'));
  res.json({ success: true });
});

// ── GET /api/bridge/latest ──────────────────────
// Mac 대시보드 / 웹 브릿지 페이지 폴링용
router.get('/latest', (req, res) => {
  res.json(sanitizedState());
});

module.exports = router;
