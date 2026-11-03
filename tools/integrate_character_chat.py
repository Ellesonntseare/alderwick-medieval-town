"""Install the generated-chat view without replacing world/economy work."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parent.parent
path = ROOT / 'game/village_life.gd'
text = path.read_text(encoding='utf-8')
if 'var ai: Node' not in text:
    text = text.replace('var entry: LineEdit', 'var entry: TextEdit\nvar ai: Node', 1)
    text = text.replace('\tmake_interface()\n', '\tai=Node.new()\n\tai.set_script(load("res://town_dialogue.gd"))\n\tadd_child(ai)\n\tmake_interface()\n', 1)
start = text.index('func make_interface() -> void:')
end = text.index('\nfunc open_dialog(', start)
text = text[:start] + 'func make_interface() -> void:\n\tpreload("res://dialogue_panel.gd").build(self)\n' + text[end:]
text = text.replace('"turns":preload("res://resident_dialogue.gd").exchange(a,b)', '"turns":[]')
start = text.index('func tick_chat(')
end = text.index('\nfunc stop_chat(', start)
text = text[:start] + '''func tick_chat(person: CharacterBody3D,delta: float) -> void:
	if not chats.has(person.chat_id):return
	var chat: Dictionary=chats[person.chat_id]
	if chat.leader!=person:return
	ai.tick_social(person,chat,delta)
''' + text[end:]
old = '''	var greeting: String=active.speak("hello")
	transcript.text=active.person_name+": "+greeting
	if town.speech:town.speech.read_dialogue(active,greeting)
'''
assert old in text, 'Opening dialogue changed; inspect before applying'
text = text.replace(old, '\ttranscript.text=""\n', 1)
text = text.replace('\tdialog.position=Vector2((get_viewport().get_visible_rect().size.x-800)/2,get_viewport().get_visible_rect().size.y-475)', '\tai.layout()\n\tai.open(person)', 1)
start = text.index('func send(message: String) -> void:')
end = text.index('\nfunc close_dialog()', start)
text = text[:start] + '''func send(message: String) -> void:
	ai.send(message)
''' + text[end:]
text = text.replace('\tactive=null\n\tdialog.hide()', '\tactive=null\n\tai.close()\n\tdialog.hide()', 1)
path.write_text(text, encoding='utf-8')

cast = json.loads((ROOT/'game/character_stories.json').read_text(encoding='utf-8'))
names = [person['name'] for person in cast['characters']]
assert len(names) == len(set(names)) == 45
parts = ['# '+cast['title'], '', cast['world'], '',
         'These backgrounds support generated, free-form character conversation. They are not saved replies. '
         'Story arcs are narrative designs; their physical missions and endings require game implementation.', '']
for index, person in enumerate(cast['characters'], 1):
    parts += [f"## {index}. {person['name']}", '', person['past'], '',
              '**What matters to them:** '+person['want'], '',
              '**Current difficulty:** '+person['problem'], '',
              '**Connected storyline:** '+person['story'], '',
              '**Something learned through familiarity:** '+person['private_fact'], '',
              '**Relationships:** '+'; '.join(name+' — '+relation for name, relation in person['connections'].items())+'.', '',
              '**Voice and personality:** '+person['voice'], '']
(ROOT/'CHARACTER-STORIES.md').write_text('\n'.join(parts), encoding='utf-8')
print('CHARACTER_CHAT_INTEGRATED cast=45 side_panel=true authored_replies=false')
