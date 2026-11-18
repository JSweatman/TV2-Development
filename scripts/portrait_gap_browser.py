"""Actual local Flutter app, empty results, unchanged browser zoom. No live data."""
import functools,http.server,json,re,threading,sys
from pathlib import Path
from playwright.sync_api import sync_playwright
web,out=map(Path,sys.argv[1:3]);out.mkdir(parents=True,exist_ok=True)
class Quiet(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*a):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',54330),functools.partial(Quiet,directory=str(web)))
threading.Thread(target=server.serve_forever,daemon=True).start();results=[]
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
  for width,height in [(320,568),(360,640),(360,740),(390,844),(430,932),(320,480),(844,390),(1280,800)]:
   context=browser.new_context(viewport={'width':width,'height':height},device_scale_factor=1,is_mobile=width<1000,has_touch=width<1000)
   page=context.new_page();page.goto('http://127.0.0.1:54330/')
   page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
   page.get_by_role('button',name='+1 Shared calling-code namespace',exact=True).click()
   page.wait_for_timeout(250)
   video=page.get_by_text(re.compile('Video preview placeholder')).last.bounding_box()
   first=page.get_by_role('button',name='1',exact=True).bounding_box()
   enter=page.get_by_role('button',name='ENTER',exact=True).bounding_box()
   gap=first['y']-video['y']-video['height'] if first and video else None
   visible=bool(enter and enter['height']>=47.9 and enter['y']+enter['height']<=height)
   page.screenshot(path=str(out/f'{width}x{height}.png'))
   # Short screens retain normal vertical scroll as fallback.
   for _ in range(20):
    box=page.get_by_role('button',name='ENTER',exact=True).bounding_box()
    if box and box['height']>=47.9 and box['y']>=0 and box['y']+box['height']<=height:break
    page.mouse.move(width/2,height*.85);page.mouse.wheel(0,160);page.wait_for_timeout(120)
   else:raise AssertionError('ENTER not reachable')
   assert page.evaluate('visualViewport.scale')==1
   results.append({'viewport':[width,height],'gap_css':gap,'first_key':first,'enter_initial':enter,
                   'bottom_row_visible_initially':visible,'enter_reachable':True,'scale':1})
   # One complete synthetic result, selection and ENTER retain navigation.
   page.mouse.move(width/2,height*.5);page.mouse.wheel(0,-3000);page.wait_for_timeout(200)
   for _ in range(20):
    box=page.get_by_role('button',name='7',exact=True).bounding_box()
    if box and box['height']>=48 and box['y']>=0 and box['y']+box['height']<=height:break
    page.mouse.move(width/2,height*.85);page.mouse.wheel(0,100);page.wait_for_timeout(120)
   page.get_by_role('button',name='7',exact=True).click()
   page.mouse.wheel(0,-3000);page.wait_for_timeout(200)
   suggestion=page.get_by_text(re.compile('Synthetic viewport listing')).last
   suggestion.wait_for();page.wait_for_timeout(400)
   page.screenshot(path=str(out/f'{width}x{height}-single.png'))
   suggestion.click();page.wait_for_timeout(500)
   for _ in range(20):
    box=page.get_by_role('button',name='ENTER',exact=True).bounding_box()
    if box and box['height']>=47.9 and box['y']>=0 and box['y']+box['height']<=height:break
    page.mouse.move(width/2,height*.85);page.mouse.wheel(0,160);page.wait_for_timeout(120)
   page.get_by_role('button',name='ENTER',exact=True).click()
   page.get_by_role('button',name='Save listing',exact=True).wait_for()
   page.get_by_role('button',name='Back',exact=True).click()
   page.get_by_text('1*70001',exact=True).first.wait_for()
   results[-1]['single_selection_enter_return']=True
   context.close()
  browser.close()
finally:server.shutdown()
(out/'result.json').write_text(json.dumps(results,indent=2));print(json.dumps(results))
