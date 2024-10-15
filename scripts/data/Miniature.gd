class_name Miniature extends Resource

@export var display_name: String
@export var _mesh: Mesh
@export var material: Material
@export var density: float = 1
@export var face_values: Dictionary

var _cached_mesh: ArrayMesh
var _cached_shape: ConvexPolygonShape3D = null
var _cached_volume: float = INF
var _cached_deduced_face_values: Dictionary

func resolve_face_value(idx: int):
	deduce_faces_values()
	
	var ret = face_values.get(idx)
	if ret:
		return ret
	return _cached_deduced_face_values.get(idx)

func shape() -> ConvexPolygonShape3D:
	if not _cached_shape:
		_cached_shape = mesh().create_convex_shape(true, true)
	return _cached_shape

func _triangle_volume(a: Vector3, b: Vector3, c: Vector3) -> float:
	return a.dot(b.cross(c)) / 6.

func mesh() -> ArrayMesh:
	if not _cached_mesh:
		if _mesh is not ArrayMesh:
			var arr_mesh = ArrayMesh.new()
			arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _mesh.get_mesh_arrays())
			_cached_mesh = arr_mesh
		else:
			_cached_mesh = _mesh
	return _cached_mesh

func volume() -> float:
	if _cached_volume == INF:
		_cached_volume = 0
		var mesh_data = MeshDataTool.new()
		mesh_data.create_from_surface(mesh(), 0)
		for i in range(mesh_data.get_face_count()):
			var p0 = mesh_data.get_vertex(mesh_data.get_face_vertex(i, 0))
			var p1 = mesh_data.get_vertex(mesh_data.get_face_vertex(i, 1))
			var p2 = mesh_data.get_vertex(mesh_data.get_face_vertex(i, 2))
			_cached_volume += _triangle_volume(p0, p1, p2)
		_cached_volume = abs(_cached_volume)
	return _cached_volume

func mass() -> float:
	return volume() * density

func deduce_faces_values():
	if not _cached_deduced_face_values.is_empty():
		return
	
	var mesh_data = MeshDataTool.new()
	mesh_data.create_from_surface(mesh(), 0)
	
	for face in range(mesh_data.get_face_count()):
		var min_idx = -1
		var min_dot = INF
		for valued_face_idx in face_values:
			var normal = mesh_data.get_face_normal(valued_face_idx)
			var dot = normal.dot(mesh_data.get_face_normal(face))
			if dot < min_dot:
				min_dot = dot
				min_idx = valued_face_idx
		_cached_deduced_face_values[face] = face_values[min_idx]

func instantiate(instantiator: Node3D, at: Vector3) -> Node3D:
	var rb = RigidBody3D.new()
	
	instantiator.get_tree().root.add_child(rb)
	var script = load("res://scripts/interactions/InteractibleMiniature.gd")
	rb.set_script(script)
	if rb is InteractibleMiniature:
		rb._net_fallback_peer = instantiator.get_multiplayer_authority()
	
	rb._miniature = self
	rb.set_multiplayer_authority(1)
	
	rb.global_position = at
	rb.mass = mass()

	var csg_mesh = CSGMesh3D.new()
	csg_mesh.mesh = mesh()
	if material != null:
		csg_mesh.material = material
	rb.add_child(csg_mesh)
	
	var collider = CollisionShape3D.new()
	collider.shape = shape()
	rb.add_child(collider)
	
	rb.set_process(true)
	rb.set_physics_process(true)
	
	return rb
