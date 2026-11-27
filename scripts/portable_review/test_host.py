import http.client
from http.server import ThreadingHTTPServer
from pathlib import Path
import tempfile
import threading
import unittest
from readonly_host import handler_for

class ReadOnlyTests(unittest.TestCase):
    def test_static_range_and_rejected_mutations(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);(root/'index.html').write_text('sample')
            (root/'sample.mp4').write_bytes(bytes(range(32)))
            server=ThreadingHTTPServer(('127.0.0.1',0),handler_for(root))
            thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
            try:
                def request(method,path,headers=None):
                    c=http.client.HTTPConnection('127.0.0.1',server.server_port)
                    c.request(method,path,headers=headers or {});r=c.getresponse()
                    out=(r.status,dict(r.getheaders()),r.read());c.close();return out
                for method in ('GET','HEAD'):
                    status,headers,body=request(method,'/')
                    self.assertEqual(status,200);self.assertEqual(headers['Cache-Control'],'no-store')
                    self.assertEqual(body,b'sample' if method=='GET' else b'')
                for value,expected in [('bytes=0-15',bytes(range(16))),('bytes=16-',bytes(range(16,32))),('bytes=-4',bytes(range(28,32)))]:
                    status,headers,body=request('GET','/sample.mp4',{'Range':value})
                    self.assertEqual(status,206);self.assertEqual(body,expected)
                    self.assertEqual(headers['Accept-Ranges'],'bytes')
                for value in ('bytes=32-','bytes=-0','bytes=20-10','bytes=0-1,3-4','bad'):
                    status,headers,_=request('GET','/sample.mp4',{'Range':value})
                    self.assertEqual(status,416);self.assertEqual(headers['Content-Range'],'bytes */32')
                for method in ('POST','PUT','DELETE','PATCH','OPTIONS','TRACE','CONNECT'):
                    self.assertEqual(request(method,'/')[0],405)
                for path in ('/owner','/v1/resolve','/.env','/../secret','/%2e%2e/secret'):
                    self.assertEqual(request('GET',path)[0],404)
            finally:
                server.shutdown();server.server_close();thread.join()

if __name__=='__main__': unittest.main()
