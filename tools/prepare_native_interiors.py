import bpy,pathlib,json,math,bmesh,sys
from mathutils import Vector,Matrix
R=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town');OUT=R/'game/downloaded';ONLY=sys.argv[-1] if '--' in sys.argv else '';records=json.loads((OUT/'native-interiors.json').read_text()) if ONLY else {}
# Coordinates below are Blender Z-up; runtime coordinates are converted to Godot Y-up.
CONFIG={
'viking_hall':dict(center=[0,0],size=[12,8,3.3],floor=.2,door=[0,5.3],direction=1),
'viking_house':dict(center=[0,0],size=[7,8,2.8],floor=.2,door=[0,5.2],direction=1),
'medieval_house':dict(center=[0,0],size=[11,6,2.8],floor=.2,door=[0,3.9],direction=1),
'boathouse':dict(center=[0,0],size=[13,9,2.8],floor=.2,door=[0,6.2],direction=1),
'watchtower':dict(center=[0,0],size=[2.2,2.2,2.8],floor=.2,door=[0,1.5],direction=1),
'downloaded_forge':dict(center=[3.125,-4.75],size=[2.8,3.6,3.3],floor=.0871282,door=[3.125,-8.0],direction=-1,offset_y=-.0871282,open_roof=True,preserve_original=True,asset_scale=2.5),
'fortress':dict(center=[0,0],size=[12,12,3.2],floor=.2,door=[0,11.7],direction=1),
'arnstein_castle':dict(center=[-2,1],size=[4,4,3.0],floor=9.8,door=[-2,-2.2],direction=-1,offset_y=-9.6,open_roof=True),
'feira_castle':dict(center=[-4,4],size=[10,10,3.0],floor=7.6,door=[-4,14],direction=1,offset_y=-7.4,open_roof=True),
'castle_xix':dict(center=[-3,5],size=[7,7,3.0],floor=.472,door=[0,-16.5],direction=-1,offset_y=-.272,open_roof=True)
}
for key,cfg in CONFIG.items():
 if ONLY and key!=ONLY:continue
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(OUT/(key+'.glb')));objects=[o for o in bpy.data.objects if o.type=='MESH']
 for o in objects:
  world=o.matrix_world.copy();o.parent=None;o.data=o.data.copy();o.data.transform(world);o.data.transform(Matrix.Scale(cfg.get("asset_scale",1),4));o.matrix_world=Matrix.Identity(4)
 x,y=cfg['center'];w,d,h=cfg['size'];floor=cfg['floor'];dx,dy=cfg['door'];direction=cfg['direction'];removed=0
 # Clear the usable room only inside the existing building/courtyard footprint.
 boxes=[(x-w/2+.12,x+w/2-.12,y-d/2+.12,y+d/2-.12,floor-.02,floor+h+.05)]
 # The actual entrance tunnel joins the outside to the same physical floor.
 extent=max(abs(dy),d/2)+3.0
 if key=='arnstein_castle':outside_y=-10.0;inner_y=-.65
 elif key=='feira_castle':outside_y=29.0;inner_y=8.0
 elif key=='castle_xix':outside_y=-24.0;inner_y=3.0
 else:outside_y=direction*(max(abs(dy),d/2)+2.0);inner_y=y+direction*(d/2-.5)
 boxes.append((dx-.85,dx+.85,min(outside_y,inner_y),max(outside_y,inner_y),floor-.04,floor+2.55))
 if cfg.get("preserve_original"):boxes=[]
 for o in objects:
  bm=bmesh.new();bm.from_mesh(o.data);drop=[]
  # Split faces at each opening boundary before removing the interior. A
  # centroid-only removal leaves long triangles across otherwise open doors.
  for a,b,c,d,e,f in boxes:
   for axis,value in [(0,a),(0,b),(1,c),(1,d),(2,e),(2,f)]:
    coordinate=Vector((0,0,0));coordinate[axis]=value
    normal=Vector((0,0,0));normal[axis]=1
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00002,plane_co=coordinate,plane_no=normal,clear_inner=False,clear_outer=False)
  for face in bm.faces:
   p=face.calc_center_median()
   if any(a<p.x<b and c<p.y<d and e<p.z<f for a,b,c,d,e,f in boxes):drop.append(face)
  removed+=len(drop)
  if drop:bmesh.ops.delete(bm,geom=drop,context='FACES')
  bm.to_mesh(o.data);bm.free()
  for material in o.data.materials:
   if material:material.use_backface_culling=False
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:
  if len(o.data.polygons):o.select_set(True)
 bpy.context.view_layer.objects.active=next(o for o in objects if len(o.data.polygons))
 bpy.ops.export_scene.gltf(filepath=str(OUT/(key+'_walkable.glb')),export_format='GLB',use_selection=True,export_animations=False,export_materials='EXPORT')
 cfg['id']=key;cfg['removed_faces']=removed;cfg['outside_y']=outside_y;cfg['inner_y']=inner_y
 records[key]=cfg;print('NATIVE_GEOMETRY_READY',key,'removed',removed,'floor',floor,flush=True)
(OUT/'native-interiors.json').write_text(json.dumps(records,indent=2))
print('NATIVE_INTERIORS_PREPARED',len(records),flush=True)
