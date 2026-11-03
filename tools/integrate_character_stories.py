"""Promote the approved character designs while retaining the existing cast."""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
path = root / 'game/character_stories.json'
data = json.loads(path.read_text(encoding='utf-8'))
staged_path = root / 'STAGED-CHARACTER-STORIES.json'
staged = json.loads(staged_path.read_text(encoding='utf-8'))
additions = staged['characters'] + [
    dict(name='Ollie', model='runner_child', role='Village child',
         past='Ollie lives in Willow House and knows the square through games, errands and watching the stallholders work.',
         want='Make a little model village for the Winter Fair with help from the neighbours.',
         problem='Ollie promised Theo a model bridge but used the last straight twigs on the market stalls.',
         connections={'Theo':'older friend who helps build things', 'Greta':'trusted adult at Willow House', 'Nell':'likes the small carved boats Nell leaves for children'},
         story='Find fallen twigs with permission, ask Theo for help with the bridge and display the model at the fair. Small supervised errands and play fit Ollie; adult employment and tavern drinking do not.',
         private_fact='Ollie has named every wonky model house after someone in town but worries that they might be offended.',
         voice='Young, curious and direct; ordinary childlike questions without baby talk.'),
    dict(name='Theo', model='runner_youth', role='Young apprentice',
         past='Theo lives at Hearth House and is learning simple woodworking by watching the craftspeople and practising on offcuts.',
         want='Finish a small wooden sign well enough to give it to Bram rather than hide the mistakes.',
         problem='Theo would rather redo an uneven letter in secret than ask Finn how to fix it.',
         connections={'Ollie':'younger friend building a model village', 'Bram':'trusted adult at Hearth House', 'Finn':'patient teacher for simple woodworking'},
         story='Compare a practice sign with Finn, learn to repair the uneven letter, and help Ollie build a model bridge. Learning, play and light supervised tasks replace adult shifts or alcohol.',
         private_fact='Theo keeps the very first crooked practice letter because it shows how much the newer ones have improved.',
         voice='Youthful, thoughtful and a little proud; enthusiasm grows when talking about making things.'),
]
by_name = {person['name']: person for person in data['characters']}
for person in additions:
    by_name[person['name']] = person
data['characters'] = list(by_name.values())
assert len(data['characters']) == 53
path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
doc = root / 'CHARACTER-STORIES.md'
text = doc.read_text(encoding='utf-8')
for index, person in enumerate(additions, 46):
    if f'## {index}. {person["name"]}' in text:
        continue
    links = '; '.join(f'{name} — {relation}' for name, relation in person['connections'].items())
    text += f'\n## {index}. {person["name"]}\n\n{person["past"]}\n\n**Work or daily role:** {person["role"]}.\n\n**What matters to them:** {person["want"]}\n\n**Current difficulty:** {person["problem"]}\n\n**Connected storyline:** {person["story"]}\n\n**Something learned through familiarity:** {person["private_fact"]}\n\n**Relationships:** {links}.\n\n**Voice and personality:** {person["voice"]}\n'
doc.write_text(text, encoding='utf-8')
staged['status'] = 'Integrated into the 53-resident town after user approval of the corrected previews.'
staged_path.write_text(json.dumps(staged, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print('CHARACTER_STORIES_INTEGRATED count=53 adults_added=6 children_added=2')
