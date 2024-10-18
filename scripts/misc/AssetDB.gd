extends Node3D

var miniatures: Dictionary = {}

@onready var builtins = [
	preload("res://data/miniatures/Box.tres"),
	preload("res://data/miniatures/D6.tres"),
	preload("res://data/miniatures/Teapot.tres")
]

func _load_builtins():
	for builtin in builtins:
		miniatures[builtin.id] = builtin

func _ready():
	_load_builtins()

@rpc("call_local", "any_peer")
func instantiate(id: StringName, at: Vector3, rot: Vector3):
	var miniature = miniatures.get(id)
	assert(miniature != null)
	var instance = miniature.instantiate(self, at)
	instance.rotation = rot
