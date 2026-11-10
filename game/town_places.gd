extends Node

var town: Node3D
var clock:=0.0
var work_clock:=0.0
var notices: Array[Label3D]=[]
var output: Node3D
var output_count:=0

func _ready() -> void:
	town=get_parent()
	setup.call_deferred()

func setup() -> void:
	while not town.life.navigation_ready:await get_tree().process_frame
	for point: Vector3 in [Vector3(5,0,-18),Vector3(-10,0,17),Vector3(107,0,-65)]:
		var board:=Node3D.new();town.add_child(board);board.position=point
		town.box(board,Vector3(.12,2.3,.12),Vector3(0,1.15,0),Color("604b35"),false)
		town.box(board,Vector3(2.5,1.1,.1),Vector3(0,1.9,0),Color("4e3e2d"),false)
		var notice:=Label3D.new();board.add_child(notice);notice.position=Vector3(0,1.9,.065)
		notice.font_size=20;notice.pixel_size=.004;notice.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		notices.append(notice)
	for person in town.life.people:
		if person.person_name=="Sven" and person.indoor_house:
			output=Node3D.new();person.indoor_house.add_child(output)
			output.position=Vector3(-1.5,0,1)
	update_boards()

func news() -> Array[String]:
	var events: Array[String]=[]
	for mission in town.adventures.definitions:
		if town.adventures.progress[mission.id].status!="complete":continue
		var line: String={"missing_delivery":"Ada's misplaced greens have reached the square market.","wagon_fittings":"Oren's supply wagon has its replacement fittings.","overdue_surveyor":"Ansel has checked in safely from the western gatehouse."}.get(mission.id,mission.get("result_news",mission.summary))
		events.append(line)
	return events

func update_boards() -> void:
	var lines:=news()
	var latest: String=lines[-1] if not lines.is_empty() else "Winter Fair preparations · ask neighbours how to help."
	for notice in notices:
		notice.text="ALDERWICK NEWS\n"+latest+"\nSquare market: %d vegetable portions"%int(town.jobs.markets.city.stock)

func _process(delta: float) -> void:
	if not town.life.navigation_ready:return
	clock+=delta;work_clock+=delta
	if clock>5:
		clock=0;update_boards()
		for person in town.life.people:
			var nearby:=false
			for board in notices:
				if person.position.distance_to(board.global_position)<7:nearby=true
			if not nearby:continue
			for text in news():
				var heard:=false
				for event in person.heard_events:
					if event.get("text","")==text:heard=true
				if not heard:person.heard_events.append({"text":text,"source":"a public notice near me"})
				if person.heard_events.size()>20:person.heard_events.pop_front()
	if work_clock>20:
		work_clock=0
		if town.day_night.night or not output:return
		for person in town.life.people:
			if person.person_name!="Sven" or person.talking or person.posture!="standing":continue
			if output_count<3:
				town.detailed_prop("Stool",output,Vector3(output_count*.65,0,0),Vector3(.45,.48,.45),false)
				output_count+=1
			person.recent_events.append({"text":"I finished a stool in the castle workshop.","kind":"crafted"})
			if person.recent_events.size()>20:person.recent_events.pop_front()
			town.jobs.furniture_made+=1;town.economy.pay(person,"crafted")
