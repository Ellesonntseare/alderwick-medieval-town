extends Control

var map: Node

func _draw() -> void:
	if not is_instance_valid(map) or not map.town.player:return
	var task: Dictionary=map.navigation_objective()
	var font:=ThemeDB.fallback_font
	if not map.opened:return
	draw_string(font,Vector2(20,30),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
	var scale_width: float=map.camera.unproject_position(map.center+Vector3(20,0,0)).x-map.camera.unproject_position(map.center).x
	draw_line(Vector2(20,size.y-25),Vector2(20+scale_width,size.y-25),Color.WHITE,3)
	draw_string(font,Vector2(20,size.y-34),"20 m",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
	var used: Array[Vector2]=[]
	for location in map.town.locations:
		var p: Array=location.position
		var screen: Vector2=map.camera.unproject_position(Vector3(p[0],0,p[2]))
		if not Rect2(Vector2.ZERO,size).has_point(screen):continue
		var clear:=true
		for previous in used:
			if absf(previous.y-screen.y)<17 and absf(previous.x-screen.x)<130:clear=false;break
		if not clear:continue
		used.append(screen)
		draw_circle(screen,3,Color("e8d6ac"))
		draw_string_outline(font,screen+Vector2(6,-5),String(location.name),HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color("17251f"))
		draw_string(font,screen+Vector2(6,-5),String(location.name),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fff1cc"))
	var player: Vector3=map.town.player.global_position
	if map.town.home_district.inside:player=map.town.home_district.porch
	var here: Vector2=map.camera.unproject_position(player)
	draw_circle(here,9,Color("183a47"));draw_circle(here,6,Color("72e5ff"))
	var heading:=Vector2(sin(-map.town.player.rotation.y),-cos(map.town.player.rotation.y))
	draw_line(here,here+heading*22,Color("72e5ff"),3,true)
	draw_string(font,here+Vector2(12,17),"YOU · inside your home" if map.town.home_district.inside else "YOU",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("9defff"))
	if not task.is_empty():
		var destination: Vector2=map.camera.unproject_position(task.point)
		var clamped:=destination.clamp(Vector2.ONE*20,size-Vector2.ONE*20)
		if not destination.is_equal_approx(clamped):
			var direction:=clamped.direction_to(destination)
			draw_colored_polygon(PackedVector2Array([clamped+direction*9,clamped-direction*5+direction.orthogonal()*6,clamped-direction*5-direction.orthogonal()*6]),Color("ffd582"))
		else:
			draw_circle(clamped,9,Color("4c371c"));draw_circle(clamped,6,Color("ffb54c"))
