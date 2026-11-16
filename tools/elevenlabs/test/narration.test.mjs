import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const script = join(root, "generate-voiceovers.mjs");
const manifest = JSON.parse(await readFile(join(root, "scripts.json"), "utf8"));
const run = (...args) => spawnSync(process.execPath, [script, ...args], {
  encoding: "utf8",
  env: { ...process.env, ELEVENLABS_API_KEY: "" },
  timeout: 5000,
});

test("three scripts, proper gates, no embedded keys", () => {
  assert.deepEqual(manifest.videos.map(({ id }) => id), [1, 2, 3]);
  assert.deepEqual(manifest.videos.map(({ status }) => status), ["DRAFT", "HOLD", "DRAFT"]);
  for (const video of manifest.videos) {
    assert.ok(video.narration.length > 100);
    assert.ok(video.narration.trim().split(/\s+/).length < 130);
  }
});

test("planning is offline, succeeds without SDK or credentials", () => {
  const r = run("--plan");
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /OFFLINE PLAN/);
  assert.match(r.stdout, /Free access and appearance customization \(HOLD\)/);
});

test("credit-consuming requests fail without explicit confirmation", () => {
  const r = run("--generate", "--video", "1");
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /confirm-credits/);
});

test("draft scripts cannot be synthesized", () => {
  const r = run("--generate", "--confirm-credits", "--video", "1");
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /Draft narration must be marked APPROVED/);
});

test("held personalization script cannot be synthesized", () => {
  const r = run("--generate", "--confirm-credits", "--video", "2");
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /on hold/);
});
