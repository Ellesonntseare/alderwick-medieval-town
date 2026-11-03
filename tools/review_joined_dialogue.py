import json,time,urllib.request,pathlib,os
root=pathlib.Path(__file__).resolve().parents[1]
url='http://127.0.0.1:34320'
for attempt in range(180):
    try:
        with urllib.request.urlopen(url+'/health?pid='+str(os.getpid()),timeout=3) as response:data=json.load(response)
        if data.get('ready'):break
    except OSError:pass
    time.sleep(.5)
else:raise RuntimeError('Local dialogue model did not become ready')
turns=[{'name':'Roslin','text':'The herb garden needs a clear path for deliveries.'},{'name':'Fenn','text':'We could use the woodland entrance instead.'}]
participants=[{'name':'Roslin','occupation':'Herbalist'},{'name':'Fenn','occupation':'Range keeper'}]
for name,message in [('Roslin','I heard you discussing the garden path. Could I join you? What needs doing?'),('Fenn','Fenn, would the woodland entrance leave enough room for the deliveries?')]:
    turns.append({'name':'You','text':message})
    body={'name':name,'message':message,'scope':'review','pid':os.getpid(),'context':{'occupation':next(p['occupation'] for p in participants if p['name']==name),'current_activity':'Talking with another resident and the visitor','joined_conversation':{'participants':participants,'recent_turns':turns[-12:],'player_has_joined':True}}}
    request=urllib.request.Request(url+'/chat',data=json.dumps(body).encode(),headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(request,timeout=170) as response:reply=json.load(response)
    assert reply['generated'] and reply['name']==name and len(reply['reply'])>20,reply
    turns.append({'name':name,'text':reply['reply']})
    print('JOINED_AI_REPLY',name,reply['seconds'],reply['reply'],flush=True)
(root/'review/characters/joined-dialogue-review.json').write_text(json.dumps(turns,indent=2))
print('JOINED_DIALOGUE_REVIEW_COMPLETE passed=true speakers=2 local_generation=true',flush=True)
