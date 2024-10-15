extends Node3D

@onready var status_label = $"Camera/Canvas/Status Label"
@onready var hover_label = $"Camera/Canvas/Hover Label"
@onready var camera = $"Camera"

const INTERACTION_RAY_LENGTH = 1200.

const MOVEMENT_SPEED = 10.
const BOOST_COEFFICIENT = 2.1
const ROTATION_SPEED = 0.0001

var last_mouse_pos = Vector2.ZERO

enum {
	HORIZONTAL_GRAB,
}

var locked_height = false
var interact_with_frozen = false

var mode = HORIZONTAL_GRAB
var held_item: RigidBody3D = null
var held_distance = 0

@export var active_miniature: Miniature

func try_grab(result):
	if result:
		var target = result['collider']
		if target is InteractibleMiniature:
			if interact_with_frozen:
				target.freeze = false
			if target.freeze:
				return
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
	else:
		if Input.is_action_just_pressed("Do"):
			try_grab(raycast)

func _process_mode(dt, hovered):
	if mode == HORIZONTAL_GRAB:
		_process_horizontal_grab(dt, hovered)

func _mode_to_str() -> String:
	if mode == HORIZONTAL_GRAB:
		return "Horizontal Grab"
	return "?????"

func _update_status_text():
	status_label.text = ""
	status_label.text += "Mode: " + _mode_to_str() + "\n"
	status_label.text += ""

func _update_hover_text(result):
	hover_label.text = ""
	if not result or not (result['collider'] is Interactible):
		return
	if result['collider'] is RigidBody3D:
		if result['collider'].freeze and not interact_with_frozen:
			return
	var mouse_pos = get_viewport().get_mouse_position()
	hover_label.text = result['collider'].display_name()
	hover_label.position = mouse_pos + Vector2(15, -15)

static func random_direction() -> Vector3:
	var theta := randf() * TAU
	var phi := acos(2.0 * randf() - 1.0)
	var sin_phi := sin(phi)
	return Vector3(cos(theta) * sin_phi, sin(theta) * sin_phi, cos(phi))

func _handle_movement(dt: float):
	var back_forth = Input.get_axis("Back", "Forward")
	var up_down = Input.get_axis("Down", "Up")
	var left_right = Input.get_axis("Left", "Right")
	
	var speed = MOVEMENT_SPEED
	if Input.is_action_pressed("Boost"):
		speed *= BOOST_COEFFICIENT
	
	var direction = Vector3.ZERO
	if locked_height:
		var horizontal_plane = Plane(Vector3.UP)
		var fb = horizontal_plane.project(-camera.basis.z).normalized() * back_forth
		var lr = horizontal_plane.project(camera.basis.x).normalized() * left_right
		var ud = Vector3.UP * up_down
		direction = (lr + fb).normalized() + ud
	else:
		var lr = camera.basis.x * left_right
		var ud = camera.basis.y * up_down
		var fb = -camera.basis.z * back_forth
		direction = (lr + ud + fb).normalized()

	var displacement = direction * speed * dt
	translate(displacement)

func _handle_toggles():
	if Input.is_action_just_pressed("Toggle Lock Height"):
		locked_height = not locked_height
	if Input.is_action_just_pressed("Toggle Freeze"):
		interact_with_frozen = not interact_with_frozen

func _handle_panning(dt: float):
	var panning = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	var current_mouse_pos = get_viewport().get_mouse_position()
	var mouse_delta = current_mouse_pos - last_mouse_pos
	last_mouse_pos = current_mouse_pos
	
	if panning:
		camera.rotate_x(rad_to_deg(-mouse_delta.y) * ROTATION_SPEED)

		# for rotation.x == TAU the WS axis of movement gets flipped
		# crude fix, but rather logical
		const EPSILON = 0.000001
		camera.rotation.x = clamp(camera.rotation.x, -TAU / 4 + EPSILON, TAU / 4 - EPSILON)
		self.rotate_y(rad_to_deg(-mouse_delta.x) * ROTATION_SPEED)	

func _hover_raycast():
	var mouse_pos = get_viewport().get_mouse_position()
	
	var from = self.global_position
	var to = from + camera.project_ray_normal(mouse_pos) * INTERACTION_RAY_LENGTH
	if held_item:
		held_item.linear_velocity = Vector3.ZERO
		held_item.angular_velocity = Vector3.ZERO
	var space = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collide_with_areas = false
	if held_item:
		query.exclude = Array([held_item.get_rid()])
	
	return space.intersect_ray(query)

func _handle_poke_reroll(target):
	const REROLL_JUMP_HEIGHT = 2
	var jump_velocity = sqrt(2 * 9.8 * REROLL_JUMP_HEIGHT)
	if target is RigidBody3D:
		target.linear_velocity += Vector3.UP * jump_velocity
		target.angular_velocity += random_direction() * (4 * randf() * TAU + PI)

func _handle_poke_freeze(target):
	if target is RigidBody3D:
		target.freeze = not target.freeze

func _handle_poke(result: Dictionary):
	if result:
		var target = result['collider']
		if Input.is_action_just_pressed("Reroll"):
			_handle_poke_reroll(target)
		if Input.is_action_just_pressed("Freeze"):
			_handle_poke_freeze(target)
		if Input.is_key_pressed(KEY_T):
			active_miniature.instantiate(self, result['position'] + result['normal'])

func _process(dt: float) -> void:
	if not is_multiplayer_authority():
		return
	_update_status_text()
	_handle_toggles()
	_handle_movement(dt)
	_handle_panning(dt)
	var result = _hover_raycast()
	_handle_poke(result)
	_update_hover_text(result)
	_process_mode(dt, result)
