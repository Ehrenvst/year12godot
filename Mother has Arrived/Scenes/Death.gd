extends Node3D

func _on_area_3d_body_entered(body):
	if body.is_in_group("Player"):
		get_tree().change_scene_to_file("res://Scenes/Death Screen.tscn")
