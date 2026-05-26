/* ════════════════════════════════════════════════
   StudyPulse — Frontend App
════════════════════════════════════════════════ */

const API = (() => {
  const BASE = '';
  let token = localStorage.getItem('sp_token');

  function setToken(t) { token = t; localStorage.setItem('sp_token', t); }
  function clearToken() { token = null; localStorage.removeItem('sp_token'); }

  async function req(method, path, body) {
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = 'Bearer ' + token;
    const res = await fetch(BASE + path, {
      method, headers,
      body: body ? JSON.stringify(body) : undefined,
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
    return data;
  }

  return {
    get: (p) => req('GET', p),
    post: (p, b) => req('POST', p, b),
    put: (p, b) => req('PUT', p, b),
    patch: (p, b) => req('PATCH', p, b),
    del: (p) => req('DELETE', p),
    setToken, clearToken,
    isLoggedIn: () => !!token,
  };
})();

/* ── 상태 ── */
const state = {
  user: null,
  subjects: [],
  timers: {},         // subjectId → { sessionId, running, elapsed, interval }
  missions: [],
  myGroup: null,
  myGroupMembers: [],
  myGroupMessages: [],
  aiHistory: [],
  selectedGroupIcon: '📚',
  selectedGroupColor: '#30D158',
  selectedSubjectColor: '#007AFF',
};

/* ── 유틸 ── */
const $ = (id) => document.getElementById(id);
const el = (tag, cls, text) => {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
};
function fmt(sec) {
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
  return `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
}
function fmtMin(sec) {
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
  if (h > 0) return `${h}시간 ${m}분`;
  return `${m}분`;
}
function showToast(msg, ms = 2600) {
  const t = $('toast');
  t.textContent = msg;
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), ms);
}
function plantEmoji(lv) {
  if (lv < 3) return '🌱';
  if (lv < 7) return '🌿';
  if (lv < 15) return '🌳';
  return '🌲';
}
function plantLabel(lv) {
  if (lv < 3) return '새싹';
  if (lv < 7) return '성장 중';
  if (lv < 15) return '나무';
  return '울창한 숲';
}

/* ════════════════════════════════════════════════
   인증
════════════════════════════════════════════════ */
async function login(data) {
  API.setToken(data.token);
  state.user = data.user;
  showApp();
  await loadAll();
}

async function tryAutoLogin() {
  if (!API.isLoggedIn()) return;
  try {
    state.user = await API.get('/api/auth/me');
    showApp();
    await loadAll();
  } catch {
    API.clearToken();
  }
}

function showApp() {
  $('login-screen').hidden = true;
  $('app').hidden = false;
  if (state.user) {
    const initial = (state.user.name || '?')[0];
    $('sidebar-avatar-circle').textContent = initial;
    $('sidebar-user-name').textContent = state.user.name || '-';
    updateSidebarLevel();
  }
}

function updateSidebarLevel() {
  const u = state.user;
  if (!u) return;
  $('sidebar-user-level').textContent = `Lv.${u.level || 1} · ${plantLabel(u.level || 1)}`;
}

/* ════════════════════════════════════════════════
   데이터 로딩
════════════════════════════════════════════════ */
async function loadAll() {
  await Promise.all([loadSubjects(), loadMissions(), loadHRV(), loadMyGroup()]);
  updatePlantUI();
  updateStats();
}

async function loadSubjects() {
  try {
    state.subjects = await API.get('/api/subjects');
    renderTimerList();
  } catch (e) { console.error('subjects:', e); }
}

async function loadMissions() {
  try {
    state.missions = await API.get('/api/missions/personal');
    renderMissions();
  } catch (e) { console.error('missions:', e); }
}

async function loadHRV() {
  try {
    const d = await API.get('/api/health/hrv-latest');
    if (d && d.heartRate) {
      $('hrv-value').textContent = `${d.heartRate} BPM`;
      $('hrv-badge').querySelector('.hrv-dot').classList.add('active');
    }
  } catch {}
}

async function loadMyGroup() {
  try {
    const groups = await API.get('/api/groups/my');
    if (groups && groups.length > 0) {
      state.myGroup = groups[0];
      await loadGroupDetail();
      $('group-no-group').hidden = true;
      $('group-has-group').hidden = false;
    } else {
      state.myGroup = null;
      $('group-no-group').hidden = false;
      $('group-has-group').hidden = true;
      loadRecommendedGroups();
    }
  } catch (e) { console.error('group:', e); }
}

async function loadGroupDetail() {
  if (!state.myGroup) return;
  try {
    const [members, msgs] = await Promise.all([
      API.get(`/api/groups/${state.myGroup.id}/members`),
      API.get(`/api/groups/${state.myGroup.id}/messages`),
    ]);
    state.myGroupMembers = members;
    state.myGroupMessages = msgs;
    renderGroupDetail();
  } catch (e) { console.error('groupDetail:', e); }
}

async function loadRecommendedGroups() {
  try {
    const groups = await API.get('/api/groups/recommended');
    renderGroupCards('group-recommended', groups, true);
  } catch {}
}

async function refreshUser() {
  try {
    state.user = await API.get('/api/auth/me');
    const initial = (state.user.name || '?')[0];
    $('sidebar-avatar-circle').textContent = initial;
    $('sidebar-user-name').textContent = state.user.name || '-';
    updatePlantUI();
  } catch {}
}

function updateStats() {
  const total = Object.values(state.timers).reduce((a, t) => a + (t.elapsed || 0), 0);
  $('stat-study-time').textContent = fmt(total);
  const done = state.missions.filter(m => m.isCompleted || m.completedToday > 0).length;
  $('stat-missions').textContent = `${done}/${state.missions.length}`;
  $('stat-subjects').textContent = `${state.subjects.length}/10`;
}

/* ════════════════════════════════════════════════
   타이머 렌더링 (리스트 형태)
════════════════════════════════════════════════ */
function renderTimerList() {
  const list = $('timer-grid');
  list.innerHTML = '';

  if (!state.subjects.length) {
    list.innerHTML = '<div class="timer-empty"><div class="timer-empty-icon">📚</div><div>과목을 추가해 타이머를 시작하세요</div></div>';
    return;
  }

  state.subjects.forEach(sub => {
    const timer = state.timers[sub.id] || { running: false, elapsed: 0 };
    const row = el('div', `timer-row${timer.running ? ' running' : ''}`);
    row.dataset.id = sub.id;
    row.style.setProperty('--subject-color', sub.color || '#ccc');

    const info = el('div', 'timer-row-info');
    const name = el('div', 'timer-row-name', sub.name);
    info.appendChild(name);

    const display = el('div', 'timer-display', fmt(timer.elapsed || 0));
    display.id = `timer-display-${sub.id}`;

    const btn = el('button', timer.running ? 'timer-btn timer-btn-stop' : 'timer-btn timer-btn-start',
      timer.running ? '■ 정지' : '▶ 시작');
    btn.onclick = () => timer.running ? stopTimer(sub.id) : startTimer(sub.id);

    row.append(info, display, btn);
    list.appendChild(row);
  });
}

async function startTimer(subjectId) {
  try {
    const session = await API.post('/api/timers/start', { subjectId });
    state.timers[subjectId] = { sessionId: session.id, running: true, elapsed: 0 };
    state.timers[subjectId].interval = setInterval(() => {
      state.timers[subjectId].elapsed++;
      const d = $(`timer-display-${subjectId}`);
      if (d) d.textContent = fmt(state.timers[subjectId].elapsed);
      updateStats();
    }, 1000);
    renderTimerList();
    showToast('⏱ 타이머 시작!');
  } catch (e) { showToast('오류: ' + e.message); }
}

async function stopTimer(subjectId) {
  const t = state.timers[subjectId];
  if (!t) return;
  clearInterval(t.interval);
  try {
    const result = await API.put(`/api/timers/${t.sessionId}/stop`, { durationSeconds: t.elapsed });
    t.running = false;
    if (result.pxEarned > 0) {
      showToast(`+${result.pxEarned} PX 획득! 🎉`);
      await refreshUser();
    }
    renderTimerList();
    updateStats();
  } catch (e) { showToast('오류: ' + e.message); }
}

/* ════════════════════════════════════════════════
   식물 / 성장
════════════════════════════════════════════════ */
function updatePlantUI() {
  const u = state.user;
  if (!u) return;
  const lv = u.level || 1;
  const px = u.px || 0;
  const pxInLevel = px % 100;

  $('plant-emoji').textContent = plantEmoji(lv);
  $('plant-level').textContent = plantLabel(lv);
  $('plant-px').textContent = `${px.toLocaleString()} PX`;
  $('plant-progress').style.width = `${pxInLevel}%`;
  $('plant-progress-label').textContent = `${100 - pxInLevel} PX 남음`;
  updateSidebarLevel();
}

/* ════════════════════════════════════════════════
   미션 렌더링
════════════════════════════════════════════════ */
function renderMissions() {
  const list = $('mission-list');
  list.innerHTML = '';
  const done = state.missions.filter(m => m.isCompleted || m.completedToday > 0).length;
  $('mission-count-badge').textContent = `${done}/${state.missions.length}`;

  if (!state.missions.length) {
    list.innerHTML = '<div class="loading-row">미션 없음</div>';
    return;
  }
  state.missions.forEach(m => {
    const completed = m.isCompleted || (m.completedToday > 0);
    const item = el('div', `mission-item${completed ? ' completed' : ''}`);
    const check = el('div', 'mission-check', completed ? '✓' : '');
    const text = el('span', 'mission-text', m.title);
    const px = el('span', 'mission-px', `+${m.pxReward || m.px_reward} PX`);
    if (!completed) item.onclick = () => completeMission(m.id);
    item.append(check, text, px);
    list.appendChild(item);
  });
  updateStats();
}

async function completeMission(id) {
  try {
    const result = await API.post(`/api/missions/${id}/complete`);
    showToast(`미션 완료! +${result.pxEarned} PX 🎯`);
    await loadMissions();
    await refreshUser();
  } catch (e) { showToast(e.message); }
}

/* ════════════════════════════════════════════════
   그룹
════════════════════════════════════════════════ */
function renderGroupDetail() {
  const g = state.myGroup;
  if (!g) return;

  $('group-name-title').textContent = g.name;
  $('group-info-meta').textContent = `${state.myGroupMembers.length} / ${g.maxMembers || g.max_members || 8} 명`;
  $('group-member-count').textContent = `${state.myGroupMembers.length}명 공부중`;
  $('group-clear-count').textContent = `클리어 ${g.missionClearCount || g.mission_clear_count || 0}회`;

  // 활동 달력 월 레이블
  const now = new Date();
  $('activity-month-label').textContent = `${now.getMonth() + 1}월 활동 ${now.getFullYear()}`;

  renderGroupRankingList('group-ranking-list', state.myGroupMembers);
  renderGroupChat();
  renderActivityCal();
  loadGroupMissions();
}

function renderGroupRankingList(containerId, members) {
  const list = $(containerId);
  list.innerHTML = '';
  members.forEach((m, i) => {
    const row = el('div', 'rank-row');
    const medals = ['🥇', '🥈', '🥉'];
    const numCls = i < 3 ? `rank-num ${['gold','silver','bronze'][i]}` : 'rank-num';
    const num = el('div', numCls, i < 3 ? medals[i] : `${i + 1}`);
    const av = el('div', 'rank-avatar', (m.name || '?')[0]);
    const info = el('div', 'rank-info');
    info.innerHTML = `<div class="rank-name">${m.name}</div><div class="rank-meta">${fmtMin(m.todayStudySeconds || m.today_study_seconds || 0)} 공부</div>`;
    const badge = el('span', 'rank-tag', `Lv.${m.level}`);
    row.append(num, av, info, badge);
    list.appendChild(row);
  });
}

function renderGroupChat() {
  const box = $('chat-messages');
  box.innerHTML = '';
  state.myGroupMessages.slice(-50).forEach(msg => {
    const isMe = (msg.userId || msg.user_id) === state.user?.id;
    const wrap = el('div');
    const bubble = el('div', `chat-bubble ${isMe ? 'me' : 'other'}`);
    if (!isMe) {
      const meta = el('div', 'chat-bubble-meta', msg.userName || msg.user_name || '');
      bubble.appendChild(meta);
    }
    bubble.appendChild(document.createTextNode(msg.message));
    wrap.appendChild(bubble);
    box.appendChild(wrap);
  });
  box.scrollTop = box.scrollHeight;
}

async function loadGroupMissions() {
  if (!state.myGroup) return;
  try {
    const missions = await API.get(`/api/missions/group/${state.myGroup.id}`);
    const list = $('group-missions');
    list.innerHTML = '';
    (missions || []).forEach(m => {
      const completed = m.completedToday > 0;
      const item = el('div', `mission-item${completed ? ' completed' : ''}`);
      const check = el('div', 'mission-check', completed ? '✓' : '');
      const text = el('span', 'mission-text', m.title);
      const px = el('span', 'mission-px', `+${m.px_reward || m.pxReward} PX`);
      if (!completed) {
        item.onclick = async () => {
          try {
            await API.post(`/api/missions/${m.id}/complete`, { groupId: state.myGroup.id });
            showToast('그룹 미션 완료! 🏆');
            loadGroupMissions();
          } catch (e) { showToast(e.message); }
        };
      }
      item.append(check, text, px);
      list.appendChild(item);
    });
  } catch {}
}

function renderActivityCal() {
  const cal = $('activity-cal');
  cal.innerHTML = '';
  for (let i = 27; i >= 0; i--) {
    const cell = el('div', 'cal-cell');
    const lv = Math.random() > 0.55 ? Math.floor(Math.random() * 4) + 1 : 0;
    if (lv) cell.classList.add(`lv${lv}`);
    cal.appendChild(cell);
  }
}

function renderGroupCards(containerId, groups, showJoin) {
  const c = $(containerId);
  c.innerHTML = '';
  if (!groups || !groups.length) {
    c.innerHTML = '<div class="loading-row">그룹 없음</div>';
    return;
  }
  groups.slice(0, 8).forEach(g => {
    const card = el('div', 'group-card');
    const icon = el('div', 'group-card-icon', g.icon || '📚');
    const info = el('div', 'group-card-info');
    info.innerHTML = `<div class="group-card-name">${g.name}</div><div class="group-card-desc">${g.description || ''}</div><div class="group-card-meta">${g.memberCount || 0}/${g.maxMembers || g.max_members || 8}명</div>`;
    card.append(icon, info);

    if (showJoin) {
      const btn = el('button', 'btn-search', '참가');
      btn.style.cssText = 'padding:6px 14px;font-size:12px';
      btn.onclick = async () => {
        try {
          await API.post(`/api/groups/${g.id}/join`);
          showToast('그룹에 참가했습니다! 🎉');
          await loadMyGroup();
          switchTab('group');
        } catch (e) { showToast(e.message); }
      };
      card.appendChild(btn);
    }
    c.appendChild(card);
  });
}

/* ════════════════════════════════════════════════
   랭킹
════════════════════════════════════════════════ */
async function loadRankings() {
  try {
    const data = await API.get('/api/rankings/personal');
    const rankings = data.rankings || [];
    const myRank = data.myRank;

    if (myRank) {
      $('my-rank-num').textContent = `#${myRank.rankPosition || myRank.rank_position || '-'}`;
      $('my-rank-name').textContent = myRank.name || state.user?.name || '-';
      $('my-rank-sub').textContent = `Lv.${myRank.level} · ${myRank.px} PX`;
    }

    const list = $('personal-ranking-list');
    list.innerHTML = '';
    rankings.forEach((r, i) => {
      const row = el('div', 'rank-row');
      if (myRank && r.id === myRank.id) row.style.background = '#EAF8EE';
      const medals = ['🥇', '🥈', '🥉'];
      const numCls = i < 3 ? `rank-num ${['gold','silver','bronze'][i]}` : 'rank-num';
      const num = el('div', numCls, i < 3 ? medals[i] : `${i + 1}`);
      const av = el('div', 'rank-avatar', (r.name || '?')[0]);
      const info = el('div', 'rank-info');
      info.innerHTML = `<div class="rank-name">${r.name}</div><div class="rank-meta">Lv.${r.level}</div>`;
      const px = el('div', 'rank-px', `${r.px} PX`);
      row.append(num, av, info, px);
      list.appendChild(row);
    });
  } catch (e) { console.error('ranking:', e); }

  try {
    const gList = await API.get('/api/rankings/groups');
    const list = $('group-ranking-global-list');
    list.innerHTML = '';
    (gList || []).forEach((g, i) => {
      const row = el('div', 'rank-row');
      const medals = ['🥇', '🥈', '🥉'];
      const numCls = i < 3 ? `rank-num ${['gold','silver','bronze'][i]}` : 'rank-num';
      const num = el('div', numCls, i < 3 ? medals[i] : `${i + 1}`);
      const av = el('div', 'rank-avatar', g.icon || '📚');
      av.style.background = '#EAF8EE';
      av.style.fontSize = '16px';
      const info = el('div', 'rank-info');
      info.innerHTML = `<div class="rank-name">${g.name}</div><div class="rank-meta">${g.memberCount || g.member_count || 0}명 · 클리어 ${g.missionClearCount || g.mission_clear_count || 0}회</div>`;
      const px = el('div', 'rank-px', `${g.totalPx || g.total_px || 0} PX`);
      row.append(num, av, info, px);
      list.appendChild(row);
    });
  } catch {}
}

