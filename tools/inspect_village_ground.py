import bpy,pathlib,numpy as np
from mathutils import Vector
R=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town');bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(R/'game/downloaded/satellite_village.glb'))
records=[]
for o in bpy.data.objects:
 if o.type!='MESH':continue
 p=np.array([(o.matrix_world@Vector(c))[:] for c in o.bound_box]);lo=p.min(0);hi=p.max(0);sz=hi-lo;records.append((float(sz[0]*sz[1]),o.name,lo.tolist(),hi.tolist()))
for v in sorted(records,reverse=True)[:15]:print('VILLAGE_GROUND_CANDIDATE',v,flush=True)
