import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import { config, loadEnv } from "./config.js";
import {
  completeMission,
  createGroup,
  createMission,
  getAiCoach,
  endStudySession,
  getAiChat,
  getAiRecommendation,
  getAiReport,
  connectWatchBridge,
  getDashboard,
  getDeviceStatus,
  getDrowsinessTimeline,
  getFocusTimeline,
  getGroupRanking,
  getState,
  getStressSeries,
  login,
  getTodaysMissions,
  receiveHealthSample,
  receiveHeadMotionSample,
  seedDemoData,
  signUp,
  socialLogin,
  startStudySession,
  updateNotificationSettings,
  updateUser
} from "./store.js";

loadEnv();

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const publicDir = normalize(join(__dirname, "..", "public"));
const port = config().port;

const contentTypes = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml"
};

function sendJson(res, status, payload) {
  res.writeHead(status, { "content-type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(payload, null, 2));
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const raw = Buffer.concat(chunks).toString("utf8");
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch {
    const error = new Error("Invalid JSON body");
    error.status = 400;
    throw error;
  }
}

async function serveStatic(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const requested = url.pathname === "/" ? "/index.html" : url.pathname;
  const filePath = normalize(join(publicDir, requested));

  if (!filePath.startsWith(publicDir)) {
    sendJson(res, 403, { error: "Forbidden" });
    return;
  }

  try {
    const file = await readFile(filePath);
    const contentType = contentTypes[extname(filePath)] || "application/octet-stream";
    res.writeHead(200, { "content-type": contentType });
    res.end(file);
  } catch {
    sendJson(res, 404, { error: "Not found" });
  }
}

async function handleApi(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname;
  const method = req.method || "GET";
  const body = method === "GET" ? {} : await readBody(req);

  if (method === "POST" && path === "/api/dev/seed") {
    sendJson(res, 200, await seedDemoData());
    return;
  }

  if (method === "POST" && path === "/api/auth/google") {
    sendJson(res, 200, await socialLogin(body));
    return;
  }

  if (method === "POST" && path === "/api/auth/signup") {
    sendJson(res, 201, await signUp(body));
    return;
  }

  if (method === "POST" && path === "/api/auth/login") {
    sendJson(res, 200, await login(body));
    return;
  }

  if (method === "POST" && path === "/api/auth/logout") {
    sendJson(res, 200, { ok: true });
    return;
  }

  if (method === "PATCH" && path === "/api/users/me") {
    sendJson(res, 200, await updateUser(body));
    return;
  }

  if (method === "POST" && path === "/api/study/start") {
    sendJson(res, 201, await startStudySession(body));
    return;
  }

  if (method === "POST" && path === "/api/study/end") {
    sendJson(res, 200, await endStudySession(body));
    return;
  }

  if (method === "GET" && path === "/api/study/current") {
    sendJson(res, 200, await getState("currentSession"));
    return;
  }

  if (method === "POST" && (path === "/api/health/heart-rate" || path === "/api/health/hrv-bridge")) {
    sendJson(res, 201, await receiveHealthSample(body));
    return;
  }

  if (method === "POST" && path === "/api/motion/headphone-sample") {
    sendJson(res, 201, await receiveHeadMotionSample(body));
    return;
  }

  if (method === "GET" && path === "/api/dashboard") {
    sendJson(res, 200, await getDashboard());
    return;
  }

  if (method === "GET" && path === "/api/dashboard/focus") {
    sendJson(res, 200, await getFocusTimeline());
    return;
  }

  if (method === "GET" && path === "/api/dashboard/stress") {
    sendJson(res, 200, await getStressSeries());
    return;
  }

  if (method === "GET" && path === "/api/dashboard/drowsiness") {
    sendJson(res, 200, await getDrowsinessTimeline());
    return;
  }

  if (method === "GET" && path === "/api/devices/status") {
    sendJson(res, 200, await getDeviceStatus());
    return;
  }

  if (method === "POST" && path === "/api/devices/watch-bridge/connect") {
    sendJson(res, 200, await connectWatchBridge());
    return;
  }

  if (method === "GET" && path === "/api/ai/report") {
    sendJson(res, 200, await getAiReport());
    return;
  }

  if (method === "GET" && path === "/api/ai/recommend") {
    sendJson(res, 200, await getAiRecommendation());
    return;
  }

  if (method === "GET" && path === "/api/ai/coach") {
    sendJson(res, 200, await getAiCoach());
    return;
  }

  if (method === "POST" && path === "/api/ai/chat") {
    sendJson(res, 200, await getAiChat(body));
    return;
  }

  if (method === "POST" && path === "/api/groups") {
    sendJson(res, 201, await createGroup(body));
    return;
  }

  if (method === "GET" && path === "/api/groups/ranking") {
    sendJson(res, 200, await getGroupRanking(url.searchParams.get("groupId")));
    return;
  }

  if (method === "POST" && path === "/api/missions") {
    sendJson(res, 201, await createMission(body));
    return;
  }

  if (method === "GET" && path === "/api/missions/today") {
    sendJson(res, 200, await getTodaysMissions());
    return;
  }

  if (method === "POST" && path === "/api/missions/complete") {
    sendJson(res, 200, await completeMission(body));
    return;
  }

  if (method === "PUT" && path === "/api/settings/notification") {
    sendJson(res, 200, await updateNotificationSettings(body));
    return;
  }

  sendJson(res, 404, { error: "Unknown endpoint", method, path });
}

const server = createServer(async (req, res) => {
  try {
    if (req.url?.startsWith("/api/")) {
      await handleApi(req, res);
      return;
    }
    await serveStatic(req, res);
  } catch (error) {
    sendJson(res, error.status || 500, { error: error.message || "Server error" });
  }
});

server.listen(port, () => {
  console.log(`StudyPuls local MVP running at http://localhost:${port}`);
});
