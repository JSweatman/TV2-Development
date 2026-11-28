from pathlib import Path
root=Path('../qa/android_contacts')
p=Path('pubspec.yaml');p.write_text(p.read_text().replace('dev_dependencies:', 'dev_dependencies:\n  integration_test:\n    sdk: flutter'))
p=Path('android/app/build.gradle.kts');p.write_text(p.read_text().replace('defaultConfig {','defaultConfig {\n        testInstrumentationRunner = "com.sundara.preview.tv2.ContactInstrumentation"',1))
for path,src in [('android/app/src/main/kotlin/com/sundara/preview/tv2/MainActivity.kt','MainActivity.kt'),('android/app/src/androidTest/kotlin/com/sundara/preview/tv2/ContactInstrumentation.kt','ContactInstrumentation.kt'),('integration_test/contact_test.dart','contact_test.dart')]:
 p=Path(path);p.parent.mkdir(parents=True,exist_ok=True);p.write_text((root/src).read_text())
p=Path('android/app/src/main/AndroidManifest.xml');p.write_text(p.read_text().replace('android:label="tv2"','android:label="TV2 Contacts TEST ONLY"'))
# Debug-only emulator network allowance, not a released policy change.
p=Path('android/app/src/debug/AndroidManifest.xml');s=p.read_text();s=s.replace('</manifest>','<application android:usesCleartextTraffic="true" /></manifest>');p.write_text(s)
