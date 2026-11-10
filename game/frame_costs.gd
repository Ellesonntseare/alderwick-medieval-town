extends RefCounted

# Opt-in tracing for an isolated benchmark. Ordinary play allocates no records.
static var enabled:=false
static var totals: Dictionary={}
static var slow: Array[Dictionary]=[]

static func reset() -> void:
	totals.clear();slow.clear();enabled=true

static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func finish(label: String,start: int,context: Variant="") -> void:
	if start==0 or not enabled:return
	var ms:=float(Time.get_ticks_usec()-start)/1000.0
	if not totals.has(label):totals[label]={"calls":0,"total_ms":0.0,"max_ms":0.0,"over_50ms":0}
	var record: Dictionary=totals[label]
	record.calls+=1;record.total_ms+=ms;record.max_ms=maxf(record.max_ms,ms)
	if ms>50:record.over_50ms+=1
	if ms<2:return
	slow.append({"task":label,"ms":ms,"context":context,"frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames()})
	if slow.size()>128:
		slow.sort_custom(func(a: Dictionary,b: Dictionary):return a.ms>b.ms)
		slow.resize(64)

static func report() -> Dictionary:
	slow.sort_custom(func(a: Dictionary,b: Dictionary):return a.ms>b.ms)
	return {"tasks":totals.duplicate(true),"slow":slow.duplicate(true)}
