import bpy,pathlib,json
from mathutils import Vector
R=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town');bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(R/'game/downloaded/downloaded_forge.glb'))
for o in bpy.data.objects:
 if o.type!='MESH':continue
 p=[o.matrix_world@Vector(c) for c in o.bound_box];lo=[min(v[i] for v in p) for i in range(3)];hi=[max(v[i] for v in p) for i in range(3)];print('FORGE_PART',o.name,'min',lo,'max',hi,flush=True)
