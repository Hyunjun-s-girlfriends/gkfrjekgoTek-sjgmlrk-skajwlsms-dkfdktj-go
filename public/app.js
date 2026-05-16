const $ = (selector) => document.querySelector(selector);

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "content-type": "application/json" },
    ...options,
    body: options.body ? JSON.stringify(options.body) : undefined
  });
  if (!response.ok) throw new Error((await response.json()).error || "Request failed");
  return response.json();
}

function metric(label, value, hint) {
  return `
    <div class="metric">
      <span>${label}</span>
      <strong>${value}</strong>
      <span>${hint}</span>
    </div>
  `;
}

function drawLineChart(canvas, points, key, color) {
  const ctx = canvas.getContext("2d");
  const width = canvas.width;
  const height = canvas.height;
  const padding = 38;
  ctx.clearRect(0, 0, width, height);
  ctx.strokeStyle = "#dce2ea";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(padding, padding);
  ctx.lineTo(padding, height - padding);
  ctx.lineTo(width - padding, height - padding);
  ctx.stroke();

  if (!points.length) return;

  const max = 100;
  const min = 0;
  const stepX = points.length === 1 ? 0 : (width - padding * 2) / (points.length - 1);

  ctx.strokeStyle = color;
  ctx.lineWidth = 4;
  ctx.beginPath();
  points.forEach((point, index) => {
    const x = padding + stepX * index;
    const y = height - padding - ((point[key] - min) / (max - min)) * (height - padding * 2);
    if (index === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.stroke();

  ctx.fillStyle = "#172033";
  ctx.font = "22px system-ui";
  points.forEach((point, index) => {
    const x = padding + stepX * index;
    const y = height - padding - ((point[key] - min) / (max - min)) * (height - padding * 2);
    ctx.beginPath();
    ctx.arc(x, y, 6, 0, Math.PI * 2);
    ctx.fill();
    ctx.font = "14px system-ui";
    ctx.fillText(point.hour, Math.max(8, x - 18), height - 12);
  });
}

async function render() {
  const [dashboard, focus, stress, report, ranking, coach] = await Promise.all([
    api("/api/dashboard"),
    api("/api/dashboard/focus"),
    api("/api/dashboard/stress"),
    api("/api/ai/report"),
    api("/api/groups/ranking"),
    api("/api/ai/coach")
  ]);

  $("#profile").innerHTML = `
    <strong>${dashboard.user.name}</strong>
    ${dashboard.user.title} · ${dashboard.user.xp}px · ${dashboard.user.credits} credits
  `;

  $("#dashboard").innerHTML = [
    metric("총 공부 시간", `${dashboard.totals.totalMinutes}분`, `${dashboard.totals.sessionCount} sessions`),
    metric("평균 집중도", `${dashboard.totals.avgFocus}점`, "100점에 가까울수록 좋음"),
    metric("평균 스트레스", `${dashboard.totals.avgStress}점`, "최적 구간은 45-65"),
    metric("미션", `${dashboard.totals.missionDone}/${dashboard.totals.missionTotal}`, "완료 현황")
  ].join("");

  $("#bestHourBadge").textContent = `추천 시간 ${dashboard.totals.bestHour}`;
  drawLineChart($("#focusChart"), focus, "focus", "#2f6fed");

  $("#stressList").innerHTML = stress.slice(-6).reverse().map((item) => `
    <div class="stress-item">
      <div>
        <strong>${new Date(item.timestamp).toLocaleTimeString("ko-KR", { hour: "2-digit", minute: "2-digit" })}</strong>
        <span>HR ${item.heartRate} · HRV ${item.hrv}</span>
      </div>
      <strong>${item.stress}</strong>
    </div>
  `).join("");

  $("#subjectSelect").innerHTML = dashboard.subjects.map((subject) => `
    <option value="${subject.id}">${subject.name}</option>
  `).join("");

  $("#currentSession").textContent = dashboard.currentSession
    ? `${dashboard.currentSession.subjectName} 진행 중 · ${new Date(dashboard.currentSession.startedAt).toLocaleTimeString("ko-KR")}`
    : "진행 중인 타이머가 없습니다.";

  $("#aiReport").innerHTML = `
    <div class="report-block"><strong>요약</strong><p>${report.summary}</p></div>
    <div class="report-block"><strong>잘되는 시간</strong><p>${coach.bestTime}</p></div>
    <div class="report-block"><strong>약한 시간</strong><p>${coach.weakTime}</p></div>
    <div class="report-block"><strong>코칭</strong><p>${coach.coaching}</p></div>
    <div class="report-block"><strong>다음 계획</strong><p>${report.nextPlan.join(" · ")}</p></div>
  `;

  $("#rankingList").innerHTML = ranking.rows.map((row) => `
    <div class="ranking-item">
      <strong>${row.rank}. ${row.name}</strong>
      <span>${row.totalMinutes}분 · ${row.xp}px · 보상 ${row.rewardCredits} credits</span>
    </div>
  `).join("");
}

$("#timerForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  await api("/api/study/start", {
    method: "POST",
    body: { subjectId: $("#subjectSelect").value }
  });
  await render();
});

$("#endSessionButton").addEventListener("click", async () => {
  await api("/api/study/end", { method: "POST", body: {} });
  await render();
});

$("#healthForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  await api("/api/health/heart-rate", {
    method: "POST",
    body: {
      heartRate: Number($("#heartRateInput").value),
      hrv: Number($("#hrvInput").value)
    }
  });
  await render();
});

$("#chatForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const reply = await api("/api/ai/chat", {
    method: "POST",
    body: { message: $("#chatInput").value }
  });
  $("#chatReply").textContent = reply.message;
});

$("#seedButton").addEventListener("click", async () => {
  await api("/api/dev/seed", { method: "POST", body: {} });
  await render();
});

render().catch((error) => {
  document.body.insertAdjacentHTML("beforeend", `<p style="color:#df3f62;padding:20px">${error.message}</p>`);
});
