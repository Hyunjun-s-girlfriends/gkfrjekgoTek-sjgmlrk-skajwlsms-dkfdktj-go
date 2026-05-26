const router = require('express').Router();
const auth = require('../middleware/auth');
const db = require('../config/database');

// 타이머 시작 — 새 세션 레코드 생성 후 반환
router.post('/start', auth, async (req, res) => {
  try {
    const { subjectId } = req.body;
    const [result] = await db.execute(
      'INSERT INTO timer_sessions (user_id, subject_id, start_time, session_date) VALUES (?, ?, NOW(), CURDATE())',
      [req.user.id, subjectId || null]
    );
    const [rows] = await db.execute('SELECT * FROM timer_sessions WHERE id = ?', [result.insertId]);
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '타이머 시작 실패' });
  }
});

// 타이머 종료 — 클라이언트가 측정한 durationSeconds를 기준으로 PX 계산
router.put('/:id/stop', auth, async (req, res) => {
  try {
    const { durationSeconds } = req.body;
    await db.execute(
      'UPDATE timer_sessions SET end_time = NOW(), duration_seconds = ? WHERE id = ? AND user_id = ?',
      [durationSeconds, req.params.id, req.user.id]
    );

    // PX 공식: 360초(6분)당 1px → 1시간 = 10px
    // px + level을 단일 쿼리로 원자적 업데이트 (레이스 컨디션 방지)
    const pxEarned = Math.floor(durationSeconds / 360);
    if (pxEarned > 0) {
      await db.execute(
        'UPDATE users SET px = px + ?, level = FLOOR((px + ?) / 100) + 1 WHERE id = ?',
        [pxEarned, pxEarned, req.user.id]
      );
    }

    const [rows] = await db.execute('SELECT * FROM timer_sessions WHERE id = ?', [req.params.id]);
    res.json({ session: rows[0], pxEarned });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '타이머 종료 실패' });
  }
});

// 오늘 타이머 세션 목록 (과목 정보 포함)
router.get('/today', auth, async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT ts.*, s.name as subject_name, s.color as subject_color
       FROM timer_sessions ts
       LEFT JOIN subjects s ON ts.subject_id = s.id
       WHERE ts.user_id = ? AND ts.session_date = CURDATE()
       ORDER BY ts.start_time DESC`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '세션 조회 실패' });
  }
});

// 과목별 오늘 총 공부 시간 요약
router.get('/today/summary', auth, async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT s.id, s.name, s.color,
              COALESCE(SUM(ts.duration_seconds), 0) as total_seconds
       FROM subjects s
       LEFT JOIN timer_sessions ts ON s.id = ts.subject_id AND ts.session_date = CURDATE()
       WHERE s.user_id = ?
       GROUP BY s.id`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '요약 조회 실패' });
  }
});

module.exports = router;
