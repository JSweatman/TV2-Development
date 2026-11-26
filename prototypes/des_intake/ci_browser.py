"""CI-only Chrome acceptance via stdlib + ChromeDriver. No hosted destinations.
Not the managed Sites preview, an installed PWA, or physical-device evidence.
"""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading
import time
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from server import make_server

ELEMENT='element-6066-11e4-a52e-4f735466cecf'

def main():
    assert os.environ.get('GITHUB_ACTIONS')=='true', 'This acceptance runner is CI-only.'
    chrome=shutil.which('google-chrome') or shutil.which('google-chrome-stable')
    driver=shutil.which('chromedriver')
    assert chrome and driver, 'Runner must provide Chrome and ChromeDriver in PATH; no downloads.'
    for binary in (chrome,driver):
        print(binary, subprocess.check_output([binary,'--version'],text=True).strip(),flush=True)
    print('source',subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
          'runner',os.environ.get('ImageOS'),os.environ.get('ImageVersion'),flush=True)
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
    base=f'http://127.0.0.1:{port}'
    def wire(method,path,data=None):
        request=Request(base+path,method=method,data=None if data is None else json.dumps(data).encode(),headers={'Content-Type':'application/json'})
        try:
            with urlopen(request,timeout=15) as response:result=json.load(response)
        except HTTPError as error:raise AssertionError(error.read().decode()) from error
        return result.get('value')
    with tempfile.TemporaryDirectory(prefix='des-browser-') as temp:
        proc=subprocess.Popen([driver,f'--port={port}','--allowed-ips=127.0.0.1'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            for _ in range(100):
                try:
                    if wire('GET','/status')['ready']:break
                except OSError:pass
                time.sleep(.1)
            else:raise AssertionError('ChromeDriver not ready')
            for width,height in ((1280,900),(390,844)):
                server=make_server(str(Path(temp)/f'{width}.sqlite'),0)
                thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
                session=None
                try:
                    capabilities=wire('POST','/session',{'capabilities':{'alwaysMatch':{'browserName':'chrome','goog:chromeOptions':{'binary':chrome,'args':['--headless=new','--disable-background-networking','--disable-component-update','--no-first-run','--no-default-browser-check',f'--user-data-dir={temp}/profile-{width}']}}}})
                    session=capabilities['sessionId'];prefix='/session/'+session
                    def call(method,path,data=None):return wire(method,prefix+path,data)
                    def script(code,*args):return call('POST','/execute/sync',{'script':code,'args':list(args)})
                    def find(id):return call('POST','/element',{'using':'css selector','value':'#'+id})[ELEMENT]
                    def click(id):return call('POST','/element/'+find(id)+'/click',{})
                    def keys(id,value):return call('POST','/element/'+find(id)+'/value',{'text':value})
                    def text(id):return call('GET','/element/'+find(id)+'/text')
                    def wait(predicate,label):
                        deadline=time.monotonic()+8
                        while time.monotonic()<deadline:
                            if predicate():return
                            time.sleep(.05)
                        raise AssertionError(label)
                    def fill(id,value):
                        click(id);keys(id,'\ue009a\ue000'+value) # real Ctrl+A, release, then typing
                    def approve():fill('pin','2468');click('approve')
                    call('POST','/window/rect',{'width':width,'height':height})
                    # ChromeDriver's supported CDP extension specifies CSS viewport, avoiding outer-window minimums.
                    call('POST','/goog/cdp/execute',{'cmd':'Emulation.setDeviceMetricsOverride','params':{'width':width,'height':height,'deviceScaleFactor':1,'mobile':False}})
                    origin=f'http://127.0.0.1:{server.server_port}'
                    call('POST','/url',{'url':origin})
                    wait(lambda:script("return !!document.getElementById('number')"),'worksheet did not initialize')
                    assert script('return window.innerWidth')==width
                    assert script('return document.documentElement.scrollWidth<=window.innerWidth'), 'horizontal overflow'
                    # Native WebDriver key events, no script focus/activation.
                    call('POST','/actions',{'actions':[{'type':'key','id':'keyboard','actions':[{'type':'keyDown','value':'\ue004'},{'type':'keyUp','value':'\ue004'}]}]})
                    assert script('return document.activeElement.id')=='number'
                    assert script('return getComputedStyle(document.activeElement).outlineStyle')!='none'
                    keys('number','\ue004');assert script('return document.activeElement.id')=='name'
                    fill('number','1*700001');keys('number','\ue004')
                    wait(lambda:'Occupied' in text('error-number'),'occupied fixture feedback missing')
                    fill('number','81*700001')
                    assert text('error-number')=='', 'stale occupied feedback after input'
                    keys('number','\ue004');wait(lambda:text('error-number')=='','cross-NID validation failed')
                    # RTA restriction through actual selects and save.
                    click('plan');keys('plan','\ue010\ue007');click('rta');keys('rta','\ue010\ue007')
                    approve();click('save')
                    wait(lambda:'10E' in text('error-rta'),'RTA guard missing')
                    click('rta');keys('rta','\ue011\ue007');click('ack')
                    click('simulate-possession');assert 'eligibility pending' in text('phone-result')
                    approve();click('save')
                    wait(lambda:'Synthetic draft saved' in text('status'),'draft was not saved')
                    assert '81*700001' in text('status')
                    wait(lambda:'phone verification required' in text('rows'),'pending state absent')
                    call('POST','/refresh',{})
                    wait(lambda:'81*700001' in text('rows'),'row lost after reload')
                    assert 'phone verification required' in text('rows')
                    # API state independently confirms no activation; browser used UI to save.
                    with urlopen(origin+'/api/rows') as response:rows=json.load(response)
                    assert len(rows)==3 and rows[-1]['state']=='phone_verification_required'
                    resources=script('return performance.getEntriesByType("resource").map(x=>x.name)')
                    assert all(url.startswith(origin+'/') for url in resources),'external page resource request'
                    print(json.dumps({'viewport':[width,height],'browser':capabilities['capabilities']['browserVersion'],'passed':['keyboard focus/traversal','duplicate','cross-NID correction','10E RTA guard','simulated possession remains pending','save/reload','no horizontal overflow','same-origin page resources']}),flush=True)
                finally:
                    if session:wire('DELETE','/session/'+session)
                    server.shutdown();server.server_close();thread.join(timeout=3)
        finally:
            proc.terminate();proc.wait(timeout=10)
if __name__=='__main__':main()
