extends Node3D

@export var axis := Vector3.UP
@export var degrees_per_second := 120.
@export var bounce_speed = 0.
@export var bounce_amplitude = 0.
@export var time = 0

func _process(dt: float):
	time += dt
	rotate(axis, deg_to_rad(degrees_per_second * dt))
	translate(Vector3.UP * bounce_amplitude * sin(bounce_speed * time))
