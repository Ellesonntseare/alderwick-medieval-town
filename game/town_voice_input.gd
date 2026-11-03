extends Node

const Phone=preload("res://mobile_runtime.gd")

signal transcribed(text: String)
var ai: Node
var selector: OptionButton
var controls: VBoxContainer
var devices: OptionButton
var record_button: Button
var auto_send: CheckBox
var notice: Label
var level: ProgressBar
var microphone: AudioStreamPlayer
var capture: AudioEffectCapture
var bus_name := "AlderwickMicrophone"
var recording := false
var recognizing := false
var samples := PackedFloat32Array()
var elapsed := 0.0
var sample_rate := 48000
var generation := 0
var request: HTTPRequest

func build(owner: Node,column: VBoxContainer) -> void:
	ai=owner
	var row := HBoxContainer.new()
	column.add_child(row)
	selector=OptionButton.new()
	selector.add_item("Type a message")
	selector.add_item("Use microphone")
	selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(selector)
	selector.item_selected.connect(func(index: int):controls.visible=index==1;if index==0:cancel())
	controls=VBoxContainer.new()
	column.add_child(controls)
	devices=OptionButton.new()
	devices.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	devices.tooltip_text="Choose your microphone"
	for device in AudioServer.get_input_device_list():devices.add_item(device)
	devices.item_selected.connect(func(index: int):cancel();AudioServer.input_device=devices.get_item_text(index))
	controls.add_child(devices)
	record_button=Button.new()
	record_button.text="Start speaking  [Ctrl+Space]"
	record_button.pressed.connect(toggle)
	controls.add_child(record_button)
	level=ProgressBar.new()
	level.custom_minimum_size.y=6
	level.show_percentage=false
	controls.add_child(level)
	auto_send=CheckBox.new()
	auto_send.text="Send when I finish speaking"
	auto_send.button_pressed=true
	auto_send.add_theme_font_size_override("font_size",12)
	controls.add_child(auto_send)
	notice=Label.new()
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	notice.text="Press to record, then press again to finish. Up to 20 seconds."
	notice.add_theme_font_size_override("font_size",12)
	controls.add_child(notice)
	controls.hide()

func _input(event: InputEvent) -> void:
	if not ai or not ai.life.active or not selector or selector.selected!=1:return
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.physical_keycode==KEY_SPACE:
		toggle()
		get_viewport().set_input_as_handled()

func ensure_capture() -> void:
	if microphone:return
	var index := AudioServer.get_bus_index(bus_name)
	if index<0:
		index=AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(index,bus_name)
	# Capture precedes muting: microphone audio never feeds the speakers.
	capture=AudioEffectCapture.new()
	capture.buffer_length=1.0
	AudioServer.add_bus_effect(index,capture)
	AudioServer.set_bus_mute(index,true)
	microphone=AudioStreamPlayer.new()
	microphone.bus=bus_name
	add_child(microphone)

func toggle() -> void:
	if recording:finish();return
	if recognizing or ai.waiting:return
	if not ai.town.speech or not ai.town.speech.available:
		notice.text="Voice service is loading. You can still type a message."
		if ai.town.speech:ai.town.speech.check_health()
		return
	if not ai.town.speech.recognition_available:
		notice.text="Microphone recognition is unavailable. You can still type."
		return
	begin()

func begin(source: AudioStream=null) -> void:
	if OS.has_feature("Android"):
		OS.request_permissions()
	if recording or recognizing:return
	ensure_capture()
	generation+=1
	samples.clear()
	elapsed=0
	sample_rate=AudioServer.get_mix_rate()
	capture.clear_buffer()
	microphone.stream=source if source else AudioStreamMicrophone.new()
	if ai.town.speech:ai.town.speech.set_listening(true)
	microphone.play()
	recording=true
	record_button.text="Finish speaking  [Ctrl+Space]"
	notice.text="Listening…"

