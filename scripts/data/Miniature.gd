class_name Miniature extends Resource

@export var display_name: String
@export var id: StringName
@export var _mesh: Mesh
@export var material: Material
@export var density: float = 1
@export var face_values: Dictionary

var _cached_mesh: ArrayMesh
var _cached_shape: ConvexPolygonShape3D = null
var _cached_volume: float = INF
var _cached_deduced_face_values: Dictionary
var _cached_vertical_support: float = INF
var _cached_center: Vector3 = Vector3.INF

func vertical_support_height():
	if _cached_vertical_support == INF:
		var mesh_data = MeshDataTool.new()
		mesh_data.create_from_surface(mesh(), 0)
		var min_y = +INF
		for v in range(mesh_data.get_vertex_count()):
			var vert = mesh_data.get_vertex(v)
			min_y = min(vert.y, min_y)
		_cached_vertical_support = -min_y
	return _cached_vertical_support

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

func center() -> Vector3:
	# https://stackoverflow.com/questions/48918530/how-to-compute-the-centroid-of-a-mesh-with-triangular-faces
	# doesn't seem correct because of 
	# https://stackoverflow.com/questions/66891594/calculate-the-centroid-of-a-3d-mesh-of-triangles
	# but fine overall, i'm not doing rocket science after all
	if _cached_center == Vector3.INF:
		var mesh_data = MeshDataTool.new()
		mesh_data.create_from_surface(mesh(), 0)
		var total_area = 0
		var centroid = Vector3.ZERO
		for i in range(mesh_data.get_face_count()):
			var p0 = mesh_data.get_vertex(mesh_data.get_face_vertex(i, 0))
			var p1 = mesh_data.get_vertex(mesh_data.get_face_vertex(i, 1))
			var p2 = mesh_data.get_vertex(mesh_data.get_face_vertex(i, 2))
			var area = 0.5 * (p1 - p0).cross(p2 - p0).length()
			var center = (p0 + p1 + p2) / 3
			centroid += area * center
			total_area += area
		centroid /= total_area
		_cached_center = centroid
	return _cached_center

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
