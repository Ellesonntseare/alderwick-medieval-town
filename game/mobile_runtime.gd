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
var actions: GridContainer
var preferences: AcceptDialog
var control_scale:=1.0
var look_sensitivity:=1.0
var dead_zone:=.12
var invert_look:=false
var use_button: Button

func load_controls() -> void:
	if not FileAccess.file_exists("user://touch-settings.json"):return
	var saved=JSON.parse_string(FileAccess.get_file_as_string("user://touch-settings.json"))
	if not saved is Dictionary:return
	control_scale=clampf(float(saved.get("scale",1)),.8,1.35)
	look_sensitivity=clampf(float(saved.get("sensitivity",1)),.3,2)
	dead_zone=clampf(float(saved.get("dead_zone",.12)),0,.35)
	invert_look=bool(saved.get("invert",false))

func save_controls() -> void:
	var file:=FileAccess.open("user://touch-settings.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"scale":control_scale,"sensitivity":look_sensitivity,"dead_zone":dead_zone,"invert":invert_look}))

func reset_touches() -> void:
	move_axis=Vector2.ZERO;joystick_touch=-1;look_touch=-1
	if stick:stick.position=Vector2(58,58)
	if using_workbench:held_key(KEY_E,false);using_workbench=false

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:reset_touches()

func layout_controls() -> void:
	joystick.scale=Vector2.ONE*control_scale
	joystick.offset_top=-30-170*control_scale
	joystick.offset_bottom=joystick.offset_top+170
	actions.scale=Vector2.ONE*control_scale
	actions.offset_left=-20-290*control_scale;actions.offset_top=-20-246*control_scale
	actions.offset_right=actions.offset_left+290;actions.offset_bottom=actions.offset_top+246

func build_preferences(root: Control) -> void:
	preferences=AcceptDialog.new();preferences.title="Touch controls";root.add_child(preferences)
	var column:=VBoxContainer.new();column.custom_minimum_size.x=420;preferences.add_child(column)
	for spec in [["Button and joystick size",.8,1.35,control_scale],["Look sensitivity",.3,2.0,look_sensitivity],["Joystick dead zone",0,.35,dead_zone]]:
		var label:=Label.new();label.text=spec[0];column.add_child(label)
		var slider:=HSlider.new();slider.min_value=spec[1];slider.max_value=spec[2];slider.step=.01;slider.value=spec[3];slider.custom_minimum_size.y=42;column.add_child(slider)
		var title: String=spec[0]
		slider.value_changed.connect(func(value: float):
			if title=="Button and joystick size":control_scale=value;layout_controls()
			elif title=="Look sensitivity":look_sensitivity=value
			else:dead_zone=value
			save_controls())
	var invert:=CheckBox.new();invert.text="Invert vertical look";invert.button_pressed=invert_look;invert.custom_minimum_size.y=48;column.add_child(invert)
	invert.toggled.connect(func(value: bool):invert_look=value;save_controls())

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
	load_controls()
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
	actions=GridContainer.new();actions.columns=2;root.add_child(actions)
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.offset_left=-310;actions.offset_top=-205;actions.offset_right=-20;actions.offset_bottom=-20
	actions.add_theme_constant_override("h_separation",10);actions.add_theme_constant_override("v_separation",10)
	button(actions,"Talk",talk)
	var use:=button(actions,"Use",use_nearby)
	use_button=use
	use.button_down.connect(begin_use)
	use.button_up.connect(func():
		if using_workbench:held_key(KEY_E,false)
		using_workbench=false)
	button(actions,"Jump",func():town.player.jump_requested=true)
	var run:=button(actions,"Run",func():pass);run.toggle_mode=true;run.toggled.connect(func(value: bool):running=value)
	button(actions,"View",func():town.toggle_view();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE)
	button(actions,"Menu",func():town.toggle_menu())
	button(actions,"Activities",func():town.interior_activities.open())
	button(actions,"Controls",func():reset_touches();preferences.popup_centered())
	build_preferences(root);layout_controls()
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
	if town.get("home_district") and town.home_district.prompt and not town.home_district.prompt.text.is_empty():
		if Time.get_ticks_msec()-town.home_district.transferred_at>700:
			if town.home_district.inside:town.home_district.leave_home()
			else:town.home_district.enter_home()
		return
	if not town.player.resting.is_empty():town.player.stand_from_furniture();return
	if town.adventures:
		var task: String=town.adventures.nearby_task()
		if not task.is_empty():town.adventures.use_task(task);return
	if town.life.nearest_furniture and (not town.life.nearest_door or town.life.nearest_furniture.global_position.distance_to(town.player.position)<town.life.nearest_door.global_position.distance_to(town.player.position)):
		town.player.use_furniture(town.life.nearest_furniture,"sitting" if town.life.nearest_furniture.is_in_group("seats") else "sleeping")
	elif town.life.nearest_door:town.life.nearest_door.toggle(town.player.position)

func _input(event: InputEvent) -> void:
	if not enabled() or not is_instance_valid(town) or not joystick:return
	if blocked():reset_touches();return
	if event is InputEventScreenTouch:
		if not event.pressed:
			if event.index==joystick_touch:joystick_touch=-1;move_axis=Vector2.ZERO;stick.position=Vector2(58,58)
			if event.index==look_touch:look_touch=-1
		elif joystick.get_global_rect().has_point(event.position):
			joystick_touch=event.index;joystick_origin=joystick.global_position+Vector2(85,85)*control_scale
		elif event.position.x>get_viewport().get_visible_rect().size.x*.35 and not actions.get_global_rect().has_point(event.position) and event.position.y>70:look_touch=event.index
	if event is InputEventScreenDrag:
		if event.index==joystick_touch:
			move_axis=((event.position-joystick_origin)/(65*control_scale)).limit_length(1)
			if move_axis.length()<dead_zone:move_axis=Vector2.ZERO
			stick.position=Vector2(58,58)+move_axis*55
		elif event.index==look_touch:
			if town.view_mode==1:
				town.orbit-=event.relative.x*.004*look_sensitivity;town.update_camera()
			else:
				town.player.rotation.y-=event.relative.x*.004*look_sensitivity
				var camera: Node3D=town.player.camera if town.view_mode==0 else town.player.arm
				camera.rotation.x=clampf(camera.rotation.x-event.relative.y*.004*look_sensitivity*(-1 if invert_look else 1),-1.1,.2)

func blocked() -> bool:
	if town.get("character_life") and town.character_life.view.visible():return true
	if town.get("interior_activities") and town.interior_activities.panel.visible:return true
	if town.get("player_home") and town.player_home.panel.visible:return true
	return (not town.player.enabled and town.view_mode!=1) or (town.get("builder") and town.builder.active) or town.life.active or (connection and connection.visible) or (preferences and preferences.visible)

func _process(_delta: float) -> void:
	if enabled() and Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if enabled() and is_instance_valid(town) and is_instance_valid(town.life) and controls:
		# Keep dialogs visible in this layer while suppressing world input beneath them.
		var modal: bool=(connection and connection.visible) or (preferences and preferences.visible)
		controls.visible=modal or not blocked()
		if blocked():reset_touches()
		if use_button:
			use_button.text="Stand" if not town.player.resting.is_empty() else "Use"

