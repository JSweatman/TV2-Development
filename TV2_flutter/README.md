# List Number TV2 Flutter Client

TV2's mobile client consumes the public resolver API hosted on Render.

## Country / NID behavior

TV2 intentionally has **no hard-coded default country code**. On first launch the
client requests `/v1/countries` from the resolver and requires the user to choose
a country/namespace. The selected NID is stored locally and reused until the user
changes it.

An explicitly entered namespace such as `91*529` or a Global Code such as `*529`
continues to override the selected local context according to the resolver grammar.

## Development API

The default API base is `https://tv2-development.onrender.com`.

It can be overridden at build time with:

`--dart-define=TV2_API_BASE_URL=https://example.test`

## Scope

The client is a TV2 test bed. Landing-page presentation, WebRTC provider
integration, CDD, permissions, and enrollment flows are separate layers and are
not fabricated in this checkpoint.

## iOS Simulator preview (new development track)

The iOS app uses the **same Flutter `lib/` source and resolver API** as Android. There is no separate iOS business-logic fork.

GitHub Actions workflow: [ios-simulator-preview-build](../.github/workflows/ios-simulator-preview-build.yml). On a macOS runner with Flutter and Xcode it:
1. Runs `bash ../scripts/prepare_ios_simulator_preview.sh` from this directory to generate a preview-only native iOS runner.
2. Runs `flutter pub get` and `flutter test`.
3. Compiles an iOS Simulator debug app with `flutter build ios --simulator --debug`.
4. Requires bundle identifier `com.sundara.preview.tv2` and display name `TV2 Preview`.
5. Stores an unsigned simulator archive and provenance under the **tv2-ios-simulator-preview** Actions artifact. It also archives the generated native runner for source review.

**Limitations:** The simulator archive is not an `.ipa`, is not signed for a physical iPhone, and cannot be sent to TestFlight. This preview generator is only the first build-validation step. A stable, reviewed `ios/` source tree, Apple Team/account, protected signing credentials, signed builds, actual iPhone testing, and release review are still required.

See [iOS development and acceptance plan](../docs/IOS_DEVELOPMENT_ACCEPTANCE_2026-11-07.md). The original installed Android TV2 app must never be uninstalled or overwritten to test iOS or Android previews.
