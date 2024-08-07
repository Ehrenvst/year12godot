extends Control


func _ready():
	$"VBoxContainer/Level 1".grab_focus()

func _on_level_1_pressed():
	get_tree().change_scene_to_file("res://Testing Levels.tscn")

func _on_quit_pressed():
	get_tree().quit()
