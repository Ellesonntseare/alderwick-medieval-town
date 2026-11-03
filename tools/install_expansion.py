import pathlib,zipfile,re,json,shutil
ROOT=pathlib.Path(__file__).resolve().parents[1]
archive=pathlib.Path(r'C:\Users\elles\Downloads\MedievalVillageKit_Godot_0.3.0.zip')
names=['Barn','Stable','Brewery','Inn','Apiary','Pigsty','TrainingYard','ForesterHut','Watermill','Woodcutter','Pottery','Tannery','Storehouse','Smokehouse','Longhouse','TownhouseGablefront']
src=ROOT/'source-assets'/'dungeon-selected'
with zipfile.ZipFile(archive) as z:
 prefix='MedievalVillageKit_Godot/'
 allnames=set(z.namelist());seen=set();pending={f'kit/structures/{n}.tscn' for n in names}
 pending.update({'kit/models/VK/Prop/SM_VK_Prop_ShopGoods_Produce.glb','kit/materials/M_VK_Crops.tres','kit/materials/M_VK_Pumpkin.tres'})
 for crop in ['Cabbage','Carrot','Onion','Pumpkin','Turnip']:
  pending.add(f'kit/models/VK/Crop/SM_VK_Crop_{crop}.glb')
 while pending:
  name=pending.pop()
  if name in seen:continue
  seen.add(name)
  dest=src/name
  if not dest.exists():
   data=z.read(prefix+name);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
  if dest.suffix in ('.tscn','.tres','.gdshader','.gdshaderinc'):
   for ref in re.findall(r'res://([^"\s)]+)',dest.read_text(encoding='utf-8-sig')):
    if prefix+ref in allnames and ref not in seen:pending.add(ref)
 game=ROOT/'game'
 for folder in ['kit/structures','kit/models','kit/textures']:
  shutil.copytree(src/folder,game/folder,dirs_exist_ok=True)
 for f in (game/'kit'/'structures').glob('*.tscn'):
  s=f.read_text(encoding='utf-8-sig').replace('res://addons/medieval_kit/Runtime/KitStructure.cs','res://kit_structure.gd').replace('res://addons/medieval_kit/Runtime/KitPiece.cs','res://kit_piece.gd')
  f.write_text(s,encoding='utf-8')
 for f in (src/'kit'/'materials').glob('*.tres'):
  s=f.read_text();tex=re.search(r'\[ext_resource type="Texture2D" path="([^"]+)" id="2"\]',s);color=re.search(r'shader_parameter/base_color = (Color\([^\n]+\))',s)
  out='[gd_resource type="StandardMaterial3D" load_steps=%d format=3]\n\n'%(2 if tex else 1)
  if tex:out+='[ext_resource type="Texture2D" path="'+tex[1]+'" id="1"]\n\n'
  out+='[resource]\nvertex_color_use_as_albedo = true\nroughness = 0.86\ncull_mode = 2\n'
  if color:out+='albedo_color = '+color[1]+'\n'
  if tex:out+='albedo_texture = ExtResource("1")\n'
  (game/'kit'/'materials'/f.name).write_text(out)
 (ROOT/'expansion-assets.json').write_text(json.dumps({'archive':str(archive),'structures':names,'dependencies':sorted(seen)},indent=2))
print('EXPANSION_INSTALLED',len(names),'structures',len(seen),'verified ZIP entries',flush=True)
