extends CharacterBody2DPlus

@export_group('Powers')
@export var double_jump = true
@export var edge_grab = true

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

@export_range(0.0, 100.0, 0.1) var facing_change_slowdown = 0
@export var facing_change_slowdown_duration: float = 0

## If negative, will use the gravity of the physics settings.
@export var gravity = -1

## Max falling speed at which you can grab the edge to hang on
@export var max_grab_speed = 500

@export var climbing_speed = 100

@export_group("Tweaks")

## Hang from edge automatically without needing to press a button. Press crouch to drop.
@export var auto_hang_from_edge = true

## Attempting to move away from grabbed edge releases grab
@export var edge_directional_release = true

## Jumping from edge grab is airflip
@export var air_flip_edge_jump = true

@onready var jep_l = $JumpEdgePush_Left
@onready var jep_lt = $JumpEdgePush_LeftThreshold
@onready var jep_r = $JumpEdgePush_Right
@onready var jep_rt = $JumpEdgePush_RightThreshold

@onready var standing_collider = $StandingCollider
@onready var crouching_collider = $CrouchingCollider

@onready var grab_ray = $GrabRay
@onready var climb_checker = $ClimbChecker
@onready var climb_rect = $ClimbChecker/ClimbRect

var prev_position = position
var input_dir = 0
var jump_pressed = 0
var can_jump_from_floor = 0
var can_jump_from_edge_grab = false
var can_double_jump = false
var double_jumped = false
var facing = 1
var changed_facing = false
var facing_change_slowdown_timer = 0

var current_jump_speed = 0

var jump_peak = 0
var was_on_floor = is_on_floor()

var is_walking = false
var is_crouching = false
var was_crouching = false

enum EdgeGrab {
	NULL,
	GRABBING,
	CLIMBING
}
var edge_grab_state = EdgeGrab.NULL
var edge_grabbed = null
var edge_grabbed_prev_pos = null

var climb_platform = null
var relative_climb_pos = null # Relative to climb_platform
var relative_target_climb_pos = null # Relative to climb_platform
var climb_end_timer = null

var falling_through = 0 # When > 0 player can fall through one-way platforms


func _ready():
	crouching_collider.disabled = true
	climb_rect.add_exception(self)
	if gravity < 0:
		gravity = ProjectSettings.get_setting("physics/2d/default_gravity")


