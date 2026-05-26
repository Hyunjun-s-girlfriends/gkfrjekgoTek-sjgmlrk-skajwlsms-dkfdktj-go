/**
 * 기존 StudyPuls MVP SwiftUI 앱과의 호환 레이어
 * 기존 API 형식을 새 Express+MySQL 서버가 지원하도록 변환
 */
const router = require('express').Router();
const auth = require('../middleware/auth');
const db = require('../config/database');

// OpenAI lazy 초기화 (API 키 없어도 서버 시작 가능)
let _openai = null;
function getOpenAI() {
  if (!_openai && process.env.OPENAI_API_KEY) {
    const OpenAI = require('openai');
    _openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  }
  return _openai;
}

// HRV → 스트레스/집중도 계산 (기존 로직 유지)
function stressFromHRV(hrv, heartRate) {
  const hrvStress = Math.max(0, Math.min(100, 100 - (hrv || 0)));
  const hrStress = Math.max(0, Math.min(100, ((heartRate || 70) - 55) * 1.4));
  return Math.round(hrvStress * 0.65 + hrStress * 0.35);
}
function focusFromStress(stress) {
  return Math.max(0, Math.min(100, Math.round(100 - Math.abs(stress - 55) * 1.7)));
}
function hourKey(ts) {
  return `${String(new Date(ts).getHours()).padStart(2, '0')}:00`;
}
function avg(arr) {
  return arr.length ? Math.round(arr.reduce((a, b) => a + b, 0) / arr.length) : 0;
}

// 현재 세션 (인메모리 간단 관리)
const activeSessions = new Map(); // userId → sessionId

// ─── GET /api/dashboard ────────────────────────────────
router.get('/dashboard', auth, async (req, res) => {
  const uid = req.user.id;
  const [[user]] = await db.execute('SELECT * FROM users WHERE id = ?', [uid]);
  const [sessions] = await db.execute(
    `SELECT ts.*, s.name as subject_name FROM timer_sessions ts
     LEFT JOIN subjects s ON ts.subject_id = s.id
     WHERE ts.user_id = ? AND ts.session_date = CURDATE()
     ORDER BY ts.start_time DESC`,
    [uid]
  );
  const [hrv] = await db.execute(
    `SELECT hrv_sdnn as hrv, heart_rate as heartRate, stress_index, recorded_at as timestamp
     FROM hrv_data WHERE user_id = ? AND DATE(recorded_at) = CURDATE()
     ORDER BY recorded_at ASC`,
    [uid]
  );
  const [subjects] = await db.execute(
    `SELECT s.id, s.name, s.color,
            COALESCE(SUM(ts.duration_seconds)/60, 0) as totalMinutes
     FROM subjects s LEFT JOIN timer_sessions ts ON s.id = ts.subject_id AND ts.session_date = CURDATE()
     WHERE s.user_id = ?
     GROUP BY s.id`,
    [uid]
  );
  const [missions] = await db.execute(
    `SELECT m.id,
      (SELECT COUNT(*) FROM mission_logs ml WHERE ml.mission_id = m.id AND ml.user_id = ? AND DATE(ml.completed_at) = CURDATE()) as done
     FROM missions m WHERE m.type = 'personal'`,
    [uid]
  );
  const [groupMembers] = await db.execute(
    'SELECT group_id FROM group_members WHERE user_id = ? LIMIT 1', [uid]
  );

  const totalMinutes = Math.round(sessions.reduce((a, s) => a + (s.duration_seconds || 0) / 60, 0));
  const stressValues = hrv.map(h => stressFromHRV(h.hrv, h.heartRate));
  const focusValues = hrv.map(h => focusFromStress(stressFromHRV(h.hrv, h.heartRate)));

  const hourlyFocus = {};
  hrv.forEach(h => {
    const k = hourKey(h.timestamp);
    (hourlyFocus[k] = hourlyFocus[k] || []).push(focusFromStress(stressFromHRV(h.hrv, h.heartRate)));
  });
  const bestHour = Object.entries(hourlyFocus)
    .map(([h, v]) => ({ h, f: avg(v) }))
    .sort((a, b) => b.f - a.f)[0]?.h || '-';

  const currentSessionId = activeSessions.get(uid);
  let currentSession = null;
  if (currentSessionId) {
    const [cs] = await db.execute(
      `SELECT ts.*, s.name as subjectName FROM timer_sessions ts
       LEFT JOIN subjects s ON ts.subject_id = s.id WHERE ts.id = ?`,
      [currentSessionId]
    );
    if (cs[0] && !cs[0].end_time) {
      currentSession = {
        id: String(cs[0].id),
        subjectName: cs[0].subjectName || '기타',
        startedAt: cs[0].start_time,
        endedAt: null,
        totalMinutes: 0
      };
    }
  }

  res.json({
    user: {
      id: String(uid),
      username: user.email?.split('@')[0],
      name: user.name,
      xp: user.px || 0,
      credits: Math.floor((user.px || 0) / 10),
      title: levelTitle(user.level || 1),
      streakDays: user.streak_days || 0,
      level: user.level || 1,
    },
    totals: {
      totalMinutes,
      sessionCount: sessions.length,
      avgStress: avg(stressValues),
      avgFocus: avg(focusValues),
      bestHour,
      drowsyCount: 0,
      missionDone: missions.filter(m => m.done > 0).length,
      missionTotal: missions.length,
    },
    subjects: subjects.map(s => ({
      id: s.id.toString(),
      name: s.name,
      color: s.color,
      totalMinutes: Math.round(s.totalMinutes),
      avgStress: avg(stressValues),
      avgFocus: avg(focusValues),
    })),
    recentSessions: sessions.slice(0, 8).map(s => ({
      id: String(s.id),
      subjectName: s.subject_name || '기타',
      startedAt: s.start_time,
      endedAt: s.end_time,
      totalMinutes: Math.round((s.duration_seconds || 0) / 60),
      avgStress: null, avgFocus: null, avgHeartRate: null, avgHrv: null,
    })),
    currentSession,
    devices: [
      { id: 'watch_bridge', name: 'Apple Watch Bridge', deviceType: 'APPLE_WATCH_BRIDGE',
        status: hrv.length > 0 ? 'connected' : 'waiting', bridgeMode: true,
        lastSyncedAt: hrv.at(-1)?.timestamp || null },
      { id: 'airpods', name: 'AirPods CoreMotion', deviceType: 'AIRPODS',
        status: 'waiting', bridgeMode: false, lastSyncedAt: null },
    ],
    notification: { focusAlert: true, missionAlert: true, drowsinessAlert: true },
    groupId: groupMembers[0]?.group_id?.toString() || null,
  });
});

