extends CharacterBody2D
class_name PlayerCharacter

@export_group('Powers')
@export var double_jump = true

@export_group('Movement Parameters')
@export_range(10.0, 200.0, 0.1, 'or_greater') var run_speed = 150.0

## How much time in seconds before you hit the ground a jump press is valid.
@export_range(0.0, 1.0, 0.01) var jump_buffer = 0.05
## How much time in seconds after you've fallen of an edge you can still
## perform a single jump as if you were still on ground.
@export_range(0.0, 0.2, 0.01) var coyote_time = 0.1

## Maximum height of the single jump in pixels.
@export var jump_max_height = 16 * 4
## Maximum height of the double jump in pixels.
@export var double_jump_max_height = 16 * 3

## How much does jump speed get reduced when jump button is released.
@export_range(0.0, 100.0, 0.1) var jump_percentage_reduction = 50

## If negative, will use the gravity of the physics settings.
@export var gravity = -1

@onready var sprite = $Sprite2D
@onready var ap = $AnimationPlayer

@onready var jep_l = $JumpEdgePush_Left
@onready var jep_lt = $JumpEdgePush_LeftThreshold
@onready var jep_r = $JumpEdgePush_Right
@onready var jep_rt = $JumpEdgePush_RightThreshold

var delta_x = 0
var input_dir = 0
var jump_pressed = 0
var can_jump_from_floor = 0
var can_double_jump = false
var double_jumped = false

var prev_position = position
var prev_velocity = velocity

var current_jump_speed = 0

func _ready():
	if gravity < 0:
		gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
		current_jump_speed -= gravity * delta
	
	# Handle jump.
	jump_pressed -= delta
	jump_pressed = max(jump_pressed, 0)
	can_jump_from_floor -= delta
	can_jump_from_floor = max(can_jump_from_floor, 0)
	
	if Input.is_action_just_pressed("jump"):
		jump_pressed = jump_buffer
	
	if is_on_floor():
		can_jump_from_floor = coyote_time
		
		# Reset double jump
		can_double_jump = true
	
	# TODO: implement number five of this video
	# https://www.youtube.com/watch?v=Bsy8pknHc0M
	
	# For normal jump parabola:
	# gravity = - 2 * height / duration ^ 2
	# init_jump_speed = 2 * height / duration
	# using the above we can create the initial conditions we need
	# to create a jump of the given height and duration
	# Adding horizontal movement gives us:
	# duration = distance / x_speed
	# so if instead of duration we just need to cover a certain distance
	# we can substitute this in the above equations
	
	double_jumped = false
	if jump_pressed:
		if can_jump_from_floor:
			jump_pressed = 0
			can_jump_from_floor = 0
			velocity.y = - 2 * jump_max_height * sqrt(gravity / (2 * jump_max_height))
			current_jump_speed = -velocity.y
		elif can_double_jump:
			jump_pressed = 0
			can_double_jump = false
			velocity.y = - 2 * double_jump_max_height * sqrt(gravity / (2 * double_jump_max_height))
			current_jump_speed = -velocity.y
			double_jumped = true
	
	# Zero the speed of the current jump as player is moving downwards
	if velocity.y >= 0:
		current_jump_speed = 0
	
	# Reduce velocity y if jump is released while jumping and
	# our negative y velocity exists, at least partially, due to a jump
	if velocity.y < 0 and Input.is_action_just_released("jump") and current_jump_speed > 0:
		velocity.y += current_jump_speed * jump_percentage_reduction * 0.01
		current_jump_speed = 0
		velocity.y = min(velocity.y, 0)
	
	# Get the input direction and handle the movement/deceleration.
	input_dir = Input.get_axis("move_left", "move_right")
	if input_dir:
		velocity.x = input_dir * run_speed
	else:
		velocity.x = move_toward(velocity.x, 0, run_speed)
	
	# Push player out of a roof edge if they jump too close to it
	var jump_edge_raycasts = jep_l and jep_lt and jep_r and jep_rt and true or false
	var pushed_left = false
	var pushed_right = false
	if jump_edge_raycasts and velocity.y < 0:
		jep_l.target_position.y = velocity.y * delta
		jep_lt.target_position.y = velocity.y * delta
		jep_r.target_position.y = velocity.y * delta
		jep_rt.target_position.y = velocity.y * delta
		
		if jep_l.is_colliding() and not jep_lt.is_colliding() and not jep_rt.is_colliding() and not jep_r.is_colliding():
			var v = velocity
			velocity = -(jep_l.position - jep_lt.position) / delta
			move_and_slide_cornerbug()
			velocity = v
			pushed_right = true
		
		if jep_r.is_colliding() and not jep_rt.is_colliding() and not jep_lt.is_colliding() and not jep_l.is_colliding():
			var v = velocity
			velocity = -(jep_r.position - jep_rt.position) / delta
			move_and_slide_cornerbug()
			velocity = v
			pushed_left = true
	
	move_and_slide_cornerbug()
	
	if pushed_right:
		var v = velocity
		velocity = (jep_l.position - jep_lt.position) / delta
		move_and_slide_cornerbug()
		velocity = v
	
	if pushed_left:
		var v = velocity
		velocity = (jep_r.position - jep_rt.position) / delta
		move_and_slide_cornerbug()
		velocity = v
	
	delta_x = position.x - prev_position.x
	
	handle_anim_tree()

func move_and_slide_cornerbug(max_recursions: int = 5):
	# Store prevs
	prev_position = position
	prev_velocity = velocity
	
	move_and_slide()
	
	# Stop if recursion is not allowed
	if max_recursions <= 0:
		return
	
	# Corner bug workaround
	var col = get_last_slide_collision()
	# Check if velocity and collision are perpendicular...
	if col and not col.get_normal().dot(prev_velocity):
		# And if collision caused movement to stop...
		if col.get_remainder().length() >= safe_margin:
			# Reset to location where it can slide along the wall it collided with
			position = prev_position + col.get_normal() * safe_margin
			
			# Retry move with less recursion
			move_and_slide_cornerbug(max_recursions - 1)


# Animation Stuff

@onready var at = $AnimationTree
var prev_anim = null
var prev_frame = null
var frame_lasted = 0
var texture_name_matcher = RegEx.create_from_string('\\/.*')

# WARNING: animation tree has this bug: https://github.com/godotengine/godot/issues/91215
# It can be bypassed by setting animation mixer callback mode to manual on the animation tree node
# and then calling advance in several steps (5 seems to be the minimum that works well)
# giving it as an argument delta / number_of_steps

func handle_anim_tree():
	at.grounded = is_on_floor()
	at.small_v_speed = abs(velocity.y) < 100
	at.descending = velocity.y >= 100
	at.ascending = velocity.y <= -100
	at.double_jumped = double_jumped
	
	if abs(delta_x) > 0.25:
		at.running = true
		at.idling = false
	else:
		at.running = false
		at.idling = true
	
	at.changed_facing = false
	if input_dir:
		var prev_r = at.right
		if input_dir > 0:
			at.right = true
			at.left = false
		else:
			at.right = false
			at.left = true
		at.changed_facing = at.right != prev_r
