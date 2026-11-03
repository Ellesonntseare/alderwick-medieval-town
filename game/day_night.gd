extends Node

var town: Node3D
var enabled := false
var phase := 0.5
var cycle_seconds := 60.0
var night := false
var sun: DirectionalLight3D
var environment: Environment
var clock_label: Label
var toggle: CheckBox

func _ready() -> void:
	town=get_parent()
	sun=town.get_node("Sun")
	environment=town.get_node("WorldEnvironment").environment

func set_enabled(value: bool) -> void:
	var was_enabled := enabled
	enabled=value
	if toggle:toggle.set_pressed_no_signal(value)
	if not enabled:
		phase=0.5
		apply_time()
		set_night(false)
	else:
		if not was_enabled:phase=0.70
		apply_time()

func _process(delta: float) -> void:
	if enabled:
		phase=fposmod(phase+delta/cycle_seconds,1.0)
		apply_time()
	if clock_label:
		var minutes := int(phase*1440)
		clock_label.text=("Night" if night else "Day")+" · %02d:%02d"%[minutes/60,minutes%60] if enabled else "Daylight · cycle off"

func apply_time() -> void:
	var daylight := smoothstep(-0.18,0.3,-cos(phase*TAU))
	sun.rotation_degrees=Vector3(-maxf(8.0,sin((phase-0.25)*TAU)*65.0),-32,0)
	sun.light_energy=lerpf(0.06,0.72,daylight)
	sun.light_color=Color("9cadde").lerp(Color("fff0d8"),daylight)
	environment.ambient_light_energy=lerpf(0.15,0.28,daylight)
	environment.ambient_light_color=Color("6b82b3").lerp(Color("d4dbdd"),daylight)
	environment.fog_light_color=Color("26334e").lerp(Color("cbd4be"),daylight)
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	sky_material.sky_top_color=Color("080f24").lerp(Color("7198b5"),daylight)
	sky_material.sky_horizon_color=Color("273752").lerp(Color("e7dac0"),daylight)
	sky_material.ground_horizon_color=Color("26314a").lerp(Color("d9d3b4"),daylight)
	for lamp in get_tree().get_nodes_in_group("street_lamps"):lamp.light_energy=lerpf(2.0,0.5,daylight)
	set_night(phase>=0.77 or phase<0.24)

func set_night(value: bool) -> void:
	if value==night:return
	night=value
	if town.life and town.life.navigation_ready:town.life.set_night_routine(night)
