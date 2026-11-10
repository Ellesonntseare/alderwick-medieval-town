"""Review isolated generated dialogue about weather and personally heard news."""
import json,os,pathlib,time
from urllib.request import Request,urlopen
root=pathlib.Path(__file__).resolve().parents[1]
url='http://127.0.0.1:34320'
started=time.monotonic()
while time.monotonic()-started<120:
 try:
  with urlopen(url+'/health?pid='+str(os.getpid()),timeout=5) as response:health=json.load(response)
  if health.get('ready'):break
 except OSError:pass
 time.sleep(1)
else:raise RuntimeError('Local AI did not become ready; this review does not restart services')
context={'name':'Finn','occupation':'Workshop carpenter','current_activity':'Sheltering beneath a workshop overhang during rain','time':'day','recent_personal_events':[], 'player_story_state':{'surroundings_and_news':{'weather':'Rain','indoors':False,'known_town_events':[{'fact':"Ada's labelled greens were delivered to the western market by mistake. Nobody has established theft.",'source':'Corvin told me while we spoke near the workyard.'}],'instruction':'Speak naturally. Distinguish what somebody told you from something you witnessed. Do not claim the visitor recovered the crate or completed a mission.'},'mission_facts_you_know':[],'trust_score':0}}
payload={'name':'Finn','message':"Why are you sheltering here? Have you heard anything about Ada's missing delivery?",'context':context,'scope':'review','pid':os.getpid()}
with urlopen(Request(url+'/chat',json.dumps(payload).encode(),{'Content-Type':'application/json'}),timeout=160) as response:
 result=json.load(response)
assert result.get('generated') and result.get('reply'),result
reply=result['reply'].lower()
assert any(word in reply for word in ['rain','wet','shelter','weather']),result
assert any(word in reply for word in ['corvin','told','heard','said']),result
assert not any(word in reply for word in ['you returned the crate','you recovered the crate','you brought back the crate']),result
print('LIVING_CONTEXT_GENERATED_REPLY',json.dumps(result),flush=True)
print('LIVING_CONTEXT_REVIEW_COMPLETE passed=true',flush=True)
