import { readFileSync } from "node:fs";
import { resolve } from "node:path";

let loaded = false;

export function loadEnv() {
  if (loaded) return;
  loaded = true;

  const envPath = resolve(".env");
  let raw = "";
  try {
    raw = readFileSync(envPath, "utf8");
  } catch {
    return;
  }

  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const separator = trimmed.indexOf("=");
    if (separator === -1) continue;
    const key = trimmed.slice(0, separator).trim();
    let value = trimmed.slice(separator + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (!process.env[key]) process.env[key] = value;
  }
}

export function config() {
  loadEnv();
  return {
    port: Number(process.env.PORT || 3000),
    openAiApiKey: process.env.OPENAI_API_KEY || "",
    openAiModel: process.env.OPENAI_MODEL || "gpt-4.1-mini",
    openAiTimeoutMs: Number(process.env.OPENAI_TIMEOUT_MS || 6500),
    openAiEnabled: process.env.AI_PROVIDER === "openai" && Boolean(process.env.OPENAI_API_KEY),
    mysql: {
      host: process.env.MYSQL_HOST || "127.0.0.1",
      port: Number(process.env.MYSQL_PORT || 3306),
      database: process.env.MYSQL_DATABASE || "studypuls",
      appUser: process.env.MYSQL_APP_USER || "studypuls_app",
      adminUser: process.env.MYSQL_ADMIN_USER || "studypuls_admin"
    }
  };
}
