"""Real local inference checks, isolated from player conversation history."""
import json
import time
import sys
from urllib.request import Request, urlopen

sys.stdout.reconfigure(encoding='utf-8')

URL='http://127.0.0.1:34320'

def get(path):
    with urlopen(URL+path,timeout=8) as response:return json.load(response)

def say(name,text,context):
    started=time.monotonic()
    request=Request(URL+'/chat',data=json.dumps({'name':name,'message':text,'context':context,'scope':'review'}).encode(),headers={'Content-Type':'application/json'})
    with urlopen(request,timeout=180) as response:data=json.load(response)
    assert data.get('generated') and data.get('reply'),'No actual generated reply'
    print('LOCAL_AI_REPLY',name,'seconds=',round(time.monotonic()-started,2),json.dumps(data['reply'],ensure_ascii=False),flush=True)
    return data['reply']

if __name__=='__main__':
    deadline=time.monotonic()+1800
    while time.monotonic()<deadline:
        try:
            if get('/health')['ready']:break
        except OSError:pass
        time.sleep(4)
    else:raise RuntimeError('Local model did not become available')
    failures=[]
    first=say('Mara',"I'm Moss. I repair fishing nets, and I cannot stand turnips. Has anything made you laugh lately?",{'occupation':'Baker','current_activity':'Preparing bread','time':'day'})
    if len(first)<30:failures.append('Mara gave no useful reply')
    second=say('Mara','What is my name, what do I repair, and which vegetable did I dislike?',{'occupation':'Baker','time':'day'})
    if not all(word in second.lower() for word in ['moss','net','turnip']):failures.append('Specific player facts were forgotten')
    guard=say('Nell','Edric seems very serious. Have you ever made him laugh?',{'occupation':'Guard','guard_post':'the south gate','current_activity':'Guarding the south gate','time':'day'})
    if any(phrase in guard.lower() for phrase in ['at night i go home','return to my post in the morning','choose a topic']):failures.append('Guard recited a schedule instead of responding')
    history=get('/history?name=Mara&scope=review')['messages']
    if not any('Moss' in turn['content'] for turn in history):failures.append('Conversation was not saved')
    outsider=get('/history?name=Mina&scope=review')['messages']
    if any('Moss' in turn['content'] for turn in outsider):failures.append('Private conversation leaked to another character')
    exchange=[]
    for name,partner in [('Nell','Edric'),('Edric','Nell')]:
        request=Request(URL+'/social',data=json.dumps({'name':name,'partner':partner,'context':{'occupation':'Guard','time':'day'},'exchange':exchange}).encode(),headers={'Content-Type':'application/json'})
        with urlopen(request,timeout=180) as response:turn=json.load(response)
        if not turn.get('generated') or not turn.get('reply'):failures.append('No generated neighbour exchange')
        exchange.append({'name':name,'text':turn['reply']})
        print('LOCAL_NEIGHBOUR_REPLY',name,json.dumps(turn['reply'],ensure_ascii=False),flush=True)
    print('LOCAL_AI_REVIEW_COMPLETE failures=',failures,flush=True)
    raise SystemExit(1 if failures else 0)