function levelTitle(level) {
  if (level < 3) return '새싹 학습자';
  if (level < 7) return '루틴 탐색자';
  if (level < 15) return '집중 마스터';
  return '학습 전문가';
}

// ─── GET /api/dashboard/focus ──────────────────────────
router.get('/dashboard/focus', auth, async (req, res) => {
  const [hrv] = await db.execute(
    'SELECT hrv_sdnn as hrv, heart_rate as heartRate, recorded_at as timestamp FROM hrv_data WHERE user_id = ? AND DATE(recorded_at) = CURDATE()',
    [req.user.id]
  );
  const grouped = {};
  hrv.forEach(h => {
    const k = hourKey(h.timestamp);
    (grouped[k] = grouped[k] || []).push(focusFromStress(stressFromHRV(h.hrv, h.heartRate)));
  });
  res.json(Object.entries(grouped).sort().map(([hour, v]) => ({ hour, focus: avg(v) })));
});

// ─── GET /api/dashboard/stress ─────────────────────────
router.get('/dashboard/stress', auth, async (req, res) => {
  const [hrv] = await db.execute(
    'SELECT hrv_sdnn as hrv, heart_rate as heartRate, recorded_at as timestamp FROM hrv_data WHERE user_id = ? AND DATE(recorded_at) = CURDATE() ORDER BY recorded_at ASC',
    [req.user.id]
  );
  res.json(hrv.map(h => {
    const stress = stressFromHRV(h.hrv, h.heartRate);
    return { timestamp: h.timestamp, hour: hourKey(h.timestamp),
             stress, focus: focusFromStress(stress), heartRate: h.heartRate || 0, hrv: h.hrv || 0 };
  }));
});

// ─── GET /api/dashboard/drowsiness ─────────────────────
router.get('/dashboard/drowsiness', auth, async (_req, res) => {
  res.json([]); // AirPods CoreMotion 데이터 없음
});

