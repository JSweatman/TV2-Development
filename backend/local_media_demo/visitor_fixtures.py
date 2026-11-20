"""Disposable visitor demo records; never mounted by production app.py."""
import asyncio
from dataclasses import replace
from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from .server import TLS_ORIGIN


def install_visitor_fixtures(app):
    import app as resolver
    from repository import FixtureRepository, ListingRecord, ResourceRecord, ButtonRecord
    @app.middleware('http')
    async def delayed_preview(request, call_next):
        # Controlled latency proves ENTER does not wait for a display-name preview.
        if request.url.path == '/v1/prefix':
            await asyncio.sleep(0.75)
        return await call_next(request)

    uploaded = app.dependency_overrides[resolver.get_repository]()
    rows = [ListingRecord('1', '700001', None, 'Northstar (sample)', 'business', 'basic'),
            ListingRecord('1', '70002', None, 'Alex (sample)', 'person', 'basic')]

    class VisitorRepository(FixtureRepository):
        def get_listing(self, country_code, base, tldx):
            row = super().get_listing(country_code, base, tldx)
            if row is None:
                return None
            business = base == '700001'
            source = uploaded.get_listing('1', '5247', None)
            resources = list(source.resources if business and source else ())
            resources += [ResourceRecord('theme', 'landing_theme', None,
                          {'version': 1, 'palette': 'graphite' if business else 'lotus',
                           'hero': 'horizon' if business else 'petals'}),
                          ResourceRecord('website', 'web', TLS_ORIGIN + '/sample-website', {})]
            return replace(row, resources=tuple(resources),
                           buttons=(ButtonRecord(1, 'WEBSITE', 'website'),))

    app.dependency_overrides[resolver.get_repository] = lambda: VisitorRepository(rows)
    routes = APIRouter()
    @routes.get('/sample-website', response_class=HTMLResponse)
    def website():
        return '''<!doctype html><html lang="en"><meta name="viewport" content="width=device-width">
<title>Northstar sample website</title><h1>Northstar Workshop</h1>
<p>Synthetic local business destination. Discover the business, watch its introduction,
and visit its website from one List Number.</p>
<p>Return to the TV2 tab to keep your listing. No account, purchase or contact details required.</p></html>'''
    @routes.get('/review', response_class=HTMLResponse)
    def review():
        return """<!doctype html><html lang="en"><meta name="viewport" content="width=device-width">
<title>Private TV2 visitor review</title><h1>A business introduction from one List Number</h1>
<p>Visitors can find your page, watch your introduction and open your website.</p>
<p>Private local review: synthetic sample listings only. Browsing needs no account.</p>
<p>Sample business: <strong>1*700001</strong></p>
<p>Sample personal listing: <strong>1*70002</strong></p>
<a href="/">Open List Number TV2</a></html>"""
    for route in routes.routes:
        app.router.routes.insert(-1, route)
