#!/usr/bin/env bash
# Run from TV2_flutter/ on macOS with Flutter and Xcode installed.
set -euo pipefail

if [[ ! -f pubspec.yaml || ! -f lib/main.dart ]]; then
  echo "::error::Run this script from TV2_flutter."
  exit 1
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "::error::Flutter is not installed."
  exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "::error::Xcode is required for the iOS test build."
  exit 1
fi

# Preview-only identity. Do not infer the production App Store bundle ID.
# Flutter may create its stock MyApp widget test when adding a platform to an
# existing source-only project. Preserve any pre-existing test, but remove the
# newly generated incompatible template test before running our real suite.
had_widget_test=false
[[ -e test/widget_test.dart ]] && had_widget_test=true
flutter create --platforms=ios --project-name tv2 --org com.sundara.preview .
if [[ "$had_widget_test" == false && -f test/widget_test.dart ]]; then
  if grep -Fq 'pumpWidget(const MyApp())' test/widget_test.dart; then
    rm test/widget_test.dart
    echo 'Removed Flutter-generated MyApp sample test; TV2 tests are preserved.'
  else
    echo "::error::Unexpected new widget_test.dart; review rather than delete it."
    exit 1
  fi
fi

plist="ios/Runner/Info.plist"
project="ios/Runner.xcodeproj/project.pbxproj"
[[ -f "$plist" && -f "$project" ]] || {
  echo "::error::iOS native runner was not generated."
  exit 1
}
if ! grep -Fq 'com.sundara.preview.tv2' "$project"; then
  echo "::error::Unexpected iOS bundle ID; refusing to continue."
  exit 1
fi

# This display name is deliberately different from any future production app.
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName TV2 Preview' "$plist" \
  || /usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string TV2 Preview' "$plist"

echo "Generated unsigned iOS simulator runner for TV2 Preview."
