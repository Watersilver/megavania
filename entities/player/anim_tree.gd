extends AnimationTree

# WARNING: animation tree has this bug: https://github.com/godotengine/godot/issues/91215
# It can be bypassed by setting animation mixer callback mode to manual on the animation tree node
# and then calling advance in several steps (5 seems to be the minimum that works well)
# giving it as an argument delta / number_of_steps

@export var left = false
@export var right = true
@export var changed_facing = false
@export var running = false
@export var idling = true
@export var grounded = true
@export var small_v_speed = true
@export var descending = false
@export var ascending = false
@export var double_jumped = false
