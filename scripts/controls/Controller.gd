extends Node3D

@onready var status_label = $"Camera/Canvas/Status Label"
@onready var hover_label = $"Camera/Canvas/Hover Label"
@onready var camera = $"Camera"

const EPSILON = 0.000001

const INTERACTION_RAY_LENGTH = 1200.

const MOVEMENT_SPEED = 10.
const BOOST_COEFFICIENT = 2.1
const ROTATION_SPEED = 0.0001
const OBJECT_SPIN_SPEED_DEG_PER_S = 360

var is_moving = false

var last_mouse_pos = Vector2.ZERO

enum {
	MODE_GRAB,
	MODE_RULER,
	MODE_SPAWN,
	amount_of_modes
}

@export var active_miniature: Miniature

var locked_height = false
var interact_with_frozen = false

var mode = MODE_GRAB

# MODE_GRAB
var held_item: RigidBody3D = null
var held_distance = 0

# MODE_RULER
const MIN_RULER_LENGTH = 0.1
const MAX_RULER_LENGTH = 60
const RULER_EXTEND_SPEED = 10
var is_ruler_valid = false
var current_ruler_length = 10
var is_ruler_updating = false

# MODE_SPAWN
@export var SPAWN_OVERLAY_SHADER: ShaderMaterial = null
const SPAWN_ROTATION_SPEED_DEG_PER_S = 720
var spawn_rotation_deg = 0

func try_grab(result):
	if result:
		var target = result['collider']
		if target is InteractibleMiniature:
			if not target.can_puppeteer():
				return
			target.take_puppeteer.rpc()
			if interact_with_frozen:
				target.freeze = false
			if target.freeze:
				return
			held_item = result['collider']
			held_item.angular_velocity = Vector3.ZERO
			held_item.linear_velocity = Vector3.ZERO

func release_held():
	held_item.release_puppeteer.rpc()
	held_item = null

func get_mouse_scroll() -> int:
	var _pressed = func(name):
		return Input.is_action_just_pressed(name) or Input.is_action_pressed(name)
	
	var scroll = -1 if _pressed.call("Gentle Down") else 0
	scroll += 1 if _pressed.call("Gentle Up") else 0
	return scroll

func _reset_flags():
	is_moving = false
	is_ruler_updating = false

func _process_grab(dt, raycast):
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
			release_held()
	else:
		if Input.is_action_just_pressed("Do"):
			try_grab(raycast)

func _max_ruler_extension():
	return max(MIN_RULER_LENGTH + EPSILON, floor(current_ruler_length))

func _process_ruler(dt: float, raycast):
	var length_extension = RULER_EXTEND_SPEED * dt * get_mouse_scroll()
	current_ruler_length = clamp(current_ruler_length + length_extension, MIN_RULER_LENGTH + EPSILON, MAX_RULER_LENGTH)
	
	var held = Input.is_action_pressed("Do")
	if raycast and held:
		var new_position = raycast['position']
		var d = new_position - $Ruler/A.global_position
		# TODO: do proper checks
		var len = clamp(d.length(), 0, _max_ruler_extension())
		$Ruler/B.global_position = $Ruler/A.global_position + d.normalized() * len
		is_ruler_updating = true

	if Input.is_action_just_released("Do"):
		is_ruler_valid = !!raycast
		is_ruler_updating = true

	if not raycast:
		return

	if Input.is_action_just_pressed("Do"):
		$Ruler/A.global_position = raycast['position']
		is_ruler_updating = true

func _process_spawn(dt, raycast):
	if not raycast:
		return
	
	var preview = $"Spawn Preview"
	var preview_mesh = $"Spawn Preview/Preview Mesh"
	
	preview.global_position = raycast['position']
	preview_mesh.mesh = active_miniature.mesh()
	preview_mesh.position.y = active_miniature.vertical_support_height()
	
	spawn_rotation_deg += get_mouse_scroll() * dt * OBJECT_SPIN_SPEED_DEG_PER_S
	preview.rotation_degrees.y = spawn_rotation_deg
	
	if active_miniature.material == null:
		preview_mesh.material = SPAWN_OVERLAY_SHADER
	else:
		preview_mesh.material = active_miniature.material.duplicate()
		preview_mesh.material.albedo_color.a = 0.5
		preview_mesh.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		preview_mesh.material.next_pass = SPAWN_OVERLAY_SHADER
	
	if Input.is_action_just_pressed("Do"):
		var at = raycast['position'] + Vector3.UP * active_miniature.vertical_support_height()
		instantiate(preview_mesh.global_position, preview.rotation)