/* ════════════════════════════════════════════════
   분석
════════════════════════════════════════════════ */
async function loadAnalytics() {
  try {
    const [weekly, focus, monthly] = await Promise.all([
      API.get('/api/analytics/weekly-stress'),
      API.get('/api/dashboard/focus'),
      API.get('/api/analytics/subjects-monthly'),
    ]);
    renderWeeklyChart(weekly || []);
    renderFocusChart(focus || []);
    renderSubjectBars(monthly || []);
  } catch (e) { console.error('analytics:', e); }
}

function renderWeeklyChart(data) {
  const canvas = $('chart-weekly-stress');
  const empty = $('chart-stress-empty');
  if (!data.length) { empty.style.display = 'flex'; canvas.style.display = 'none'; return; }
  empty.style.display = 'none'; canvas.style.display = 'block';
  drawLineChart(canvas, data.map(d => d.avgStress || d.avg_stress || 0), data.map(d => d.date), '#FF3B30', 'rgba(255,59,48,0.08)');
}
function renderFocusChart(data) {
  const canvas = $('chart-focus');
  const empty = $('chart-focus-empty');
  if (!data.length) { empty.style.display = 'flex'; canvas.style.display = 'none'; return; }
  empty.style.display = 'none'; canvas.style.display = 'block';
  drawLineChart(canvas, data.map(d => d.focus || d.avgFocus || 0), data.map(d => d.hour), '#30D158', 'rgba(48,209,88,0.08)');
}