func _physics_process(delta):
	
	prev_position = position
	
	var is_climbing = edge_grab_state == EdgeGrab.CLIMBING
	
	
	# Add the gravity.
	if not is_on_floor() and edge_grab_state == EdgeGrab.NULL:
		velocity.y += gravity * delta
		current_jump_speed -= gravity * delta
	
	
	# Handle crouching
	was_crouching = is_crouching
	is_crouching = is_climbing
	if is_on_floor():
		if Input.is_action_pressed("crouch") and not is_climbing:
			is_crouching = true
	
	if is_crouching:
		crouching_collider.disabled = false
		standing_collider.disabled = true
	else:
		# Check if it is possible to stand up
		if was_crouching:
			var col = move_and_collide(Vector2.UP * (standing_collider.shape.size.y - crouching_collider.shape.size.y), true)
			
			if col and col.get_normal().y > 0:
				is_crouching = true
		
		if not is_crouching:
			crouching_collider.disabled = true
			standing_collider.disabled = false
	
	
	# Handle platform fallthrough
	if is_on_floor() and Input.is_action_pressed("crouch") and Input.is_action_just_pressed("jump") and not is_climbing:
		falling_through = 0.07
	
	
	# Handle jump.
	jump_pressed -= delta
	jump_pressed = max(jump_pressed, 0)
	can_jump_from_floor -= delta
	can_jump_from_floor = max(can_jump_from_floor, 0)
	
	if Input.is_action_just_pressed("jump") and not falling_through:
		jump_pressed = jump_buffer
	
	is_walking = false
	if is_on_floor():
		can_jump_from_floor = coyote_time
		
		# Reset double jump
		can_double_jump = true
		
		is_walking = Input.is_action_pressed("walk")
	
	can_jump_from_edge_grab = false
	if edge_grab_state == EdgeGrab.GRABBING:
		can_jump_from_edge_grab = true
		
		# Reset double jump
		can_double_jump = true
	
	# For normal jump parabola:
	# gravity = - 2 * height / duration ^ 2
	# init_jump_speed = 2 * height / duration
	# using the above we can create the initial conditions we need
	# to create a jump of the given height and duration
	# Adding horizontal movement gives us:
	# duration = distance / x_speed
	# so if instead of duration we just need to cover a certain distance
	# we can substitute this in the above equations
	
	var just_jumped = false
	double_jumped = false
	if jump_pressed and not is_crouching and not is_climbing:
		if can_jump_from_floor or (can_jump_from_edge_grab and not air_flip_edge_jump):
			jump_pressed = 0
			can_jump_from_floor = 0
			velocity.y = - 2 * jump_max_height * sqrt(gravity / (2 * jump_max_height))
			current_jump_speed = -velocity.y
			just_jumped = true
		elif (can_double_jump and double_jump) or (can_jump_from_edge_grab and air_flip_edge_jump):
			jump_pressed = 0
			can_double_jump = false
			velocity.y = - 2 * double_jump_max_height * sqrt(gravity / (2 * double_jump_max_height))
			current_jump_speed = -velocity.y
			double_jumped = true
			just_jumped = true
	
	# Zero the speed of the current jump as player is moving downwards
	if velocity.y >= 0:
		current_jump_speed = 0
	
	# Reduce velocity y if jump is released while jumping and
	# our negative y velocity exists, at least partially, due to a jump
	if velocity.y < 0 and Input.is_action_just_released("jump") and current_jump_speed > 0:
		velocity.y += current_jump_speed * jump_percentage_reduction * 0.01
		current_jump_speed = 0
		velocity.y = min(velocity.y, 0)
	
	
	# Handle horizontal movement
	changed_facing = false
	facing_change_slowdown_timer = max(facing_change_slowdown_timer - delta, 0)
	input_dir = Input.get_axis("move_left", "move_right")
	if is_climbing:
		input_dir = 0
	var speed = run_speed
	if is_crouching:
		speed *= 0.4
	if is_walking:
		speed *= 0.55
	
	if input_dir and (not edge_grabbed or just_jumped or edge_directional_release):
		var prev_facing = facing
		facing = input_dir
		if facing != prev_facing:
			changed_facing = true
			facing_change_slowdown_timer = facing_change_slowdown_duration
		if facing_change_slowdown_timer:
			velocity.x = input_dir * speed * (1 - facing_change_slowdown * 0.01)
		else:
			velocity.x = input_dir * speed
	else:
		facing_change_slowdown_timer = 0
		velocity.x = move_toward(velocity.x, 0, run_speed)
	
	if not is_on_floor():
		facing_change_slowdown_timer = 0
	
	
	# Push player out of a roof edge if they jump too close to it
	var jump_edge_raycasts = jep_l and jep_lt and jep_r and jep_rt and true or false
	var pushed_left = false
	var pushed_right = false
	if jump_edge_raycasts and velocity.y < 0:
		jep_l.target_position.y = velocity.y * delta
		jep_lt.target_position.y = velocity.y * delta
		jep_r.target_position.y = velocity.y * delta
		jep_rt.target_position.y = velocity.y * delta
		
		jep_l.force_raycast_update()
		jep_lt.force_raycast_update()
		jep_r.force_raycast_update()
		jep_rt.force_raycast_update()
		
		if jep_l.is_colliding() and not jep_lt.is_colliding() and not jep_rt.is_colliding() and not jep_r.is_colliding():
			change_pos(-(jep_l.position - jep_lt.position))
			pushed_right = true
		
		if jep_r.is_colliding() and not jep_rt.is_colliding() and not jep_lt.is_colliding() and not jep_l.is_colliding():
			change_pos(-(jep_r.position - jep_rt.position))
			pushed_left = true
	
	
	if falling_through:
		can_jump_from_floor = 0
		set_collision_mask_value(2, false)
		falling_through -= delta
		if falling_through < 0:
			falling_through = 0
	if not falling_through:
		set_collision_mask_value(2, true)
	
	
	# Perform movement
	was_on_floor = is_on_floor()
	
	move_and_slide_plus()
	
	if pushed_right:
		var v = velocity
		velocity = (jep_l.position - jep_lt.position) / delta
		move_and_slide_plus()
		velocity = v
	
	if pushed_left:
		var v = velocity
		velocity = (jep_r.position - jep_rt.position) / delta
		move_and_slide_plus()
		velocity = v
	
	
	# Mark highest point of jump
	if not is_on_floor():
		if was_on_floor or double_jumped:
			jump_peak = position.y
		jump_peak = min(jump_peak, position.y)
	
	
	# Edge grab
	var prev_edge_grabbed = edge_grabbed
	if edge_grab_state == EdgeGrab.GRABBING:
		edge_grab_state = EdgeGrab.NULL
	if edge_grab_state == EdgeGrab.CLIMBING and climb_end_timer != null:
		if climb_end_timer <= 0:
			climb_end_timer = 0
			edge_grab_state = EdgeGrab.NULL
		climb_end_timer -= delta
	if edge_grab_state == EdgeGrab.NULL:
		climb_platform = null
		relative_climb_pos = null
		relative_target_climb_pos = null
		climb_end_timer = null
	edge_grabbed = null
	if edge_grab:
		if auto_hang_from_edge:
			grab_ray.scale.x = facing
			grab_ray.enabled = not Input.is_action_pressed("crouch") and not changed_facing
		else:
			if Input.is_action_pressed("edge_grab"):
				grab_ray.enabled = true
				grab_ray.scale.x = facing
			else:
				grab_ray.enabled = false
		
		if grab_ray.enabled and edge_grab_state != EdgeGrab.CLIMBING:
			var prev_pos_grabbed = prev_position # prev position after getting moved by grabbed platform
			
			# Move alongside prev grabbed edge if it exists
			if prev_edge_grabbed:
				var delta_pos = prev_edge_grabbed.position - edge_grabbed_prev_pos
				var edge_dir = sign(prev_edge_grabbed.position.x - position.x)
				
				# Always move towards edge
				delta_pos.x = abs(delta_pos.x) * edge_dir
				
				var pos_before = position
				change_pos(delta_pos)
				var pos_after = position
				prev_pos_grabbed += pos_after - pos_before
			
			# Check if we're still grabbing edge
			if velocity.y >= 0 and velocity.y < max_grab_speed and not is_on_floor():
				var gr_reset_y = grab_ray.position.y
				grab_ray.position.y -= position.y - prev_pos_grabbed.y
				var gr_start_y = grab_ray.position.y
				for _i in 10:
					grab_ray.force_raycast_update()
					var y = grab_ray.position.y
					if grab_ray.is_colliding():
						var grab_collider = grab_ray.get_collider()
						var grab_col_children = grab_ray.get_collider().get_children()
						var one_way = false
						for child in grab_col_children:
							if child is CollisionShape2D:
								if child.one_way_collision:
									one_way = true
									break
						
						grab_ray.position.y -= 1
						grab_ray.force_raycast_update()
						
						if not one_way and not grab_ray.is_colliding():
							edge_grabbed = grab_collider
							edge_grabbed_prev_pos = edge_grabbed.position
						
						if edge_grabbed:
							position.y = prev_pos_grabbed.y + (y - gr_start_y)
							if not prev_pos_grabbed:
								# Floor position during first grab to ensure consistent grab position
								position.y = floor(position.y)
							velocity.y = 0
							var v = velocity
							velocity.x = grab_ray.scale.x
							move_and_slide_plus()
							velocity = v
							edge_grab_state = EdgeGrab.GRABBING
							break
						grab_ray.position.y = y
					
					if grab_ray.position.y == position.y:
						break
					
					grab_ray.position.y = move_toward(grab_ray.position.y, gr_reset_y, 1)
				
				grab_ray.position.y = gr_reset_y
		
		# Autoclimb when floor only missed by a bit
		# TODO
		
		# Handle edge climbing
		climb_checker.position.x = facing * abs(climb_checker.position.x)
		climb_checker.scale.x = facing
		climb_rect.force_shapecast_update()
		
		# Finish climbing
		if edge_grab_state == EdgeGrab.CLIMBING:
			was_crouching = true
		
		# Start climbing
		if edge_grab_state == EdgeGrab.GRABBING and not climb_rect.is_colliding():
			# We can climb but should we?
			var should_climb = false
			if auto_hang_from_edge:
				should_climb = Input.is_action_just_pressed("edge_grab")
			else:
				if facing == 1 and Input.is_action_just_pressed("move_right"):
					should_climb = true
				elif facing == -1 and Input.is_action_just_pressed("move_left"):
					should_climb = true
			
			if should_climb and not just_jumped:
				#position += climb_checker.position
				#move_and_slide_plus()
				#climbing_timer = 0.5
				
				climb_platform = edge_grabbed
				relative_target_climb_pos = climb_checker.global_position - climb_platform.global_position
				relative_climb_pos = global_position - climb_platform.global_position
				edge_grab_state = EdgeGrab.CLIMBING
		
		if edge_grab_state == EdgeGrab.CLIMBING:
			# Adjust position
			global_position = climb_platform.global_position + relative_climb_pos
			
			if relative_climb_pos.y <= relative_target_climb_pos.y:
				var dir = sign(relative_target_climb_pos.x - relative_climb_pos.x)
				# Move towards platform until target reached
				relative_climb_pos += climbing_speed * delta * Vector2.RIGHT * dir
				if dir != sign(relative_target_climb_pos.x - relative_climb_pos.x):
					relative_climb_pos.x = relative_target_climb_pos.x
					change_pos(Vector2.DOWN)
					climb_end_timer = 0.1
			else:
				# Move up until target reached
				relative_climb_pos += climbing_speed * delta * Vector2.UP
				if relative_climb_pos.y <= relative_target_climb_pos.y:
					relative_climb_pos.y = relative_target_climb_pos.y
			
		


