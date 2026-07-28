const SERVICE_NAME = "fortis-build-telegram";
const TELEGRAM_API_BASE = "https://api.telegram.org";

export default {
  fetch(request, env, ctx) {
    return handleRequest(request, env, { fetch, ctx });
  },
};

export async function handleRequest(request, env, platform = {}) {
  const url = new URL(request.url);

  if (request.method === "GET" && url.pathname === "/health") {
    return json({ ok: true, service: SERVICE_NAME });
  }

  const match = url.pathname.match(/^\/deploy\/([^/]+)$/);
  if (request.method !== "POST" || !match) {
    return json({ ok: false, error: "not_found" }, 404);
  }

  if (!(await secretMatches(match[1], env.DEPLOY_WEBHOOK_SECRET))) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }

  let event;
  try {
    event = await request.json();
  } catch {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  const text = formatDeployMessage(event);
  const response = await sendTelegram(text, env, platform.fetch ?? fetch);
  if (!response.ok) {
    return json({ ok: false, error: "telegram_failed" }, 502);
  }

  return json({ ok: true });
}

export function formatDeployMessage(event) {
  const status = normalizeStatus(event?.status);
  const title = `Fortis deploy ${status}`;
  const lines = [
    `<b>${escapeHtml(title)}</b>`,
    fieldLine("Environment", event?.environment),
    fieldLine("Branch", event?.branch),
    fieldLine("Parent", formatCommit(event?.ref, event?.commitSubject)),
    fieldLine("Frontend", formatCommit(event?.frontendRef, event?.frontendCommitSubject)),
    fieldLine("Backend", formatCommit(event?.backendRef, event?.backendCommitSubject)),
    fieldLine("URL", event?.url),
    fieldLine("Exit", event?.exitCode),
    fieldLine("Line", event?.line),
    fieldLine("Generated", event?.generatedAt),
  ].filter(Boolean);

  return lines.join("\n");
}

function formatCommit(ref, subject) {
  if (!ref && !subject) {
    return "";
  }

  if (ref && subject) {
    return `${ref} - ${subject}`;
  }

  return ref || subject;
}

async function sendTelegram(text, env, fetchImpl) {
  const token = required(env.TELEGRAM_BOT_TOKEN, "TELEGRAM_BOT_TOKEN");
  const chatId = required(env.TELEGRAM_CHAT_ID, "TELEGRAM_CHAT_ID");
  const endpoint = `${TELEGRAM_API_BASE}/bot${token}/sendMessage`;
  const body = new FormData();

  body.set("chat_id", chatId);
  body.set("text", text);
  body.set("parse_mode", "HTML");

  if (env.TELEGRAM_THREAD_ID) {
    body.set("message_thread_id", env.TELEGRAM_THREAD_ID);
  }

  return fetchImpl(endpoint, { method: "POST", body });
}

function normalizeStatus(status) {
  if (status === "started" || status === "succeeded" || status === "failed") {
    return status;
  }

  return "unknown";
}

function fieldLine(label, value) {
  if (value === undefined || value === null || value === "") {
    return "";
  }

  return `<b>${escapeHtml(label)}:</b> ${escapeHtml(String(value))}`;
}

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

async function secretMatches(provided, expected) {
  if (!expected) {
    return false;
  }

  const [providedDigest, expectedDigest] = await Promise.all([sha256(provided), sha256(expected)]);
  return timingSafeEqual(providedDigest, expectedDigest);
}

async function sha256(value) {
  const bytes = new TextEncoder().encode(value);
  return new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
}

function timingSafeEqual(a, b) {
  if (a.byteLength !== b.byteLength) {
    return false;
  }

  let diff = 0;
  for (let index = 0; index < a.byteLength; index += 1) {
    diff |= a[index] ^ b[index];
  }

  return diff === 0;
}

function required(value, name) {
  if (!value) {
    throw new Error(`Missing required env ${name}`);
  }

  return value;
}

function json(body, status = 200) {
  return Response.json(body, {
    status,
    headers: {
      "cache-control": "no-store",
    },
  });
}
