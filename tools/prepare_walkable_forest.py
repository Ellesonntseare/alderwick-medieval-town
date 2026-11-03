"""Build one reusable woodland patch with real ground and trunk metadata."""
import bpy,pathlib,json,numpy as np
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
root=pathlib.Path(__file__).resolve().parents[1]
out=root/'game/downloaded/forest';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r'C:\Users\elles\Downloads\a_forest_3_with_a_road_at_night_for_game.glb')
meshes=[obj for obj in bpy.data.objects if obj.type=='MESH']
ground=next(obj for obj in meshes if any(mat and mat.name=='Material.003' for mat in obj.data.materials))
vertices=[ground.matrix_world@v.co for v in ground.data.vertices]
tree=BVHTree.FromPolygons(vertices,[list(p.vertices) for p in ground.data.polygons])
coords=np.array([p[:] for p in vertices]);low=coords.min(0);high=coords.max(0)
centre=Vector(((low[0]+high[0])/2,(low[1]+high[1])/2,0))
base=float(np.quantile(coords[:,2],.1));scale=3.2
width=(high[0]-low[0])*scale;depth=(high[1]-low[1])*scale
def height(x,y):
    hit=tree.ray_cast(Vector((x,y,10)),Vector((0,0,-1)))[0]
    return hit.z if hit else base
def transformed(point):
    p=(point-centre)*scale;p.z=(point.z-base)*scale
    margin=min(width/2-abs(p.x),depth/2-abs(p.y))
    t=max(0,min(1,margin/3.0));smooth=t*t*(3-2*t)
    return min(.65,max(0,p.z)*smooth)
trunks=[];kept=[]
for obj in meshes:
    points=[obj.matrix_world@vertex.co for vertex in obj.data.vertices]
    lo=Vector(tuple(min(p[k] for p in points) for k in range(3)));hi=Vector(tuple(max(p[k] for p in points) for k in range(3)));mid=(lo+hi)/2
    if obj!=ground and (mid.x<low[0] or mid.x>high[0] or mid.y<low[1] or mid.y>high[1]):
        bpy.data.objects.remove(obj,do_unlink=True);continue
    old=height(mid.x,mid.y);new=transformed(Vector((mid.x,mid.y,old)))
    delta=new-(old-base)*scale
    obj.parent=None;obj.matrix_world=Matrix.Identity(4)
    for vertex,point in zip(obj.data.vertices,points):
        vertex.co=(point-centre)*scale;vertex.co.z=(point.z-base)*scale+delta
        if obj==ground:vertex.co.z=transformed(point)
    is_trunk=any(mat and mat.name=='Material.004' for mat in obj.data.materials)
    if is_trunk:
        centre_x=(mid.x-centre.x)*scale;centre_z=-(mid.y-centre.y)*scale
        trunk_height=(hi.z-lo.z)*scale
        trunks.append({'x':centre_x,'z':centre_z,'y':max(0,(lo.z-base)*scale+delta),'radius':max(.10,float(max(hi.x-lo.x,hi.y-lo.y))*scale*.48),'height':trunk_height})
    obj.name='ForestGround' if obj==ground else 'ForestTrunk' if is_trunk else 'ForestUnderstory' if hi.z-lo.z<.65 else 'ForestFoliage'
    kept.append(obj)
for category in ['ForestGround','ForestTrunk','ForestFoliage','ForestUnderstory']:
    items=[obj for obj in bpy.data.objects if obj.type=='MESH' and obj.name.startswith(category)]
    if not items:continue
    bpy.ops.object.select_all(action='DESELECT')
    for obj in items:obj.select_set(True)
    bpy.context.view_layer.objects.active=items[0]
    if len(items)>1:bpy.ops.object.join()
    bpy.context.object.name=category
for obj in list(bpy.data.objects):
    if obj.type!='MESH':bpy.data.objects.remove(obj,do_unlink=True)
for image in bpy.data.images:
    if max(image.size)>2048:
        factor=2048/max(image.size);image.scale(round(image.size[0]*factor),round(image.size[1]*factor))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(out/'woodland_patch.glb'),export_format='GLB',use_selection=True,export_animations=False)
(out/'layout.json').write_text(json.dumps({'width':width,'depth':depth,'source_scale':scale,'trunks':trunks,'trees':len(trunks),'ground_edges':'blended to shared earth'},indent=2))
print('WALKABLE_FOREST_EXPORTED trunks=',len(trunks),'size=',width,depth,flush=True)
