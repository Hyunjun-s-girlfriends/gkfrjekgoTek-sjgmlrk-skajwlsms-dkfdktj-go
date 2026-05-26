const router = require('express').Router();
const auth = require('../middleware/auth');
const db = require('../config/database');

// 과목 목록 조회 (sort_order 오름차순)
router.get('/', auth, async (req, res) => {
  try {
    const [rows] = await db.execute(
      'SELECT * FROM subjects WHERE user_id = ? ORDER BY sort_order ASC',
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '과목 조회 실패' });
  }
});

// 과목 생성 — 사용자당 최대 10개 제한
router.post('/', auth, async (req, res) => {
  try {
    const { name, color } = req.body;
    if (!name) return res.status(400).json({ error: '과목명 필요' });

    const [existing] = await db.execute(
      'SELECT COUNT(*) as cnt FROM subjects WHERE user_id = ?',
      [req.user.id]
    );
    if (existing[0].cnt >= 10) {
      return res.status(400).json({ error: '최대 10개까지 생성 가능합니다.' });
    }

    // sort_order는 현재 과목 수로 설정 (새 과목을 맨 뒤에 배치)
    const [result] = await db.execute(
      'INSERT INTO subjects (user_id, name, color, sort_order) VALUES (?, ?, ?, ?)',
      [req.user.id, name, color || '#007AFF', existing[0].cnt]
    );
    const [rows] = await db.execute('SELECT * FROM subjects WHERE id = ?', [result.insertId]);
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '과목 생성 실패' });
  }
});

// 과목 수정 — 전달된 필드만 업데이트 (COALESCE로 부분 업데이트)
router.put('/:id', auth, async (req, res) => {
  try {
    const { name, color } = req.body;
    await db.execute(
      'UPDATE subjects SET name = COALESCE(?, name), color = COALESCE(?, color) WHERE id = ? AND user_id = ?',
      [name, color, req.params.id, req.user.id]
    );
    const [rows] = await db.execute('SELECT * FROM subjects WHERE id = ?', [req.params.id]);
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '과목 수정 실패' });
  }
});

// 과목 삭제 (연결된 timer_sessions는 subject_id가 NULL로 처리됨 — ON DELETE SET NULL)
router.delete('/:id', auth, async (req, res) => {
  try {
    await db.execute('DELETE FROM subjects WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '과목 삭제 실패' });
  }
});

module.exports = router;
