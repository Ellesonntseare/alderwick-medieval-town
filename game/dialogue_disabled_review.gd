extends SceneTree

class PanelLife extends Node:
	var town: Node3D
	var ai: Node
	var active: CharacterBody3D
	var hint: Label
	var talk_button: Button
	var dialog: PanelContainer
	var heading: Label
	var transcript: RichTextLabel
	var trade_row: HBoxContainer
	var trade_status: Label
	var entry: TextEdit
	func send_entry() -> void:ai.send(entry.text)
	func close_dialog() -> void:pass
	func open_dialog(_person: Node) -> void:pass

class Economy extends Node:
	func player_buy() -> void:pass
	func player_sell() -> void:pass

class Town extends Node3D:
	var economy: Node
	var player: Node3D
	var view_mode := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var town := Town.new()
	root.add_child(town)
	town.economy=Economy.new()
	town.add_child(town.economy)
	town.player=Node3D.new()
	town.add_child(town.player)
	var life := PanelLife.new()
	life.town=town
	town.add_child(life)
	life.ai=load("res://town_dialogue.gd").new()
	life.add_child(life.ai)
	preload("res://dialogue_panel.gd").build(life)
	var speech: Node=load("res://town_speech.gd").new()
	town.add_child(speech)
	# Exercise normal startup and public entry points without --no-ai flags.
	life.ai.check_health()
	life.ai.send("A message must never leave this game")
	life.ai.health_result(0,503,PackedStringArray(),PackedByteArray())
	speech.check_health()
	speech.health_result(0,503,PackedStringArray(),PackedByteArray())
	speech.set_enabled(true)
	await process_frame
	await process_frame
	var passed: bool=not life.ai.is_processing() and not speech.is_processing()
	passed=passed and life.ai.backend_pid==0 and speech.backend_pid==0
	passed=passed and not life.ai.health_pending and not speech.available and not speech.enabled
	passed=passed and life.ai.voice_input==null and not life.entry.visible
	passed=passed and not life.ai.submit.is_visible_in_tree()
	print("DIALOGUE_DISABLED_REVIEW_COMPLETE passed=",passed," backend_pids=",life.ai.backend_pid,",",speech.backend_pid," input_hidden=",not life.entry.visible)
	quit(0 if passed else 1)
