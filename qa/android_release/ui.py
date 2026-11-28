import subprocess,time,xml.etree.ElementTree as E,re
PKG='com.sundara.qa.release.tv2'
def adb(*args):return subprocess.check_output(['adb',*args],text=True,timeout=25)
def nodes():
 adb('shell','uiautomator','dump','/sdcard/qa-ui.xml')
 root=E.fromstring(adb('shell','cat','/sdcard/qa-ui.xml'))
 return [(x.get('text','') or x.get('content-desc',''),x) for x in root.iter('node')]
def find(label,contains=False):
 for _ in range(12):
  rows=nodes()
  found=[x for text,x in rows if (label in text if contains else text==label)]
  if found:return found[0]
  time.sleep(1)
 raise AssertionError('UI missing '+label+'; visible='+repr([t for t,x in rows if t]))
def tap(label,contains=False):
 x=find(label,contains);a,b,c,d=map(int,re.findall(r'\d+',x.get('bounds')));assert c>a and d>b
 adb('shell','input','tap',str((a+c)//2),str((b+d)//2));print('UI_TAP '+label,flush=True);time.sleep(.6)
adb('shell','am','start','-n',PKG+'/.MainActivity');tap('Japan',True)
for d in '529':tap(d)
tap('ENTER');find('Save listing');rows=nodes();assert not any(t=='ENTER' for t,x in rows)
assert any('Sample Release QA' in t for t,x in rows);print('LISTING_ONLY_STATE_CONFIRMED',flush=True)
tap('Back');find('ENTER');assert any('529' in t for t,x in nodes());print('KEYPAD_RETURN_WITH_529_CONFIRMED',flush=True)
print('TV2_RELEASE_QA_UI_PASS',flush=True)