function drawLineChart(canvas, values, labels, color, fillColor) {
  const W = canvas.parentElement.clientWidth;
  const H = parseInt(canvas.getAttribute('height')) || 160;
  canvas.width = W * devicePixelRatio;
  canvas.height = H * devicePixelRatio;
  canvas.style.width = W + 'px';
  canvas.style.height = H + 'px';
  const ctx = canvas.getContext('2d');
  ctx.scale(devicePixelRatio, devicePixelRatio);
  const pad = { top: 16, right: 16, bottom: 28, left: 40 };
  const cw = W - pad.left - pad.right;
  const ch = H - pad.top - pad.bottom;
  const max = Math.max(...values, 1);
  ctx.clearRect(0, 0, W, H);

  // 그리드
  ctx.strokeStyle = '#F0F1F3'; ctx.lineWidth = 1;
  [0, 25, 50, 75, 100].forEach(v => {
    if (v > max * 1.1) return;
    const y = pad.top + ch - (v / (max * 1.1)) * ch;
    ctx.beginPath(); ctx.moveTo(pad.left, y); ctx.lineTo(pad.left + cw, y); ctx.stroke();
    ctx.fillStyle = '#9CA3AF'; ctx.font = '10px system-ui'; ctx.textAlign = 'right';
    ctx.fillText(v, pad.left - 4, y + 3);
  });

  if (values.length < 2) return;
  const step = cw / (values.length - 1);
  const pts = values.map((v, i) => ({
    x: pad.left + i * step,
    y: pad.top + ch - (v / (max * 1.1)) * ch,
  }));

  // 채우기
  ctx.beginPath();
  ctx.moveTo(pts[0].x, pad.top + ch);
  pts.forEach(p => ctx.lineTo(p.x, p.y));
  ctx.lineTo(pts[pts.length - 1].x, pad.top + ch);
  ctx.closePath();
  ctx.fillStyle = fillColor; ctx.fill();

  // 라인
  ctx.beginPath(); ctx.moveTo(pts[0].x, pts[0].y);
  for (let i = 1; i < pts.length; i++) {
    const cp = { x: (pts[i-1].x + pts[i].x) / 2, y: (pts[i-1].y + pts[i].y) / 2 };
    ctx.quadraticCurveTo(pts[i-1].x, pts[i-1].y, cp.x, cp.y);
  }
  ctx.lineTo(pts[pts.length-1].x, pts[pts.length-1].y);
  ctx.strokeStyle = color; ctx.lineWidth = 2.5; ctx.lineJoin = 'round'; ctx.stroke();

  // 점
  pts.forEach(p => {
    ctx.beginPath(); ctx.arc(p.x, p.y, 3.5, 0, Math.PI * 2); ctx.fillStyle = color; ctx.fill();
    ctx.beginPath(); ctx.arc(p.x, p.y, 1.5, 0, Math.PI * 2); ctx.fillStyle = '#FFF'; ctx.fill();
  });

  // 레이블
  ctx.fillStyle = '#9CA3AF'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
  labels.forEach((lb, i) => {
    ctx.fillText(lb ? String(lb).slice(-5) : '', pad.left + i * step, pad.top + ch + 16);
  });
}

