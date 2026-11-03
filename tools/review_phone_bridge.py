"""Test endpoint pairing and private proxy routing without running model inference."""
import importlib.util,pathlib,threading,urllib.request,urllib.error,json
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
root=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('phone_bridge',root/'tools/phone_bridge.py');bridge=importlib.util.module_from_spec(spec);spec.loader.exec_module(bridge)
class Local(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  body=json.dumps({'ready':True,'path':self.path}).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(body)
# The test reserves a temporary local port, while the upstream is mocked.
from io import BytesIO
class Response(BytesIO):
 status=200
 headers={'Content-Type':'application/json'}
def mocked(request,timeout=0):
 assert request.full_url.startswith('http://127.0.0.1:34320/health?pid=')
 return Response(b'{"ready":true}')
bridge.urlopen=mocked
server=ThreadingHTTPServer(('127.0.0.1',0),bridge.Handler)
threading.Thread(target=server.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{server.server_port}'
with urllib.request.urlopen(base+'/token/'+bridge.TOKEN+'/ai/health') as response:assert json.load(response)['ready']
for path,status in [('/token/wrong/ai/health',403),('/token/'+bridge.TOKEN+'/ai/arbitrary-file',404)]:
 try:urllib.request.urlopen(base+path);raise AssertionError('Request should be rejected')
 except urllib.error.HTTPError as error:assert error.code==status
server.shutdown();server.server_close()
print('PHONE_BRIDGE_REVIEW_COMPLETE paired_proxy=true wrong_token_rejected=true arbitrary_endpoint_rejected=true')
