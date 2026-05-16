import { randomBytes, scryptSync, timingSafeEqual } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { getCoaching } from "./aiCoach.js";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const dataFile = join(__dirname, "..", "data", "studypuls.local.json");

const nowIso = () => new Date().toISOString();
const dateKey = (value = new Date()) => new Date(value).toISOString().slice(0, 10);
const hourKey = (value) => `${String(new Date(value).getHours()).padStart(2, "0")}:00`;
const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
const id = (prefix) => `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;

function hashPassword(password) {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(String(password), salt, 64).toString("hex");
  return `${salt}:${hash}`;
}

function verifyPassword(password, storedHash) {
  const [salt, hash] = String(storedHash || "").split(":");
  if (!salt || !hash) return false;
  const candidate = scryptSync(String(password), salt, 64);
  const expected = Buffer.from(hash, "hex");
  return expected.length === candidate.length && timingSafeEqual(expected, candidate);
}

function publicUser(user) {
  const { passwordHash, ...safeUser } = user;
  return safeUser;
}

function stressFromSample(sample) {
  const hrv = Number(sample.hrv || 0);
  const heartRate = Number(sample.heartRate || 0);
  const hrvStress = clamp(100 - hrv, 0, 100);
  const hrStress = clamp((heartRate - 55) * 1.4, 0, 100);
  return Math.round(hrvStress * 0.65 + hrStress * 0.35);
}

function focusFromStress(stress) {
  const distanceFromOptimal = Math.abs(stress - 55);
  return clamp(Math.round(100 - distanceFromOptimal * 1.7), 0, 100);
}

function average(numbers) {
  if (!numbers.length) return 0;
  return Math.round(numbers.reduce((sum, value) => sum + value, 0) / numbers.length);
}

function minutesBetween(start, end) {
  return Math.max(0, Math.round((new Date(end).getTime() - new Date(start).getTime()) / 60000));
}

function createDemoState() {
  const userId = "user_demo";
  const groupId = "group_focus";
  const subjects = [
    { id: "subject_math", name: "수학", color: "#2563eb" },
    { id: "subject_english", name: "영어", color: "#16a34a" },
    { id: "subject_cs", name: "자료구조", color: "#e11d48" }
  ];
  const today = dateKey();
  const sessions = [
    {
      id: "session_morning_math",
      userId,
      subjectId: "subject_math",
      subjectName: "수학",
      startedAt: `${today}T00:30:00.000Z`,
      endedAt: `${today}T01:25:00.000Z`,
      totalMinutes: 55
    },
    {
      id: "session_afternoon_cs",
      userId,
      subjectId: "subject_cs",
      subjectName: "자료구조",
      startedAt: `${today}T05:00:00.000Z`,
      endedAt: `${today}T06:15:00.000Z`,
      totalMinutes: 75
    }
  ];

  const healthSamples = [
    ["session_morning_math", 73, 62, `${today}T00:35:00.000Z`],
    ["session_morning_math", 78, 58, `${today}T00:55:00.000Z`],
    ["session_morning_math", 81, 55, `${today}T01:15:00.000Z`],
    ["session_afternoon_cs", 86, 42, `${today}T05:10:00.000Z`],
    ["session_afternoon_cs", 92, 35, `${today}T05:45:00.000Z`],
    ["session_afternoon_cs", 79, 51, `${today}T06:10:00.000Z`]
  ].map(([sessionId, heartRate, hrv, timestamp]) => {
    const sample = { id: id("health"), sessionId, heartRate, hrv, timestamp };
    return {
      ...sample,
      stress: stressFromSample(sample),
      focus: focusFromStress(stressFromSample(sample))
    };
  });

  const motionEvents = [
    {
      id: id("motion"),
      sessionId: "session_morning_math",
      deviceId: "device_demo_airpods",
      pitch: -44.2,
      roll: 2.4,
      yaw: 8.1,
      sleepyScore: 92,
      downDurationSeconds: 74,
      detectedAt: `${today}T02:05:00.000Z`,
      source: "airpods-core-motion",
      type: "drowsy"
    },
    {
      id: id("motion"),
      sessionId: "session_afternoon_cs",
      deviceId: "device_demo_airpods",
      pitch: -39.5,
      roll: 1.8,
      yaw: 3.7,
      sleepyScore: 82,
      downDurationSeconds: 66,
      detectedAt: `${today}T07:20:00.000Z`,
      source: "airpods-core-motion",
      type: "drowsy"
    }
  ];

  return {
    users: [
      {
        id: userId,
        email: "demo@studypuls.local",
        username: "demo",
        passwordHash: hashPassword("demo1234"),
        name: "김체리",
        phone: "010-0000-0000",
        provider: "local",
        xp: 1280,
        credits: 420,
        title: "루틴 탐색자",
        tags: ["아침형", "자료구조"],
        createdAt: nowIso()
      }
    ],
    subjects,
    titles: [
      { id: "title_seedling", name: "새싹 학습자", condition: "가입 완료" },
      { id: "title_routine", name: "루틴 탐색자", condition: "총 공부 120분 이상" },
      { id: "title_recovery", name: "회복 감지자", condition: "스트레스 피크 후 휴식 미션 완료" }
    ],
    groups: [
      {
        id: groupId,
        name: "캡스톤 집중반",
        description: "중간 발표 전 데모를 만드는 그룹",
        inviteCode: "SP-CHERRY",
        createdBy: userId,
        createdAt: nowIso()
      }
    ],
    groupMembers: [
      { groupId, userId, role: "owner", joinedAt: nowIso() },
      { groupId, userId: "user_jieun", role: "member", displayName: "지은", xp: 980, totalMinutes: 102 },
      { groupId, userId: "user_eunyu", role: "member", displayName: "은유", xp: 1120, totalMinutes: 136 }
    ],
    sessions,
    healthSamples,
    missions: [
      {
        id: "mission_today_1",
        userId,
        title: "수학 45분 집중",
        type: "study_minutes",
        target: 45,
        rewardXp: 80,
        rewardCredits: 30,
        titleReward: "",
        completed: true,
        createdAt: `${today}T00:00:00.000Z`,
        completedAt: `${today}T01:25:00.000Z`
      },
      {
        id: "mission_today_2",
        userId,
        title: "스트레스 피크 후 5분 휴식",
        type: "recovery",
        target: 1,
        rewardXp: 60,
        rewardCredits: 20,
        titleReward: "회복 감지자",
        completed: false,
        createdAt: `${today}T00:00:00.000Z`,
        completedAt: null
      }
    ],
    chatMessages: [],
    aiReports: [],
    notificationEvents: [],
    smsVerifications: [],
    watchDevices: [
      {
        id: "device_demo_watch",
        userId,
        name: "Demo Apple Watch",
        deviceType: "APPLE_WATCH_BRIDGE",
        status: "connected",
        bridgeMode: true,
        lastSyncedAt: nowIso()
      },
      {
        id: "device_demo_airpods",
        userId,
        name: "AirPods CoreMotion",
        deviceType: "AIRPODS",
        status: "waiting",
        bridgeMode: false,
        lastSyncedAt: null
      }
    ],
    motionEvents,
    settings: {
      notification: {
        focusAlert: true,
        missionAlert: true,
        drowsinessAlert: true
      }
    },
    currentSession: null
  };
}

async function readState() {
  try {
    return normalizeState(JSON.parse(await readFile(dataFile, "utf8")));
  } catch {
    const state = createDemoState();
    await writeState(state);
    return state;
  }
}

function normalizeState(state) {
  state.motionEvents ||= [];
  state.watchDevices ||= [];
  state.settings ||= {};
  state.settings.notification ||= {};
  state.settings.notification.focusAlert ??= true;
  state.settings.notification.missionAlert ??= true;
  state.settings.notification.drowsinessAlert ??= true;

  const userId = currentUser(state)?.id || "user_demo";
  if (!state.watchDevices.some((device) => device.deviceType === "AIRPODS")) {
    state.watchDevices.push({
      id: "device_airpods_core_motion",
      userId,
      name: "AirPods CoreMotion",
      deviceType: "AIRPODS",
      status: "waiting",
      bridgeMode: false,
      lastSyncedAt: null
    });
  }
  if (!state.watchDevices.some((device) => device.deviceType === "APPLE_WATCH_BRIDGE")) {
    state.watchDevices.push({
      id: "device_watch_bridge",
      userId,
      name: "Apple Watch Bridge",
      deviceType: "APPLE_WATCH_BRIDGE",
      status: "connected",
      bridgeMode: true,
      lastSyncedAt: nowIso()
    });
  }
  return state;
}

async function writeState(state) {
  await mkdir(dirname(dataFile), { recursive: true });
  await writeFile(dataFile, JSON.stringify(state, null, 2));
  return state;
}

function currentUser(state) {
  return state.users[0];
}

function sessionSamples(state, sessionId) {
  return state.healthSamples.filter((sample) => sample.sessionId === sessionId);
}

function summarizeSessions(state) {
  return state.sessions.map((session) => {
    const samples = sessionSamples(state, session.id);
    const stressValues = samples.map((sample) => sample.stress);
    const focusValues = samples.map((sample) => sample.focus);
    return {
      ...session,
      avgStress: average(stressValues),
      avgFocus: average(focusValues),
      avgHeartRate: average(samples.map((sample) => sample.heartRate)),
      avgHrv: average(samples.map((sample) => sample.hrv))
    };
  });
}

function subjectSummary(state) {
  const sessions = summarizeSessions(state);
  return state.subjects.map((subject) => {
    const matches = sessions.filter((session) => session.subjectId === subject.id);
    return {
      ...subject,
      totalMinutes: matches.reduce((sum, session) => sum + session.totalMinutes, 0),
      avgStress: average(matches.map((session) => session.avgStress).filter(Boolean)),
      avgFocus: average(matches.map((session) => session.avgFocus).filter(Boolean))
    };
  });
}

export async function getState(key) {
  const state = await readState();
  return key ? state[key] : state;
}

export async function seedDemoData() {
  return writeState(createDemoState());
}

export async function socialLogin({ accessToken = "demo-token", provider = "google" }) {
  const state = await readState();
  const user = currentUser(state);
  user.provider = provider;
  user.lastLoginAt = nowIso();
  await writeState(state);
  return { accessToken, user: publicUser(user) };
}

export async function signUp({ phone, name, googleId, username, password }) {
  const state = await readState();
  const normalizedUsername = username || googleId || phone || `user_${state.users.length + 1}`;
  if (state.users.some((item) => item.username === normalizedUsername)) {
    const error = new Error("Username already exists");
    error.status = 409;
    throw error;
  }
  const user = {
    id: id("user"),
    email: `${googleId || normalizedUsername}@studypuls.local`,
    username: normalizedUsername,
    passwordHash: hashPassword(password || randomBytes(10).toString("hex")),
    name: name || "새 사용자",
    phone: phone || "",
    provider: googleId ? "google" : "phone",
    xp: 0,
    credits: 0,
    title: "새싹 학습자",
    tags: [],
    createdAt: nowIso()
  };
  state.users.push(user);
  await writeState(state);
  return { user: publicUser(user) };
}

export async function login({ username, password }) {
  const state = await readState();
  const user = state.users.find((item) => item.username === username);
  if (!user || !verifyPassword(password, user.passwordHash)) {
    const error = new Error("Invalid username or password");
    error.status = 401;
    throw error;
  }
  user.lastLoginAt = nowIso();
  await writeState(state);
  return {
    accessToken: `local_${randomBytes(24).toString("hex")}`,
    user: publicUser(user)
  };
}

export async function updateUser(body) {
  const state = await readState();
  const user = currentUser(state);
  Object.assign(user, {
    name: body.name ?? user.name,
    title: body.title ?? user.title,
    tags: Array.isArray(body.tags) ? body.tags : user.tags
  });
  await writeState(state);
  return publicUser(user);
}

export async function startStudySession({ subjectId = "subject_math", subjectName, startedAt = nowIso() }) {
  const state = await readState();
  const subject = state.subjects.find((item) => item.id === subjectId) || state.subjects[0];
  const session = {
    id: id("session"),
    userId: currentUser(state).id,
    subjectId: subject?.id || subjectId,
    subjectName: subjectName || subject?.name || "기타",
    startedAt,
    endedAt: null,
    totalMinutes: 0
  };
  state.currentSession = session;
  state.sessions.push(session);
  await writeState(state);
  return session;
}

export async function endStudySession({ sessionId, endedAt = nowIso() }) {
  const state = await readState();
  const session = state.sessions.find((item) => item.id === (sessionId || state.currentSession?.id));
  if (!session) {
    const error = new Error("Study session not found");
    error.status = 404;
    throw error;
  }
  session.endedAt = endedAt;
  session.totalMinutes = minutesBetween(session.startedAt, endedAt);
  if (state.currentSession?.id === session.id) state.currentSession = null;
  await writeState(state);
  return session;
}

export async function receiveHealthSample({ sessionId, heartRate, hrv, timestamp = nowIso() }) {
  const state = await readState();
  const activeSessionId = sessionId || state.currentSession?.id || state.sessions.at(-1)?.id;
  if (!activeSessionId) {
    const error = new Error("No study session available for health sample");
    error.status = 400;
    throw error;
  }
  const sample = {
    id: id("health"),
    sessionId: activeSessionId,
    heartRate: Number(heartRate),
    hrv: Number(hrv),
    timestamp
  };
  sample.stress = stressFromSample(sample);
  sample.focus = focusFromStress(sample.stress);
  state.healthSamples.push(sample);
  await writeState(state);
  return sample;
}

function drowsyScoreFromMotion({ pitch = 0, roll = 0, downDurationSeconds = 0 }) {
  const pitchDegrees = Math.abs(Number(pitch) * 180 / Math.PI);
  const rollPenalty = Math.min(Math.abs(Number(roll) * 180 / Math.PI), 30);
  const durationScore = clamp(Number(downDurationSeconds), 0, 120) / 120 * 40;
  return Math.round(clamp((pitchDegrees - 25) * 1.5 + durationScore - rollPenalty * 0.25, 0, 100));
}

export async function receiveHeadMotionSample({
  sessionId,
  pitch = 0,
  roll = 0,
  yaw = 0,
  sleepyScore,
  downDurationSeconds = 0,
  timestamp = nowIso(),
  source = "airpods-core-motion",
  type = "sample"
}) {
  const state = await readState();
  const activeSessionId = sessionId || state.currentSession?.id || state.sessions.at(-1)?.id;
  const score = sleepyScore ?? drowsyScoreFromMotion({ pitch, roll, downDurationSeconds });
  const event = {
    id: id("motion"),
    sessionId: activeSessionId || null,
    deviceId: state.watchDevices.find((device) => device.deviceType === "AIRPODS")?.id || null,
    pitch: Number(pitch),
    roll: Number(roll),
    yaw: Number(yaw),
    sleepyScore: Number(score),
    downDurationSeconds: Number(downDurationSeconds),
    detectedAt: timestamp,
    source,
    type: Number(downDurationSeconds) >= 60 && Number(score) >= 60 ? "drowsy" : type
  };
  state.motionEvents.push(event);

  const airpods = state.watchDevices.find((device) => device.deviceType === "AIRPODS");
  if (airpods) {
    airpods.status = "connected";
    airpods.lastSyncedAt = timestamp;
  }

  await writeState(state);
  return event;
}

export async function getDrowsinessTimeline() {
  const state = await readState();
  const events = state.motionEvents.filter((event) => event.type === "drowsy" || event.downDurationSeconds >= 60);
  const grouped = new Map();
  for (const event of events) {
    const key = hourKey(event.detectedAt);
    grouped.set(key, [...(grouped.get(key) || []), event]);
  }
  return [...grouped.entries()]
    .map(([hour, values]) => ({
      hour,
      count: values.length,
      avgSleepyScore: average(values.map((value) => value.sleepyScore)),
      totalMinutes: Math.max(1, Math.round(values.reduce((sum, value) => sum + Number(value.downDurationSeconds || 60), 0) / 60))
    }))
    .sort((a, b) => a.hour.localeCompare(b.hour));
}

export async function getDashboard() {
  const state = await readState();
  const user = currentUser(state);
  const sessions = summarizeSessions(state);
  const samples = state.healthSamples;
  const totalMinutes = sessions.reduce((sum, session) => sum + session.totalMinutes, 0);
  const avgStress = average(samples.map((sample) => sample.stress));
  const avgFocus = average(samples.map((sample) => sample.focus));
  const bestHour = getBestFocusHour(samples);
  const drowsiness = await getDrowsinessTimeline();

  return {
    user: publicUser(user),
    totals: {
      totalMinutes,
      sessionCount: sessions.length,
      avgStress,
      avgFocus,
      bestHour,
      drowsyCount: drowsiness.reduce((sum, item) => sum + item.count, 0),
      missionDone: state.missions.filter((mission) => mission.completed).length,
      missionTotal: state.missions.length
    },
    subjects: subjectSummary(state),
    recentSessions: sessions.slice(-8).reverse(),
    currentSession: state.currentSession,
    notification: state.settings.notification,
    devices: getDeviceStatusFromState(state)
  };
}

function getDeviceStatusFromState(state) {
  return state.watchDevices.map((device) => ({
    id: device.id,
    name: device.name,
    deviceType: device.deviceType || "APPLE_WATCH_BRIDGE",
    status: device.status || "waiting",
    bridgeMode: Boolean(device.bridgeMode),
    lastSyncedAt: device.lastSyncedAt || null
  }));
}

export async function getDeviceStatus() {
  const state = await readState();
  return { devices: getDeviceStatusFromState(state) };
}

export async function connectWatchBridge() {
  const state = await readState();
  let watch = state.watchDevices.find((device) => device.deviceType === "APPLE_WATCH_BRIDGE");
  if (!watch) {
    watch = {
      id: id("device"),
      userId: currentUser(state).id,
      name: "Apple Watch Bridge",
      deviceType: "APPLE_WATCH_BRIDGE",
      bridgeMode: true
    };
    state.watchDevices.push(watch);
  }
  watch.status = "connected";
  watch.lastSyncedAt = nowIso();
  await writeState(state);
  return { devices: getDeviceStatusFromState(state) };
}

function getBestFocusHour(samples) {
  const grouped = new Map();
  for (const sample of samples) {
    const key = hourKey(sample.timestamp);
    grouped.set(key, [...(grouped.get(key) || []), sample.focus]);
  }
  const ranked = [...grouped.entries()]
    .map(([hour, values]) => ({ hour, focus: average(values) }))
    .sort((a, b) => b.focus - a.focus);
  return ranked[0]?.hour || "-";
}

function buildAnalysis(state) {
  const samples = state.healthSamples
    .map((sample) => ({
      timestamp: sample.timestamp,
      hour: hourKey(sample.timestamp),
      heartRate: sample.heartRate,
      hrv: sample.hrv,
      stress: sample.stress,
      focus: sample.focus
    }))
    .sort((a, b) => a.timestamp.localeCompare(b.timestamp));
  const grouped = new Map();
  for (const sample of samples) {
    const key = sample.hour;
    grouped.set(key, [...(grouped.get(key) || []), sample]);
  }
  const hourlyRanking = [...grouped.entries()]
    .map(([hour, values]) => ({
      hour,
      focus: average(values.map((value) => value.focus)),
      stress: average(values.map((value) => value.stress)),
      hrv: average(values.map((value) => value.hrv)),
      heartRate: average(values.map((value) => value.heartRate))
    }))
    .sort((a, b) => b.focus - a.focus);

  return {
    averageFocus: average(samples.map((sample) => sample.focus)),
    averageStress: average(samples.map((sample) => sample.stress)),
    hourlyRanking,
    stressSeries: samples,
    subjectSummary: subjectSummary(state)
  };
}

export async function getFocusTimeline() {
  const state = await readState();
  const grouped = new Map();
  for (const sample of state.healthSamples) {
    const key = hourKey(sample.timestamp);
    grouped.set(key, [...(grouped.get(key) || []), sample.focus]);
  }
  return [...grouped.entries()]
    .map(([hour, values]) => ({ hour, focus: average(values) }))
    .sort((a, b) => a.hour.localeCompare(b.hour));
}

export async function getStressSeries() {
  const state = await readState();
  return state.healthSamples
    .map((sample) => ({
      timestamp: sample.timestamp,
      hour: hourKey(sample.timestamp),
      stress: sample.stress,
      focus: sample.focus,
      heartRate: sample.heartRate,
      hrv: sample.hrv
    }))
    .sort((a, b) => a.timestamp.localeCompare(b.timestamp));
}

export async function getAiReport() {
  const state = await readState();
  const coaching = await getCoaching(buildAnalysis(state));
  const report = {
    createdAt: nowIso(),
    summary: coaching.summary,
    insight: `${coaching.bestTime} ${coaching.weakTime}`,
    coaching: coaching.coaching,
    nextPlan: coaching.nextActions,
    provider: coaching.provider,
    warning: coaching.warning
  };
  return report;
}

export async function getAiRecommendation() {
  const state = await readState();
  const dashboard = await getDashboard();
  const coaching = await getCoaching(buildAnalysis(state));
  return {
    bestHour: dashboard.totals.bestHour,
    recommendation: coaching.bestTime,
    weakTime: coaching.weakTime,
    coaching: coaching.coaching,
    provider: coaching.provider,
    confidence: dashboard.totals.sessionCount >= 2 ? "medium" : "low"
  };
}

export async function getAiChat({ message = "" }) {
  const state = await readState();
  const coaching = await getCoaching(buildAnalysis(state), message);
  return {
    role: "assistant",
    message: `${coaching.summary} ${coaching.bestTime} ${coaching.weakTime} ${coaching.coaching}`,
    nextActions: coaching.nextActions,
    basedOn: coaching.provider
  };
}

export async function getAiCoach() {
  const state = await readState();
  return getCoaching(buildAnalysis(state));
}

export async function createGroup({ groupName, description = "" }) {
  const state = await readState();
  const group = {
    id: id("group"),
    name: groupName || "새 스터디 그룹",
    description,
    inviteCode: `SP-${Math.random().toString(36).slice(2, 8).toUpperCase()}`,
    createdBy: currentUser(state).id,
    createdAt: nowIso()
  };
  state.groups.push(group);
  state.groupMembers.push({ groupId: group.id, userId: currentUser(state).id, role: "owner", joinedAt: nowIso() });
  await writeState(state);
  return group;
}

export async function getGroupRanking(groupId) {
  const state = await readState();
  const targetGroup = groupId || state.groups[0]?.id;
  const user = currentUser(state);
  const ownMinutes = state.sessions.reduce((sum, session) => sum + session.totalMinutes, 0);
  const rows = state.groupMembers
    .filter((member) => member.groupId === targetGroup)
    .map((member) => ({
      userId: member.userId,
      name: member.displayName || (member.userId === user.id ? user.name : member.userId),
      xp: member.userId === user.id ? user.xp : member.xp || 0,
      totalMinutes: member.userId === user.id ? ownMinutes : member.totalMinutes || 0
    }))
    .sort((a, b) => b.totalMinutes - a.totalMinutes || b.xp - a.xp)
    .map((row, index) => ({ ...row, rank: index + 1, rewardCredits: rankReward(index + 1, "group") }));
  return { groupId: targetGroup, rows };
}

function rankReward(rank, type) {
  if (type === "group") {
    if (rank <= 3) return 200;
    if (rank <= 20) return 100;
    if (rank <= 50) return 50;
    return 0;
  }
  if (rank <= 3) return 500;
  if (rank <= 20) return 250;
  if (rank <= 50) return 100;
  if (rank <= 100) return 50;
  return 0;
}

export async function createMission({ userId, type = "study_minutes", target = 30, title }) {
  const state = await readState();
  const mission = {
    id: id("mission"),
    userId: userId || currentUser(state).id,
    title: title || `${target}분 집중하기`,
    type,
    target: Number(target),
    rewardXp: 50,
    rewardCredits: 20,
    titleReward: "",
    completed: false,
    createdAt: nowIso(),
    completedAt: null
  };
  state.missions.push(mission);
  await writeState(state);
  return mission;
}

export async function getTodaysMissions() {
  const state = await readState();
  const today = dateKey();
  return state.missions.filter((mission) => dateKey(mission.createdAt) === today);
}

export async function completeMission({ missionId }) {
  const state = await readState();
  const mission = state.missions.find((item) => item.id === missionId);
  if (!mission) {
    const error = new Error("Mission not found");
    error.status = 404;
    throw error;
  }
  if (!mission.completed) {
    mission.completed = true;
    mission.completedAt = nowIso();
    const user = currentUser(state);
    user.xp += mission.rewardXp;
    user.credits += mission.rewardCredits;
    if (mission.titleReward) user.title = mission.titleReward;
  }
  await writeState(state);
  return { mission, user: publicUser(currentUser(state)) };
}

export async function updateNotificationSettings({ focusAlert, missionAlert, drowsinessAlert }) {
  const state = await readState();
  state.settings.notification = {
    focusAlert: typeof focusAlert === "boolean" ? focusAlert : state.settings.notification.focusAlert,
    missionAlert: typeof missionAlert === "boolean" ? missionAlert : state.settings.notification.missionAlert,
    drowsinessAlert: typeof drowsinessAlert === "boolean" ? drowsinessAlert : state.settings.notification.drowsinessAlert
  };
  await writeState(state);
  return state.settings.notification;
}
