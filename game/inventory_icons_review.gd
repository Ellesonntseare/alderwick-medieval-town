extends SceneTree
const World=preload("res://town_map_review.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(192,192);root.set_disable_input(true)
	RenderingServer.set_default_clear_color(Color("e0d3b7"))
	var town:=World.Town.new();root.add_child(town)
	var light:=DirectionalLight3D.new();town.add_child(light);light.rotation_degrees=Vector3(-30,-35,0);light.light_energy=1.4
	var fill:=DirectionalLight3D.new();town.add_child(fill);fill.rotation_degrees=Vector3(-25,140,0);fill.light_energy=.8
	var camera:=Camera3D.new();town.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.0;camera.position=Vector3(2,1.6,3);camera.look_at(Vector3(0,.5,0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ui/items"))
	var names: Array=["Timber","MetalFittings","Carrot","Stool","Table_Large","Crate_Wooden","Axe_Bronze","Anvil_Log","Book_Stack_1"]
	if "--expanded-shop-icons" in OS.get_cmdline_user_args():names=["Bed_Twin1","Lantern_Wall","Bag"]
	for asset in names:
		var holder:=Node3D.new();town.add_child(holder)
		if asset=="Timber":
			for i in range(3):town.box(holder,Vector3(1.2,.16,.25),Vector3(0,.18+i*.18,0),Color("906540"),false)
		elif asset=="MetalFittings":
			for i in range(2):
				town.box(holder,Vector3(.75,.10,.15),Vector3(0,.25+i*.35,0),Color("8c939b"),false)
				town.box(holder,Vector3(.15,.3,.15),Vector3(-.3,.38+i*.35,0),Color("8c939b"),false)
		else:town.detailed_prop(asset,holder,Vector3.ZERO,Vector3(1.2,.9,.75),false)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://ui/items/"+asset+".png")
		town.remove_child(holder);holder.free()
	print("INVENTORY_ICONS_COMPLETE count=",names.size());quit()