function renderSubjectBars(subjects) {
  const container = $('subject-bars');
  container.innerHTML = '';
  if (!subjects.length) {
    container.innerHTML = '<div style="color:var(--text-3);font-size:13px;padding:16px 0">이번 달 데이터 없음</div>';
    return;
  }
  const max = Math.max(...subjects.map(s => s.totalSeconds || s.total_seconds || 0), 1);
  subjects.forEach(s => {
    const sec = s.totalSeconds || s.total_seconds || 0;
    const row = el('div', 'subject-bar-row');
    const label = el('div', 'subject-bar-label', s.name);
    const track = el('div', 'subject-bar-track');
    const fill = el('div', 'subject-bar-fill');
    fill.style.background = s.color || '#007AFF';
    fill.style.width = `${(sec / max) * 100}%`;
    track.appendChild(fill);
    const val = el('div', 'subject-bar-val', fmtMin(sec));
    row.append(label, track, val);
    container.appendChild(row);
  });
}

/* ════════════════════════════════════════════════
   AI
════════════════════════════════════════════════ */
async function requestAnalysis() {
  const btn = $('btn-analyze');
  btn.textContent = '⏳ 분석 중...';
  btn.disabled = true;

  const box = $('ai-analysis-result');
  const text = $('ai-analysis-text');
  box.hidden = false;
  text.textContent = '분석 중입니다...';

  try {
    const data = await API.post('/api/ai/analyze');
    text.textContent = data.analysis || '분석 결과를 가져오지 못했습니다.';
  } catch (e) {
    text.textContent = '분석 실패: ' + e.message;
  }
  btn.textContent = '✨ 분석 리포트';
  btn.disabled = false;
}

