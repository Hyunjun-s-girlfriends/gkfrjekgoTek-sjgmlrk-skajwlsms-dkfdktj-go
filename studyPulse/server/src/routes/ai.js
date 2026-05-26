const router = require('express').Router();
const auth = require('../middleware/auth');
const db = require('../config/database');

// OpenAI 인스턴스 지연 초기화 — API 키가 없어도 서버 시작 가능
let _openai = null;
function getOpenAI() {
  if (!_openai && process.env.OPENAI_API_KEY) {
    const OpenAI = require('openai');
    _openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
      timeout: parseInt(process.env.OPENAI_TIMEOUT_MS || '6500'),
    });
  }
  return _openai;
}

const AI_MODEL = () => process.env.OPENAI_MODEL || 'gpt-4.1-mini';

// 오늘의 공부/HRV 데이터를 한 번에 수집 (AI 프롬프트 구성용)
async function getTodayData(userId) {
  const [[user]] = await db.execute('SELECT name, level, px FROM users WHERE id = ?', [userId]);
  const [sessions] = await db.execute(
    `SELECT ts.duration_seconds, s.name as subject_name
     FROM timer_sessions ts LEFT JOIN subjects s ON ts.subject_id = s.id
     WHERE ts.user_id = ? AND ts.session_date = CURDATE()`,
    [userId]
  );
  const [hrv] = await db.execute(
    `SELECT AVG(hrv_sdnn) as avg_hrv, AVG(stress_index) as avg_stress, AVG(heart_rate) as avg_hr
     FROM hrv_data WHERE user_id = ? AND DATE(recorded_at) = CURDATE()`,
    [userId]
  );

  const totalStudy = sessions.reduce((a, s) => a + s.duration_seconds, 0);
  const bySubject = sessions.reduce((acc, s) => {
    const key = s.subject_name || '미분류';
    acc[key] = (acc[key] || 0) + s.duration_seconds;
    return acc;
  }, {});

  return { user, totalStudy, bySubject, hrv: hrv[0] };
}

// AI 학습 분석 리포트
router.post('/analyze', auth, async (req, res) => {
  const data = await getTodayData(req.user.id);
  const totalHours = (data.totalStudy / 3600).toFixed(1);
  const subjectSummary = Object.entries(data.bySubject)
    .map(([name, sec]) => `${name}: ${(sec / 3600).toFixed(1)}시간`)
    .join(', ') || '없음';

  const prompt = `당신은 AI 학습 코치입니다. 다음 데이터를 분석해서 한국어로 피드백을 주세요.

오늘 공부 데이터:
- 총 공부 시간: ${totalHours}시간
- 과목별: ${subjectSummary}
- 평균 HRV(SDNN): ${data.hrv?.avg_hrv?.toFixed(1) || '데이터 없음'} ms
- 평균 스트레스 지수: ${data.hrv?.avg_stress?.toFixed(1) || '데이터 없음'} / 100
- 평균 심박수: ${data.hrv?.avg_hr?.toFixed(0) || '데이터 없음'} bpm

다음 내용을 포함해서 분석해주세요:
1. 오늘 공부 습관 분석 (2-3문장)
2. 스트레스/HRV 상태 평가 (2문장)
3. 개선이 필요한 점 (2문장)
4. 내일 공부 계획 추천 (구체적으로)

친근하고 격려하는 톤으로 작성해주세요.`;

  const openai = getOpenAI();
  if (!openai) {
    return res.json({ analysis: '(AI 키 미설정) 오늘 공부 데이터가 기록되었습니다. OpenAI API 키를 설정하면 AI 분석을 받을 수 있어요.' });
  }

  try {
    const completion = await openai.chat.completions.create({
      model: AI_MODEL(),
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 600,
    });
    res.json({ analysis: completion.choices[0].message.content });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'AI 분석 실패', details: err.message });
  }
});

// AI 챗봇
router.post('/chat', auth, async (req, res) => {
  const { message, history = [] } = req.body;
  if (!message) return res.status(400).json({ error: '메시지 필요' });

  const data = await getTodayData(req.user.id);
  const systemPrompt = `당신은 StudyPulse의 AI 학습 코치입니다. 사용자의 공부를 도와주는 친근한 어시스턴트입니다.

사용자 현재 상태:
- 오늘 총 공부: ${(data.totalStudy / 3600).toFixed(1)}시간
- 현재 스트레스: ${data.hrv?.avg_stress?.toFixed(0) || '측정 없음'}/100
- 레벨: ${data.user?.level || 1}

공부 방법, 학습 전략, 집중력 향상, 스트레스 관리 등에 대해 도움을 주세요.
짧고 실용적인 답변을 한국어로 해주세요.`;

  const messages = [
    { role: 'system', content: systemPrompt },
    ...history.slice(-6),
    { role: 'user', content: message },
  ];

  const openai = getOpenAI();
  if (!openai) {
    return res.json({ reply: 'AI 키가 설정되지 않아 응답할 수 없어요. .env 파일에 OPENAI_API_KEY를 설정해주세요.' });
  }

  try {
    const completion = await openai.chat.completions.create({
      model: AI_MODEL(),
      messages,
      max_tokens: 400,
    });
    res.json({ reply: completion.choices[0].message.content });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'AI 응답 실패' });
  }
});

module.exports = router;
