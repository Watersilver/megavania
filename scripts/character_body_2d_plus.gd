extends CharacterBody2D
class_name CharacterBody2DPlus

var max_move_and_slide_plus_recursions: int = 5

## Chages position using velocities under the hood
func change_pos(change: Vector2, max_recursions: int = max_move_and_slide_plus_recursions):
	var v = velocity
	velocity = change / get_physics_process_delta_time()
	move_and_slide_plus(max_recursions)
	velocity = v

## Position before last move_and_slide_plus call
var last_position_msp = position
## Velocity before last move_and_slide_plus call
var last_velocity_msp = velocity

## Alternative to move_and_slide without cornerbug
func move_and_slide_plus(max_recursions: int = max_move_and_slide_plus_recursions):
	# Store prevs
	last_position_msp = position
	last_velocity_msp = velocity
	
	move_and_slide()
	
	# Stop if recursion is not allowed
	if max_recursions <= 0:
		return
	
	# Corner bug workaround
	var col = get_last_slide_collision()
	# Check if velocity and collision are perpendicular...
	if col and not col.get_normal().dot(last_velocity_msp):
		# And if collision caused movement to stop...
		if col.get_remainder().length() >= safe_margin:
			# Reset to location where it can slide along the wall it collided with
			position = last_position_msp + col.get_normal() * safe_margin
			
			# Retry move with less recursion
			move_and_slide_plus(max_recursions - 1)
