class_name InteractibleMiniature extends Interactible

var _rigidbody: RigidBody3D
var _mesh: CSGMesh3D

func rigidbody() -> RigidBody3D:
	return _rigidbody

func mesh() -> CSGMesh3D:
	return _mesh
