class_name InteractibleMiniature extends Interactible

@export var _rigidbody: RigidBody3D
@export var _mesh: CSGMesh3D
@export var _collider: CollisionShape3D
@export var _miniature: Miniature

var _net_fallback_peer: int = 1

var busy = false;

func top_face():
	var mesh_data = MeshDataTool.new()
	mesh_data.create_from_surface(_miniature.mesh(), 0)
	
	var max_idx = -1
	var max_dot = -INF
	for face in range(mesh_data.get_face_count()):
		var normal = self.transform.translated(-self.global_position) * mesh_data.get_face_normal(face)
		var dot = Vector3.UP.dot(normal)
		if dot >= max_dot:
			max_dot = dot 
			max_idx = face
	if max_idx == -1:
		return null
	return max_idx

func display_name() -> String:
	if _miniature.face_values:
		var top_face = top_face()
		var face_value = _miniature.resolve_face_value(top_face())
		return _miniature.display_name + ' (' + str(face_value) + ')'
	return _miniature.display_name

func miniature() -> Miniature:
	return _miniature

func rigidbody() -> RigidBody3D:
	return _rigidbody

func mesh() -> CSGMesh3D:
	return _mesh

func can_puppeteer():
	return is_multiplayer_authority() || !busy

@rpc("any_peer", "call_local")
func take_puppeteer():
	if busy and get_multiplayer_authority() != multiplayer.get_remote_sender_id():
		return

	set_multiplayer_authority(multiplayer.get_remote_sender_id())
	busy = true

@rpc("call_local")
func release_puppeteer():
	busy = false
	if _net_fallback_peer in multiplayer.get_peers():
		set_multiplayer_authority(_net_fallback_peer)
	else:
		set_multiplayer_authority(1)

func _physics_process(dt) -> void:
	if is_multiplayer_authority() and not self.sleeping:
		sync_physics_properties.rpc(
			global_position,
			global_rotation, 
			self.linear_velocity, 
			self.angular_velocity, 
		)

@rpc("unreliable")
func sync_physics_properties(pos, rot, lin_vel, ang_vel):
	global_position = pos
	global_rotation = rot
	self.linear_velocity = lin_vel
	self.angular_velocity = ang_vel

static func random_direction(rand_float: float) -> Vector3:
	var theta := rand_float * TAU
	var phi := acos(2.0 * rand_float - 1.0)
	var sin_phi := sin(phi)
	return Vector3(cos(theta) * sin_phi, sin(theta) * sin_phi, cos(phi))

@rpc("any_peer", "call_local")
func sync_reroll(rand_float):
	if busy:
		return
	set_multiplayer_authority(1)
	const REROLL_JUMP_HEIGHT = 2
	var jump_velocity = sqrt(2 * 9.8 * REROLL_JUMP_HEIGHT)
	self.linear_velocity += Vector3.UP * jump_velocity
	self.angular_velocity += random_direction(rand_float) * (4 * rand_float * TAU + PI)

@rpc("any_peer", "call_local")
func sync_toggle_freeze():
	if busy:
		return
	self.freeze = not self.freeze