func drain() -> void:
	if not capture:return
	var frames := capture.get_buffer(capture.get_frames_available())
	var energy := 0.0
	for frame in frames:
		var value: float=(frame.x+frame.y)*0.5
		samples.append(value)
		energy+=value*value
	if not frames.is_empty():level.value=clampf(sqrt(energy/frames.size())*600,0,100)

func _process(delta: float) -> void:
	if not recording:return
	elapsed+=delta
	drain()
	notice.text="Listening… "+str(ceili(elapsed))+" / 20 seconds"
	if elapsed>=20:finish()

func wav_buffer() -> PackedByteArray:
	var output := PackedByteArray()
	output.resize(44+samples.size()*2)
	for spec in [[0,"RIFF"],[8,"WAVEfmt "],[36,"data"]]:
		var bytes: PackedByteArray=spec[1].to_ascii_buffer()
		for index in range(bytes.size()):output[spec[0]+index]=bytes[index]
	output.encode_u32(4,36+samples.size()*2)
	output.encode_u32(16,16)
	output.encode_u16(20,1)
	output.encode_u16(22,1)
	output.encode_u32(24,sample_rate)
	output.encode_u32(28,sample_rate*2)
	output.encode_u16(32,2)
	output.encode_u16(34,16)
	output.encode_u32(40,samples.size()*2)
	for index in range(samples.size()):output.encode_s16(44+index*2,roundi(clampf(samples[index],-1,1)*32767))
	return output

func finish() -> void:
	if not recording:return
	drain()
	recording=false
	microphone.stop()
	record_button.text="Start speaking  [Ctrl+Space]"
	level.value=0
	if ai.town.speech:ai.town.speech.set_listening(false)
	if samples.size()<sample_rate*.3:
		notice.text="That was too short. Press again and speak a little longer."
		samples.clear()
		return
	var ticket := generation
	var person: Node=ai.life.active
	var dialogue_ticket: int=ai.generation
	recognizing=true
	record_button.disabled=true
	notice.text="Turning your speech into words…"
	request=HTTPRequest.new()
	add_child(request)
	request.timeout=60
	var call := request
	call.request_completed.connect(func(_result: int,code: int,_headers: PackedStringArray,body: PackedByteArray):
		call.queue_free()
		if ticket!=generation:return
		recognizing=false
		record_button.disabled=false
		if ai.generation!=dialogue_ticket or ai.life.active!=person:return
		var result=JSON.parse_string(body.get_string_from_utf8()) if code==200 else null
		if not (result is Dictionary):notice.text="I could not understand that recording. Try again or type.";return
		var text: String=String(result.get("text","")).strip_edges()
		if text.is_empty():notice.text="No speech was heard. Check your microphone and try again.";return
		ai.life.entry.text=text
		notice.text="Heard: "+text
		transcribed.emit(text)
		if auto_send.button_pressed:ai.send(text)
		else:ai.life.entry.grab_focus())
	var data := wav_buffer()
	samples.clear()
	var error := call.request_raw(Phone.backend_url(34319)+"/transcribe",PackedStringArray(["Content-Type: audio/wav"]),HTTPClient.METHOD_POST,data)
	if error!=OK:
		recognizing=false
		record_button.disabled=false
		call.queue_free()
		notice.text="The voice service could not be reached. You can still type."

func cancel() -> void:
	generation+=1
	recording=false
	recognizing=false
	samples.clear()
	if microphone:microphone.stop()
	if capture:capture.clear_buffer()
	if is_instance_valid(request):request.cancel_request();request.queue_free()
	if ai and ai.town.speech:ai.town.speech.set_listening(false)
	if record_button:record_button.text="Start speaking  [Ctrl+Space]";record_button.disabled=false
	if level:level.value=0
	if notice:notice.text="Press to record, then press again to finish. Up to 20 seconds."

func _exit_tree() -> void:
	if microphone:microphone.stop()
	var index := AudioServer.get_bus_index(bus_name)
	if index>=0:AudioServer.remove_bus(index)

