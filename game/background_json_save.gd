extends RefCounted

# The scene thread owns snapshots; the worker only sees detached Dictionaries.
# One worker serializes all writes for this owner, coalescing queued saves by
# absolute path. Explicit saves and shutdown drain older work before writing.
var worker:=Thread.new()
var mutex:=Mutex.new()
var wake:=Semaphore.new()
var completed:=Semaphore.new()
var pending: Dictionary={}
var active:=false
var stopping:=false
var failures: Dictionary={}
var notices: Array[String]=[]
var report_failures:=true
var temporary_suffix:=""

func save(path: String,data: Dictionary,background:=false) -> Error:
	report_errors()
	var absolute:=ProjectSettings.globalize_path(path)
	if not background:
		flush()
		var result:=write_payload(absolute,data)
		record_result(absolute,result)
		report_errors()
		return result
	if stopping:return ERR_UNAVAILABLE
	if not worker.is_started():
		temporary_suffix=".pending-"+str(get_instance_id())
		var result:=worker.start(run,Thread.PRIORITY_LOW)
		if result!=OK:
			record_result(absolute,result);report_errors();return result
	var snapshot:=data.duplicate(true)
	mutex.lock();pending[absolute]=snapshot;mutex.unlock()
	wake.post()
	return OK

func run() -> void:
	while true:
		wake.wait()
		mutex.lock()
		if pending.is_empty():
			var done:=stopping
			mutex.unlock()
			if done:return
			continue
		var path: String=pending.keys()[0]
		var snapshot: Dictionary=pending[path]
		pending.erase(path);active=true
		mutex.unlock()
		var result:=write_payload(path,snapshot)
		record_result(path,result)
		mutex.lock();active=false;var more:=not pending.is_empty();mutex.unlock()
		completed.post()
		if more:wake.post()

func write_payload(path: String,data: Dictionary) -> Error:
	# Replace only after a complete successful write; a failed write leaves the
	# previous save intact. No scene objects, resources or UI enter this method.
	var temporary:=path+temporary_suffix
	if temporary_suffix.is_empty():temporary=path+".pending-"+str(get_instance_id())
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if not file:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var result:=file.get_error()
	file.close()
	if result==OK:result=DirAccess.rename_absolute(temporary,path)
	if result!=OK and FileAccess.file_exists(temporary):DirAccess.remove_absolute(temporary)
	return result

func record_result(path: String,result: Error) -> void:
	mutex.lock()
	if result==OK:failures.erase(path)
	else:
		failures[path]=result
		notices.append("Could not save "+path+": "+error_string(result))
	mutex.unlock()

func flush() -> Error:
	while true:
		mutex.lock();var busy:=active or not pending.is_empty();mutex.unlock()
		if not busy:break
		completed.wait()
	mutex.lock();var result: Error=OK if failures.is_empty() else failures.values()[0];mutex.unlock()
	report_errors()
	return result

func report_errors() -> void:
	mutex.lock();var messages:=notices.duplicate();notices.clear();mutex.unlock()
	if report_failures:
		for message in messages:push_warning(message)

func shutdown() -> Error:
	var result:=flush()
	mutex.lock();stopping=true;mutex.unlock()
	if worker.is_started():
		wake.post();worker.wait_to_finish()
	return result