var floor_obj = null
var prev_floor_pos = null
var delta_x_floored = 0 # Delta x (relative to floor movement when grounded)

func _process(delta):
	delta_x_floored = (position.x - prev_position.x) * 60 / delta
	
	if floor_obj and prev_floor_pos:
		var delta_x_floor = (floor_obj.position.x - prev_floor_pos.x) * 60 / delta
		delta_x_floored -= delta_x_floor
	
	handle_animations()
	
	if floor_obj:
		prev_floor_pos = floor_obj.position
	
	var col = move_and_collide(Vector2.DOWN, true)
	if col and is_on_floor():
		floor_obj = col.get_collider()


# Animation Stuff
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var push_ray = $PushRay
var was_moving = false
var was_walking = false
var was_pushing = false
var touching_wall = false

enum Actions {
	IDLE,
	RUN,
	WALK,
	PUSH,
	JUMP,
	CROUCH_IDLE,
	CROUCH_WALK,
	EDGE_GRAB,
	EDGE_CLIMB
}

func is_anim_playing(anim):
	if anim == animated_sprite_2d.animation:
		return animated_sprite_2d.is_playing()
	return false

func is_any_anim_playing(anims: Array[String]):
	for anim in anims:
		if anim == animated_sprite_2d.animation:
			return animated_sprite_2d.is_playing()
	return false

