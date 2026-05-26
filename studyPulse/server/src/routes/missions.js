const router = require('express').Router();
const auth = require('../middleware/auth');
const db = require('../config/database');

// 개인 일일 미션 목록 (오늘 완료 여부 포함)
router.get('/personal', auth, async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT m.*,
              (SELECT COUNT(*) FROM mission_logs ml
               WHERE ml.mission_id = m.id AND ml.user_id = ? AND DATE(ml.completed_at) = CURDATE()) as completed_today
       FROM missions m
       WHERE m.type = 'personal' AND m.is_daily = TRUE`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '미션 조회 실패' });
  }
});

// 그룹 일일 미션 목록 (오늘 그룹 완료 여부 포함)
router.get('/group/:groupId', auth, async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT m.*,
              (SELECT COUNT(*) FROM mission_logs ml
               WHERE ml.mission_id = m.id AND ml.group_id = ? AND DATE(ml.completed_at) = CURDATE()) as completed_today
       FROM missions m
       WHERE m.type = 'group' AND m.is_daily = TRUE`,
      [req.params.groupId]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '그룹 미션 조회 실패' });
  }
});

// 미션 완료 처리 — 하루에 한 번만 완료 가능 (mission_logs 중복 체크)
router.post('/:id/complete', auth, async (req, res) => {
  try {
    const { groupId } = req.body;
    const missionId = req.params.id;

    const [existing] = await db.execute(
      'SELECT id FROM mission_logs WHERE mission_id = ? AND user_id = ? AND DATE(completed_at) = CURDATE()',
      [missionId, req.user.id]
    );
    if (existing.length) return res.status(400).json({ error: '오늘 이미 완료한 미션입니다.' });

    const [missions] = await db.execute('SELECT * FROM missions WHERE id = ?', [missionId]);
    if (!missions.length) return res.status(404).json({ error: '미션 없음' });

    const mission = missions[0];

    await db.execute(
      'INSERT INTO mission_logs (mission_id, user_id, group_id, px_earned) VALUES (?, ?, ?, ?)',
      [missionId, req.user.id, groupId || null, mission.px_reward]
    );

    // px + level을 단일 쿼리로 원자적 업데이트 (레이스 컨디션 방지)
    await db.execute(
      'UPDATE users SET px = px + ?, level = FLOOR((px + ?) / 100) + 1 WHERE id = ?',
      [mission.px_reward, mission.px_reward, req.user.id]
    );

    // 그룹 미션: 그룹 누적 PX + 클리어 카운트 업데이트
    if (groupId) {
      await db.execute(
        'UPDATE `groups` SET total_px = total_px + ?, mission_clear_count = mission_clear_count + 1 WHERE id = ?',
        [mission.px_reward, groupId]
      );
    }

    const [user] = await db.execute('SELECT px, level FROM users WHERE id = ?', [req.user.id]);
    res.json({ success: true, pxEarned: mission.px_reward, user: user[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '미션 완료 처리 실패' });
  }
});

module.exports = router;
