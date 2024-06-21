extends Node3D

@onready var animation_player = $AnimationPlayer

var is_open = false

func _ready():
	animation_player.play("RESET")

func open():
	if is_open:
		animation_player.play_backwards("open")
	else:
		animation_player.play("open")
	is_open = !is_open
