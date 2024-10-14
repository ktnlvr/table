extends Camera3D

@onready var parent = $".."

const INTERACTION_RAY_LENGTH = 1200.

const MOVEMENT_SPEED = 10.
const BOOST_COEFFICIENT = 2.1
const ROTATION_SPEED = 0.0001

var last_mouse_pos = Vector2.ZERO

enum {
	HORIZONTAL_GRAB,
}

var locked_height = false
var mode = HORIZONTAL_GRAB
var held_item: RigidBody3D = null
var held_distance = 0

var last_raycast_from := Vector3.ZERO 
var last_raycast_to := Vector3.ZERO

func try_grab(result):
	if result:
		if result['collider'] is RigidBody3D:
			held_item = result['collider']
			held_item.angular_velocity = Vector3.ZERO
			held_item.linear_velocity = Vector3.ZERO

func _process_horizontal_grab(dt, raycast):
	if held_item:
		if not raycast:
			return
		
		var direction = Vector3.ZERO
		const K = 10
		const HOVER_DISTANCE = 1.3
		var target = raycast['position'] + HOVER_DISTANCE * Vector3.UP
		
		direction = target - held_item.position
		held_item.linear_velocity = direction * K
		
		if Input.is_action_just_pressed("Do"):
			held_item = null
		if Input.is_action_just_released("Do"):
			held_item.global_position = target
	else:
		if Input.is_action_just_pressed("Do"):
			try_grab(raycast)

func _process_mode(dt, hovered):
	if mode == HORIZONTAL_GRAB:
		_process_horizontal_grab(dt, hovered)

func _process(dt: float) -> void:
	if Input.is_action_just_pressed("Lock Height"):
		locked_height = not locked_height
	
	var back_forth = Input.get_axis("Back", "Forward")
	var up_down = Input.get_axis("Down", "Up")
	var left_right = Input.get_axis("Left", "Right")
	
	var speed = MOVEMENT_SPEED
	if Input.is_action_pressed("Boost"):
		speed *= BOOST_COEFFICIENT
	
	var direction = Vector3.ZERO
	if locked_height:
		var horizontal_plane = Plane(Vector3.UP)
		var fb = horizontal_plane.project(-self.basis.z).normalized() * back_forth
		var lr = horizontal_plane.project(self.basis.x).normalized() * left_right
		var ud = Vector3.UP * up_down
		direction = (lr + fb).normalized() + ud
	else:
		var lr = self.basis.x * left_right
		var ud = self.basis.y * up_down
		var fb = -self.basis.z * back_forth
		direction = (lr + ud + fb).normalized()
	var displacement = direction * speed * dt
	parent.translate(displacement)
	
	var panning = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	var current_mouse_pos = get_viewport().get_mouse_position()
	var mouse_delta = current_mouse_pos - last_mouse_pos
	last_mouse_pos = current_mouse_pos
	
	if panning:
		self.rotate_x(rad_to_deg(-mouse_delta.y) * ROTATION_SPEED)
		parent.rotate_y(rad_to_deg(-mouse_delta.x) * ROTATION_SPEED)

	var hovered_item = null
	
	if not Input.is_action_pressed("Freeze"):
		last_raycast_from = self.global_position
		last_raycast_to = last_raycast_from + self.project_ray_normal(current_mouse_pos) * INTERACTION_RAY_LENGTH
		if held_item:
			held_item.linear_velocity = Vector3.ZERO
			held_item.angular_velocity = Vector3.ZERO
	var space = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.new()
	query.from = last_raycast_from
	query.to = last_raycast_to
	query.collide_with_areas = false
	if held_item:
		query.exclude = Array([held_item.get_rid()])
	
	var result = space.intersect_ray(query)
	
	_process_mode(dt, result)
