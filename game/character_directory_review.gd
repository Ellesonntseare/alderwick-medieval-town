extends SceneTree

class Player extends Node3D:
	var enabled := false

class Person extends CharacterBody3D:
	var person_name := ""
	var occupation := ""
	var style := ""
	var activity := "At work in town"
	var posture := "standing"

class Life extends Node:
	var navigation_ready := true
	var people: Array[CharacterBody3D]=[]
	var active: Node
	func close_dialog() -> void:active=null
	func open_dialog(person: Node) -> void:active=person

class Town extends Node3D:
	var menu_body: VBoxContainer
	var life: Node
	var player: Node3D
	var view_mode := 1

func _initialize() -> void:run.call_deferred()

func run() -> void:
	root.size=Vector2i(1280,800)
	root.title="Character directory check"
	var town := Town.new()
	root.add_child(town)
	town.menu_body=VBoxContainer.new()
	town.add_child(town.menu_body)
	town.player=Player.new()
	town.add_child(town.player)
	town.life=Life.new()
	town.add_child(town.life)
	var appearances=JSON.parse_string(FileAccess.get_file_as_string("res://characters/roster_appearance.json"))
	for entry in appearances:
		var person := Person.new()
		person.person_name=entry.name
		person.style=entry.style
		person.occupation=entry.role
		person.set_meta("district",entry.district)
		town.add_child(person)
		town.life.people.append(person)
	var directory: Node=load("res://character_directory.gd").new()
	town.add_child(directory)
	for frame in range(8):await process_frame
	directory.open()
	for frame in range(5):await process_frame
	var failures: Array[String]=[]
	if directory.entries.size()!=53 or directory.grid.get_child_count()!=53:failures.append("All 53 residents must appear")
	if directory.portraits.size()!=53:failures.append("Every resident needs an actual rendered portrait")
	directory.search.text="Mina"
	directory.refresh()
	if directory.grid.get_child_count()!=1:failures.append("Name search must filter faces")
	directory.search.text=""
	directory.refresh()
	var mina: CharacterBody3D
	for person in town.life.people:
		if person.person_name=="Mina":mina=person
	directory.select(mina)
	if not directory.profile.text.contains("Mina") or directory.large_face.texture==null:failures.append("Selected face needs names and background")
	if directory.panel.get_rect().end.x>1280 or directory.panel.get_rect().end.y>800:failures.append("Directory must fit the screen")
	for frame in range(3):await process_frame
	if "--capture-directory" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../town-character-directory.png")
	directory.talk_selected()
	if town.life.active!=mina:failures.append("Selected resident must be passed to the chat view")
	print("CHARACTER_DIRECTORY_REVIEW_COMPLETE failures=",failures," residents=",directory.entries.size()," actual_faces=",directory.portraits.size()," selected=",mina.person_name)
	quit(0 if failures.is_empty() else 1)
