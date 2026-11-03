extends RefCounted

const WORK := {
	"Baker":"The bread needs attention long before the square gets busy. I check the dough, mind the heat, and set aside loaves for people who cannot leave their work. A good crust matters, but feeding the neighbours matters more.",
	"Blacksmith":"Most of my day is spent repairing things people already own: a cart fitting, a worn hinge, or a tool with a damaged edge. The forge takes patience. Rush the heat and you can spoil good iron; take your time and a small repair can keep a household working for another season.",
	"Herbalist":"I sort what comes in from the fields and keep careful track of where each bundle was gathered. Some plants look alike until you take a closer look. I would rather tell someone I need more information than pretend every leaf is useful for the same thing.",
	"Innkeeper":"The tavern is part kitchen, part meeting place, and part refuge for tired travellers. I keep an eye on the tables and try to make sure quieter guests get a seat as well. You hear plenty here, though I do not repeat everything people say over supper.",
	"Guard":"I make the rounds between the gate, the square, and the training yard. Most problems are ordinary ones: a cart left in the way, an argument that needs cooling, or a traveller who cannot find the inn. Being useful is better than looking fierce.",
	"Farmer":"Farm work follows the weather more than the clock. There are supplies to move, beds to check, and animals that need a little patience. On market days I bring what is ready, and I try to leave the ground in good condition for the next crop.",
	"Merchant":"I arrange the display so people can see what is fresh, then answer questions and keep the counter tidy. A regular customer notices when you take care with small things. I would rather have them come back next week than hurry them into a choice today.",
	"Weaver":"Cloth is a great many small decisions repeated carefully. I sort the fibres, check the tension, and look for a flaw before it grows into a larger problem. You can tell quite a lot about a piece of work by how its edges have been finished.",
	"Carpenter":"Timber has a character of its own. I check the grain and the joints before deciding how a piece should be used. A sound chair or a door that hangs properly may not attract much praise, but people notice very quickly when either one fails.",
	"Brewer":"I keep the vessels clean, check the stores, and make sure each batch gets the time it needs. It is quieter work than people expect. Much of the skill is knowing when to leave something alone and when a small change really needs attention.",
	"Miller":"The mill depends on steady motion and regular checks. Grain, sacks, and machinery all need attention, and the weather can change what the day allows. When the work goes well, several other trades in town can get on with theirs.",
	"Forester":"I make the rounds near the woodland and watch the condition of the paths and trees. Not every fallen branch needs moving, and not every good tree ought to be cut. The town needs timber, but it needs a healthy wood next year as well.",
	"Stable keeper":"Horses are easier to care for when you pay attention before they become unsettled. I check the space around them, keep supplies ready, and leave room for quiet movement. Visitors do better when they approach calmly and let an animal see them coming.",
	"Town clerk":"I keep track of requests and try to send people to the right place before a small misunderstanding wastes half a day. Much of town life depends on somebody remembering what was agreed. Clear records are less exciting than a good story, but often more useful."
}

static func reply(person: Node,message: String) -> String:
	var text := message.to_lower().strip_edges()
	var topic := "town"
	if "more" in text or "continue" in text:topic=person.last_topic
	elif "work" in text or "sell" in text or "buy" in text or "job" in text or "guard" in text or "deliver" in text or "suppl" in text or "furniture" in text or "crop" in text:topic="work"
	elif "home" in text or "live" in text or "family" in text:topic="home"
	elif "rumour" in text or "rumor" in text or "news" in text or "today" in text or "happened" in text:topic="rumours"
	elif "animal" in text or "horse" in text or "cow" in text:topic="animals"
	elif "life" in text or "yourself" in text or "feel" in text:topic="life"
	elif "name" in text or "who are" in text:topic="identity"
	elif text in ["hello","hi","hey"]:topic="greeting"
	person.last_topic=topic
	person.dialogue_turns+=1
	var followup := "more" in text or "continue" in text
	if topic=="rumours" and not person.heard_events.is_empty():return preload("res://resident_dialogue.gd").news(person)
	if topic=="rumours" and not person.recent_events.is_empty():return preload("res://resident_dialogue.gd").update(person)+" That is something I have done myself today. I would rather tell you what I know than repeat a story I cannot check."
	match topic:
		"greeting":return ("Welcome back. It is good to see you again." if person.visits>1 else "Welcome to Alderwick. I'm %s, the %s."%[person.person_name,person.occupation.to_lower()])+" I have a little time to talk. You can ask about my work, life here, the animals, or places around town. Choose a topic below, or type your own question; if you want a longer explanation, ask me to tell you more."
		"identity":return "I'm %s, and I work as the %s. I live near %s. Around here, the people at the next table are often the people whose work you depend on tomorrow, so I try to remember faces and make time for a conversation."%[person.person_name,person.occupation.to_lower(),person.home]
		"work":
			if followup:return "The part visitors rarely notice is the preparation. I check the space, the supplies, and what needs doing next before I start the visible work. When another trade is delayed, I have to adjust rather than pretend the day is going exactly to plan. That is one reason we stop to speak in the square: a few words can save a wasted trip."
			var answer: String=WORK.get(person.occupation,"I divide my day between the work that needs finishing and the errands that keep it possible. There is always something to check, tidy, or carry before a job is truly done.")
			if not person.guard_label.is_empty():answer="My post is "+person.guard_label+". I stay here for the day, watch the approach, and leave room for people using the entrance. At night I go home to sleep, then return to the same post in the morning."
			if not person.stall_name.is_empty():answer="At this stall I have "+person.stall_name+". I keep the display tidy and help visitors choose what they need. "+answer
			return preload("res://resident_dialogue.gd").update(person)+" "+answer+" If you like, I can tell you more about the daily routine."
		"home":return "I live near %s. It is good to have somewhere familiar to return after the square has quietened down. At night we head indoors, leave the paths clear, and close the doors once everyone is inside. A room does not need to be grand to feel welcoming; a sound bed, a chair, and a little light make a difference. In the morning it is back to work and seeing what the day brings."%person.home
		"animals":return "You will find cows and sheep around the farm areas, pigs near the pens, horses by the stable, and a small dog closer to town. I like the way they make a place feel lived in, but give them a little room when they move. The farm workers and stable keeper know those areas best. Listen as you approach: you may hear an animal before you see it around a building."
		"life":return "What I like about Alderwick is that a day has several different rhythms. The market is busy for a while, then people drift back to their work or stop for a short conversation. I enjoy a quiet seat when there is time for one. I would like the town to grow without losing that feeling that you can still recognise the person coming down the street."
		"rumours":return ["People have been talking about the new pottery and storehouse on the outer lanes. A new building changes more than the view: it gives people another reason to cross town and meet somebody they might otherwise miss. I am curious to see which part of the square becomes busiest as those trades settle in.","The usual subject is the weather and whether the next market day will stay dry. Someone always has a confident prediction. I find it safer to look at the sky and keep a little room in the day for surprises; a town runs better when everyone can adjust their plans.","There is plenty of talk in the tavern, but I try to separate a good story from something I know. If you want reliable directions, ask a worker about their own place. If you want a tale that grows with each telling, stay for another conversation at the tables."][person.dialogue_turns%3]
		_:return "The market square is the easiest place to get your bearings. The tavern, bakery, forge, and town hall are around the central streets; farther out are the farms, stable, woodland trades, and riverside mill. More buildings have been added along the outer lanes, including a pottery and storehouse. You can open the doors and explore the furnished rooms. Ask me about a topic that interests you, or choose Tell me more to continue."
