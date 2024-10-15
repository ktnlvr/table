class_name InteractibleMiniature extends Interactible

@export var _rigidbody: RigidBody3D
@export var _mesh: CSGMesh3D
@export var _collider: CollisionShape3D
@export var _miniature: Miniature

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
	print(get_multiplayer_authority(), multiplayer.get_remote_sender_id())
	if busy and get_multiplayer_authority() != multiplayer.get_remote_sender_id():
		return
	
	set_multiplayer_authority(multiplayer.get_remote_sender_id())
	busy = true

@rpc("call_local")
func release_puppeteer():
	busy = false
	set_multiplayer_authority(1)

func _physics_process(dt) -> void:
	if is_multiplayer_authority():
		sync_physics_properties.rpc(
			global_position,
			global_rotation, 
			self.linear_velocity, 
			self.angular_velocity, 
		)

@rpc("any_peer", "unreliable")
func sync_physics_properties(pos, rot, lin_vel, ang_vel):
	if get_multiplayer_authority() != multiplayer.get_remote_sender_id():
		return
	global_position = pos
	global_rotation = rot
	self.linear_velocity = lin_vel
	self.angular_velocity = ang_vel
