class_name StateMachine

var _state_transitions = {}
var _current_state

func get_current_state():
	return _current_state

func connect_state_output_to_state(output, state):
	_state_transitions[output] = state

func transition(output):
	var new_state = _state_transitions[output]
	if new_state:
		_current_state = new_state
