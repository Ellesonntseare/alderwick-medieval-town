"""Exercise actual local synthesis and recognition without opening a microphone."""
import io,json,pathlib,time,urllib.request,urllib.error,wave,hashlib,os
root=pathlib.Path(__file__).resolve().parents[1]
url='http://127.0.0.1:34319'
def request(path,data=None,kind='application/json'):
    value=json.dumps(data).encode() if isinstance(data,dict) else data
    try:
        with urllib.request.urlopen(urllib.request.Request(url+path,data=value,headers={'Content-Type':kind}),timeout=90) as response:return response.read()
    except urllib.error.HTTPError as error:raise RuntimeError(error.read().decode()) from error
for attempt in range(60):
    try:
        health=json.loads(request('/health?pid='+str(os.getpid())));break
    except OSError:time.sleep(.5)
else:raise RuntimeError('Voice service did not start')
assert health['recognition_ready'] and health['voice_profiles']>=53,health
line='Could you tell me what is happening at the market today?'
results={}
for name in ['Duncan','Roslin','Ollie']:
    started=time.monotonic()
    data=request('/speak',{'character':name,'text':line})
    path=root/'review/characters'/(name+'-voice.wav');path.write_bytes(data)
    with wave.open(io.BytesIO(data),'rb') as audio:
        assert audio.getnframes()>1000 and audio.getnchannels()==1
        results[name]={'seconds':audio.getnframes()/audio.getframerate(),'generation_seconds':round(time.monotonic()-started,2),'sha256':hashlib.sha256(data).hexdigest()}
    if name=='Duncan':
        words=json.loads(request('/transcribe',data,'audio/wav'))
        assert words['heard_speech'] and 'market' in words['text'].lower(),words
        results['transcription']=words
    print('ASSIGNED_VOICE_CHECK',name,results[name],flush=True)
silence=io.BytesIO()
with wave.open(silence,'wb') as wav:
    wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(16000);wav.writeframes(bytes(32000))
assert not json.loads(request('/transcribe',silence.getvalue(),'audio/wav'))['heard_speech']
assert len({results[name]['sha256'] for name in ['Duncan','Roslin','Ollie']})==3
(root/'review/characters/voice-runtime-review.json').write_text(json.dumps(results,indent=2))
print('TOWN_VOICE_RUNTIME_REVIEW_COMPLETE passed=true silence_rejected=true real_microphone_opened=false',flush=True)
