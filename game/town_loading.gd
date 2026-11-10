extends CanvasLayer

var town: Node
var status: Label
var progress: ProgressBar
var previous_3d_disabled := false
var last_stage: String

func _ready() -> void:
	town=get_parent();layer=50
	var viewport := get_viewport()
	previous_3d_disabled = viewport.disable_3d
	viewport.disable_3d = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background:=ColorRect.new();background.color=Color("14251f");add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre:=CenterContainer.new();add_child(centre);centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column:=VBoxContainer.new();column.custom_minimum_size.x=minf(550, get_viewport().get_visible_rect().size.x - 48);column.add_theme_constant_override("separation",20);centre.add_child(column)
	var title:=Label.new();title.text="A L D E R W I C K";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",32);column.add_child(title)
	status=Label.new();status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(status)
	progress=ProgressBar.new();progress.custom_minimum_size.y=20;progress.show_percentage=false;column.add_child(progress)
	stage("Preparing the town…",5)

func stage(text: String,value: float) -> void:
	status.text = text
	progress.value = value
	if town.join_started >= 0 and not text.begins_with("Preparing neighbours") and last_stage != text:
		print("TOWN_JOIN_STAGE elapsed_ms=", Time.get_ticks_msec() - town.join_started, " ", text)
		last_stage = text

func _process(_delta: float) -> void:
	if not town.session or not town.session.ready_for_use or not town.session.systems_ready():return
	get_viewport().disable_3d = previous_3d_disabled
	town.set_meta("world_loading", false)
	town.loading_screen = null
	if town.view_mode != 1 and not preload("res://mobile_runtime.gd").enabled():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if town.join_started >= 0:
		print("TOWN_JOIN_READY elapsed_ms=", Time.get_ticks_msec() - town.join_started, " inside=", town.home_district.inside, " view=", town.view_mode)
	queue_free()