func is_anim_on_any_frame(frames: Array[int]):
	for frame in frames:
		if animated_sprite_2d.frame == frame:
			return true
	return false

func handle_animations():
	var grounded = is_on_floor()
	var landed = not was_on_floor and grounded
	var is_moving = input_dir and abs(delta_x_floored) > 0.25
	
	var is_pushing = false
	push_ray.scale.x = facing
	touching_wall = push_ray.is_colliding()
	if not is_crouching and is_on_wall() and touching_wall and input_dir:
		var w = get_wall_normal()
		is_pushing = w.x == -input_dir
		if is_pushing:
			is_moving = true
	
	animated_sprite_2d.flip_h = facing == -1
	
	var prev_animation = animated_sprite_2d.animation
	#var prev_frame = animated_sprite_2d.frame
	
	# Target animations are the ones that are looping, ie the non transitional
	var action: Actions
	
	# Determine target animation
	if edge_grab_state == EdgeGrab.CLIMBING:
		action = Actions.EDGE_CLIMB
	elif grounded:
		if is_crouching:
			if is_moving:
				action = Actions.CROUCH_WALK
			else:
				action = Actions.CROUCH_IDLE
		elif is_pushing:
			action = Actions.PUSH
		elif is_moving:
			if is_walking:
				action = Actions.WALK
			else:
				action = Actions.RUN
		else:
			action = Actions.IDLE
	elif edge_grab_state == EdgeGrab.GRABBING:
		action = Actions.EDGE_GRAB
	else:
		action = Actions.JUMP
	
	# Handle transtitions to target animation represented by action
	match action:
		Actions.IDLE:
			if was_crouching:
				animated_sprite_2d.play_backwards("crouching")
			elif was_moving:
				if was_walking or was_pushing:
					animated_sprite_2d.play("walk_stop")
				else:
					animated_sprite_2d.play("run_stop")
			elif landed:
				animated_sprite_2d.play("land_still")
			elif not is_any_anim_playing(["run_stop", "walk_stop", "land_still", "crouching"]):
				animated_sprite_2d.play("idle")
		Actions.WALK:
			if landed:
				animated_sprite_2d.play("land_run")
			elif was_crouching:
				animated_sprite_2d.play_backwards("crouching")
			elif changed_facing:
				animated_sprite_2d.play("walk_turn")
				animated_sprite_2d.frame = 0
			elif not is_any_anim_playing(["walk_turn", "land_run", "crouching"]):
				if is_anim_playing("run"):
					if is_anim_on_any_frame([0,4]):
						var is_frame_0 = animated_sprite_2d.frame == 0
						animated_sprite_2d.play("walk")
						if is_frame_0:
							animated_sprite_2d.frame = 4
				elif is_anim_playing("run_turn"):
					if is_anim_on_any_frame([4]):
						animated_sprite_2d.play("walk")
				else:
					animated_sprite_2d.play("walk")
					if prev_animation == "run_turn":
						animated_sprite_2d.frame = 4
		Actions.RUN:
			if landed:
				animated_sprite_2d.play("land_run")
			elif was_crouching:
				animated_sprite_2d.play_backwards("crouching")
			elif changed_facing:
				animated_sprite_2d.play("run_turn")
				animated_sprite_2d.frame = 0
			elif not is_any_anim_playing(["land_run", "run_turn", "crouching"]):
				animated_sprite_2d.play("run")
		Actions.CROUCH_IDLE:
			if was_moving:
				animated_sprite_2d.play_backwards("crouch_stop")
			elif not is_anim_playing("crouch_stop"):
				if not was_crouching:
					animated_sprite_2d.play("crouching")
				elif not is_anim_playing("crouching"):
					animated_sprite_2d.play("crouch_idle")
		Actions.CROUCH_WALK:
			if changed_facing:
				animated_sprite_2d.play("crouch_turn")
			elif not is_anim_playing("crouch_turn"):
				if not was_crouching:
					animated_sprite_2d.play("crouching")
				elif not is_anim_playing("crouching"):
					animated_sprite_2d.play("crouch_walk")
		Actions.PUSH:
			if landed:
				animated_sprite_2d.play("land_run")
			elif not is_anim_playing("land_run"):
				animated_sprite_2d.play("push")
		Actions.JUMP:
			if double_jumped or (falling_through and velocity.y >= 0):
				animated_sprite_2d.play("double_jump")
			elif not is_anim_playing("double_jump"):
				animated_sprite_2d.play("jump")
				if abs(velocity.y) < 100:
					animated_sprite_2d.frame = 1
				elif velocity.y >= 100:
					animated_sprite_2d.frame = 2
				else:
					animated_sprite_2d.frame = 0
		Actions.EDGE_GRAB:
			animated_sprite_2d.play("edge_climb")
			if animated_sprite_2d.frame > 0:
				animated_sprite_2d.frame_progress = 0
		Actions.EDGE_CLIMB:
			if not is_anim_playing("edge_climb") and prev_animation == "edge_climb":
				animated_sprite_2d.play("crouch_idle")
			elif not is_anim_playing("crouch_idle"):
				animated_sprite_2d.play("edge_climb")
				if animated_sprite_2d.frame < 1:
					animated_sprite_2d.frame = 1
	
	# Store previous values
	was_moving = is_moving
	was_walking = is_walking
	was_pushing = is_pushing