async function sendAIChat(msg) {
  if (!msg?.trim()) return;
  const chatBox = $('ai-chat-messages');
  state.aiHistory.push({ role: 'user', content: msg });

  const userBubble = el('div', 'chat-bubble me', msg);
  chatBox.appendChild(userBubble);
  chatBox.scrollTop = chatBox.scrollHeight;

  const loadBubble = el('div', 'chat-bubble other');
  loadBubble.innerHTML = '<span class="typing-dots">●●●</span>';
  chatBox.appendChild(loadBubble);

  try {
    const data = await API.post('/api/ai/chat', {
      message: msg,
      history: state.aiHistory.slice(-8),
    });
    loadBubble.textContent = data.reply || '응답 없음';
    state.aiHistory.push({ role: 'assistant', content: data.reply });
  } catch (e) {
    loadBubble.textContent = '오류: ' + e.message;
  }
  chatBox.scrollTop = chatBox.scrollHeight;
  $('ai-chat-input').value = '';
}

/* ════════════════════════════════════════════════
   탭 전환
════════════════════════════════════════════════ */
const TAB_TITLES = {
  dashboard: '대시보드',
  analytics: '과목별 공부시간',
  ai:        'AI 어시스턴트',
  group:     '그룹',
  ranking:   '랭킹',
};

