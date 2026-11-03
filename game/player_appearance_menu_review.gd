extends SceneTree

class Life extends Node:
	var active: Node
	func close_dialog() -> void:active=null

class Town extends Node3D:
	var player: CharacterBody3D
	var menu_body: VBoxContainer
	var life: Node
	var view_mode := 1
	func set_view(mode: int) -> void:
		view_mode=mode
		player.set_view(mode)

func _initialize() -> void:run.call_deferred()

func run() -> void:
	root.size=Vector2i(1280,800)
	root.title="Player appearance menu check"
	var town := Town.new()
	root.add_child(town)
	town.menu_body=VBoxContainer.new()
	town.add_child(town.menu_body)
	town.menu_body.hide()
	town.life=Life.new()
	town.add_child(town.life)
	town.player=load("res://player.gd").new()
	town.add_child(town.player)
	town.player.set_view(1)
	var menu: Node=load("res://player_appearance_menu.gd").new()
	town.add_child(menu)
	menu.open()
	for frame in range(6):await process_frame
	var failures: Array[String]=[]
	var seen: Dictionary={}
	for skin in menu.entries:
		if seen.has(skin.base):failures.append("Repeated base model "+skin.base)
		seen[skin.base]=true
	if menu.entries.size()!=9 or menu.portraits.size()!=9:failures.append("Nine approved distinct models and actual faces must appear")
	menu.search.text="Knight"
	menu.refresh()
	if menu.grid.get_child_count()!=1:failures.append("Name search must filter skins")
	menu.search.text=""
	menu.refresh()
	for skin in menu.entries:
		if skin.id=="emlyn":menu.select(skin);break
	if menu.large_face.texture==null or not menu.details.text.contains("Emlyn"):failures.append("Selected face needs name and information")
	for frame in range(4):await process_frame
	if "--capture-skins" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../town-player-appearance-menu.png")
	menu.apply_selected(false)
	if town.player.skin_id!="emlyn" or town.view_mode!=2:failures.append("Choosing a face must change the player's skin and show third person")
	print("PLAYER_APPEARANCE_MENU_REVIEW_COMPLETE failures=",failures," unique_bases=",seen.size()," selected_skin=",town.player.skin_id)
	quit(0 if failures.is_empty() else 1)
