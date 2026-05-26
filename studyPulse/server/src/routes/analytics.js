const router = require('express').Router();
const auth = require('../middleware/auth');
const db = require('../config/database');

// 특정 날짜의 시간대별 HRV 평균 + 공부 세션 목록
// ?date=YYYY-MM-DD 파라미터 없으면 오늘 날짜 사용
router.get('/hrv-by-hour', auth, async (req, res) => {
  try {
    const { date } = req.query;
    const targetDate = date || new Date().toISOString().split('T')[0];

    const [hrv] = await db.execute(
      `SELECT HOUR(recorded_at) as hour,
              AVG(hrv_sdnn) as avg_hrv,
              AVG(heart_rate) as avg_hr,
              AVG(stress_index) as avg_stress
       FROM hrv_data
       WHERE user_id = ? AND DATE(recorded_at) = ?
       GROUP BY HOUR(recorded_at)
       ORDER BY hour`,
      [req.user.id, targetDate]
    );

    const [sessions] = await db.execute(
      `SELECT HOUR(ts.start_time) as hour, s.name as subject_name, s.color,
              ts.duration_seconds
       FROM timer_sessions ts
       LEFT JOIN subjects s ON ts.subject_id = s.id
       WHERE ts.user_id = ? AND ts.session_date = ?
       ORDER BY ts.start_time`,
      [req.user.id, targetDate]
    );

    res.json({ hrv, sessions });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '시간대별 분석 조회 실패' });
  }
});

// 최근 7일 일별 스트레스/HRV 평균
router.get('/weekly-stress', auth, async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT DATE(recorded_at) as date,
              AVG(stress_index) as avg_stress,
              AVG(hrv_sdnn) as avg_hrv,
              AVG(heart_rate) as avg_hr
       FROM hrv_data
       WHERE user_id = ? AND recorded_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
       GROUP BY DATE(recorded_at)
       ORDER BY date`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '주간 스트레스 조회 실패' });
  }
});

// 특정 월의 과목별 총 공부시간 — ?year=2025&month=5 파라미터 지원
router.get('/subjects-monthly', auth, async (req, res) => {
  try {
    const { year, month } = req.query;
    const y = year || new Date().getFullYear();
    const m = month || new Date().getMonth() + 1;

    const [rows] = await db.execute(
      `SELECT s.id, s.name, s.color,
              CAST(SUM(ts.duration_seconds) AS UNSIGNED) as total_seconds,
              COUNT(ts.id) as session_count
       FROM timer_sessions ts
       JOIN subjects s ON ts.subject_id = s.id
       WHERE ts.user_id = ? AND YEAR(ts.session_date) = ? AND MONTH(ts.session_date) = ?
       GROUP BY s.id
       ORDER BY total_seconds DESC`,
      [req.user.id, y, m]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '월별 과목 조회 실패' });
  }
});

// 특정 월의 일별 총 공부시간 — 잔디 캘린더 렌더링용
router.get('/daily-monthly', auth, async (req, res) => {
  try {
    const { year, month } = req.query;
    const y = year || new Date().getFullYear();
    const m = month || new Date().getMonth() + 1;

    const [rows] = await db.execute(
      `SELECT session_date as date,
              SUM(duration_seconds) as total_seconds
       FROM timer_sessions
       WHERE user_id = ? AND YEAR(session_date) = ? AND MONTH(session_date) = ?
       GROUP BY session_date
       ORDER BY session_date`,
      [req.user.id, y, m]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '월별 일별 조회 실패' });
  }
});

module.exports = router;
