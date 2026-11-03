"""Fit the six supplied character sources to the town's common motion rig.

Original GLBs remain unchanged. Every output has the same named limb bones
as the existing residents, including the shared work, seated and sleep clips.
"""
import pathlib

root = pathlib.Path(__file__).resolve().parents[1]
path = root / "tools" / "rig_new_characters.py"
source = path.read_text(encoding="utf-8")
configuration = [
    ('saxon_warrior_-_t_pose.glb', 'saxon', [(.21,0,1.43),(.48,0,1.43),(.74,0,1.43)]),
    ('bruce.glb', 'bruce', [(.23,.04,1.47),(.48,.04,1.47),(.77,.04,1.47)]),
    ('deadly_assassin_-_warrior_body_armor_weapons.glb', 'armoured_assassin', [(.21,0,1.43),(.44,0,1.43),(.66,0,1.43)]),
    ('medieval (1).glb', 'robed_scholar', [(.20,0,1.43),(.28,-.01,1.16),(.27,-.03,.96)]),
    ('medieval.glb', 'medieval_woman', [(.19,0,1.43),(.24,-.01,1.15),(.23,-.03,.94)]),
    ('cult_member_enemy_character.glb', 'cult_archer', [(.20,0,1.43),(.30,-.17,1.28),(.30,-.38,1.35)]),
]
original = next(line for line in source.splitlines() if line.startswith("CONFIG="))
source = source.replace(original, "CONFIG="+repr(configuration), 1)
source = source.replace("REPORT=json.loads((R/'rigged-character-report.json').read_text()) if ONLY else []", "REPORT=json.loads((R/'rigged-character-report.json').read_text())")
source = source.replace("if any(x in o.name.lower() for x in ['floor','rock_','gold_gold']):", "if any(x in o.name.lower() for x in ['floor','rock_','gold_gold','icosphere']):")
source = source.replace(
    "for o in meshes:\n  world=o.matrix_world.copy();o.parent=None;",
    """# Bake the source skin before removing its original armature. This
 # preserves the supplied pose instead of exposing transformed bind geometry.
 if style in ['bruce','armoured_assassin']:
  bpy.context.view_layer.update();graph=bpy.context.evaluated_depsgraph_get()
  for obj in meshes:
   evaluated=obj.evaluated_get(graph)
   obj.data=bpy.data.meshes.new_from_object(evaluated,preserve_all_data_layers=True,depsgraph=graph)
 for o in meshes:
  world=o.matrix_world.copy();o.parent=None;""", 1)
source = source.replace(
    "# Keep the source hierarchy and bone names so all existing gameplay poses work.",
    """if style=='saxon':
  for obj in meshes:
   if 'shield' in obj.name.lower():rigid[obj.name]='LowerArm.L'
   elif any(word in obj.name.lower() for word in ['scabbard','dagger','sword','belt']):rigid[obj.name]='Hips'
 if style=='cult_archer':
  for obj in meshes:
   if 'bow' in obj.name.lower() or 'string' in obj.name.lower():rigid[obj.name]='Wrist.L'
   elif 'quiver' in obj.name.lower() or 'arrow' in obj.name.lower():rigid[obj.name]='Chest'
 # Keep the source hierarchy and bone names so all existing gameplay poses work.""", 1)
source = source.replace("if style=='mercenary' and n.startswith(('Shoulder.','UpperArm.','LowerArm.','Wrist.')):", "if style=='cult_archer' and n.startswith(('Shoulder.','UpperArm.','LowerArm.','Wrist.')):")
source = source.replace("if style=='viking' and o.name.startswith('Object_3') and .25<p[k,2]<.90 and abs(p[k,0])<.35:", "if style in ['robed_scholar','medieval_woman'] and .23<p[k,2]<.94 and abs(p[k,0])<.36:")
exec(compile(source, str(path), "exec"))
