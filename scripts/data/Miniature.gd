class_name Miniature extends Resource

@export var display_name: String
@export var mesh: Mesh
@export var material: Material

@export_category("Misc")
@export var density: float = 1

var _cached_shape: ConvexPolygonShape3D = null
var _cached_volume: float = INF

func shape() -> ConvexPolygonShape3D:
	if not _cached_shape:
		_cached_shape = mesh.create_convex_shape(true, true)
	return _cached_shape

func _triangle_volume(a: Vector3, b: Vector3, c: Vector3) -> float:
	return a.dot(b.cross(c)) / 6.

func volume() -> float:
	if _cached_volume == INF:
		_cached_volume = 0
		var mesh_data = MeshDataTool.new()
		mesh_data.create_from_surface(mesh, 0)
		for i in range(mesh_data.get_face_count()):
			var p0 = mesh_data.get_vertex(mesh_data.get_face_vertex(i, 0))
			var p1 = mesh_data.get_vertex(mesh_data.get_face_vertex(i, 1))
			var p2 = mesh_data.get_vertex(mesh_data.get_face_vertex(i, 2))
			_cached_volume += _triangle_volume(p0, p1, p2)
		_cached_volume = abs(_cached_volume)
	return _cached_volume

func mass() -> float:
	return volume() * density

func instantiate(instantiator: Node3D, at: Vector3) -> Node3D:
	var rb = RigidBody3D.new()
	instantiator.get_tree().root.add_child(rb)
	rb.set_script(InteractibleMiniature)
	rb._miniature = self
	
	rb.global_position = at
	rb.mass = mass()

	var csg_mesh = CSGMesh3D.new()
	csg_mesh.mesh = mesh
	if material != null:
		csg_mesh.material = material
	rb.add_child(csg_mesh)
	
	var collider = CollisionShape3D.new()
	collider.shape = shape()
	rb.add_child(collider)
	
	return rb
