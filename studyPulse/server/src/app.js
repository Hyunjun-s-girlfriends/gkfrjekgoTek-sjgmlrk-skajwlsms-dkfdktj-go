require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const express = require('express');
const cors = require('cors');
const http = require('http');
const path = require('path');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);

// Socket.IO CORS: 개발 환경에서는 전체 허용, 프로덕션에서는 origin 제한 필요
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
});

app.use(cors());
app.use(express.json());
app.set('io', io);

// 웹 프론트엔드 정적 파일 (public/)
app.use(express.static(path.join(__dirname, '../../public')));

// ── 기능별 라우트 ──
app.use('/api/auth', require('./routes/auth'));
app.use('/api/auth', require('./routes/users'));

// ── 호환 레이어 (기존 SwiftUI 앱 API 형식 지원) ──
// 구체적인 라우트보다 먼저 등록되어야 /api/dashboard 등이 올바르게 처리됨
app.use('/api', require('./routes/compat'));

app.use('/api/health', require('./routes/health'));
app.use('/api/bridge', require('./routes/bridge'));
app.use('/api/subjects', require('./routes/subjects'));
app.use('/api/timers', require('./routes/timers'));
app.use('/api/groups', require('./routes/groups'));
app.use('/api/rankings', require('./routes/rankings'));
app.use('/api/missions', require('./routes/missions'));
app.use('/api/analytics', require('./routes/analytics'));
app.use('/api/ai', require('./routes/ai'));

// 서버 상태 체크 엔드포인트
app.get('/health', (_, res) => res.json({ status: 'ok', time: new Date() }));

// SPA fallback: /api 가 아닌 경로는 index.html 반환
app.get('*', (req, res) => {
  if (!req.path.startsWith('/api')) {
    res.sendFile(path.join(__dirname, '../../public/index.html'));
  } else {
    res.status(404).json({ error: '존재하지 않는 API 엔드포인트입니다.' });
  }
});

// 전역 에러 핸들러 (라우트에서 next(err)로 전달된 에러 처리)
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[Error]', err.stack || err.message);
  res.status(500).json({ error: '서버 내부 오류가 발생했습니다.' });
});

// Socket.IO — 그룹 채팅 룸 관리
io.on('connection', (socket) => {
  socket.on('join-group', (groupId) => socket.join(`group-${groupId}`));
  socket.on('leave-group', (groupId) => socket.leave(`group-${groupId}`));
  socket.on('disconnect', () => {});
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`StudyPulse server running on port ${PORT}`);
  console.log(`Local:   http://localhost:${PORT}`);
});
