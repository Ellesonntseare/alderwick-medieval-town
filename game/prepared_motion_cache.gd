extends RefCounted

# Store plain transform key data only. No scene, script, method or resource
# objects are deserialized from the writable cache.
const ROOT="user://prepared-motion-v2/"
const FORMAT:=2
static var source_keys: Dictionary={}
static var hits:=0
static var misses:=0
static var current_rig:=""
static var bucket: Dictionary={}
static var loaded:=false
static var dirty:=false

static func select_rig(id: String) -> void:
	var recipe:=FileAccess.get_file_as_string("res://motion_library.gd").sha256_text() if FileAccess.file_exists("res://motion_library.gd") else str(FORMAT)
	current_rig=(id+recipe+str(FORMAT)).sha256_text();bucket={};loaded=false;dirty=false

static func load_bucket() -> void:
	if loaded:return
	loaded=true
	var file:=FileAccess.open_compressed(ROOT+current_rig+"-rig.cache",FileAccess.READ,FileAccess.COMPRESSION_ZSTD)
	if not file or file.get_length()>64_000_000:return
	var data: Variant=file.get_var(false);file.close()
	if data is Dictionary and data.get("id")==current_rig and data.get("clips") is Dictionary:bucket=data.clips

static func finish_rig() -> void:
	if dirty:
		write_file(current_rig+"-rig",{"id":current_rig,"clips":bucket})
	current_rig="";bucket={};loaded=false;dirty=false

static func snapshot(clip: Animation) -> Dictionary:
	var tracks: Array=[]
	for index in range(clip.get_track_count()):
		tracks.append({"type":clip.track_get_type(index),"path":String(clip.track_get_path(index)),"interp":clip.track_get_interpolation_type(index),"wrap":clip.track_get_interpolation_loop_wrap(index),"enabled":clip.track_is_enabled(index),"keys":clip.get("tracks/"+str(index)+"/keys")})
	return {"length":clip.length,"loop":clip.loop_mode,"step":clip.step,"tracks":tracks}

static func key(rig_key: String,name: String,source: Animation,rests: Dictionary) -> String:
	if not source_keys.has(name):
		var recipe:=FileAccess.get_file_as_string("res://motion_library.gd").sha256_text() if FileAccess.file_exists("res://motion_library.gd") else str(FORMAT)
		source_keys[name]=var_to_bytes([FORMAT,recipe,snapshot(source),rests]).hex_encode().sha256_text()
	return (rig_key+":"+name+":"+String(source_keys[name])).sha256_text()

static func restore(id: String,rig: Skeleton3D,path: String) -> Animation:
	if "--no-motion-cache" in OS.get_cmdline_user_args():return null
	if not current_rig.is_empty():
		load_bucket()
		var prepared: Animation=decode(bucket[id],rig,path) if bucket.get(id) is Dictionary else null
		if prepared:hits+=1
		else:misses+=1
		return prepared
	var file:=FileAccess.open_compressed(ROOT+id+".cache",FileAccess.READ,FileAccess.COMPRESSION_ZSTD)
	if not file or file.get_length()>8_000_000:misses+=1;return null
	var data: Variant=file.get_var(false)
	file.close()
	if not data is Dictionary or data.get("id")!=id or not data.get("clip") is Dictionary:misses+=1;return null
	var clip:=decode(data.clip,rig,path)
	if clip:hits+=1
	else:misses+=1
	return clip

static func decode(data: Dictionary,rig: Skeleton3D,path: String) -> Animation:
	if not data.get("tracks") is Array or data.tracks.size()>512:return null
	if not (data.get("length") is float or data.get("length") is int):return null
	var length:=float(data.length)
	if not is_finite(length) or length<0 or length>600:return null
	if int(data.get("loop",-1)) not in [Animation.LOOP_NONE,Animation.LOOP_LINEAR,Animation.LOOP_PINGPONG]:return null
	var step:=float(data.get("step",0))
	if not is_finite(step) or step<=0:return null
	for record in data.tracks:
		if not record is Dictionary or record.get("type") not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:return null
		if not record.get("path") is String or not record.get("keys") is PackedFloat32Array:return null
		var target:=NodePath(record.path)
		if target.get_subname_count()!=1 or String(target.get_concatenated_names())!=path or rig.find_bone(String(target.get_subname(0)))<0:return null
		var stride:=6 if int(record.type)==Animation.TYPE_ROTATION_3D else 5
		if record.keys.size()%stride!=0 or record.keys.size()>1_000_000:return null
		if int(record.get("interp",-1))<0 or int(record.interp)>Animation.INTERPOLATION_CUBIC_ANGLE:return null
		var last:=-INF
		for offset in range(0,record.keys.size(),stride):
			var time: float=record.keys[offset]
			if time<0 or time<last or time>length+.001:return null
			last=time
			for component in range(stride):
				if not is_finite(float(record.keys[offset+component])):return null
	var clip:=Animation.new();clip.length=length;clip.loop_mode=int(data.loop);clip.step=step
	for record in data.tracks:
		var index:=clip.add_track(int(record.type))
		clip.track_set_path(index,NodePath(record.path))
		clip.track_set_interpolation_type(index,int(record.interp))
		clip.track_set_interpolation_loop_wrap(index,bool(record.get("wrap",true)))
		clip.track_set_enabled(index,bool(record.get("enabled",true)))
		clip.set("tracks/"+str(index)+"/keys",record.keys)
	return clip

static func save(id: String,clip: Animation) -> void:
	if "--no-motion-cache" in OS.get_cmdline_user_args():return
	if not current_rig.is_empty():
		load_bucket();bucket[id]=snapshot(clip);dirty=true
		return
	write_file(id,{"id":id,"clip":snapshot(clip)})

static func write_file(id: String,data: Dictionary) -> void:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))!=OK:return
	var path:=ROOT+id+".cache"
	var file:=FileAccess.open_compressed(path+".pending",FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
	if not file:return
	file.store_var(data)
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".pending"),ProjectSettings.globalize_path(path))
