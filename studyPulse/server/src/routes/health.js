const router = require('express').Router();
const auth = require('../middleware/auth');
const db = require('../config/database');

// iPhone StudyPulsGhost 앱에서 HRV 데이터 수신
// 인증 방식 두 가지 지원:
//   1. 요청 바디에 token(JWT) 포함 → 토큰에서 userId 추출
//   2. token 없이 userId 직접 전달 → 신뢰된 내부 네트워크 환경 전제
router.post('/hrv-bridge', async (req, res) => {
  try {
    const { userId, hrvSdnn, heartRate, stressIndex, recordedAt, token } = req.body;

    let targetUserId = userId;

    if (token) {
      const jwt = require('jsonwebtoken');
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        targetUserId = decoded.id;
      } catch {
        return res.status(401).json({ error: '유효하지 않은 토큰' });
      }
    }

    if (!targetUserId) return res.status(400).json({ error: 'userId 필요' });

    await db.execute(
      'INSERT INTO hrv_data (user_id, hrv_sdnn, heart_rate, stress_index, recorded_at) VALUES (?, ?, ?, ?, ?)',
      [targetUserId, hrvSdnn, heartRate, stressIndex, recordedAt || new Date()]
    );
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '저장 실패' });
  }
});

// 가장 최근 HRV 데이터 1건 — 앱 대시보드 실시간 상태 표시용
router.get('/hrv-latest', auth, async (req, res) => {
  try {
    const [rows] = await db.execute(
      'SELECT * FROM hrv_data WHERE user_id = ? ORDER BY recorded_at DESC LIMIT 1',
      [req.user.id]
    );
    res.json(rows[0] || null);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '조회 실패' });
  }
});

// 오늘 HRV 전체 목록 — 시간대별 분석 차트용
router.get('/hrv-today', auth, async (req, res) => {
  try {
    const [rows] = await db.execute(
      'SELECT * FROM hrv_data WHERE user_id = ? AND DATE(recorded_at) = CURDATE() ORDER BY recorded_at ASC',
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '조회 실패' });
  }
});

module.exports = router;
