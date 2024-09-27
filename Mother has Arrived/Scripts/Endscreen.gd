extends Control


func _ready():
	$"VBoxContainer/Title".grab_focus()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_title_pressed():
	get_tree().change_scene_to_file("res://Scenes/Title Screen.tscn")

func _on_quit_pressed():
	get_tree().quit()
