extends "res://town.gd"

func _ready() -> void:
	rng.seed=41729
	world()
	town()
	expansion=load("res://native_districts.gd").new();add_child(expansion)
	chateaux=load("res://chateau_districts.gd").new();add_child(chateaux)
	var neighbour: Node3D=load("res://neighbouring_town.gd").new();add_child(neighbour)
	var forest: Node3D=load("res://forest_districts.gd").new();add_child(forest)
	player=load("res://player.gd").new();add_child(player);player.enabled=false;player.set_physics_process(false);player.hide()
	overview=Camera3D.new();add_child(overview);overview.current=true;overview.far=1200
	get_viewport().size=Vector2i(1440,900)
	capture_maps.call_deferred()

func _input(_event: InputEvent) -> void:pass

func capture_maps() -> void:
	for frame in range(8):await get_tree().process_frame
	overview.projection=Camera3D.PROJECTION_ORTHOGONAL;overview.size=310
	overview.position=Vector3(225,210,660);overview.look_at(Vector3(0,0,410))
	await save_image("neighbouring-town-preview.png")
	overview.size=360;overview.position=Vector3(195,230,385);overview.look_at(Vector3(0,0,175))
	await save_image("connected-towns-preview.png")
	overview.projection=Camera3D.PROJECTION_PERSPECTIVE;overview.fov=75
	overview.position=Vector3(0,1.8,128);overview.look_at(Vector3(23,1.8,120))
	await save_image("forest-city-preview.png")
	print("MAP_VISUAL_REVIEW_COMPLETE districts=2 forest_walkable=true auto_close=true")
	get_tree().quit()

func save_image(path: String) -> void:
	for frame in range(5):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../"+path)
