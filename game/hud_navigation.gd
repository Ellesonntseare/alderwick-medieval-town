extends RefCounted

var path:=PackedVector3Array()
var searched_from:=Vector3.INF
var searched_to:=Vector3.INF
var next_search:=0

func clear() -> void:
	path.clear()
	searched_from=Vector3.INF
	searched_to=Vector3.INF
	next_search=0

static func flat_distance(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func update(town: Node,from: Vector3,to: Vector3) -> void:
	var now:=Time.get_ticks_msec()
	if now<next_search:return
	if not path.is_empty() and flat_distance(from,searched_from)<5 and flat_distance(to,searched_to)<5:return
	searched_from=from
	searched_to=to
	path=route_between(town,from,to)
	next_search=now+(5000 if path.is_empty() else 1800)

func route_between(town: Node,from: Vector3,to: Vector3) -> PackedVector3Array:
	if absf(from.y-to.y)>8 or not &"grid" in town.life:return PackedVector3Array()
	var bounds: Rect2i=town.life.grid.region
	var from_city:=bounds.has_point(Vector2i(roundi(from.x),roundi(from.z)))
	var to_city:=bounds.has_point(Vector2i(roundi(to.x),roundi(to.z)))
	if from_city and to_city:
		var local:=city_route(town.life,from,to)
		if not local.is_empty():return local
	var industry: Node=town.get("industrial_workforce")
	if not is_instance_valid(industry) or not industry.bound:return PackedVector3Array()
	var gate: Vector3=industry.gate
	if from_city==to_city:return corridor_route(industry,from,to)
	var city_point:=from if from_city else to
	var industry_point:=to if from_city else from
	var road:=corridor_route(industry,gate,industry_point)
	if road.is_empty():return PackedVector3Array()
	var city:=city_route(town.life,city_point,gate)
	if city.is_empty():return PackedVector3Array()
	city.append_array(road.slice(1))
	if not from_city:city.reverse()
	return city

func city_route(life: Node,from: Vector3,to: Vector3) -> PackedVector3Array:
	var result: PackedVector3Array=life.find_route(from,to)
	if result.is_empty() or flat_distance(result[0],from)>3 or flat_distance(result[-1],to)>3:return PackedVector3Array()
	return result

func corridor_route(industry: Node,from: Vector3,to: Vector3) -> PackedVector3Array:
	var bounds: Rect2i=industry.grid.region.grow(2)
	if not bounds.has_point(Vector2i(roundi(from.x/2),roundi(from.z/2))) or not bounds.has_point(Vector2i(roundi(to.x/2),roundi(to.z/2))):return PackedVector3Array()
	var result: PackedVector3Array=industry.route_between(from,to)
	if result.is_empty() or flat_distance(result[0],from)>4 or flat_distance(result[-1],to)>4:return PackedVector3Array()
	return result

func next_index(from: Vector3) -> int:
	var nearest:=0
	var best:=INF
	for index in range(path.size()):
		var distance:=flat_distance(path[index],from)
		if distance<best:nearest=index;best=distance
	if best>7:return -1
	if nearest+1<path.size():nearest+=1
	return nearest

func turn_hint(index: int) -> String:
	if index<1 or index>=path.size()-1:return "Follow the marked path"
	var incoming:=Vector2(path[index].x-path[index-1].x,path[index].z-path[index-1].z).normalized()
	for step in range(index,mini(path.size()-1,index+8)):
		var outgoing:=Vector2(path[step+1].x-path[step].x,path[step+1].z-path[step].z).normalized()
		var turn:=incoming.cross(outgoing)
		if absf(turn)>.65:return "Next turn right" if turn>0 else "Next turn left"
	return "Follow the marked path"
