# ElevenLabs TV2 narration — developer-only tool

This tool **only prepares audio MP3 narration** for the TV2 tutorial videos. It does not produce MP4s, captions, a Flutter player, or a shareable demo APK. See [the approved project planning brief](../../docs/TV2_DEMO_VIDEOS_ELEVENLABS_2026-11-14.md).

The founder used the official ElevenLabs CLI on the Windows PC and authorized an API key in the **local** `$HOME/Sundara-TV2/.env.local`. That private file is **not in GitHub**, and a GitHub connection cannot see it. Do **not** copy, upload, display, commit or paste it into chat.

## Safety

- The default `--plan` option does not access ElevenLabs or use credits.
- API speech generation requires **all** of: a script explicitly marked `APPROVED`, `--generate`, `--video N`, `--confirm-credits`, and the key loaded as an environment variable.
- Video 2 stays `HOLD` until the free-account/personalization feature passes actual TV2 acceptance. Never portray unimplemented app functions as working.
- Do not embed the ElevenLabs key, this generator or its SDK into the TV2 APK, PWA, or client source.
- Use the official pre-made Sarah voice as the default, subject to availability and usage rights. Account credit balance and model access require confirmation before generating.
- `@elevenlabs/elevenlabs-js` is pinned in `package.json`. Generate and review the npm lockfile before merging. No installation, audio generation, or live API test has been performed as part of this documentation/branch change.

## Local Windows setup (after obtaining this branch's files)

Run `npm.cmd install` from this tool directory, not from `C:\Windows\System32`. On the founder's PC the key remains outside the repository.

From PowerShell in `$HOME/Sundara-TV2`, a no-cost offline plan can be run as follows:

```powershell
node ".\TV2-Development\tools\elevenlabs\generate-voiceovers.mjs" --plan
```

**Do not make audio until the founder approves a paid/credit-consuming test.** For a reviewed and explicitly approved script, later:

```powershell
node --env-file=.env.local ".\TV2-Development\tools\elevenlabs\generate-voiceovers.mjs" --video 1 --generate --confirm-credits
```

MP3 output is saved locally under `tv2-voiceover-output` (outside the repository when run from the private folder). Package with actual TV2 screenshots/recordings and accurately synchronized captions in the approved video editor. Review every MP4 and playback implementation separately.

The official CLI asks for `npx.cmd -y @elevenlabs/cli@latest onboard check --answered --env-path .env.local` after code integration. Run this on the founder's local PC when the local project contains the files; the GitHub connector has no authority to run that Windows command. Do not include its secret data in screenshots.
