extends SceneTree

class GatedWriter extends "res://background_json_save.gd":
	var entered:=Semaphore.new()
	var release:=Semaphore.new()
	var gate_first:=true
	var writes:=0
	func write_payload(path: String,data: Dictionary) -> Error:
		writes+=1
		if gate_first:
			gate_first=false;entered.post();release.wait()
		if data.get("force_failure",false):return ERR_FILE_CANT_WRITE
		return super.write_payload(path,data)

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var path:="user://background-save-functional-review.json"
	var other:="user://background-save-other-review.json"
	var writer:=GatedWriter.new();writer.report_failures=false
	assert(writer.save(path,{"version":1,"nested":{"value":1}},true)==OK)
	writer.entered.wait()
	# The deliberately blocked disk worker must not prevent game frames.
	var frame_before:=Engine.get_process_frames()
	for frame in range(3):await process_frame
	assert(Engine.get_process_frames()>=frame_before+2)
	assert(writer.save(path,{"version":2},true)==OK)
	var newest:={"version":3,"nested":{"value":3}}
	assert(writer.save(path,newest,true)==OK)
	newest.nested.value=999
	writer.release.post()
	assert(writer.flush()==OK)
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(saved.version==3 and saved.nested.value==3 and writer.writes==2)
	# An explicit save returns only when it is readable and cannot be overwritten
	# by an older queued snapshot that was submitted before it.
	writer.save(path,{"version":4},true)
	assert(writer.save(path,{"version":5})==OK)
	assert(JSON.parse_string(FileAccess.get_file_as_string(path)).version==5)
	writer.save(path,{"version":6},true)
	writer.save(other,{"version":7},true)
	assert(writer.flush()==OK)
	assert(JSON.parse_string(FileAccess.get_file_as_string(path)).version==6)
	assert(JSON.parse_string(FileAccess.get_file_as_string(other)).version==7)
	writer.save(path,{"force_failure":true},true)
	assert(writer.flush()==ERR_FILE_CANT_WRITE)
	assert(JSON.parse_string(FileAccess.get_file_as_string(path)).version==6)
	assert(writer.save(path,{"version":8})==OK and writer.flush()==OK)
	var invalid:="user://background-save-missing-directory-review/nested/save.json"
	assert(writer.save(invalid,{"version":1},true)==OK)
	assert(writer.flush()!=OK)
	assert(not FileAccess.file_exists(invalid))
	writer.save(path,{"version":9},true)
	writer.shutdown()
	assert(not writer.worker.is_started())
	assert(JSON.parse_string(FileAccess.get_file_as_string(path)).version==9)
	assert(writer.save(path,{"version":10},true)==ERR_UNAVAILABLE)
	assert(not FileAccess.file_exists(ProjectSettings.globalize_path(path)+writer.temporary_suffix))
	print("BACKGROUND_SAVE_REVIEW_COMPLETE frames_continue=true latest_coalesced=true detached_snapshot=true explicit_order=true multiple_paths=true errors_detected=true previous_save_preserved=true shutdown_flush=true joined=true")
	quit()
