"""Normal release UI; bounded scroll based only on observed accessibility bounds."""
import hashlib,json,re,struct,subprocess,time,xml.etree.ElementTree as E
from pathlib import Path
from urllib.parse import urlsplit,parse_qs
PKG='com.sundara.qa.release.tv2'
def adb(*args):return subprocess.check_output(['adb',*args],text=True,timeout=25)
def bounds(node):return tuple(map(int,re.findall(r'\d+',node.get('bounds',''))))
def nodes():
 adb('shell','uiautomator','dump','/sdcard/qa-ui.xml')
 root=E.fromstring(adb('shell','cat','/sdcard/qa-ui.xml'))
 return [(x.get('text','') or x.get('content-desc',''),x) for x in root.iter('node')]
def capture(stage,rows=None):
 rows=nodes() if rows is None else rows
 png=subprocess.check_output(['adb','exec-out','screencap','-p'],timeout=25)
 assert png[:8]==b'\x89PNG\r\n\x1a\n';w,h=struct.unpack('>II',png[16:24]);Path('qa-'+stage+'.png').write_bytes(png)
 print('SCREEN_STATE '+json.dumps({'stage':stage,'pixels':[w,h],'png_sha256':hashlib.sha256(png).hexdigest(),'visible':[{'label':t,'bounds':x.get('bounds'),'scrollable':x.get('scrollable')} for t,x in rows if t or x.get('scrollable')=='true']}),flush=True)
 return rows,w,h
def find(label,contains=False):
 for _ in range(12):
  rows=nodes();found=[x for text,x in rows if (label in text if contains else text==label)]
  if found:return found[0]
  time.sleep(1)
 capture('missing-'+label.replace(' ','-'),rows)
 raise AssertionError('UI missing '+label)
def reveal(label):
 for attempt in range(4):
  rows,w,h=capture('reveal-'+label+'-'+str(attempt))
  found=[x for text,x in rows if text==label and len(bounds(x))==4 and bounds(x)[2]>bounds(x)[0] and bounds(x)[3]>bounds(x)[1]]
  if found:return found[0]
  if attempt==3:break
  # Choose the largest observed scrollable region (not the small match list).
  regions=[x for _,x in rows if x.get('scrollable')=='true' and len(bounds(x))==4]
  assert regions,'No observed scrollable container; refusing guessed gesture'
  x=max(regions,key=lambda n:(bounds(n)[2]-bounds(n)[0])*(bounds(n)[3]-bounds(n)[1]))
  a,b,c,d=bounds(x);assert 0<=a<c<=w and 0<=b<d<=h
  sx=(a+c)//2;sy=b+int((d-b)*.8);ey=b+int((d-b)*.2)
  print('BOUNDED_SCROLL '+json.dumps({'container':x.get('bounds'),'from':[sx,sy],'to':[sx,ey]}),flush=True)
  adb('shell','input','swipe',str(sx),str(sy),str(sx),str(ey),'450');time.sleep(.7)
 raise AssertionError('UI not reachable after three observed-container scrolls: '+label)
def tap_node(x,label):
 a,b,c,d=bounds(x);assert c>a and d>b
 adb('shell','input','tap',str((a+c)//2),str((b+d)//2));print('UI_TAP '+label,flush=True);time.sleep(.6)
def tap(label,contains=False):tap_node(find(label,contains),label)
def exact_requests():
 text=Path('resolver.log').read_text()
 return [parse_qs(urlsplit(path).query) for path in re.findall(r'GET (/v1/resolve\?[^ ]+)',text)]
print('DISPLAY '+adb('shell','wm','size').strip()+'; '+adb('shell','wm','density').strip(),flush=True)
adb('shell','am','start','-n',PKG+'/.MainActivity');find('Japan',True);capture('country');tap('Japan',True)
for d in '529':tap(d)
find('Sample Release QA',True);capture('preview');target=reveal('ENTER');before=len(exact_requests());assert before>=1
print('EXACT_REQUESTS_BEFORE_ENTER='+str(before),flush=True);tap_node(target,'ENTER');find('Save listing');find('Back');rows=nodes();assert not any(t=='ENTER' for t,x in rows)
assert any('Sample Release QA' in t for t,x in rows)
after=exact_requests();assert len(after)==before+1;assert after[-1].get('input')==['529'] and after[-1].get('country')==['81']
print('ENTER_FRESH_EXACT_CONFIRMED '+json.dumps(after[-1]),flush=True);capture('listing',rows);print('LISTING_ONLY_STATE_CONFIRMED',flush=True)
tap('Back');reveal('ENTER');assert any('529' in t for t,x in nodes());print('KEYPAD_RETURN_WITH_529_CONFIRMED',flush=True)
print('TV2_RELEASE_QA_UI_PASS',flush=True)
