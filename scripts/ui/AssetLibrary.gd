extends Control

@onready var asset_card = preload("res://scenes/ui/asset_miniature.tscn")

@onready var card_container = $Main/Flow

signal asset_miniature_clicked(miniature: Miniature)

func _add_miniature(miniature: Miniature):
	var instance = asset_card.instantiate()
	instance.name = miniature.display_name
	assert(instance is AssetMiniatureCard)
	instance.miniature = miniature
	
	card_container.add_child(instance)
	var card = instance.get_node("Container")

	var name: Label = card.get_node("Name")
	name.text = miniature.display_name
	
	var mesh: MeshInstance3D = card.get_node("Texture/Viewport/Mesh")
	mesh.mesh = miniature.mesh()
	if miniature.material:
		mesh.material_override = miniature.material
	
	var texture_button: TextureButton = card.get_node("Texture")
	texture_button.button_down.connect(
		func():
			asset_miniature_clicked.emit(miniature)
	)

func _ready() -> void:
	for miniature in AssetDb.miniatures.values():
		_add_miniature(miniature)
