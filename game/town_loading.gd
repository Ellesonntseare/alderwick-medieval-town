extends CanvasLayer

var town: Node
var status: Label
var progress: ProgressBar

func _ready() -> void:
	town=get_parent();layer=50
	var background:=ColorRect.new();background.color=Color("14251f");add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre:=CenterContainer.new();add_child(centre);centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column:=VBoxContainer.new();column.custom_minimum_size.x=550;column.add_theme_constant_override("separation",20);centre.add_child(column)
	var title:=Label.new();title.text="A L D E R W I C K";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",32);column.add_child(title)
	status=Label.new();status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(status)
	progress=ProgressBar.new();progress.custom_minimum_size.y=20;progress.show_percentage=false;column.add_child(progress)
	stage("Preparing the town…",5)

func stage(text: String,value: float) -> void:
	status.text=text;progress.value=value

func _process(_delta: float) -> void:
	if town.life and town.life.navigation_ready and town.home_district and town.home_district.ready_for_spawn:
		town.set_meta("world_loading",false);town.loading_screen=null;queue_free()
