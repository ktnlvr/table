class_name InteractibleMiniature extends Interactible

@export var _rigidbody: RigidBody3D
@export var _mesh: CSGMesh3D
@export var _collider: CollisionShape3D
@export var _miniature: Miniature

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
