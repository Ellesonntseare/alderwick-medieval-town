extends RefCounted

static func update(person: Node) -> String:
	if not person.guard_label.is_empty():
		var working: bool=person.life.town.day_night.night==(person.guard_shift=="night")
		if person.night_schedule:return "I am returning to my post at "+person.guard_label+"." if working else "I am going home to sleep after my "+person.guard_shift+" watch."
		return "I am keeping watch at "+person.guard_label+". This is my "+person.guard_shift+" shift."
	if not person.recent_events.is_empty():return person.recent_events[-1].text+(" I have another crate to take over now." if not person.carry_kind.is_empty() else "")
	if not person.carry_kind.is_empty():return "I am taking "+("fresh vegetables to the market" if person.carry_kind=="carrots" else "supplies to the carpenters")+". There is another load waiting after this one."
	if not person.job.is_empty():
		match String(person.job.kind):
			"farm":return "I am checking the carrots before carrying a fresh crate to the market."
			"carpentry":return "I have a stool to finish. The joints need checking before it leaves the workbench."
			"supply":return "I am collecting a supply crate from the storehouse. The workers are waiting for it."
	if not person.stall_name.is_empty():return "I am looking after the "+person.stall_name+". Fresh deliveries help keep the display full."
	return "I have been "+person.work_description().to_lower()+". I have a moment before the next errand."

static func news(person: Node) -> String:
	if person.heard_events.is_empty():return "It is good to catch up. I will look out for you when I am next in the square."
	var event: Dictionary=person.heard_events[-1]
	var action: String={"delivery":"brought fresh vegetables to the market","supply":"delivered supplies to the workyard","crafted":"finished a wooden stool","watch":"returned to the day watch"}.get(event.kind,"finished some work")
	return event.who+" "+action+" earlier. They told me about it when we stopped to talk."

static func question(person: Node) -> String:
	if not person.guard_label.is_empty():return "Has the watch at "+person.guard_label+" been quiet today?"
	match String(person.occupation):
		"Farmer":return "How are the crops today? Is another delivery ready for the market?"
		"Carpenter":return "How is the furniture coming along? Have you finished anything today?"
		"Merchant":return "Have the fresh supplies reached your part of the market?"
		"Forester":return "Have you had much to carry from the storehouse today?"
		_:return "How has your work been today? Have you had time for a break?"

static func exchange(a: Node,b: Node) -> Array[Dictionary]:
	var latest_news := news(b)
	if not a.recent_events.is_empty() and b.heard_events.is_empty():latest_news="I am glad to hear the work is moving along. The town depends on those small jobs."
	var own := update(a)
	var temperament: int=posmod(a.person_name.hash(),3)
	var reaction: String=["A steady day suits me. ","There is always another small job waiting. ","It is good when the neighbours help one another. "][temperament]
	return [{"speaker":a,"text":question(b)},{"speaker":b,"text":update(b)},{"speaker":a,"text":reaction+own},{"speaker":b,"text":latest_news}]
