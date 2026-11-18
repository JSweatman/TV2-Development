"""Optional rotation checks for the existing local synthetic TLS browser proof."""
def verify_landscape(page, output):
    page.locator('video').evaluate('(v)=>{window.tv2ObservedVideo=v;v.playbackRate=0.0625}')
    before=page.locator('video').evaluate('(v)=>v.currentTime')
    page.set_viewport_size({'width':844,'height':390})
    page.get_by_role('button',name='Exit expanded video',exact=True).wait_for()
    page.wait_for_timeout(250)
    result=page.locator('video').evaluate('''v=>({same:v===window.tv2ObservedVideo,time:v.currentTime,
        paused:v.paused,width:v.getBoundingClientRect().width,height:v.getBoundingClientRect().height,
        sourceWidth:v.videoWidth,sourceHeight:v.videoHeight})''')
    assert result['same'] and not result['paused'] and result['time']>=before
    assert abs(result['width']/result['height']-result['sourceWidth']/result['sourceHeight'])<.02
    assert page.evaluate('document.fullscreenElement===null')
    page.screenshot(path=str(output/'landscape-expanded.png'))
    page.get_by_role('button',name='Pause listing video',exact=True).click()
    paused=page.locator('video').evaluate('(v)=>v.currentTime')
    page.get_by_role('button',name='Exit expanded video',exact=True).click()
    page.wait_for_timeout(150)
    assert page.get_by_role('button',name='Exit expanded video',exact=True).count()==0
    page.set_viewport_size({'width':390,'height':844});page.wait_for_timeout(150)
    page.set_viewport_size({'width':844,'height':390});page.wait_for_timeout(150)
    assert page.get_by_role('button',name='Exit expanded video',exact=True).count()==0
    assert page.locator('video').evaluate('(v)=>v.paused && v===window.tv2ObservedVideo')
    assert abs(page.locator('video').evaluate('(v)=>v.currentTime')-paused)<.05
    page.set_viewport_size({'width':390,'height':844});page.wait_for_timeout(250)
    page.get_by_role('button',name='Play listing video',exact=True).click()
    page.set_viewport_size({'width':844,'height':390})
    page.get_by_role('button',name='Exit expanded video',exact=True).wait_for()
    page.set_viewport_size({'width':390,'height':844});page.wait_for_timeout(250)
    assert page.get_by_role('button',name='Exit expanded video',exact=True).count()==0
    assert page.locator('video').evaluate('(v)=>!v.paused && v===window.tv2ObservedVideo')
    page.screenshot(path=str(output/'portrait-return.png'))
    page.locator('video').evaluate('(v)=>v.playbackRate=1')
    return {'landscape':result,'paused_rotation_stays_inline':True,'portrait_return_same_element':True,
            'explicit_exit':True,'browser_fullscreen_not_requested':True}
