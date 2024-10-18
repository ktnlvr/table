extends Node

var multiplayer_peer = ENetMultiplayerPeer.new()

const PORT = 11999
const HOSTNAME = "127.0.0.1"

var player = preload("res://scenes/prefabs/player.tscn")

var connected_peers = []

func _on_host_pressed() -> void:
	$UI.visible = false
	multiplayer_peer.create_server(PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	DisplayServer.window_set_title("Server " + str(multiplayer.get_unique_id()))
	
	# 1 is the server peer id
	add_player(1)
	
	multiplayer.peer_connected.connect(
		func (peer_id):
			# TODO: check if this is even needed?
			add_newly_connected_player.rpc(peer_id)
			add_previous_players.rpc_id(peer_id, connected_peers)
			add_player(peer_id)
	)

func _on_join_pressed() -> void:
	$UI.visible = false
	multiplayer_peer.create_client(HOSTNAME, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	DisplayServer.window_set_title("Client " + str(multiplayer.get_unique_id()))

func add_player(peer_id):
	connected_peers.append(peer_id)
	var instance = player.instantiate()
	instance.set_multiplayer_authority(peer_id)
	get_tree().root.add_child(instance)

@rpc
func add_newly_connected_player(peer_id):
	add_player(peer_id)

@rpc
func add_previous_players(connected_peers):
	for peer in connected_peers:
		add_player(peer)

func _get_window_title() -> String:
	return "Table | " + str(Engine.get_frames_per_second()) + " FPS | NetId " + str(multiplayer.get_unique_id())

func _process(dt):
	DisplayServer.window_set_title(_get_window_title())