function switchTab(tabName) {
  // sidebar nav-item 활성화
  document.querySelectorAll('.nav-item').forEach(b => b.classList.remove('active'));
  document.querySelector(`.nav-item[data-tab="${tabName}"]`)?.classList.add('active');

  // 탭 콘텐츠 전환
  document.querySelectorAll('.tab-content').forEach(c => {
    c.hidden = true; c.classList.remove('active');
  });
  const target = $(`tab-${tabName}`);
  if (target) { target.hidden = false; target.classList.add('active'); }

  // 타이틀바 제목 업데이트
  const titleEl = $('main-page-title');
  if (titleEl) titleEl.textContent = TAB_TITLES[tabName] || tabName;

  if (tabName === 'ranking')   loadRankings();
  if (tabName === 'analytics') loadAnalytics();
  if (tabName === 'group')     loadMyGroup();
}

/* ════════════════════════════════════════════════
   프로필 패널
════════════════════════════════════════════════ */
function openProfile() {
  $('profile-panel').classList.add('open');
  $('profile-overlay').classList.add('open');
  renderProfilePanel();
}
function closeProfile() {
  $('profile-panel').classList.remove('open');
  $('profile-overlay').classList.remove('open');
}

async function renderProfilePanel() {
  const u = state.user;
  if (!u) return;

  const lv = u.level || 1;
  const px = u.px || 0;
  const streak = u.streak_days || u.streakDays || 0;
  const maxStreak = u.max_streak_days || u.maxStreakDays || 0;

  // 헤더
  $('profile-avatar-xl').textContent = (u.name || '?')[0];
  $('profile-display-name').textContent = u.name || '-';
  $('profile-level-badge').textContent = `Lv.${lv} · ${plantLabel(lv)}`;
  $('profile-streak-badge').textContent = `🔥 ${streak}일 연속`;
  $('profile-org-text').textContent = u.organization || '';
  $('profile-desc-text').textContent = u.description || '';

  // 통계
  $('pstat-px').textContent = px.toLocaleString();
  $('pstat-streak').textContent = streak;
  $('pstat-max-streak').textContent = maxStreak;

  // 편집 폼 초기값
  $('profile-edit-name').value = u.name || '';
  $('profile-edit-org').value = u.organization || '';
  $('profile-edit-desc').value = u.description || '';

  // 활동 캘린더 (28일 → 14열 × 2행)
  const now = new Date();
  $('profile-cal-label').textContent =
    `${now.getFullYear()}년 ${now.getMonth() + 1}월`;
  renderProfileCal();

  // 과목별 공부시간 (이번 달)
  try {
    const monthly = await API.get('/api/analytics/subjects-monthly');
    renderProfileSubjectBars(monthly || []);
  } catch {}
}

function renderProfileCal() {
  const cal = $('profile-activity-cal');
  cal.innerHTML = '';
  for (let i = 27; i >= 0; i--) {
    const cell = el('div', 'cal-cell');
    const lv = Math.random() > 0.5 ? Math.floor(Math.random() * 4) + 1 : 0;
    if (lv) cell.classList.add(`lv${lv}`);
    cal.appendChild(cell);
  }
}

function renderProfileSubjectBars(subjects) {
  const container = $('profile-subject-bars');
  container.innerHTML = '';
  if (!subjects.length) {
    container.innerHTML = '<div class="profile-empty-hint">이번 달 공부 기록이 없어요</div>';
    return;
  }
  const max = Math.max(...subjects.map(s => s.totalSeconds || s.total_seconds || 0), 1);
  subjects.slice(0, 5).forEach(s => {
    const sec = s.totalSeconds || s.total_seconds || 0;
    const row = el('div', 'profile-bar-row');
    const dot = el('span', 'profile-bar-dot');
    dot.style.background = s.color || '#007AFF';
    const label = el('span', 'profile-bar-label', s.name);
    const track = el('div', 'profile-bar-track');
    const fill = el('div', 'profile-bar-fill');
    fill.style.background = s.color || '#007AFF';
    fill.style.width = `${(sec / max) * 100}%`;
    track.appendChild(fill);
    const val = el('span', 'profile-bar-val', fmtMin(sec));
    row.append(dot, label, track, val);
    container.appendChild(row);
  });
}

/* ════════════════════════════════════════════════
   그룹 생성 미리보기 업데이트
════════════════════════════════════════════════ */
function updateGroupPreview() {
  $('preview-icon').textContent = state.selectedGroupIcon;
  $('preview-name').textContent = $('create-group-name').value || '그룹 이름';
  $('preview-desc').textContent = $('create-group-desc').value || '그룹 설명';
  const max = $('create-group-max').value || '8';
  $('preview-meta').textContent = `최대 인원 ${max}명`;
}

