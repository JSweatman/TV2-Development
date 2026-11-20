"""Actual Flutter web preview against disposable GoTrue and Storage."""
import asyncio
import json
import secrets
import subprocess
import threading
import time
import httpx
import uvicorn
from playwright.sync_api import sync_playwright
from .app import connect
from .providers import SupabaseAuth, SupabasePrivateStore
from .flutter_gateway import create_gateway
from .proof import AUTH, STORAGE, SERVICE, BASE

def run_flutter_proof(secret,output,web):
    output.mkdir(parents=True)
    client=httpx.Client(trust_env=False,timeout=10)
    accounts=[]
    for role in ('owner','viewer'):
        email=role+'-'+secrets.token_hex(4)+'@example.invalid';password=secrets.token_urlsafe(32)
        r=client.post(AUTH+'/signup',json={'email':email,'password':password});r.raise_for_status()
        accounts.append((email,password,r.json()['user']['id']))
    db=output/'private-metadata.sqlite'
    app=create_gateway(auth=SupabaseAuth(AUTH),store=SupabasePrivateStore(STORAGE,secret),database=db,web_dir=web)
    with connect(db) as con:
        con.execute('INSERT INTO listings VALUES (?,?)',('1*73141',accounts[0][2]))
        con.execute('INSERT INTO viewers VALUES (?,?)',('1*73141',accounts[1][2]))
    app.state.delay_upload=False
    @app.middleware('http')
    async def controlled_delay(request,call_next):
        if request.url.path.endswith('/uploads') and app.state.delay_upload:await asyncio.sleep(1)
        return await call_next(request)
    clip=output/'synthetic.mp4'
    subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','color=c=navy:s=720x1280:d=3','-vf',
        "drawbox=x=0:y=0:w=iw:h=180:color=green:t=fill,"
        "drawtext=text='TOP - UPRIGHT':fontcolor=white:fontsize=56:x=(w-tw)/2:y=60,"
        "drawtext=text='PORTRAIT':fontcolor=white:fontsize=64:x=(w-tw)/2:y=(h-th)/2,"
        "drawbox=x=0:y=1100:w=iw:h=180:color=red:t=fill,"
        "drawtext=text='BOTTOM':fontcolor=white:fontsize=56:x=(w-tw)/2:y=1160",'-c:v','libx264','-pix_fmt','yuv420p',str(clip)],check=True)
    server=uvicorn.Server(uvicorn.Config(app,host='127.0.0.1',port=54327,log_level='critical',access_log=False))
    thread=threading.Thread(target=server.run,daemon=True);thread.start()
    for _ in range(100):
        if server.started:break
        time.sleep(.05)
    result={}
    try:
      with sync_playwright() as p:
        browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
        owner=browser.new_context(viewport={'width':320,'height':640});viewer=browser.new_context(viewport={'width':320,'height':640})
        def login(context,account):
            page=context.new_page();page.goto(SERVICE)
            page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
            account_input=page.get_by_role('textbox',name='Test account',exact=True)
            account_input.click();account_input.press_sequentially(account[0],delay=15)
            account_input.press('Tab')
            password_input=page.get_by_role('textbox',name='Test password',exact=True)
            password_input.click();password_input.press_sequentially(account[1],delay=15)
            assert password_input.input_value()==account[1]
            password_input.press('Tab')
            try:
                with page.expect_response(lambda r:r.url.endswith('/preview/session')) as signed:
                    page.get_by_role('button',name='Sign in to local preview',exact=True).click()
                assert signed.value.status == 200, 'Local sign-in failed'
            except Exception:
                page.screenshot(path=str(output/'signin-diagnostic.png'))
                print('Sign-in UI:',page.locator('body').inner_text()[:1000])
                print('Field lengths:',len(page.get_by_role('textbox',name='Test account',exact=True).input_value()),len(page.get_by_role('textbox',name='Test password',exact=True).input_value()))
                raise
            return page
        page=login(owner,accounts[0]);page.get_by_role('button',name='Choose synthetic MP4').wait_for()
        assert page.evaluate('localStorage.length')==0
        assert all(c['httpOnly'] for c in owner.cookies())
        # Genuine unsupported codec in a valid MP4, under the same signed-in session.
        unsupported=output/'unsupported.mp4'
        subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i',
            'color=c=blue:s=160x90:d=1','-c:v','mpeg4',str(unsupported)],check=True)
        with page.expect_file_chooser() as rejected:page.get_by_role('button',name='Choose synthetic MP4').click()
        rejected.value.set_files(str(unsupported))
        with page.expect_response(lambda r:r.url.endswith('/uploads')) as invalid:
            page.get_by_role('button',name='Upload private draft',exact=True).click()
        assert invalid.value.status==422
        page.get_by_text('This clip could not be validated.',exact=False).first.wait_for()
        assert page.get_by_role('button',name='Sign in to local preview',exact=True).count()==0
        with connect(db) as con:assert con.execute('SELECT count(*) FROM publications').fetchone()[0]==0
        page.screenshot(path=str(output/'invalid-clip-guidance.png'))
        result['signed_in_invalid_clip_status']=422
        with page.expect_file_chooser() as chosen:page.get_by_role('button',name='Choose synthetic MP4').click()
        chosen.value.set_files(str(clip))
        page.get_by_text('Synthetic MP4 selected. Server validates content before publication.',exact=True).first.wait_for()
        app.state.delay_upload=True
        page.get_by_role('button',name='Upload private draft',exact=True).click()
        page.get_by_role('button',name='Cancel action',exact=True).click()
        page.get_by_text('Cancelled. Nothing was published; a private draft may need cleanup.',exact=True).first.wait_for()
        with connect(db) as con:assert con.execute('SELECT count(*) FROM publications').fetchone()[0]==0
        result['cancel_never_published']=True;app.state.delay_upload=False
        page.get_by_role('button',name='Upload private draft',exact=True).click()
        page.get_by_text('Private draft ready. Publish is a separate action.',exact=True).first.wait_for()
        page.get_by_role('button',name='Publish listing video',exact=True).click()
        page.get_by_text('Published for allowed viewers.',exact=True).first.wait_for()
        page.screenshot(path=str(output/'flutter-owner.png'))
        vp=login(viewer,accounts[1])
        vp.screenshot(path=str(output/'viewer-after-signin.png'))
        try:
            vp.get_by_text('Local allowed-viewer preview',exact=True).first.wait_for(timeout=10000)
        except Exception:
            vp.screenshot(path=str(output/'viewer-failure.png'))
            print('Viewer visible UI:',vp.locator('body').inner_text()[:1000])
            raise
        vp.screenshot(path=str(output/'viewer-before-load.png'))
        vp.wait_for_function('document.body.innerText.includes("Copper Observatory")')
        assert vp.get_by_role('button',name='Upload private draft').count()==0
        assert vp.locator('video').count()==0
        vp.get_by_role('button',name='Load private video',exact=True).click()
        vp.get_by_role('button',name='Play private video',exact=True).first.wait_for()
        assert vp.locator('video').evaluate('(v)=>v.paused')
        # Scroll the listing normally so the full tall frame fits the viewport.
        vp.mouse.move(160, 500)
        vp.mouse.wheel(0, 300)
        vp.wait_for_timeout(300)
        vp.get_by_role('button',name='Play private video',exact=True).click()
        vp.wait_for_function('document.querySelector("video").currentTime > 0.2')
        vp.locator('video').screenshot(path=str(output/'portrait-playing.png'))
        dimensions=vp.locator('video').evaluate('(v)=>({width:v.videoWidth,height:v.videoHeight,time:v.currentTime,paused:v.paused})')
        assert dimensions['width']==720 and dimensions['height']==1280
        assert dimensions['time']>0.2
        result['portrait_playback']=dimensions
        result['rotation_metadata_exercised']=False
        vp.screenshot(path=str(output/'flutter-viewer.png'))
        result['replacement_without_sign_in']=True
        result['actual_flutter_playback']=True
        result['no_autoplay']=True
        r=viewer.request.put(SERVICE+BASE+'/uploads',headers={'Origin':SERVICE,'Content-Type':'video/mp4'},data=clip.read_bytes());assert r.status==403;result['viewer_upload_denied']=r.status
        # Invalidate the server-side owner session without exposing a token to the UI.
        sid=owner.cookies()[0]['value'];app.state.preview_sessions[sid]='invalid'
        page.get_by_role('button',name='Upload private draft',exact=True).click()
        page.get_by_text('Session unavailable. Sign out and sign in again.',exact=True).first.wait_for()
        result['invalid_session_ui_denied']=True
        result.update({'browser':browser.version,'viewport':[320,640],'real_gotrue':True,'real_private_storage':True,'browser_token_storage':False,'request_interception':False,'physical_devices':0})
        owner.close();viewer.close();browser.close()
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
    finally:
        server.should_exit=True;thread.join(5);client.close()
