class_name InteractibleMiniature extends Interactible

@export var _rigidbody: RigidBody3D
@export var _mesh: CSGMesh3D
@export var _collider: CollisionShape3D
@export var _miniature: Miniature

func display_name() -> String:
	return _miniature.display_name
	
func miniature() -> Miniature:
	return _miniature

func rigidbody() -> RigidBody3D:
	return _rigidbody

func mesh() -> CSGMesh3D:
	return _mesh