// ─── GET /api/ai/coach ─────────────────────────────────
router.get('/ai/coach', auth, async (req, res) => {
  const uid = req.user.id;
  const [hrv] = await db.execute(
    `SELECT hrv_sdnn as hrv, heart_rate as heartRate, recorded_at as timestamp
     FROM hrv_data WHERE user_id = ? AND DATE(recorded_at) = CURDATE() ORDER BY recorded_at ASC`,
    [uid]
  );
  const [sessions] = await db.execute(
    `SELECT ts.duration_seconds, s.name as subject_name FROM timer_sessions ts
     LEFT JOIN subjects s ON ts.subject_id = s.id
     WHERE ts.user_id = ? AND ts.session_date = CURDATE()`,
    [uid]
  );

  const samples = hrv.map(h => {
    const stress = stressFromHRV(h.hrv, h.heartRate);
    return { timestamp: h.timestamp, hour: hourKey(h.timestamp), stress, focus: focusFromStress(stress), hrv: h.hrv || 0 };
  });
  const grouped = {};
  samples.forEach(s => { (grouped[s.hour] = grouped[s.hour] || []).push(s.focus); });
  const ranked = Object.entries(grouped).map(([h, v]) => ({ h, f: avg(v) })).sort((a, b) => b.f - a.f);

  const totalMinutes = Math.round(sessions.reduce((a, s) => a + (s.duration_seconds || 0) / 60, 0));
  const avgFocus = avg(samples.map(s => s.focus));
  const avgStress = avg(samples.map(s => s.stress));

  // OpenAI 또는 로컬 폴백
  const openai = getOpenAI();
  if (openai) {
    try {
      const subjectSummary = sessions.map(s => s.subject_name || '기타').join(', ') || '없음';
      const prompt = `StudyPuls 학습 코치로서 JSON만 반환. 키: summary, bestTime, weakTime, coaching, nextActions(배열).
데이터: 총공부 ${totalMinutes}분, 과목: ${subjectSummary}, 평균집중도: ${avgFocus}, 평균스트레스: ${avgStress}`;
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini', messages: [{ role: 'user', content: prompt }],
        response_format: { type: 'json_object' }, max_tokens: 400,
      });
      const ai = JSON.parse(completion.choices[0].message.content);
      return res.json({ provider: 'openai', summary: ai.summary, bestTime: ai.bestTime,
        weakTime: ai.weakTime, coaching: ai.coaching, nextActions: ai.nextActions || [] });
    } catch {}
  }

  res.json({
    provider: 'local',
    summary: `평균 집중도 ${avgFocus}점, 평균 스트레스 ${avgStress}점입니다.`,
    bestTime: ranked[0] ? `${ranked[0].h} 전후가 집중도가 가장 높은 시간대입니다.` : '아직 데이터가 부족합니다.',
    weakTime: ranked.at(-1) ? `${ranked.at(-1).h}에는 가벼운 복습을 권장합니다.` : '더 많은 공부 세션이 필요합니다.',
    coaching: avgStress > 70 ? 'HRV가 낮고 스트레스가 높습니다. 5분 스트레칭 후 재시작하세요.' : '현재 컨디션이 양호합니다. 고난도 과목에 집중하세요.',
    nextActions: ['집중이 잘 되는 시간대에 어려운 과목 배치', '스트레스가 높아지면 5분 휴식', '오늘 최소 2개 과목 타이머 기록'],
  });
});

// ─── GET /api/groups/ranking ───────────────────────────
router.get('/groups/ranking', auth, async (req, res) => {
  const uid = req.user.id;
  const groupId = req.query.groupId;

  // 내 그룹 찾기
  const [[myGroup]] = await db.execute(
    'SELECT group_id FROM group_members WHERE user_id = ? LIMIT 1', [uid]
  );
  const targetGroupId = groupId || myGroup?.group_id;

  if (!targetGroupId) {
    return res.json({ groupId: null, rows: [] });
  }

  // MySQL 8.0은 윈도우 함수 ORDER BY에서 NULLS LAST 구문을 지원하지 않음
  // COALESCE로 NULL을 0으로 치환하여 동일한 정렬 결과 확보
  const [members] = await db.execute(
    `SELECT u.id, u.name, u.px as xp,
            COALESCE(SUM(ts.duration_seconds)/60, 0) as totalMinutes,
            ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(ts.duration_seconds), 0) DESC) as rank
     FROM group_members gm
     JOIN users u ON gm.user_id = u.id
     LEFT JOIN timer_sessions ts ON u.id = ts.user_id AND ts.session_date = CURDATE()
     WHERE gm.group_id = ?
     GROUP BY u.id`,
    [targetGroupId]
  );

  const rankReward = (r) => r <= 3 ? 200 : r <= 20 ? 100 : r <= 50 ? 50 : 0;

  res.json({
    groupId: targetGroupId.toString(),
    rows: members.map((m, i) => ({
      userId: m.id.toString(),
      name: m.name,
      xp: m.xp || 0,
      totalMinutes: Math.round(m.totalMinutes),
      rank: i + 1,
      rewardCredits: rankReward(i + 1),
    })),
  });
});

