extends CanvasLayer

@onready var label = $Label
@onready var timer = $Timer
@onready var total_time_seconds : int = 0
@onready var finished_time = 0

func _ready():
	var total_time_seconds = 0
	$Timer.start()

func _on_timer_timeout():
	total_time_seconds += 1
	var m = int(total_time_seconds / 60)
	var s = total_time_seconds - m * 60
	$Label.text = '%02d:%02d' % [m, s]
