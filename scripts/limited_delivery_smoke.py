"""Read-only delivery check. Never log response content or read media bodies."""
import json
import os
import time
from datetime import datetime, timezone
from urllib.error import HTTPError
from urllib.parse import urlsplit, parse_qs
from urllib.request import Request, build_opener, HTTPRedirectHandler

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs): return None

def main():
    origin=os.environ['DELIVERY_ORIGIN'].rstrip('/')
    resolver=os.environ['DELIVERY_RESOLVER']
    opening=datetime.fromisoformat(os.environ['DELIVERY_OPENS_AT'].replace('Z','+00:00'))
    closing=datetime.fromisoformat(os.environ['DELIVERY_CLOSES_AT'].replace('Z','+00:00'))
    expected_range=os.environ['DELIVERY_CONTENT_RANGE']
    for url in (origin,resolver):
        u=urlsplit(url)
        assert u.scheme=='https' and u.hostname and not u.username and not u.password and u.port in (None,443),'invalid configuration'
    assert opening.tzinfo and closing.tzinfo and opening<closing,'invalid clock configuration'
    now=lambda:datetime.now(timezone.utc)
    assert (opening-now()).total_seconds()<480 and now()<closing,'outside allowed test window'
    opener=build_opener(NoRedirect())
    def fetch(url,range_header=None,json_body=False):
        headers={'User-Agent':'TV2-Limited-Delivery-Smoke/1.0'}
        if range_header: headers['Range']=range_header
        try: response=opener.open(Request(url,headers=headers),timeout=25)
        except HTTPError as error: response=error
        with response:
            status=response.status
            head=response.headers
            # The ONLY body read is bounded resolver JSON, parsed privately.
            data=response.read(65537) if json_body and status==200 else None
        return status,head,data
    if now()<opening:
        status,_,_=fetch(origin+'/')
        print(f'OBSERVED pre-opening page status={status}; no broader cutoff claim',flush=True)
    while now()<=opening:
        time.sleep(min(5,max(.05,(opening-now()).total_seconds())))
    assert now()<closing,'window closed before checks'
    status,headers,_=fetch(origin+'/')
    assert status==200,f'page status mismatch: {status}'
    assert 'text/html' in headers.get('Content-Type','').lower(),'page type mismatch'
    assert 'no-store' in headers.get('Cache-Control','').lower(),'page cache mismatch'
    print('PASS opened page: 200 HTML no-store',flush=True)
    status,headers,_=fetch(origin+'/clip.mp4','bytes=0-15')
    assert status==206,f'media status mismatch: {status}'
    assert headers.get('Content-Range')==expected_range,'media range/length mismatch'
    assert 'video/mp4' in headers.get('Content-Type','').lower(),'media type mismatch'
    assert 'no-store' in headers.get('Cache-Control','').lower(),'media cache mismatch'
    print('PASS opened media: 206 exact expected Content-Range no-store; body unread',flush=True)
    status,_,raw=fetch(resolver,json_body=True)
    assert status==200,f'resolver status mismatch: {status}'
    assert raw is not None and len(raw)<=65536,'resolver response size mismatch'
    payload=json.loads(raw)
    assert isinstance(payload,dict) and payload.get('status')=='resolved','resolver shape/status mismatch'
    listing=payload.get('listing')
    requested=parse_qs(urlsplit(resolver).query)['input'][0].split('*')
    assert isinstance(listing,dict) and listing.get('country_code')==requested[0] and listing.get('list_number')==requested[1] and listing.get('tldx') is None,'resolver identity mismatch'
    resources=listing.get('resources')
    assert isinstance(resources,list),'resolver resource shape mismatch'
    approved=urlsplit(origin)
    def matches(row):
        if not isinstance(row,dict) or not isinstance(row.get('uri'),str):return False
        u=urlsplit(row['uri'])
        return u.scheme=='https' and u.netloc==approved.netloc and not u.username and not u.password
    assert any(matches(r) for r in resources),'resolver approved-origin mismatch'
    print('PASS exact resolver identity and approved-origin resource; JSON not logged',flush=True)
    print('DELIVERY CHECK PASSED; HTTP only, no browser/device or closing-window claim',flush=True)

if __name__=='__main__':
    try: main()
    except AssertionError as exc: raise SystemExit('FAIL '+str(exc))
    except Exception: raise SystemExit('FAIL network/parse/configuration error; response details suppressed')
