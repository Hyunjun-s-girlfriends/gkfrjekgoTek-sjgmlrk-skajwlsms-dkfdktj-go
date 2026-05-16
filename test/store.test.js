import test from "node:test";
import assert from "node:assert/strict";
import {
  completeMission,
  endStudySession,
  getAiRecommendation,
  getDashboard,
  getDeviceStatus,
  getDrowsinessTimeline,
  getFocusTimeline,
  getGroupRanking,
  login,
  receiveHealthSample,
  receiveHeadMotionSample,
  seedDemoData,
  signUp,
  startStudySession
} from "../src/store.js";

test("dashboard summarizes seeded study and biometric data", async () => {
  await seedDemoData();

  const dashboard = await getDashboard();

  assert.equal(dashboard.user.name, "김체리");
  assert.equal(dashboard.user.passwordHash, undefined);
  assert.equal(dashboard.totals.sessionCount, 2);
  assert.equal(dashboard.totals.totalMinutes, 130);
  assert.ok(dashboard.totals.avgFocus > 0);
  assert.ok(dashboard.totals.avgStress > 0);
  assert.equal(dashboard.subjects.length, 3);
});

test("signup stores credentials privately and login returns a public user", async () => {
  await seedDemoData();

  const created = await signUp({
    username: "taein",
    password: "pass-1234",
    name: "태인"
  });
  const loggedIn = await login({ username: "taein", password: "pass-1234" });

  assert.equal(created.user.username, "taein");
  assert.equal(created.user.passwordHash, undefined);
  assert.equal(loggedIn.user.name, "태인");
  assert.equal(loggedIn.user.passwordHash, undefined);
  assert.ok(loggedIn.accessToken.startsWith("local_"));
});

test("study session accepts watch samples and updates focus timeline", async () => {
  await seedDemoData();

  const session = await startStudySession({
    subjectId: "subject_english",
    startedAt: "2026-05-16T10:00:00.000Z"
  });
  await receiveHealthSample({
    sessionId: session.id,
    heartRate: 76,
    hrv: 64,
    timestamp: "2026-05-16T10:05:00.000Z"
  });
  await endStudySession({
    sessionId: session.id,
    endedAt: "2026-05-16T10:40:00.000Z"
  });

  const focus = await getFocusTimeline();
  const ten = focus.find((item) => item.hour === "10:00");
  assert.ok(ten);
  assert.ok(ten.focus >= 0 && ten.focus <= 100);
});

test("AirPods head motion records drowsiness by hour", async () => {
  await seedDemoData();

  await receiveHeadMotionSample({
    pitch: -1.0,
    roll: 0.05,
    yaw: 0.12,
    downDurationSeconds: 72,
    timestamp: "2026-05-16T04:15:00.000Z"
  });

  const timeline = await getDrowsinessTimeline();
  const devices = await getDeviceStatus();
  const onePm = timeline.find((item) => item.hour === "13:00");

  assert.ok(onePm);
  assert.equal(onePm.count, 1);
  assert.ok(onePm.avgSleepyScore >= 60);
  assert.equal(devices.devices.some((device) => device.deviceType === "AIRPODS"), true);
});

test("mission completion grants rewards only once", async () => {
  await seedDemoData();
  const before = await getDashboard();

  await completeMission({ missionId: "mission_today_2" });
  await completeMission({ missionId: "mission_today_2" });

  const after = await getDashboard();
  assert.equal(after.user.xp, before.user.xp + 60);
  assert.equal(after.user.credits, before.user.credits + 20);
});

test("group ranking and AI recommendation are available", async () => {
  await seedDemoData();

  const ranking = await getGroupRanking();
  const recommendation = await getAiRecommendation();

  assert.equal(ranking.rows[0].rank, 1);
  assert.ok(recommendation.recommendation.includes(recommendation.bestHour));
});
