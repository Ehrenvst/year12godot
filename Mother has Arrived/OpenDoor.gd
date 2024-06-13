extends Node3D



func _on_area_3d_mouse_entered():
	$AnimationPlayer.play("Opened Door")
