extends Node

var miniatures = []

func _load_builtins():
	miniatures.append(preload("res://data/miniatures/Box.tres"))
	miniatures.append(preload("res://data/miniatures/D6.tres"))
	miniatures.append(preload("res://data/miniatures/Teapot.tres"))

func _ready():
	_load_builtins()
