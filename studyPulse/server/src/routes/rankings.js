const router = require('express').Router();
const auth = require('../middleware/auth');
const db = require('../config/database');

// 개인 랭킹 — 오늘 공부한 사람만 표시 (본인은 항상 포함), PX 기준 Top 100
router.get('/personal', auth, async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT u.id, u.name, u.profile_image, u.level, u.px,
              CAST(COALESCE(SUM(ts.duration_seconds), 0) AS UNSIGNED) as total_study_today,
              RANK() OVER (ORDER BY u.px DESC) as rank_position
       FROM users u
       LEFT JOIN timer_sessions ts ON u.id = ts.user_id AND ts.session_date = CURDATE()
       WHERE u.id = ?
          OR EXISTS (
            SELECT 1 FROM timer_sessions ts2
            WHERE ts2.user_id = u.id AND ts2.session_date = CURDATE()
          )
       GROUP BY u.id
       ORDER BY u.px DESC
       LIMIT 100`,
      [req.user.id]
    );
    const myRank = rows.find(r => r.id === req.user.id) || null;
    res.json({ rankings: rows, myRank });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '랭킹 조회 실패' });
  }
});

// 그룹 랭킹 — 내가 속한 그룹만, 미션 클리어 수 기준 (동점 시 total_px)
router.get('/groups', auth, async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT g.id, g.name, g.icon, g.total_px, g.mission_clear_count,
              CAST(COUNT(gm.id) AS UNSIGNED) as member_count,
              RANK() OVER (ORDER BY g.mission_clear_count DESC, g.total_px DESC) as rank_position
       FROM \`groups\` g
       LEFT JOIN group_members gm ON g.id = gm.group_id
       WHERE EXISTS (
         SELECT 1 FROM group_members gm2
         WHERE gm2.group_id = g.id AND gm2.user_id = ?
       )
       GROUP BY g.id
       ORDER BY g.mission_clear_count DESC, g.total_px DESC
       LIMIT 100`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '그룹 랭킹 조회 실패' });
  }
});

// 주간 PX 보상 지급 — 관리자 또는 스케줄러에서 주기적으로 호출
// 1~3위: 500px, 4~20위: 250px, 21~50위: 100px, 51~100위: 50px
router.post('/reward', auth, async (req, res) => {
  try {
    const [rankings] = await db.execute(
      'SELECT id, RANK() OVER (ORDER BY px DESC) as pos FROM users'
    );

    const rewards = [
      { min: 1,  max: 3,   px: 500 },
      { min: 4,  max: 20,  px: 250 },
      { min: 21, max: 50,  px: 100 },
      { min: 51, max: 100, px: 50 },
    ];

    for (const user of rankings) {
      const reward = rewards.find(r => user.pos >= r.min && user.pos <= r.max);
      if (reward) {
        await db.execute('UPDATE users SET px = px + ? WHERE id = ?', [reward.px, user.id]);
      }
    }

    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '보상 지급 실패' });
  }
});

module.exports = router;