/* ════════════════════════════════════════════════
   이벤트 바인딩
════════════════════════════════════════════════ */
document.addEventListener('DOMContentLoaded', async () => {

  /* 로그인 */
  $('btn-dev-login').onclick = async () => {
    const name = $('dev-name').value.trim() || '테스트유저';
    try {
      const data = await API.post('/api/auth/dev-login', { name });
      await login(data);
    } catch (e) {
      alert('로그인 실패: ' + e.message + '\n서버가 실행 중인지 확인하세요.');
    }
  };
  $('dev-name').onkeydown = e => { if (e.key === 'Enter') $('btn-dev-login').click(); };
  // ── Google OAuth ──────────────────────────────
  let _gClientId = '';
  API.get('/api/auth/config').then(cfg => {
    _gClientId = cfg.googleClientId || '';
    if (cfg.hasGoogleAuth && typeof google !== 'undefined') {
      google.accounts.id.initialize({
        client_id: _gClientId,
        callback: async ({ credential }) => {
          try {
            const data = await API.post('/api/auth/google', { idToken: credential });
            await login(data);
          } catch (e) { showToast('Google 로그인 실패: ' + e.message); }
        },
        auto_select: false,
        cancel_on_tap_outside: true,
      });
    }
  }).catch(() => {});

  $('btn-google-login').onclick = () => {
    if (!_gClientId) {
      showToast('Google OAuth 미설정 — 아래 개발 로그인을 이용하세요.');
      return;
    }
    if (typeof google === 'undefined') {
      showToast('Google 스크립트 로드 실패. 네트워크를 확인하세요.');
      return;
    }
    google.accounts.id.prompt(n => {
      // One Tap이 차단된 경우 → 팝업 폴백
      if (n.isNotDisplayed() || n.isSkippedMoment()) {
        google.accounts.oauth2.initTokenClient({
          client_id: _gClientId,
          scope: 'openid email profile',
          callback: async ({ access_token }) => {
            try {
              const info = await (await fetch('https://www.googleapis.com/oauth2/v3/userinfo',
                { headers: { Authorization: 'Bearer ' + access_token } })).json();
              const data = await API.post('/api/auth/google-token',
                { accessToken: access_token, userInfo: info });
              await login(data);
            } catch (e) { showToast('Google 로그인 실패: ' + e.message); }
          },
        }).requestAccessToken();
      }
    });
  };

  /* 사이드바 내비 */
  document.querySelectorAll('.nav-item').forEach(btn => {
    btn.onclick = () => switchTab(btn.dataset.tab);
  });

  /* 랭킹 내부 탭 */
  document.querySelectorAll('.rank-type-tab').forEach(btn => {
    btn.onclick = () => {
      document.querySelectorAll('.rank-type-tab').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const isPers = btn.dataset.rtab === 'personal';
      $('personal-ranking-list').hidden = !isPers;
      $('group-ranking-global-list').hidden = isPers;
    };
  });

  /* 과목 추가 */
  $('btn-add-subject').onclick = () => {
    if (state.subjects.length >= 10) { showToast('최대 10개까지 추가 가능합니다.'); return; }
    $('add-subject-modal').hidden = false;
    $('new-subject-name').focus();
  };
  $('btn-close-subject-modal').onclick = () => { $('add-subject-modal').hidden = true; };
  $('btn-confirm-add-subject').onclick = async () => {
    const name = $('new-subject-name').value.trim();
    if (!name) { showToast('과목 이름을 입력하세요.'); return; }
    try {
      await API.post('/api/subjects', { name, color: state.selectedSubjectColor });
      $('add-subject-modal').hidden = true;
      $('new-subject-name').value = '';
      await loadSubjects();
      showToast('과목이 추가됐습니다!');
    } catch (e) { showToast(e.message); }
  };
  $('new-subject-name').onkeydown = e => { if (e.key === 'Enter') $('btn-confirm-add-subject').click(); };

  /* 과목 색상 */
  $('subject-color-picker').querySelectorAll('.color-opt').forEach(opt => {
    opt.onclick = () => {
      $('subject-color-picker').querySelectorAll('.color-opt').forEach(o => o.classList.remove('selected'));
      opt.classList.add('selected');
      state.selectedSubjectColor = opt.dataset.color;
    };
  });

  /* 그룹 생성 모달 */
  $('btn-show-create').onclick = () => { $('create-group-modal').hidden = false; updateGroupPreview(); };
  $('btn-close-create').onclick = () => { $('create-group-modal').hidden = true; };

  /* 그룹 생성 실시간 미리보기 */
  $('create-group-name').oninput = () => {
    const len = $('create-group-name').value.length;
    $('name-char').textContent = `${len}/20`;
    updateGroupPreview();
  };
  $('create-group-desc').oninput = () => {
    const len = $('create-group-desc').value.length;
    $('desc-char').textContent = `${len}/100`;
    updateGroupPreview();
  };
  $('create-group-max').oninput = updateGroupPreview;

  $('icon-picker').querySelectorAll('.icon-opt').forEach(opt => {
    opt.onclick = () => {
      $('icon-picker').querySelectorAll('.icon-opt').forEach(o => o.classList.remove('selected'));
      opt.classList.add('selected');
      state.selectedGroupIcon = opt.dataset.icon;
      updateGroupPreview();
    };
  });
  $('color-picker').querySelectorAll('.color-opt').forEach(opt => {
    opt.onclick = () => {
      $('color-picker').querySelectorAll('.color-opt').forEach(o => o.classList.remove('selected'));
      opt.classList.add('selected');
      state.selectedGroupColor = opt.dataset.color;
    };
  });

  $('btn-create-group').onclick = async () => {
    const name = $('create-group-name').value.trim();
    if (!name) { showToast('그룹 이름을 입력하세요.'); return; }
    const privacy = document.querySelector('input[name="privacy"]:checked')?.value || 'public';
    try {
      await API.post('/api/groups', {
        name,
        description: $('create-group-desc').value.trim(),
        icon: state.selectedGroupIcon,
        color: state.selectedGroupColor,
        maxMembers: parseInt($('create-group-max').value) || 8,
        isPublic: privacy === 'public',
      });
      $('create-group-modal').hidden = true;
      showToast('그룹이 생성됐습니다! 🎉');
      await loadMyGroup();
    } catch (e) { showToast(e.message); }
  };

  /* 그룹 검색 */
  $('btn-search-group').onclick = async () => {
    const q = $('group-search-input').value.trim();
    if (!q) return;
    try {
      const results = await API.get(`/api/groups/search?q=${encodeURIComponent(q)}`);
      renderGroupCards('group-search-results', results, true);
    } catch (e) { showToast(e.message); }
  };
  $('group-search-input').onkeydown = e => { if (e.key === 'Enter') $('btn-search-group').click(); };

  /* 그룹 나가기 */
  $('btn-leave-group').onclick = async () => {
    if (!confirm('그룹에서 나가시겠습니까?')) return;
    try {
      await API.del(`/api/groups/${state.myGroup.id}/leave`);
      state.myGroup = null;
      $('group-no-group').hidden = false;
      $('group-has-group').hidden = true;
      showToast('그룹에서 나왔습니다.');
      loadRecommendedGroups();
    } catch (e) { showToast(e.message); }
  };

  /* 그룹 채팅 */
  $('btn-send-chat').onclick = async () => {
    const msg = $('chat-input').value.trim();
    if (!msg || !state.myGroup) return;
    try {
      const data = await API.post(`/api/groups/${state.myGroup.id}/messages`, { message: msg });
      state.myGroupMessages.push(data);
      $('chat-input').value = '';
      renderGroupChat();
    } catch (e) { showToast(e.message); }
  };
  $('chat-input').onkeydown = e => { if (e.key === 'Enter') $('btn-send-chat').click(); };

  /* AI */
  $('btn-analyze').onclick = requestAnalysis;
  $('btn-ai-send').onclick = () => sendAIChat($('ai-chat-input').value);
  $('ai-chat-input').onkeydown = e => { if (e.key === 'Enter') sendAIChat($('ai-chat-input').value); };
  document.querySelectorAll('.sq-btn').forEach(btn => {
    btn.onclick = () => sendAIChat(btn.dataset.q);
  });

  /* 모달 오버레이 클릭 닫기 */
  document.querySelectorAll('.modal-overlay').forEach(overlay => {
    overlay.onclick = e => { if (e.target === overlay) overlay.hidden = true; };
  });

  /* 프로필 패널 */
  $('user-avatar').onclick = openProfile;
  $('btn-close-profile').onclick = closeProfile;
  $('profile-overlay').onclick = closeProfile;

  $('btn-save-profile').onclick = async () => {
    const btn = $('btn-save-profile');
    btn.textContent = '저장 중...'; btn.disabled = true;
    try {
      const updated = await API.put('/api/users/me', {
        name: $('profile-edit-name').value.trim() || undefined,
        organization: $('profile-edit-org').value.trim() || undefined,
        description: $('profile-edit-desc').value.trim() || undefined,
      });
      state.user = updated;
      $('sidebar-avatar-circle').textContent = (updated.name || '?')[0];
      $('sidebar-user-name').textContent = updated.name || '-';
      updateSidebarLevel();
      showToast('프로필이 저장됐습니다 ✓');
      renderProfilePanel();
    } catch (e) { showToast('저장 실패: ' + e.message); }
    btn.textContent = '저장하기'; btn.disabled = false;
  };

  $('btn-logout').onclick = () => {
    if (!confirm('로그아웃 하시겠습니까?')) return;
    API.clearToken();
    state.user = null;
    Object.values(state.timers).forEach(t => clearInterval(t.interval));
    state.timers = {};
    closeProfile();
    $('app').hidden = true;
    $('login-screen').hidden = false;
    showToast('로그아웃됐습니다.');
  };

  /* 자동 로그인 */
  await tryAutoLogin();
  if (API.isLoggedIn()) {
    updatePlantUI();
    setInterval(loadHRV, 300_000);
    setInterval(updateStats, 5000);
  }
});
