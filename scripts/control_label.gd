extends Label

@export var action: String = ""
@export var action2: String = ""

func _ready():
	if action:
		if not InputMap.has_action(action):
			print("'" + action + "' is not action")
		else:
			var evs = InputMap.action_get_events(action)
			var key_names = evs.map(func (ev): return "'" + ev.as_text().replace(" (Physical)", "") + "'")
			var keys = " or ".join(PackedStringArray(key_names))
			text = text.replace("{action}", keys)
	
	if action2:
		if not InputMap.has_action(action2):
			print("'" + action2 + "' is not action")
		else:
			var evs = InputMap.action_get_events(action2)
			var key_names = evs.map(func (ev): return "'" + ev.as_text().replace(" (Physical)", "") + "'")
			var keys = " or ".join(PackedStringArray(key_names))
			text = text.replace("{action2}", keys)
