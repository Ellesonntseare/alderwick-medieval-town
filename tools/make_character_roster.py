"""Read the cast's actual model assignments for the portrait renderer."""
from pathlib import Path
import json
import re

ROOT=Path(__file__).resolve().parent.parent
source=(ROOT/'game/village_life.gd').read_text(encoding='utf-8')
base=re.search(r'var residents := \[(.*?)\n\t\]',source,re.S).group(1)
people=[{'name':name,'style':style,'role':role,'district':'city'} for name,role,_home,style in re.findall(r'\["([^"]+)","([^"]+)","([^"]+)","([^"]+)"',base)]
names=re.findall(r'"([^"]+)"',re.search(r'var extra_names := \[([^\]]+)\]',source).group(1))
styles=re.findall(r'"([^"]+)"',re.search(r'var styles := \[([^\]]+)\]',source).group(1))
for index in range(45-len(people)):
    roles=['Carpenter','Herbalist','Guard','Merchant','Farmer','Forester']
    people.append({'name':names[index],'style':styles[index%len(styles)],'role':roles[index%len(roles)],'district':'castle' if index>=17 else 'west' if index>=9 else 'city'})
approved=re.search(r'residents.append_array\(\[(.*?)\n\t\]\)',source,re.S).group(1)
for name,role,_home,style in re.findall(r'\["([^"]+)","([^"]+)","([^"]+)","([^"]+)"',approved):
    people.append({'name':name,'style':style,'role':role,'district':'west' if name=='Gareth' else 'castle' if name=='Duncan' else 'city'})
wardrobe=json.loads('{'+re.search(r'var wardrobe := \{([^}]+)\}',source).group(1)+'}')
for name,style in re.findall(r'if person.person_name==["\']([^"\']+)["\']:\s*person.style=["\']([^"\']+)["\']',source):
    for person in people:
        if person['name']==name:person['style']=style
for person in people:
    if person['name'] in wardrobe:person['style']=wardrobe[person['name']]
    if person['style'] in ['knight','viking','saxon']:person['role']='Guard'
    if person['name'] in ['Wren','Pip','Ada','Tomas','Bodil','Liv']:person['role']='Merchant'
    if person['name'] in ['Cedric','Wolfram','Rolf','Selene']:person['role']='Night guard'
stories=json.loads((ROOT/'game/character_stories.json').read_text(encoding='utf-8'))
assert {p['name'] for p in people}=={p['name'] for p in stories['characters']}
assert len(people)==53
for person in people:assert (ROOT/'game/characters'/f"{person['style']}.glb").exists(),person
(ROOT/'game/characters/roster_appearance.json').write_text(json.dumps(people,indent=2),encoding='utf-8')
print('PORTRAIT_CAST_READY',len(people),'models=',len(set(p['style'] for p in people)),flush=True)