func _process_mode(dt, raycast):
	var lookup = {
		MODE_GRAB: _process_grab,
		MODE_RULER: _process_ruler,
		MODE_SPAWN: _process_spawn,
	}
	lookup[mode].call(dt, raycast)

func _mode_to_str() -> String:
	if mode == MODE_GRAB:
		return "Grab"
	elif mode == MODE_RULER:
		return "Ruler"
	elif mode == MODE_SPAWN:
		return "Spawn"
	return "?????"

func _update_status_text():
	status_label.text = ""
	if mode == MODE_GRAB:
		var held_name = "_"
		if held_item:
			held_name = held_item.display_name()
		status_label.text += "held: " + held_name + "\n"
	elif mode == MODE_RULER:
		status_label.text += "extent: " + str(floor(_max_ruler_extension())) + "\n"
	elif mode == MODE_SPAWN:
		if active_miniature:
			status_label.text += "spawning: " + str(active_miniature.display_name) + "\n"
	status_label.text += "mode: " + _mode_to_str() + "\n"
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
	if displacement.length() > EPSILON:
		is_moving = true
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
	target.sync_reroll.rpc(randf())

func _handle_poke_freeze(target):
	target.sync_toggle_freeze.rpc()

func _handle_poke(result: Dictionary):
	if result:
		var target = result['collider']
		
		if target is InteractibleMiniature and target.can_puppeteer():
			if Input.is_action_just_pressed("Reroll"):
				_handle_poke_reroll(target)
			if Input.is_action_just_pressed("Freeze"):
				_handle_poke_freeze(target)
			
@rpc("call_local")
func instantiate(at: Vector3, rotation: Vector3):
	var instance = load("res://data/miniatures/D6.tres").instantiate(self, at)
	instance.rotation = rotation

func _handle_mode_switching():
	if Input.is_action_just_pressed("Next Mode"):
		mode = (mode + 1) % amount_of_modes
		$"Spawn Preview".visible = mode == MODE_SPAWN

func _display_ruler():
	var a = $Ruler/A.global_position
	var b = $Ruler/B.global_position
	var distance = a.distance_to(b)
	
	var visible = distance > MIN_RULER_LENGTH
	$Ruler/A.visible = visible
	$Ruler/B.visible = visible
	$Ruler/Rope.visible = visible
	$Ruler/Label.visible = visible
	
	distance = clamp(distance, MIN_RULER_LENGTH, MAX_RULER_LENGTH)
	
	if not visible:
		return

	var m = (a + b) / 2
	var label_position = get_viewport().get_camera_3d().unproject_position(m)
	var viewport_size = Vector2(get_viewport().size)
	label_position.x = clamp(label_position.x, 0, viewport_size.x)
	label_position.y = clamp(label_position.y, 0, viewport_size.y)
	$Ruler/Label.global_position = label_position
	
	$Ruler/Rope.global_position = m
	if a == b:
		return
	$Ruler/Rope.look_at(a)
	$Ruler/Rope/Mesh.scale.y = distance
	$Ruler/Label.text = str(round(distance))

func _sync_network():
	if is_moving:
		sync_position.rpc(global_position)
	if is_ruler_updating and is_ruler_valid:
		sync_ruler.rpc($Ruler/A.global_position, $Ruler/B.global_position)

func _process(dt: float) -> void:
	_reset_flags()
	_display_ruler()
	if not is_multiplayer_authority():
		return
	_handle_mode_switching()
	_update_status_text()
	_handle_toggles()
	_handle_movement(dt)
	_handle_panning(dt)
	var result = _hover_raycast()
	_handle_poke(result)
	_update_hover_text(result)
	_process_mode(dt, result)
	
	_sync_network()

func _ready() -> void:
	if not is_multiplayer_authority():
		camera.queue_free()
	name = str(get_multiplayer_authority())

@rpc("unreliable")
func sync_position(authority_position):
	global_position = authority_position

@rpc
func sync_ruler(a_pos, b_pos):
	$Ruler/A.global_position = a_pos
	$Ruler/B.global_position = b_pos
	_display_ruler()
