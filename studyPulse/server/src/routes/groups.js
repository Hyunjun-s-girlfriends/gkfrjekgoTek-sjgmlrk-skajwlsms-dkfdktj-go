const router = require('express').Router();
const auth = require('../middleware/auth');
const db = require('../config/database');
const { v4: uuidv4 } = require('uuid');

// 그룹 검색
router.get('/search', auth, async (req, res) => {
  const { q } = req.query;
  const [rows] = await db.execute(
    `SELECT g.*, CAST(COUNT(gm.id) AS UNSIGNED) as member_count,
            u.name as owner_name
     FROM \`groups\` g
     LEFT JOIN group_members gm ON g.id = gm.group_id
     LEFT JOIN users u ON g.owner_id = u.id
     WHERE g.name LIKE ?
     GROUP BY g.id
     HAVING member_count < g.max_members
     LIMIT 20`,
    [`%${q}%`]
  );
  res.json(rows);
});

// 추천 그룹 (랜덤)
router.get('/recommended', auth, async (req, res) => {
  const [rows] = await db.execute(
    `SELECT g.*, CAST(COUNT(gm.id) AS UNSIGNED) as member_count, u.name as owner_name
     FROM \`groups\` g
     LEFT JOIN group_members gm ON g.id = gm.group_id
     LEFT JOIN users u ON g.owner_id = u.id
     WHERE g.id NOT IN (
       SELECT group_id FROM group_members WHERE user_id = ?
     )
     GROUP BY g.id
     HAVING member_count < g.max_members
     ORDER BY RAND()
     LIMIT 6`,
    [req.user.id]
  );
  res.json(rows);
});

// 내 그룹 조회
router.get('/my', auth, async (req, res) => {
  const [rows] = await db.execute(
    `SELECT g.*, CAST(COUNT(gm2.id) AS UNSIGNED) as member_count, u.name as owner_name
     FROM \`groups\` g
     JOIN group_members gm ON g.id = gm.group_id AND gm.user_id = ?
     LEFT JOIN group_members gm2 ON g.id = gm2.group_id
     LEFT JOIN users u ON g.owner_id = u.id
     GROUP BY g.id`,
    [req.user.id]
  );
  res.json(rows);
});

// 그룹 생성
router.post('/', auth, async (req, res) => {
  const { name, description, icon } = req.body;
  if (!name) return res.status(400).json({ error: '그룹 이름 필요' });

  const inviteCode = uuidv4().substring(0, 8).toUpperCase();

  const [result] = await db.execute(
    'INSERT INTO `groups` (name, description, icon, invite_code, owner_id) VALUES (?, ?, ?, ?, ?)',
    [name, description || '', icon || 'book.fill', inviteCode, req.user.id]
  );

  // 생성자를 멤버로 추가
  await db.execute('INSERT INTO group_members (group_id, user_id) VALUES (?, ?)', [result.insertId, req.user.id]);

  const [rows] = await db.execute('SELECT * FROM `groups` WHERE id = ?', [result.insertId]);
  res.json(rows[0]);
});

// 그룹 참가 (초대코드)
router.post('/join', auth, async (req, res) => {
  const { inviteCode } = req.body;

  // 이미 다른 그룹에 가입된 경우 차단 (1그룹 제한)
  const [myGroups] = await db.execute(
    'SELECT COUNT(*) as cnt FROM group_members WHERE user_id = ?', [req.user.id]
  );
  if (myGroups[0].cnt > 0) return res.status(400).json({ error: '이미 그룹에 가입되어 있습니다. 현재 그룹을 탈퇴 후 참가하세요.' });

  const [groups] = await db.execute('SELECT * FROM `groups` WHERE invite_code = ?', [inviteCode]);
  if (!groups.length) return res.status(404).json({ error: '그룹을 찾을 수 없습니다.' });

  const group = groups[0];
  const [members] = await db.execute('SELECT COUNT(*) as cnt FROM group_members WHERE group_id = ?', [group.id]);
  if (members[0].cnt >= group.max_members) return res.status(400).json({ error: '그룹이 가득 찼습니다.' });

  await db.execute('INSERT INTO group_members (group_id, user_id) VALUES (?, ?)', [group.id, req.user.id]);
  res.json({ success: true, group });
});

