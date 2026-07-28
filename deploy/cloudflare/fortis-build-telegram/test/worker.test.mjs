import assert from "node:assert/strict";
import test from "node:test";

import { handleRequest } from "../src/worker.mjs";

const env = {
  DEPLOY_WEBHOOK_SECRET: "deploy-secret",
  TELEGRAM_BOT_TOKEN: "telegram-token",
  TELEGRAM_CHAT_ID: "-1004435908726",
  TELEGRAM_THREAD_ID: "370",
};

test("health endpoint returns ok without hitting Telegram", async () => {
  const calls = [];
  const response = await handleRequest(new Request("https://worker.example/health"), env, {
    fetch: async (...args) => {
      calls.push(args);
      return new Response("{}");
    },
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true, service: "fortis-build-telegram" });
  assert.equal(calls.length, 0);
});

test("deploy endpoint rejects a bad path secret", async () => {
  const calls = [];
  const response = await handleRequest(
    new Request("https://worker.example/deploy/wrong-secret", {
      method: "POST",
      body: JSON.stringify({ status: "started" }),
    }),
    env,
    {
      fetch: async (...args) => {
        calls.push(args);
        return new Response("{}");
      },
    },
  );

  assert.equal(response.status, 401);
  assert.equal(calls.length, 0);
});

test("deploy endpoint sends build event to the configured Telegram topic", async () => {
  const calls = [];
  const response = await handleRequest(
    new Request("https://worker.example/deploy/deploy-secret", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        status: "succeeded",
        environment: "dev-vm",
        ref: "abc1234",
        url: "http://85.208.87.187/",
      }),
    }),
    env,
    {
      fetch: async (...args) => {
        calls.push(args);
        return Response.json({ ok: true });
      },
    },
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true });
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], "https://api.telegram.org/bottelegram-token/sendMessage");

  const form = calls[0][1].body;
  assert.equal(form.get("chat_id"), "-1004435908726");
  assert.equal(form.get("message_thread_id"), "370");
  assert.equal(form.get("parse_mode"), "HTML");
  assert.match(form.get("text"), /Fortis deploy succeeded/);
  assert.match(form.get("text"), /abc1234/);
});
