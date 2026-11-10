extends SceneTree
class Events extends "res://town_events.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var events:=Events.new();root.add_child(events)
	events.save_path="user://events-background-functional-review.json"
	events.records={"delivery":{"id":"delivery","text":"A supply delivery arrived."}}
	events.knowledge={"Ada":{"delivery":"I witnessed this nearby."}}
	events.save_state(true)
	events.knowledge.Ada.delivery="A later conversation."
	assert(events.save_writer.flush()==OK)
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(events.save_path))
	assert(saved.events.delivery.text=="A supply delivery arrived.")
	assert(saved.knowledge.Ada.delivery=="I witnessed this nearby.")
	events.save_state()
	saved=JSON.parse_string(FileAccess.get_file_as_string(events.save_path))
	assert(saved.knowledge.Ada.delivery=="A later conversation.")
	events.records["closing"]={"text":"Last queued event."};events.save_state(true)
	events.free()
	saved=JSON.parse_string(FileAccess.get_file_as_string("user://events-background-functional-review.json"))
	assert(saved.events.closing.text=="Last queued event.")
	print("EVENTS_SAVE_REVIEW_COMPLETE immutable_snapshot=true manual_readable=true shutdown_flush=true")
	quit()
