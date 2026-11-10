extends RefCounted

# Ownership changes once, at the contact frame. Cancelling never undoes a
# committed transfer or removes the prop. Callers validate their own targets.
var active:=false
var committed:=false
var elapsed:=0.0
var duration:=1.2
var contact:=.55
var kind:=""
var clip:=""
var animator: AnimationPlayer
var transfer: Callable
var completed: Callable

func begin(player: AnimationPlayer,action: String,on_contact: Callable,on_done: Callable=Callable()) -> bool:
	if active or not is_instance_valid(player):return false
	var candidates: Array=["Interact","PickUp"] if action=="handover" else ["PickUp","WorkHarvest","Interact"]
	clip=""
	for candidate: String in candidates:
		if player.has_animation(candidate):clip=candidate;break
	if clip.is_empty():return false
	animator=player;kind=action;transfer=on_contact;completed=on_done
	active=true;committed=false;elapsed=0;duration=1.15 if action=="handover" else 1.35
	contact=.52 if action=="handover" else .58 if action=="pickup" else .62
	var length:=maxf(.01,animator.get_animation(clip).length)
	animator.speed_scale=1
	animator.play(clip,.12,(-1.0 if action=="place" else 1.0)*length/duration,action=="place")
	return true

func ratio() -> float:return clampf(elapsed/duration,0,1)

func tick(delta: float) -> void:
	if not active:return
	if not is_instance_valid(animator):cancel();return
	elapsed+=maxf(0,delta)
	if not committed and ratio()>=contact:
		if not transfer.is_valid() or transfer.call()!=true:cancel();return
		if not active:return
		committed=true
	if elapsed>=duration:
		finish()

func cancel() -> void:
	if not active:return
	if is_instance_valid(animator) and animator.current_animation==clip:animator.stop(true)
	finish()

func finish() -> void:
	active=false
	var done:=completed
	transfer=Callable()
	completed=Callable()
	if done.is_valid():done.call()
