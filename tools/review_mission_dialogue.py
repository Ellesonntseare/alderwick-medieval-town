"""Exercise real local generation using authoritative mission facts, review history."""
import json,os,time,pathlib,subprocess,sys
from urllib.request import Request,urlopen
ROOT=pathlib.Path(__file__).resolve().parents[1]
URL='http://127.0.0.1:34320'
started=time.monotonic()
service=None
service_log=(ROOT/'mission-ai-service-review.log').open('ab',buffering=0)
while time.monotonic()-started<120:
 try:
  with urlopen(URL+'/health?pid='+str(os.getpid()),timeout=3) as response:health=json.load(response)
  if health.get('ready'):break
 except OSError:
  if service is None:service=subprocess.Popen([sys.executable,str(ROOT/'tools/ai/chat_server.py')],stdout=service_log,stderr=service_log,creationflags=0x08000000)
 print('MISSION_AI_WARMUP',round(time.monotonic()-started,1),flush=True)
 time.sleep(3)
else:raise RuntimeError('Local AI did not become ready')
missions=json.loads((ROOT/'game/story_missions.json').read_text())['missions']
checks=[('Corvin','Where did the destination label send Ada\'s missing vegetable crate?',missions[0]['steps'][0]['fact']),('Ansel','Greta was worried about your check-in. Are you safe at Montfaucon?',missions[2]['steps'][2]['fact'])]
for name,message,fact in checks:
 payload={'name':name,'message':message,'scope':'review','pid':os.getpid(),'context':{'name':name,'player_story_state':{'trust_score':0,'mission_facts_you_know':[{'known_fact':fact}],'instruction':'Share these real known facts when asked. Do not invent theft, combat, or completed deliveries.'}}}
 with urlopen(Request(URL+'/chat',json.dumps(payload).encode(),{'Content-Type':'application/json'}),timeout=160) as response:result=json.load(response)
 assert result.get('generated') and result.get('reply'),result
 if name=='Corvin':
  assert any(word in result['reply'].lower() for word in ['fère','fere','tardenois']),result
  assert not any(word in result['reply'].lower() for word in ['alden','not where','elsewhere','misprint for']),result
 if name=='Ansel':assert not any(word in result['reply'].lower() for word in ['yes, greta','hello greta','dear greta']),result
 print('MISSION_GENERATED_REPLY',json.dumps(result),flush=True)
print('MISSION_LOCAL_AI_REVIEW_COMPLETE passed=true',flush=True)
