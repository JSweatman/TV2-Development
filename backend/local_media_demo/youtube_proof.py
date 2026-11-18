"""Local Flutter build + official documented YouTube sample. No interception."""
import functools,http.server,json,re,sys,threading
from pathlib import Path
from playwright.sync_api import sync_playwright,TimeoutError

def main():
    web,output=map(Path,sys.argv[1:3]);output.mkdir(parents=True,exist_ok=True)
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self,*args):pass
    server=http.server.ThreadingHTTPServer(('127.0.0.1',54326),functools.partial(Quiet,directory=str(web)))
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    try:
      with sync_playwright() as p:
        browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
        page=browser.new_page(viewport={'width':390,'height':844})
        requests=[];failures=[]
        page.on('request',lambda r:requests.append(r.url))
        page.on('requestfailed',lambda r:failures.append({'url':r.url,'failure':r.failure}))
        page.goto('http://127.0.0.1:54326/')
        page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
        page.get_by_role('button',name='Load YouTube video',exact=True).wait_for()
        assert not any('youtube' in u or 'googlevideo' in u or 'ytimg' in u for u in requests)
        assert page.locator('iframe').count()==0
        page.screenshot(path=str(output/'before-opt-in.png'))
        page.get_by_role('button',name='Load YouTube video',exact=True).click()
        frame=page.locator('iframe');frame.wait_for()
        src=frame.get_attribute('src');assert src=='https://www.youtube-nocookie.com/embed/M7lc1UVf-VE?autoplay=0&playsinline=1'
        box=frame.bounding_box();assert box['width']>=200 and box['height']>=200
        assert frame.get_attribute('referrerpolicy')=='strict-origin-when-cross-origin'
        assert "camera 'none'" in frame.get_attribute('allow') and "microphone 'none'" in frame.get_attribute('allow')
        page.wait_for_timeout(4000)
        result={'browser':browser.version,'viewport':[390,844],'no_provider_request_before_opt_in':True,'canonical_src':src,'frame_size':[box['width'],box['height']],'actual_playback':False,'interception':False,'certificate_bypass':False}
        blocked=[f for f in failures if 'youtube' in f['url']]
        if blocked:result['provider_failures']=blocked
        else:
            provider=next((f for f in page.frames if 'youtube-nocookie.com' in f.url),None)
            if provider:
                result['provider_visible_text']=provider.locator('body').inner_text(timeout=5000)[:600]
                play=provider.get_by_role('button',name=re.compile(r'^Play',re.I))
                if play.count():
                    play.first.click()
                    try:
                        provider.wait_for_function('document.querySelector("video")?.currentTime > 0.2',timeout=10000)
                        result['actual_playback']=True
                    except TimeoutError:result['playback_gate']='Provider did not begin playback within ten seconds after Play.'
        page.screenshot(path=str(output/'after-opt-in.png'))
        page.get_by_role('button',name='Dismiss YouTube video',exact=True).click()
        page.wait_for_function('document.querySelectorAll("iframe").length === 0')
        assert page.get_by_role('button',name='Open on YouTube',exact=True).count()==1
        result['dismiss_removed_iframe']=True;result['fallback_visible']=True
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
        browser.close()
    finally:server.shutdown();server.server_close()
if __name__=='__main__':main()