// ─── GET /api/devices/status ───────────────────────────
router.get('/devices/status', auth, async (req, res) => {
  const [[latest]] = await db.execute(
    'SELECT recorded_at FROM hrv_data WHERE user_id = ? ORDER BY recorded_at DESC LIMIT 1',
    [req.user.id]
  );
  res.json({
    devices: [
      { id: 'watch_bridge', name: 'Apple Watch Bridge', deviceType: 'APPLE_WATCH_BRIDGE',
        status: latest ? 'connected' : 'waiting', bridgeMode: true,
        lastSyncedAt: latest?.recorded_at || null },
      { id: 'airpods', name: 'AirPods CoreMotion', deviceType: 'AIRPODS',
        status: 'waiting', bridgeMode: false, lastSyncedAt: null },
    ],
  });
});

// ─── POST /api/devices/watch-bridge/connect ────────────
router.post('/devices/watch-bridge/connect', auth, async (_req, res) => {
  res.json({
    devices: [
      { id: 'watch_bridge', name: 'Apple Watch Bridge', deviceType: 'APPLE_WATCH_BRIDGE',
        status: 'connected', bridgeMode: true, lastSyncedAt: new Date().toISOString() },
      { id: 'airpods', name: 'AirPods CoreMotion', deviceType: 'AIRPODS',
        status: 'waiting', bridgeMode: false, lastSyncedAt: null },
    ],
  });
});

// ─── POST /api/study/start ─────────────────────────────
router.post('/study/start', auth, async (req, res) => {
  const uid = req.user.id;
  const { subjectId } = req.body;
  const [result] = await db.execute(
    'INSERT INTO timer_sessions (user_id, subject_id, start_time, session_date) VALUES (?, ?, NOW(), CURDATE())',
    [uid, subjectId || null]
  );
  activeSessions.set(uid, result.insertId);
  const [rows] = await db.execute(
    `SELECT ts.*, s.name as subjectName FROM timer_sessions ts
     LEFT JOIN subjects s ON ts.subject_id = s.id WHERE ts.id = ?`,
    [result.insertId]
  );
  const s = rows[0];
  res.json({ id: String(s.id), subjectName: s.subjectName || '기타',
             startedAt: s.start_time, endedAt: null, totalMinutes: 0 });
});

// ─── POST /api/study/end ───────────────────────────────
router.post('/study/end', auth, async (req, res) => {
  const uid = req.user.id;
  const sessionId = req.body.sessionId || activeSessions.get(uid);
  if (!sessionId) return res.status(404).json({ error: '진행 중인 세션 없음' });

  const [[session]] = await db.execute('SELECT * FROM timer_sessions WHERE id = ? AND user_id = ?', [sessionId, uid]);
  if (!session) return res.status(404).json({ error: '세션 없음' });

  const durationSeconds = Math.floor((Date.now() - new Date(session.start_time).getTime()) / 1000);
  await db.execute('UPDATE timer_sessions SET end_time = NOW(), duration_seconds = ? WHERE id = ?', [durationSeconds, sessionId]);

  const pxEarned = Math.floor(durationSeconds / 360);
  if (pxEarned > 0) {
    await db.execute('UPDATE users SET px = px + ?, level = FLOOR((px + ?) / 100) + 1 WHERE id = ?', [pxEarned, pxEarned, uid]);
  }
  activeSessions.delete(uid);

  res.json({ id: String(sessionId), subjectName: session.subject_name || '기타',
             startedAt: session.start_time, endedAt: new Date().toISOString(),
             totalMinutes: Math.round(durationSeconds / 60) });
});

// ─── GET /api/study/current ────────────────────────────
router.get('/study/current', auth, async (req, res) => {
  const uid = req.user.id;
  const sessionId = activeSessions.get(uid);
  if (!sessionId) return res.json(null);
  const [[s]] = await db.execute(
    `SELECT ts.*, s.name as subjectName FROM timer_sessions ts
     LEFT JOIN subjects s ON ts.subject_id = s.id WHERE ts.id = ? AND ts.user_id = ?`,
    [sessionId, uid]
  );
  if (!s || s.end_time) return res.json(null);
  res.json({ id: String(s.id), subjectName: s.subjectName || '기타', startedAt: s.start_time, endedAt: null, totalMinutes: 0 });
});

// ─── PATCH /api/users/me ───────────────────────────────
router.patch('/users/me', auth, async (req, res) => {
  const { name, title, tags } = req.body;
  await db.execute('UPDATE users SET name = COALESCE(?, name) WHERE id = ?', [name, req.user.id]);
  const [[user]] = await db.execute('SELECT * FROM users WHERE id = ?', [req.user.id]);
  res.json({ id: String(user.id), username: user.email?.split('@')[0], name: user.name,
             xp: user.px || 0, credits: Math.floor((user.px || 0) / 10), title: levelTitle(user.level || 1) });
});

