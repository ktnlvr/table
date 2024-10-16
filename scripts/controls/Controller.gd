extends Node3D

@onready var status_label = $"Camera/Canvas/Status Label"
@onready var hover_label = $"Camera/Canvas/Hover Label"
@onready var camera = $"Camera"
@onready var asset_library = $"Camera/Canvas/Asset Library"
@onready var selection = $Camera/Canvas/Selection

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
	MODE_SELECT,
	amount_of_modes
}

@export var active_miniature: Miniature

var locked_height = false
var interact_with_frozen = false

var mode = MODE_GRAB

# MODE_GRAB
var held_items = []
var held_origins = []
var held_distance := 0.

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

# MODE_SELECT
var select_begin := Vector2.ZERO

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
			var held_item = result['collider']
			held_item.angular_velocity = Vector3.ZERO
			held_item.linear_velocity = Vector3.ZERO
			held_items = [held_item]
			held_origins = [Vector3.ZERO]

func release_held():
	for item in held_items:
		item.release_puppeteer.rpc()
	held_items = []

func get_mouse_scroll() -> int:
	var _pressed = func(name):
		return Input.is_action_just_pressed(name) or Input.is_action_pressed(name)
	
	var scroll = -1 if _pressed.call("Gentle Down") else 0
	scroll += 1 if _pressed.call("Gentle Up") else 0
	return scroll

func _is_asset_library_open() -> bool:
	return asset_library.visible

func _reset_flags():
	is_moving = false
	is_ruler_updating = false

func _process_grab(dt, raycast):
	if held_items:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			release_held()
			return
		
		if not raycast:
			return
		
		var direction = Vector3.ZERO
		const K = 10
		const HOVER_DISTANCE = 1.3
		var target = raycast['position'] + HOVER_DISTANCE * Vector3.UP
		
		for i in range(held_items.size()):
			var item = held_items[i]
			var origin = held_origins[i]
			direction = (target + origin) - item.global_position
			item.linear_velocity = direction * K

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
	spawn_rotation_deg += get_mouse_scroll() * dt * OBJECT_SPIN_SPEED_DEG_PER_S
	preview.rotation_degrees.y = spawn_rotation_deg

	if preview_mesh.mesh != active_miniature.mesh():
		preview_mesh.mesh = active_miniature.mesh()
		preview_mesh.position.y = active_miniature.vertical_support_height()
		
		if active_miniature.material == null:
			preview_mesh.material = SPAWN_OVERLAY_SHADER
		else:
			preview_mesh.material = active_miniature.material.duplicate()
			preview_mesh.material.next_pass = SPAWN_OVERLAY_SHADER
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_switch_to_mode(MODE_GRAB)
	if Input.is_action_just_pressed("Do"):
		var at = raycast['position'] + Vector3.UP * active_miniature.vertical_support_height()
		AssetDb.instantiate.rpc(
			active_miniature.id,
			preview_mesh.global_position,
			preview.rotation
		)

func _process_select(dt, raycast):
	var select_end = get_viewport().get_mouse_position()
	var select_min = Vector2.ZERO
	select_min.x = min(select_begin.x, select_end.x)
	select_min.y = min(select_begin.y, select_end.y)
	var select_max = select_begin + select_end - select_min
	var size = select_max - select_min
	selection.position = select_min
	selection.size = size

	if Input.is_action_just_released("Do"):
		var vertices = PackedVector3Array()
		var positions = [
			select_min,
			select_max,
			Vector2(select_min.x, select_max.y),
			Vector2(select_max.x, select_min.y)
		]
		
		var points = PackedVector3Array()
		for p in positions:
			var v = camera.project_ray_normal(p)
			var w = v * INTERACTION_RAY_LENGTH
			points.push_back(v + camera.global_position)
			points.push_back(w + camera.global_position)

		var shape = ConvexPolygonShape3D.new()
		shape.points = points

		var space = get_world_3d().direct_space_state
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		var result = space.intersect_shape(query, 128)
		
		if result:
			held_items = []
			held_origins = []
			var origin_center = Vector3.ZERO
			for res in result:
				if res['collider'] is InteractibleMiniature:
					held_items.append(res['collider'])
					origin_center += res['collider'].global_position
			origin_center /= held_items.size()
			for item in held_items:
				held_origins.append(item.global_position - origin_center)
		_switch_to_mode(MODE_GRAB)

