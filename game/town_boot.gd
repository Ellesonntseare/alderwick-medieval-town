extends Control

const Phone=preload("res://mobile_runtime.gd")

var health: HTTPRequest
var pending:=false
var clock:=0.0
var elapsed:=0.0
var backend_pid:=0
var started:=false
var ai_ready:=false
var status: Label

func _ready() -> void:
	get_window().title="Alderwick"
	var background:=ColorRect.new();background.color=Color("14251f")
	add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre:=CenterContainer.new();add_child(centre);centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column:=VBoxContainer.new();column.custom_minimum_size=Vector2(510,0);column.add_theme_constant_override("separation",20);centre.add_child(column)
	var title:=Label.new();title.text="A L D E R W I C K";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",36);title.modulate=Color("efd7a8");column.add_child(title)
	status=Label.new();status.text="Getting conversations ready…";status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	var description:=Label.new();description.text="Your town will open when conversations are ready.\nYou can also enter now and explore while they load.";description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(description)
	var enter:=Button.new();enter.text="Enter town now";enter.custom_minimum_size.y=44;enter.pressed.connect(start_town);column.add_child(enter)
	health=HTTPRequest.new();health.timeout=2;add_child(health)
	health.request_completed.connect(health_result)
	if Phone.enabled() or "--no-ai" in OS.get_cmdline_user_args():start_town.call_deferred()
	else:check_health()

func check_health() -> void:
	if pending or started:return
	pending=true
	if health.request("http://127.0.0.1:34320/health?pid="+str(OS.get_process_id()))!=OK:pending=false

func health_result(_result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	pending=false
	if started:return
	var data=JSON.parse_string(body.get_string_from_utf8()) if code==200 else null
	ai_ready=data is Dictionary and data.get("ready",false)==true
	if ai_ready:start_town.call_deferred();return
	if code!=200 and (backend_pid==0 or not OS.is_process_running(backend_pid)):
		var executable:=ProjectSettings.globalize_path("res://../tools/speech/python/pythonw.exe")
		var script:=ProjectSettings.globalize_path("res://../tools/ai/chat_server.py")
		if FileAccess.file_exists(executable):backend_pid=OS.create_process(executable,PackedStringArray([script]),false)

func _process(delta: float) -> void:
	if started:return
	clock+=delta;elapsed+=delta
	if clock>1.5:clock=0;check_health()
	if elapsed>35:status.text="Conversations are still warming up.\nYou can enter the town whenever you like."

func start_town() -> void:
	if started:return
	started=true
	if "--validate-town-boot" in OS.get_cmdline_user_args():
		print("TOWN_BOOT_REVIEW_COMPLETE ai_ready=",ai_ready," elapsed=",elapsed)
		get_tree().quit(0 if ai_ready or "--no-ai" in OS.get_cmdline_user_args() else 1)
		return
	status.text="Opening Alderwick…"
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://town.tscn")