// ─── GET /api/missions/today ───────────────────────────
router.get('/missions/today', auth, async (req, res) => {
  const uid = req.user.id;
  const [rows] = await db.execute(
    `SELECT m.*,
            (SELECT COUNT(*) FROM mission_logs ml WHERE ml.mission_id = m.id AND ml.user_id = ? AND DATE(ml.completed_at) = CURDATE()) as done
     FROM missions m WHERE m.type = 'personal'`,
    [uid]
  );
  res.json(rows.map(m => ({
    id: m.id.toString(), userId: uid.toString(),
    title: m.title, type: m.mission_type, target: m.target_value,
    rewardXp: m.px_reward, rewardCredits: Math.floor(m.px_reward / 3),
    completed: m.done > 0,
    createdAt: m.created_at, completedAt: m.done > 0 ? new Date().toISOString() : null,
  })));
});

// ─── POST /api/missions/complete ──────────────────────
router.post('/missions/complete', auth, async (req, res) => {
  const uid = req.user.id;
  const missionId = req.body.missionId;
  const [[mission]] = await db.execute('SELECT * FROM missions WHERE id = ?', [missionId]);
  if (!mission) return res.status(404).json({ error: '미션 없음' });

  const [existing] = await db.execute(
    'SELECT id FROM mission_logs WHERE mission_id = ? AND user_id = ? AND DATE(completed_at) = CURDATE()',
    [missionId, uid]
  );
  if (existing.length) return res.status(400).json({ error: '이미 완료' });

  await db.execute('INSERT INTO mission_logs (mission_id, user_id, px_earned) VALUES (?, ?, ?)', [missionId, uid, mission.px_reward]);
  await db.execute('UPDATE users SET px = px + ?, level = FLOOR((px + ?) / 100) + 1 WHERE id = ?', [mission.px_reward, mission.px_reward, uid]);

  const [[user]] = await db.execute('SELECT * FROM users WHERE id = ?', [uid]);
  res.json({
    mission: { id: missionId.toString(), completed: true, completedAt: new Date().toISOString() },
    user: { id: String(user.id), name: user.name, xp: user.px, credits: Math.floor(user.px / 10) },
  });
});

// ─── POST /api/health/heart-rate (alias) ──────────────
router.post('/health/heart-rate', auth, async (req, res) => {
  const { heartRate, hrv, timestamp } = req.body;
  await db.execute(
    'INSERT INTO hrv_data (user_id, hrv_sdnn, heart_rate, stress_index, recorded_at) VALUES (?, ?, ?, ?, ?)',
    [req.user.id, hrv || null, heartRate || null,
     stressFromHRV(hrv, heartRate), timestamp || new Date()]
  );
  res.json({ success: true });
});

// ─── POST /api/dev/seed ────────────────────────────────
router.post('/dev/seed', async (_req, res) => {
  res.json({ ok: true, message: 'Express+MySQL 서버는 schema.sql로 초기화하세요.' });
});

// ─── POST /api/auth/logout ─────────────────────────────
router.post('/auth/logout', (_req, res) => {
  res.json({ ok: true });
});

// ─── GET /api/auth/signup, login (Legacy - 호환용) ──────
router.post('/auth/signup', async (req, res) => {
  res.status(400).json({ error: 'Google OAuth를 사용해주세요. /api/auth/google' });
});
router.post('/auth/login', async (req, res) => {
  res.status(400).json({ error: 'Google OAuth를 사용해주세요. /api/auth/google' });
});

// ─── PUT /api/settings/notification ───────────────────
router.put('/settings/notification', auth, async (_req, res) => {
  res.json({ focusAlert: true, missionAlert: true, drowsinessAlert: true });
});

// ─── GET /api/groups (compat createGroup) ─────────────
router.post('/groups', auth, async (req, res) => {
  const { groupName, description } = req.body;
  const { v4: uuidv4 } = require('uuid');
  const inviteCode = uuidv4().substring(0, 8).toUpperCase();
  const [result] = await db.execute(
    'INSERT INTO `groups` (name, description, invite_code, owner_id) VALUES (?, ?, ?, ?)',
    [groupName || '새 스터디 그룹', description || '', inviteCode, req.user.id]
  );
  await db.execute('INSERT INTO group_members (group_id, user_id) VALUES (?, ?)', [result.insertId, req.user.id]);
  const [[group]] = await db.execute('SELECT * FROM `groups` WHERE id = ?', [result.insertId]);
  res.status(201).json({ ...group, inviteCode });
});

module.exports = router;
