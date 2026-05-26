const router = require('express').Router();
const auth = require('../middleware/auth');
const db = require('../config/database');

// 프로필 수정 — 전달된 필드만 업데이트 (COALESCE로 부분 업데이트)
router.put('/me', auth, async (req, res) => {
  try {
    const { name, description, organization } = req.body;
    await db.execute(
      'UPDATE users SET name = COALESCE(?, name), description = COALESCE(?, description), organization = COALESCE(?, organization) WHERE id = ?',
      [name, description, organization, req.user.id]
    );
    const [rows] = await db.execute('SELECT * FROM users WHERE id = ?', [req.user.id]);
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '프로필 수정 실패' });
  }
});

module.exports = router;
