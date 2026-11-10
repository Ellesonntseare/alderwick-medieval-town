extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
 var stage := Node3D.new()
 root.add_child(stage)
 root.size=Vector2i(360,360)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 RenderingServer.set_default_clear_color(Color("566372"))
 var light := DirectionalLight3D.new()
 stage.add_child(light)
 light.rotation_degrees=Vector3(-30,-25,0)
 var fill := DirectionalLight3D.new()
 stage.add_child(fill)
 fill.rotation_degrees=Vector3(-20,150,0)
 fill.light_energy=.8
 var camera := Camera3D.new()
 stage.add_child(camera)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=2.3
 camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
 camera.position=Vector3(2,1.5,-4)
 camera.look_at(Vector3(0,1,0))
 var canvas := CanvasLayer.new()
 stage.add_child(canvas)
 var caption := Label.new()
 canvas.add_child(caption)
 caption.position=Vector2(6,6)
 var sheet := Image.create_empty(1440,1440,false,Image.FORMAT_RGBA8)
 var styles := ["worker","emlyn","female_peasant","erika_archer"]
 var clips := ["Idle","Walk","Idle","Walk"]
 var furniture: Node3D = load("res://town.gd").new()
 var life := Node.new()
 life.set_script(load("res://village_life.gd"))
 life.town=furniture
 for row in range(styles.size()):
  var person: CharacterBody3D = load("res://villager.gd").new()
  person.style=styles[row]
  person.occupation="Guard"
  person.life=life
  var model: Node3D=load("res://characters/"+styles[row]+".glb").instantiate()
  stage.add_child(model)
  model.rotation.y=PI
  model.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
  person.visual=model
  person.set_carry("carrots")
  if "--shields-only" in OS.get_cmdline_user_args():
   for mesh in model.find_children("*","MeshInstance3D",true,false):
    if not "EquipmentShield" in String(mesh.get_path()):mesh.visible=false
  var animator: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
  preload("res://motion_library.gd").attach(model,animator,true)
  person.animator=animator
  person.set_physics_process(false)
  for column in range(clips.size()):
   await process_frame
   caption.text=styles[row]+" - "+clips[column]
   person.animate(clips[column])
   animator.play(clips[column],0)
   animator.seek(animator.current_animation_length*(.15 if column<2 else .65),true)
   animator.advance(0)
   animator.pause()
   await process_frame
   await RenderingServer.frame_post_draw
   var frame:=root.get_texture().get_image()
   frame.convert(Image.FORMAT_RGBA8)
   frame.resize(360,360)
   sheet.blit_rect(frame,Rect2i(0,0,360,360),Vector2i(column*360,row*360))
  model.queue_free()
  person.free()
  await process_frame
 sheet.save_png(ProjectSettings.globalize_path("res://../review/shields-only.png" if "--shields-only" in OS.get_cmdline_user_args() else "res://../review/carrier-postures.png"))
 life.free()
 furniture.free()
 quit()


