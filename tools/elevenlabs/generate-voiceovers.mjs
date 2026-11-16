/**
 * Developer-only TV2 narration generator.
 * Never import this into Flutter or the public FastAPI resolver.
 * Plans run offline; speech synthesis requires deliberate two-flag opt-in.
 */
import { createWriteStream } from "node:fs";
import { mkdir, readFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";

const here = dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(await readFile(join(here, "scripts.json"), "utf8"));
const args = process.argv.slice(2);
const videoIndex = args.indexOf("--video");
const videoId = videoIndex !== -1 ? Number(args[videoIndex + 1]) : undefined;
const video = manifest.videos.find((v) => v.id === videoId);
const wantsGenerate = args.includes("--generate");

if (!wantsGenerate) {
  console.log("TV2 narration drafts — OFFLINE PLAN, no ElevenLabs requests:");
  for (const item of manifest.videos) {
    const count = item.narration.trim().split(/\s+/).length;
    console.log(`  ${item.id}: ${item.title} (${item.status}) — ${count} words`);
  }
  console.log("No audio generated. To generate one APPROVED narration later,");
  console.log("use --video 1 --generate --confirm-credits after founder approval.");
  process.exit(0);
}

if (!args.includes("--confirm-credits")) {
  throw new Error("Speech synthesis can consume ElevenLabs credits. Add --confirm-credits after approval.");
}
if (!video || !Number.isInteger(videoId)) {
  throw new Error("Select an existing numbered script using --video N.");
}
if (video.status === "HOLD") {
  throw new Error("This script is on hold until its subject feature is implemented and accepted.");
}
if (video.status !== "APPROVED") {
  throw new Error("Draft narration must be marked APPROVED in scripts.json after creative review.");
}
if (!process.env.ELEVENLABS_API_KEY) {
  throw new Error("Missing ELEVENLABS_API_KEY. Load the private local .env.local with node --env-file.");
}

const { ElevenLabsClient } = await import("@elevenlabs/elevenlabs-js");
const client = new ElevenLabsClient(); // Reads ELEVENLABS_API_KEY from environment.
const voiceId = process.env.ELEVENLABS_VOICE_ID || "EXAVITQu4vr4xnSDxMaL"; // Official premade Sarah voice.
const modelId = process.env.ELEVENLABS_MODEL_ID || "eleven_multilingual_v2";
const targetDir = resolve(process.env.TV2_VOICEOVER_DIR || join(process.cwd(), "tv2-voiceover-output"));
await mkdir(targetDir, { recursive: true });
const dest = join(targetDir, `tv2-video-${videoId}-narration.mp3`);
const audio = await client.textToSpeech.convert(voiceId, {
  text: video.narration,
  modelId,
  outputFormat: "mp3_44100_128",
});
await pipeline(Readable.fromWeb(audio), createWriteStream(dest));
console.log(`Narration saved: ${dest}`);
console.log("Review narration, timing, rights and captions before inclusion in a TV2 demo.");
