extends SceneTree

class Economy extends Node:
	func player_buy() -> void:pass
	func player_sell() -> void:pass

class Town extends Node:
	var economy: Node

class Life extends Node:
	var town: Node
	var ai: Node
	var hint: Label
	var talk_button: Button
	var dialog: PanelContainer
	var heading: Label
	var transcript: RichTextLabel
	var entry: TextEdit
	var trade_row: HBoxContainer
	var trade_status: Label
	var nearest: Node
	func close_dialog() -> void:pass
	func send_entry() -> void:pass
	func open_dialog(_person: Node) -> void:pass

func _initialize() -> void:
	run.call_deferred()

func inspect(control: Node,level := 0) -> void:
	if control is Control:print("PANEL_METRIC "," ".repeat(level),control.get_class()," rect=",control.get_rect()," minimum=",control.get_combined_minimum_size()," custom=",control.custom_minimum_size)
	for child in control.get_children():inspect(child,level+1)

func run() -> void:
	root.size=Vector2i(1280,800)
	var life := Life.new()
	root.add_child(life)
	life.town=Town.new()
	life.town.economy=Economy.new()
	life.town.add_child(life.town.economy)
	life.add_child(life.town)
	life.ai=Node.new()
	life.add_child(life.ai)
	life.ai.set_script(load("res://town_dialogue.gd"))
	life.ai.set_process(false)
	life.ai.life=life
	preload("res://dialogue_panel.gd").build(life)
	life.heading.text="Edric · Guard"
	life.ai.status.text="Conversations are loading…"
	life.trade_row.hide()
	life.dialog.show()
	for frame in range(5):await process_frame
	life.ai.layout()
	for frame in range(5):await process_frame
	inspect(life.dialog)
	var send_rect: Rect2=life.ai.submit.get_global_rect()
	var passed := send_rect.end.y<=root.size.y-15
	print("DIALOGUE_PANEL_REVIEW_COMPLETE passed=",passed," send=",send_rect," viewport=",root.size)
	quit(0 if passed else 1)
