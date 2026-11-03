"""Bundle the already-installed offline recognizer and assign cast voices."""
from pathlib import Path
import json, shutil, hashlib

root=Path(__file__).resolve().parents[1]
speech=root/'tools/speech'
installed=Path(r'C:\Users\elles\Desktop\Builts\Elleson-Studio\speech')
target=speech/'recognition-packages'
target.mkdir(exist_ok=True)
for source in (installed/'python-packages').iterdir():
    if source.name=='__pycache__' or (speech/'python-packages'/source.name).exists():continue
    destination=target/source.name
    if source.is_dir():shutil.copytree(source,destination,dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__'))
    else:shutil.copy2(source,destination)
model=speech/'models/whisper-tiny'
model.mkdir(exist_ok=True)
for name in ['config.json','model.bin','tokenizer.json','vocabulary.txt']:
    shutil.copy2(installed/'models/tiny'/name,model/name)

women={'Mara','Elowen','Nell','Agnes','Sera','Wren','Ada','Greta','Astrid','Lysa','Freya','Ingrid','Mina','Tilda','Elsa','Hilda','Bodil','Ida','Erna','Alva','Liv','Edda','Selene','Roslin'}
male=['bm_george','bm_daniel','bm_fable','bm_lewis','am_michael','am_fenrir','am_puck']
female=['bf_emma','bf_isabella','bf_lily','bf_alice','af_heart','af_bella','af_nicole']
profiles={}
for person in json.loads((root/'game/character_stories.json').read_text(encoding='utf-8'))['characters']:
    name=person['name']; number=int(hashlib.sha256(name.encode()).hexdigest()[:8],16)
    pool=female if name in women else male
    first=pool[number%len(pool)];second=pool[(number//7% (len(pool)-1)+1+number%len(pool))%len(pool)]
    profiles[name]={'voice':first,'secondary':second,'mix':round(.15+(number%8)*.045,3),'speed':round(.94+(number//9%8)*.02,2),'pitch':round(.96+(number//71%9)*.01,2)}
profiles['Gareth'].update(voice='bm_george',secondary='bm_daniel',mix=.25,speed=.98,pitch=.97)
profiles['Duncan'].update(voice='bm_lewis',secondary='bm_george',mix=.35,speed=1.04,pitch=1.0)
profiles['Selene'].update(voice='bf_isabella',secondary='bf_emma',mix=.2,speed=.96,pitch=.98)
profiles['Ivor'].update(voice='bm_fable',secondary='bm_george',mix=.25,speed=.94,pitch=.98)
profiles['Roslin'].update(voice='bf_emma',secondary='bf_lily',mix=.3,speed=1.0,pitch=1.02)
profiles['Fenn'].update(voice='bm_daniel',secondary='bm_fable',mix=.4,speed=.98,pitch=1.01)
profiles['Ollie'].update(voice='af_sky',secondary='af_heart',mix=.25,speed=1.06,pitch=1.10)
profiles['Theo'].update(voice='am_puck',secondary='bm_lewis',mix=.2,speed=1.04,pitch=1.07)
profiles['Ansel']={'voice':'bm_fable','secondary':'am_michael','mix':.35,'speed':1.02,'pitch':.99}
seen=set()
for settings in profiles.values():
    while json.dumps(settings,sort_keys=True) in seen:
        settings['mix']=round(settings['mix']+.09,3)
        settings['pitch']=round(settings['pitch']+.02,2)
    seen.add(json.dumps(settings,sort_keys=True))
assert len({json.dumps(value,sort_keys=True) for value in profiles.values()})==len(profiles)
(root/'game/voice_profiles.json').write_text(json.dumps({'profiles':profiles},indent=2)+'\n',encoding='utf-8')
(model/'SOURCES.json').write_text(json.dumps({'runtime':'faster-whisper 1.2.1 / CTranslate2, copied from existing local Elleson Studio installation','model':'Systran/faster-whisper-tiny','source':'https://huggingface.co/Systran/faster-whisper-tiny','files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in model.iterdir() if p.is_file() and p.name!='SOURCES.json'}},indent=2))
print('VOICE_RUNTIME_READY offline_recognition=true assigned_profiles='+str(len(profiles)),flush=True)