// 그룹 검색으로 참가
router.post('/:id/join', auth, async (req, res) => {
  const groupId = req.params.id;

  // 이미 다른 그룹에 가입된 경우 차단 (1그룹 제한)
  const [myGroups] = await db.execute(
    'SELECT COUNT(*) as cnt FROM group_members WHERE user_id = ?', [req.user.id]
  );
  if (myGroups[0].cnt > 0) return res.status(400).json({ error: '이미 그룹에 가입되어 있습니다. 현재 그룹을 탈퇴 후 참가하세요.' });

  const [groups] = await db.execute('SELECT * FROM `groups` WHERE id = ?', [groupId]);
  if (!groups.length) return res.status(404).json({ error: '그룹 없음' });

  const group = groups[0];
  const [members] = await db.execute('SELECT COUNT(*) as cnt FROM group_members WHERE group_id = ?', [group.id]);
  if (members[0].cnt >= group.max_members) return res.status(400).json({ error: '그룹이 가득 찼습니다.' });

  await db.execute('INSERT INTO group_members (group_id, user_id) VALUES (?, ?)', [group.id, req.user.id]);
  res.json({ success: true });
});

// 그룹 나가기
router.delete('/:id/leave', auth, async (req, res) => {
  await db.execute(
    'DELETE FROM group_members WHERE group_id = ? AND user_id = ?',
    [req.params.id, req.user.id]
  );
  // 채팅 기록 삭제 (나갔다 들어오면 삭제 정책)
  await db.execute(
    'DELETE FROM group_messages WHERE group_id = ? AND user_id = ?',
    [req.params.id, req.user.id]
  );
  res.json({ success: true });
});

// 그룹 멤버 + 랭킹
router.get('/:id/members', auth, async (req, res) => {
  const [rows] = await db.execute(
    `SELECT u.id, u.name, u.profile_image, u.level, u.px,
            CAST(COALESCE(SUM(ts.duration_seconds), 0) AS UNSIGNED) as today_study_seconds
     FROM group_members gm
     JOIN users u ON gm.user_id = u.id
     LEFT JOIN timer_sessions ts ON u.id = ts.user_id AND ts.session_date = CURDATE()
     WHERE gm.group_id = ?
     GROUP BY u.id
     ORDER BY today_study_seconds DESC`,
    [req.params.id]
  );
  res.json(rows);
});

// 그룹 채팅 조회
router.get('/:id/messages', auth, async (req, res) => {
  const [rows] = await db.execute(
    `SELECT gm.*, u.name as user_name, u.profile_image
     FROM group_messages gm
     JOIN users u ON gm.user_id = u.id
     WHERE gm.group_id = ?
     ORDER BY gm.created_at ASC
     LIMIT 100`,
    [req.params.id]
  );
  res.json(rows);
});

// 채팅 메시지 전송
router.post('/:id/messages', auth, async (req, res) => {
  const { message } = req.body;
  if (!message?.trim()) return res.status(400).json({ error: '메시지 내용 필요' });

  const [result] = await db.execute(
    'INSERT INTO group_messages (group_id, user_id, message) VALUES (?, ?, ?)',
    [req.params.id, req.user.id, message.trim()]
  );

  const [rows] = await db.execute(
    `SELECT gm.*, u.name as user_name, u.profile_image
     FROM group_messages gm JOIN users u ON gm.user_id = u.id
     WHERE gm.id = ?`,
    [result.insertId]
  );

  // Socket.IO로 실시간 브로드캐스트
  const io = req.app.get('io');
  if (io) io.to(`group-${req.params.id}`).emit('new-message', rows[0]);

  res.json(rows[0]);
});

module.exports = router;
