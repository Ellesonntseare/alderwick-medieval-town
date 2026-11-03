"""Explicitly started paired LAN bridge for the Android game and local AI/voices."""
import ipaddress,json,os,pathlib,secrets,socket,subprocess,sys,threading,time
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from urllib.request import Request,urlopen
from urllib.error import HTTPError,URLError
from urllib.parse import urlsplit,parse_qsl,urlencode
ROOT=pathlib.Path(__file__).resolve().parents[1]
PAIR=ROOT/'tools/phone-pairing.json'
try:TOKEN=json.loads(PAIR.read_text())['token']
except (OSError,ValueError,KeyError):
 TOKEN=secrets.token_urlsafe(24);PAIR.write_text(json.dumps({'token':TOKEN}))
CHILDREN={}
ALLOWED={'ai':{'GET':{'/health','/history'},'POST':{'/chat','/social'}},'speech':{'GET':{'/health'},'POST':{'/speak','/transcribe'}}}
def ensure_services():
 for name,port,script in [('ai',34320,ROOT/'tools/ai/chat_server.py'),('speech',34319,ROOT/'tools/speech/server.py')]:
  try:
   with urlopen(f'http://127.0.0.1:{port}/health?pid={os.getpid()}',timeout=2):pass
  except OSError:
   if name not in CHILDREN or CHILDREN[name].poll() is not None:
    CHILDREN[name]=subprocess.Popen([sys.executable,str(script)],creationflags=0x08000000 if os.name=='nt' else 0)
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):self.forward()
 def do_POST(self):self.forward()
 def forward(self):
  peer=ipaddress.ip_address(self.client_address[0])
  if not peer.is_private and not peer.is_loopback:self.send_error(403);return
  path=urlsplit(self.path);parts=path.path.split('/')
  if len(parts)<5 or parts[1]!='token' or not secrets.compare_digest(parts[2],TOKEN):self.send_error(403);return
  service=parts[3];endpoint='/'+ '/'.join(parts[4:])
  if endpoint not in ALLOWED.get(service,{}).get(self.command,set()):self.send_error(404);return
  size=int(self.headers.get('Content-Length','0'))
  if size>8_000_000:self.send_error(413);return
  body=self.rfile.read(size) if size else None
  query=dict(parse_qsl(path.query));query['pid']=str(os.getpid())
  content_type=self.headers.get('Content-Type','application/json')
  if body and 'json' in content_type:
   try:data=json.loads(body);data['pid']=os.getpid();body=json.dumps(data).encode()
   except ValueError:self.send_error(400);return
  port=34320 if service=='ai' else 34319
  request=Request(f'http://127.0.0.1:{port}{endpoint}?{urlencode(query)}',data=body,headers={'Content-Type':content_type},method=self.command)
  try:
   with urlopen(request,timeout=180) as response:
    payload=response.read();code=response.status;kind=response.headers.get('Content-Type','application/octet-stream')
  except HTTPError as error:payload=error.read();code=error.code;kind='application/json'
  except (OSError,URLError):payload=b'{"error":"PC conversations are warming up. Try again shortly."}';code=503;kind='application/json'
  self.send_response(code);self.send_header('Content-Type',kind);self.send_header('Content-Length',str(len(payload)));self.end_headers()
  try:self.wfile.write(payload)
  except OSError:pass
def main():
 server=ThreadingHTTPServer(('0.0.0.0',34322),Handler)
 print('Alderwick phone AI — keep this window open on your private Wi-Fi.',flush=True)
 addresses=set()
 for item in socket.getaddrinfo(socket.gethostname(),None,socket.AF_INET):
  value=item[4][0]
  if ipaddress.ip_address(value).is_private and not value.startswith('127.'):addresses.add(value)
 for address in sorted(addresses):print(f'Phone connection: http://{address}:34322/token/{TOKEN}',flush=True)
 print('Paste one address into Connect to PC AI in the Android game. Close this window to stop sharing.',flush=True)
 def monitor():
  while True:
   ensure_services();time.sleep(8)
 threading.Thread(target=monitor,daemon=True).start()
 server.serve_forever()
if __name__=='__main__':main()
