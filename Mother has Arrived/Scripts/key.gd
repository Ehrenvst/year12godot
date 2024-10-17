extends Node3D

@export var has_key = false

func _on_area_3d_body_entered(body):
	if body.is_in_group("Player"):
		body._key()
		queue_free()
