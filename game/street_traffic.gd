extends RefCounted

var life: Node
var door_lines: Dictionary={}
var door_owners: Dictionary={}
var yields := 0
var crossings := 0
var max_queue := 0

func radius(person: CharacterBody3D) -> float:
	return 0.3*person.appearance_build

func moving(person: CharacterBody3D) -> bool:
	return Vector2(person.velocity.x,person.velocity.z).length()>0.15

func steer(person: CharacterBody3D,direction: Vector3,speed: float,delta: float) -> Vector3:
	var desired := direction.normalized()*speed
	var side := Vector3.UP.cross(direction).normalized()
	var adjustment := Vector3.ZERO
	var slow := 1.0
	var line_target=person.get("queue_target")
	var in_line: bool=line_target is Vector3 and line_target.is_finite()
	var single_file: bool=person.get("night_schedule")==true and person.get("home_door")!=null and (person.position.distance_to(person.home_door.global_position)<3.0 or in_line)
	for other in life.people:
		if other==person or other.posture!="standing":continue
		var gap: Vector3=other.position-person.position
		gap.y=0
		var distance := gap.length()
		var same_model: bool=person.get("style")!=null and person.get("style")==other.get("style")
		var comfort := 3.8 if same_model and not single_file else 2.1
		if distance>maxf(comfort,speed*0.8) or distance<0.001:continue
		var minimum := radius(person)+radius(other)+0.16
		if same_model and not single_file:minimum=maxf(minimum,1.7)
		var ahead := gap.dot(direction)
		if ahead< -0.3:continue
		var lateral := absf(gap.dot(side))
		if lateral>minimum+0.28:continue
		# Both directions keep to their own right. Stationary workers and
		# conversation partners retain their space while passers-by go around.
		var urgency := clampf((comfort-distance)/1.5,0,1)
		var pass_side := side
		var other_velocity := Vector3(other.velocity.x,0,other.velocity.z)
		if (other_velocity.length()<0.1 or other_velocity.dot(direction)>0.2) and gap.dot(side)>0.05:pass_side= -side
		if not single_file:adjustment+=pass_side*urgency*speed*0.95
		if ahead>0 and distance<minimum+0.42:slow=minf(slow,0.35)
	var proposal := (desired+adjustment).normalized()*speed*slow
	var probe := person.global_transform
	probe.origin.y+=0.12
	if person.test_move(probe,proposal.normalized()*maxf(0.25,speed*delta)):
		proposal=desired*slow
	# A final distance check prevents walking through a person even when
	# there is no safe space for the preferred passing manoeuvre.
	for other in life.people:
		if other==person or other.posture!="standing":continue
		if absf(other.position.y-person.position.y)>1.0:continue
		var future := person.position+proposal*delta
		var minimum := radius(person)+radius(other)+0.06
		if person.get("style")!=null and person.get("style")==other.get("style") and not person.get("night_schedule") and not other.get("night_schedule"):minimum=maxf(minimum,1.35)
		var now := Vector2(person.position.x-other.position.x,person.position.z-other.position.z).length()
		var after := Vector2(future.x-other.position.x,future.z-other.position.z).length()
		if after<minimum and after<now:
			proposal=Vector3.ZERO
			if not single_file:
				var away := side if (other.position-person.position).dot(side)<=0 else -side
				for escape: Vector3 in [away*minf(speed,1.2),-away*minf(speed,1.2)]:
					if person.test_move(probe,escape.normalized()*0.20):continue
					var clear := true
					for neighbour in life.people:
						if neighbour==person or neighbour.posture!="standing":continue
						var before_gap := Vector2(person.position.x-neighbour.position.x,person.position.z-neighbour.position.z).length()
						var next := person.position+escape*delta
						var after_gap := Vector2(next.x-neighbour.position.x,next.z-neighbour.position.z).length()
						if after_gap<radius(person)+radius(neighbour)+0.06 and after_gap<before_gap:clear=false;break
					if clear:proposal=escape;break
			yields+=1
			break
	return proposal

func request_door(person: CharacterBody3D,door: Node3D) -> int:
	if not door_lines.has(door):door_lines[door]=[]
	var line: Array=door_lines[door]
	if not line.has(person):line.append(person)
	max_queue=maxi(max_queue,line.size())
	# Someone already inside clears the threshold before a newcomer enters.
	# Ownership during an actual crossing is retained until it completes.
	var exiting: bool=person.get("night_stage") in ["exit_walk","exit_approach","leaving"]
	var owner: CharacterBody3D=door_owners.get(door)
	if exiting and owner and owner!=person and owner.get("night_stage") in ["approach","door_approach"]:
		door_owners.erase(door)
		line.erase(person)
		line.push_front(person)
	if door_owners.get(door)==person:return -1
	if not is_instance_valid(door_owners.get(door)) and line[0]==person:
		# Keep the threshold free for a player already using it.
		var local: Vector3=door.get_closed_transform().affine_inverse()*life.town.player.position
		if absf(local.z)>0.9 or local.x< -0.4 or local.x>door.width+0.4:
			door_owners[door]=person
			return -1
	return line.find(person)

func release_door(person: CharacterBody3D) -> void:
	for door in door_lines:
		var line: Array=door_lines[door]
		line.erase(person)
		if door_owners.get(door)==person:
			door_owners.erase(door)
			crossings+=1

func queue_position(person: CharacterBody3D,door: Node3D,rank: int,inside := false) -> Vector3:
	var closed: Transform3D=door.get_closed_transform()
	var distance := 1.8+maxi(rank,0)*1.0
	if inside:distance=2.15+maxi(rank,0)*0.9
	var target: Vector3=closed*Vector3(door.width/2,0.04,distance if inside else -distance)
	if inside:return target
	return target
