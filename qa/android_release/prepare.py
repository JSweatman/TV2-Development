"""Generated QA runner only. Never modifies tracked product source."""
from pathlib import Path
import xml.etree.ElementTree as E
p=Path('android/app/src/main/AndroidManifest.xml');s=p.read_text();ns='{http://schemas.android.com/apk/res/android}'
r=E.fromstring(s);present=any(x.get(ns+'name')=='android.permission.INTERNET' for x in r.findall('uses-permission'))
print('GENERATED_MAIN_INTERNET_PRESENT='+str(present),flush=True)
if not present:s=s.replace('>','>\n    <uses-permission android:name="android.permission.INTERNET"/>',1)
s=s.replace('android:label="tv2"','android:label="TV2 Release QA ONLY" android:usesCleartextTraffic="false" android:networkSecurityConfig="@xml/qa_loopback"')
p.write_text(s)
x=Path('android/app/src/main/res/xml/qa_loopback.xml');x.parent.mkdir(parents=True,exist_ok=True)
x.write_text('''<network-security-config><base-config cleartextTrafficPermitted="false"/><domain-config cleartextTrafficPermitted="true"><domain includeSubdomains="false">127.0.0.1</domain></domain-config></network-security-config>''')
p=Path('android/app/build.gradle.kts');s=p.read_text();assert 'applicationId = "com.sundara.qa.release.tv2"' in s
assert 'signingConfig = signingConfigs.getByName("debug")' in s
s=s.replace('android {','''android {
    signingConfigs.getByName("debug") {
        storeFile = file(System.getenv("TV2_QA_KEYSTORE"))
        storePassword = System.getenv("TV2_QA_PASSWORD")
        keyAlias = "qaonly"
        keyPassword = System.getenv("TV2_QA_PASSWORD")
    }
''',1).replace('release {','release {\n            isDebuggable = false',1)
p.write_text(s)
print('QA_ONLY_LOOPBACK_EXCEPTION=127.0.0.1; default cleartext=false')