func _process_mode(dt, raycast):
	var lookup = {
		MODE_GRAB: _process_grab,
		MODE_RULER: _process_ruler,
		MODE_SPAWN: _process_spawn,
		MODE_SELECT: _process_select
	}
	lookup[mode].call(dt, raycast)

func _mode_to_str() -> String:
	if mode == MODE_GRAB:
		return "Grab"
	elif mode == MODE_RULER:
		return "Ruler"
	elif mode == MODE_SPAWN:
		return "Spawn"
	elif mode == MODE_SELECT:
		return "Select"
	return "?????"

func _update_status_text():
	status_label.text = ""
	if mode == MODE_GRAB:
		var held_name = "_"
		# TODO: handle multiple held items
		if held_items:
			held_name = held_items[0].display_name()
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
	if mode == MODE_SELECT:
		return
	if not result or not (result['collider'] is Interactible):
		return
	if result['collider'] is RigidBody3D:
		if result['collider'].freeze and not interact_with_frozen:
			return
	var mouse_pos = get_viewport().get_mouse_position()
	hover_label.text = result['collider'].display_name()
	hover_label.position = mouse_pos + Vector2(15, -15)

func _handle_object_copy(result):
	var correct_mode = mode in [MODE_GRAB, MODE_SPAWN]
	var input = Input.is_action_just_pressed("Copy")
	var valid_target = result and result['collider'] is InteractibleMiniature
	
	if correct_mode and input and valid_target:
		var miniature = result['collider']._miniature
		active_miniature = miniature
		_switch_to_mode(MODE_SPAWN)

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
	var space = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collide_with_areas = false
	if held_items:
		var exclude = []
		for item in held_items:
			exclude.append(item.get_rid())
		query.exclude = exclude
	
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
	if held_items:
		if Input.is_action_just_pressed("Reroll"):
			for item in held_items:
				_handle_poke_reroll(item)
			release_held()

func _switch_to_mode(new_mode):
	selection.visible = false
	if new_mode == MODE_SELECT:
		select_begin = get_viewport().get_mouse_position()
		selection.visible = true
	$"Spawn Preview/Preview Mesh".mesh = null
	mode = new_mode

func _handle_mode_switching():
	if Input.is_action_just_pressed("Fallback Mode"):
		_switch_to_mode(MODE_GRAB)
	elif Input.is_action_just_pressed("Ruler Mode"):
		_switch_to_mode(MODE_RULER)

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

func _toggle_asset_library():
	if Input.is_action_just_pressed("Assets"):
		asset_library.visible = not asset_library.visible

func _sync_network():
	if is_moving:
		sync_position.rpc(global_position)
	if is_ruler_updating and is_ruler_valid:
		sync_ruler.rpc($Ruler/A.global_position, $Ruler/B.global_position)

func _handle_select_mode_switch():
	if Input.is_key_pressed(KEY_SHIFT) and Input.is_action_just_pressed("Do"):
		_switch_to_mode(MODE_SELECT)

func _process(dt: float) -> void:
	_reset_flags()
	_display_ruler()
	if not is_multiplayer_authority():
		return
	_toggle_asset_library()
	if _is_asset_library_open():
		return
	_handle_select_mode_switch()
	_handle_mode_switching()
	_update_status_text()
	_handle_toggles()
	_handle_movement(dt)
	_handle_panning(dt)
	var result = _hover_raycast()
	_handle_poke(result)
	_update_hover_text(result)
	_handle_object_copy(result)
	_process_mode(dt, result)
	
	_sync_network()

func _ready() -> void:
	if not is_multiplayer_authority():
		camera.queue_free()
	name = str(get_multiplayer_authority())
	
	asset_library.asset_miniature_clicked.connect(
		func(miniature):
			_switch_to_mode(MODE_SPAWN)
			asset_library.visible = false
			active_miniature = miniature
	)

@rpc("unreliable")
func sync_position(authority_position):
	global_position = authority_position

@rpc
func sync_ruler(a_pos, b_pos):
	$Ruler/A.global_position = a_pos
	$Ruler/B.global_position = b_pos
	_display_ruler()
