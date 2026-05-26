const router = require('express').Router();
const { OAuth2Client } = require('google-auth-library');
const jwt = require('jsonwebtoken');
const db = require('../config/database');

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// Google ID Token 검증 → 신규 사용자 생성 or 기존 사용자 로그인
// 연속 접속 스트릭 갱신 로직 포함
router.post('/google', async (req, res) => {
  const { idToken } = req.body;
  if (!idToken) return res.status(400).json({ error: 'idToken 필요' });

  try {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const { sub: googleId, email, name, picture } = ticket.getPayload();

    const [rows] = await db.execute('SELECT * FROM users WHERE google_id = ?', [googleId]);
    let user;

    if (rows.length === 0) {
      const [result] = await db.execute(
        'INSERT INTO users (google_id, email, name, profile_image, last_login_date) VALUES (?, ?, ?, ?, CURDATE())',
        [googleId, email, name, picture]
      );
      const [newRows] = await db.execute('SELECT * FROM users WHERE id = ?', [result.insertId]);
      user = newRows[0];
    } else {
      user = rows[0];

      // 연속 접속 스트릭 계산:
      // - 어제 접속했으면 streak +1
      // - 이틀 이상 공백이면 streak 1로 초기화
      // - 오늘 이미 접속했으면 streak 유지
      const today = new Date().toISOString().split('T')[0];
      const lastLogin = user.last_login_date
        ? new Date(user.last_login_date).toISOString().split('T')[0]
        : null;
      let newStreak = user.streak_days;

      if (lastLogin) {
        const diffDays = Math.floor((new Date(today) - new Date(lastLogin)) / 86400000);
        if (diffDays === 1) newStreak += 1;
        else if (diffDays > 1) newStreak = 1;
        // diffDays === 0: 오늘 이미 접속 → streak 유지
      } else {
        newStreak = 1;
      }

      const maxStreak = Math.max(newStreak, user.max_streak_days);
      await db.execute(
        'UPDATE users SET last_login_date = CURDATE(), streak_days = ?, max_streak_days = ? WHERE id = ?',
        [newStreak, maxStreak, user.id]
      );
      user = { ...user, streak_days: newStreak, max_streak_days: maxStreak };
    }

    const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, {
      expiresIn: '30d',
    });

    res.json({ token, user });
  } catch (err) {
    console.error(err);
    res.status(401).json({ error: 'Google 인증 실패' });
  }
});

// 개발/테스트 전용 로그인 — 프로덕션 환경에서는 403 반환
router.post('/dev-login', async (req, res) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(403).json({ error: '프로덕션 환경에서는 사용할 수 없습니다.' });
  }

  const { name = '테스트유저' } = req.body;
  try {
    let [rows] = await db.execute("SELECT * FROM users WHERE email = 'dev@studypulse.local'");
    let user;
    if (!rows.length) {
      const [result] = await db.execute(
        "INSERT INTO users (google_id, email, name, last_login_date, streak_days) VALUES ('dev_test_id', 'dev@studypulse.local', ?, CURDATE(), 1)",
        [name]
      );
      const [newRows] = await db.execute('SELECT * FROM users WHERE id = ?', [result.insertId]);
      user = newRows[0];

      // 테스트 계정 기본 과목 3개 자동 생성
      const defaultSubjects = [
        ['수학', '#007AFF'], ['영어', '#34C759'], ['자료구조', '#FF3B30'],
      ];
      for (let i = 0; i < defaultSubjects.length; i++) {
        await db.execute(
          'INSERT INTO subjects (user_id, name, color, sort_order) VALUES (?, ?, ?, ?)',
          [user.id, defaultSubjects[i][0], defaultSubjects[i][1], i]
        );
      }
    } else {
      user = rows[0];
      await db.execute('UPDATE users SET last_login_date = CURDATE() WHERE id = ?', [user.id]);
    }
    const token = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET || 'dev_secret_change_me',
      { expiresIn: '30d' }
    );
    res.json({ token, user });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '개발 로그인 실패: ' + err.message });
  }
});

// 웹 폴백: access_token + userInfo로 로그인 (One Tap 차단 시 사용)
router.post('/google-token', async (req, res) => {
  const { accessToken, userInfo } = req.body;
  if (!accessToken || !userInfo?.sub) return res.status(400).json({ error: '유효하지 않은 요청' });

  try {
    // Google UserInfo API로 토큰 검증
    const r = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
      headers: { Authorization: 'Bearer ' + accessToken },
    });
    if (!r.ok) return res.status(401).json({ error: 'Google 토큰 검증 실패' });
    const { sub: googleId, email, name, picture } = await r.json();

    const [rows] = await db.execute('SELECT * FROM users WHERE google_id = ?', [googleId]);
    let user;
    if (rows.length === 0) {
      const [result] = await db.execute(
        'INSERT INTO users (google_id, email, name, profile_image, last_login_date) VALUES (?, ?, ?, ?, CURDATE())',
        [googleId, email, name, picture]
      );
      const [nr] = await db.execute('SELECT * FROM users WHERE id = ?', [result.insertId]);
      user = nr[0];
    } else {
      user = rows[0];
      await db.execute('UPDATE users SET last_login_date = CURDATE() WHERE id = ?', [user.id]);
    }
    const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '30d' });
    res.json({ token, user });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Google 로그인 실패' });
  }
});

// 클라이언트 Google OAuth 초기화용 — Client ID만 노출 (Secret은 절대 클라이언트에 전달 금지)
router.get('/config', (req, res) => {
  res.json({
    googleClientId: process.env.GOOGLE_CLIENT_ID || '',
    hasGoogleAuth: !!(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET),
  });
});

// 현재 로그인한 사용자 정보 조회
router.get('/me', require('../middleware/auth'), async (req, res) => {
  try {
    const [rows] = await db.execute('SELECT * FROM users WHERE id = ?', [req.user.id]);
    if (!rows.length) return res.status(404).json({ error: '사용자 없음' });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '사용자 조회 실패' });
  }
});

module.exports = router;
