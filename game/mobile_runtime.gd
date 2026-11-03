extends Node

static var move_axis:=Vector2.ZERO
static var running:=false
var town: Node
var controls: CanvasLayer
var connection: AcceptDialog
var address: LineEdit
static var endpoint:=""
var joystick_touch:=-1
var look_touch:=-1
var joystick_origin:=Vector2.ZERO
var joystick: Control
var stick: ColorRect
var using_workbench:=false

static func enabled() -> bool:return OS.has_feature("Android") or "--mobile-preview" in OS.get_cmdline_user_args()

func _ready() -> void:
	if FileAccess.file_exists("user://phone-connection.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string("user://phone-connection.json"))
		if saved is Dictionary:endpoint=String(saved.get("endpoint",""))
	if enabled():
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		get_tree().node_added.connect(node_added)

static func backend_url(port: int) -> String:
	if not enabled():return "http://127.0.0.1:"+str(port)
	return endpoint.trim_suffix("/")+("/ai" if port==34320 else "/speech") if not endpoint.is_empty() else "http://127.0.0.1:1"

func node_added(node: Node) -> void:
	if node.get_script() and node.get_script().resource_path=="res://town.gd":attach.call_deferred(node)

func attach(owner: Node) -> void:
	town=owner
	while town.player==null or town.life==null:await get_tree().process_frame
	if is_instance_valid(controls):controls.queue_free()
	controls=CanvasLayer.new();controls.layer=12;add_child(controls)
	var root:=Control.new();controls.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	joystick=Control.new();root.add_child(joystick)
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left=24;joystick.offset_top=-200;joystick.offset_right=194;joystick.offset_bottom=-30
	joystick.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var base:=ColorRect.new();base.color=Color(.16,.24,.2,.55);base.size=Vector2(150,150);base.position=Vector2(10,10);base.mouse_filter=Control.MOUSE_FILTER_IGNORE;joystick.add_child(base)
	stick=ColorRect.new();stick.color=Color(.75,.8,.64,.7);stick.size=Vector2(54,54);stick.position=Vector2(58,58);stick.mouse_filter=Control.MOUSE_FILTER_IGNORE;joystick.add_child(stick)
	var actions:=GridContainer.new();actions.columns=2;root.add_child(actions)
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.offset_left=-310;actions.offset_top=-205;actions.offset_right=-20;actions.offset_bottom=-20
	actions.add_theme_constant_override("h_separation",10);actions.add_theme_constant_override("v_separation",10)
	button(actions,"Talk",talk)
	var use:=button(actions,"Use",use_nearby)
	use.button_down.connect(begin_use)
	use.button_up.connect(func():
		if using_workbench:held_key(KEY_E,false)
		using_workbench=false)
	button(actions,"Jump",func():town.player.jump_requested=true)
	var run:=button(actions,"Run",func():pass);run.toggle_mode=true;run.toggled.connect(func(value: bool):running=value)
	button(actions,"View",func():town.toggle_view();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE)
	button(actions,"Menu",func():town.toggle_menu())
	var network:=Button.new();network.text="Connect to PC AI";network.position=Vector2(20,8);network.pressed.connect(show_connection);root.add_child(network)
	connection=AcceptDialog.new();connection.title="PC conversations & voices";connection.size=Vector2i(650,240);root.add_child(connection)
	var column:=VBoxContainer.new();connection.add_child(column)
	var label:=Label.new();label.text="On your PC, open Start Phone AI.cmd.\nPaste its connection address below. Both devices need the same Wi-Fi.\nThe town works without a PC; generated dialogue and voices need this connection.";label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(label)
	address=LineEdit.new();address.placeholder_text="http://PC-IP:34322/token/your-pairing-code";address.text=endpoint;column.add_child(address)
	connection.confirmed.connect(func():
		var value:=address.text.strip_edges().trim_suffix("/")
		if not value.is_empty() and not value.begins_with("http://"):return
		endpoint=value
		var file:=FileAccess.open("user://phone-connection.json",FileAccess.WRITE);file.store_string(JSON.stringify({"endpoint":endpoint}))
		if town.life.ai:town.life.ai.URL=backend_url(34320);town.life.ai.check_health()
		if town.speech:town.speech.URL=backend_url(34319);town.speech.check_health())
	town.menu_collapsed=false;town.toggle_menu()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func button(parent: Node,text: String,action: Callable) -> Button:
	var result:=Button.new();result.text=text;result.custom_minimum_size=Vector2(135,54)
	result.add_theme_font_size_override("font_size",20);result.pressed.connect(action);parent.add_child(result);return result

func show_connection() -> void:
	address.text=endpoint;connection.popup_centered()

func held_key(key: Key,pressed: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=key;event.pressed=pressed;Input.parse_input_event(event)

func begin_use() -> void:
	using_workbench=false
	if not town.adventures:return
	var id: String=town.adventures.nearby_task()
	if id.is_empty():return
	var mission: Dictionary=town.adventures.find_mission(id)
	var step: Dictionary=mission.steps[int(town.adventures.progress[id].step)]
	if step.kind=="work":using_workbench=true;held_key(KEY_E,true)

func talk() -> void:
	if town.life.active:town.life.close_dialog()
	elif town.life.nearest:town.life.open_dialog(town.life.nearest)
	elif town.adventures and town.adventures.visitor and town.adventures.visitor.position.distance_to(town.player.position)<4:town.life.open_dialog(town.adventures.visitor)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func use_nearby() -> void:
	if not town.player.resting.is_empty():town.player.stand_from_furniture();return
	if town.adventures:
		var task: String=town.adventures.nearby_task()
		if not task.is_empty():town.adventures.use_task(task);return
	if town.life.nearest_furniture:
		town.player.use_furniture(town.life.nearest_furniture,"sitting" if town.life.nearest_furniture.is_in_group("seats") else "sleeping")
	elif town.life.nearest_door:town.life.nearest_door.toggle(town.player.position)

func _input(event: InputEvent) -> void:
	if not enabled() or not is_instance_valid(town) or not joystick:return
	if town.get("builder") and town.builder.active:move_axis=Vector2.ZERO;return
	if town.life.active or (connection and connection.visible):move_axis=Vector2.ZERO;return
	if event is InputEventScreenTouch:
		if not event.pressed:
			if event.index==joystick_touch:joystick_touch=-1;move_axis=Vector2.ZERO;stick.position=Vector2(58,58)
			if event.index==look_touch:look_touch=-1
		elif joystick.get_global_rect().has_point(event.position):
			joystick_touch=event.index;joystick_origin=joystick.global_position+Vector2(85,85)
		elif event.position.x>get_viewport().get_visible_rect().size.x*.35 and event.position.y<get_viewport().get_visible_rect().size.y-215:look_touch=event.index
	if event is InputEventScreenDrag:
		if event.index==joystick_touch:
			move_axis=((event.position-joystick_origin)/65).limit_length(1)
			stick.position=Vector2(58,58)+move_axis*55
		elif event.index==look_touch:
			if town.view_mode==1:
				town.orbit-=event.relative.x*.004;town.update_camera()
			else:
				town.player.rotation.y-=event.relative.x*.004
				var camera: Node3D=town.player.camera if town.view_mode==0 else town.player.arm
				camera.rotation.x=clampf(camera.rotation.x-event.relative.y*.004,-1.1,.2)

func _process(_delta: float) -> void:
	if enabled() and Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if enabled() and is_instance_valid(town) and is_instance_valid(town.life) and controls:
		controls.visible=not (town.get("builder") and town.builder.active) and not town.life.active

