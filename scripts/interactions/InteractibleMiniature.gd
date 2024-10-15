class_name InteractibleMiniature extends Interactible

@export var _rigidbody: RigidBody3D
@export var _mesh: CSGMesh3D
@export var _collider: CollisionShape3D
@export var _miniature: Miniature

var _upmost_face = null

func upmost_face():
	if _upmost_face == null:
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
	return _upmost_face

func display_name() -> String:
	return _miniature.display_name + ' ' + str(upmost_face())
	
func miniature() -> Miniature:
	return _miniature

func rigidbody() -> RigidBody3D:
	return _rigidbody

func mesh() -> CSGMesh3D:
	return _mesh

func _ready()->void:
	connect("sleeping_state_changed", self._on_sleeping_state)

func _process(dt):
	upmost_face()

func _on_sleeping_state():
	if self.sleeping:
		_upmost_face = upmost_face()
	else:
		_upmost_face = null
