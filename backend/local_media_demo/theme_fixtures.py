"""Synthetic local theme records only; no hosted assignment or business data."""
from dataclasses import replace
from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from .server import TLS_ORIGIN


def install_theme_fixtures(app):
    import app as resolver
    from repository import FixtureRepository, ListingRecord, ResourceRecord, ButtonRecord
    uploaded = app.dependency_overrides[resolver.get_repository]()
    rows = [ListingRecord('1','70001',None,'Night Studio · synthetic demo','test','basic'),
            ListingRecord('1','70002',None,'Garden Studio · synthetic demo','test','basic')]

    class ThemeRepository(FixtureRepository):
        def get_listing(self,country_code,base,tldx):
            row=super().get_listing(country_code,base,tldx)
            if row is None: return None
            palette,hero=('graphite','horizon') if base=='70001' else ('lotus','petals')
            source=uploaded.get_listing('1','5247',None)
            # Both synthetic records reuse the local owner's approved test asset.
            resources=list(source.resources if source else ())
            resources.append(ResourceRecord('theme','landing_theme',None,{'version':1,'palette':palette,'hero':hero}))
            resources.extend(ResourceRecord(kind,kind,None,{'handoff':'device','phone_e164':'+12025550123'}) for kind in ('call','text'))
            actions=[('CALL','call'),('TEXT','text'),('WEBSITE','website'),('DIRECTIONS','directions'),('SERVICES','services'),('ABOUT','about')]
            resources.extend(ResourceRecord(key,'web',TLS_ORIGIN+'/theme-info/'+key,{}) for _,key in actions[2:])
            buttons=tuple(ButtonRecord(i+1,label,key) for i,(label,key) in enumerate(actions))
            return replace(row,resources=tuple(resources),buttons=buttons)

    app.dependency_overrides[resolver.get_repository]=lambda:ThemeRepository(rows)
    routes=APIRouter()
    @routes.get('/theme-info/{action}',response_class=HTMLResponse)
    def info(action: str):
        # Fixed text: never echo path data into HTML.
        return '<!doctype html><title>Synthetic action</title><h1>Synthetic action destination</h1><p>Local test only. No booking, map, business or contact service.</p>'
    # Before the final static mount. No deployed application routes are modified.
    app.router.routes.insert(-1,routes.routes[0])
