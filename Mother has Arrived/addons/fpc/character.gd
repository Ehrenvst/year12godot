extends CharacterBody3D

@onready var ray = $Head/Camera/RayCast3D
@onready var player = $"."

@onready var interaction_notifier = $Control/interaction_notifier
@onready var locked = $Control/locked
@onready var unlock = $Control/unlock

var has_key = false

@export_category("Character")
@export var base_speed : float = 2.0
@export var sprint_speed : float = 6.0
@export var crouch_speed : float = 1.0
@export var speed_boost : float = 0.5

@export var acceleration : float = 10.0
@export var jump_velocity : float = 4.5

@export var mouse_sensitivity : float = 0.1
@export var immobile : bool = false
@export_file var default_reticle

@export_group("Nodes")
@export var HEAD : Node3D
@export var CAMERA : Camera3D
@export var HEADBOB_ANIMATION : AnimationPlayer
@export var JUMP_ANIMATION : AnimationPlayer
@export var CROUCH_ANIMATION : AnimationPlayer
@export var COLLISION_MESH : CollisionShape3D

@export_group("Controls")
# We are using UI controls because they are built into Godot Engine so they can be used right away
@export var JUMP : String = "ui_accept"
@export var LEFT : String = "ui_left"
@export var RIGHT : String = "ui_right"
@export var FORWARD : String = "ui_up"
@export var BACKWARD : String = "ui_down"
@export var PAUSE : String = "ui_cancel"
@export var CROUCH : String
@export var SPRINT : String

@export_group("Feature Settings")
@export var jumping_enabled : bool = true
@export var in_air_momentum : bool = true
@export var motion_smoothing : bool = true
@export var sprint_enabled : bool = true
@export var crouch_enabled : bool = true
@export_enum("Hold to Crouch", "Toggle Crouch") var crouch_mode : int = 0
@export_enum("Hold to Sprint", "Toggle Sprint") var sprint_mode : int = 0
@export var dynamic_fov : bool = true
@export var continuous_jumping : bool = true
@export var view_bobbing : bool = true
@export var jump_animation : bool = true
@export var pausing_enabled : bool = true
@export var gravity_enabled : bool = true


# Member variables
var speed : float = base_speed
var current_speed : float = 0.0
# States: normal, crouching, sprinting
var state : String = "normal"
var low_ceiling : bool = false # This is for when the cieling is too low and the player needs to crouch.
var was_on_floor : bool = true # Was the player on the floor last frame (for landing animation)

# The reticle should always have a Control node as the root
var RETICLE : Control

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity") # Don't set this as a const, see the gravity section in _physics_process


func _ready():
	#It is safe to comment this line if your game doesn't start with the mouse captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# If the controller is rotated in a certain direction for game design purposes, redirect this rotation into the head.
	HEAD.rotation.y = rotation.y
	rotation.y = 0
	
	if default_reticle:
		change_reticle(default_reticle)
	
	# Reset the camera position
	# If you want to change the default head height, change these animations.
	HEADBOB_ANIMATION.play("RESET")
	
	check_controls()
	
func _unhandled_input(event):
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			HEAD.rotation_degrees.y -= event.relative.x * mouse_sensitivity
			HEAD.rotation_degrees.x -= event.relative.y * mouse_sensitivity

func check_controls(): # If you add a control, you might want to add a check for it here.
	if !InputMap.has_action(LEFT):
		push_error("No control mapped for move left. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(RIGHT):
		push_error("No control mapped for move right. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(FORWARD):
		push_error("No control mapped for move forward. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(BACKWARD):
		push_error("No control mapped for move backward. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(PAUSE):
		push_error("No control mapped for move pause. Please add an input map control. Disabling pausing.")
		pausing_enabled = false


func change_reticle(reticle): # Yup, this function is kinda strange
	if RETICLE:
		RETICLE.queue_free()
	
	RETICLE = load(reticle).instantiate()
	RETICLE.character = self
	$UserInterface.add_child(RETICLE)

func _speedboost():
	
	print("hehe speeeeeed")
	base_speed = base_speed + speed_boost
	speed = base_speed
	
func _key():
	
	print("omg a key")
	has_key = true

func _physics_process(delta):
	# Big thanks to github.com/LorenzoAncora for the concept of the improved debug values
	current_speed = Vector3.ZERO.distance_to(get_real_velocity())
	$UserInterface/DebugPanel.add_property("Speed", snappedf(current_speed, 0.001), 1)
	$UserInterface/DebugPanel.add_property("Target speed", speed, 2)
	var cv : Vector3 = get_real_velocity()
	var vd : Array[float] = [
		snappedf(cv.x, 0.001),
		snappedf(cv.y, 0.001),
		snappedf(cv.z, 0.001)
	]
	var readable_velocity : String = "X: " + str(vd[0]) + " Y: " + str(vd[1]) + " Z: " + str(vd[2])
	$UserInterface/DebugPanel.add_property("Velocity", readable_velocity, 3)
	
	# Gravity
	#gravity = ProjectSettings.get_setting("physics/3d/default_gravity") # If the gravity changes during your game, uncomment this code
	if not is_on_floor() and gravity and gravity_enabled:
		velocity.y -= gravity * delta
	
	var input_dir = Vector2.ZERO
	if !immobile: # Immobility works by interrupting user input, so other forces can still be applied to the player
		input_dir = Input.get_vector(LEFT, RIGHT, FORWARD, BACKWARD)
	handle_movement(delta, input_dir)
	
	# The player is not able to stand up if the ceiling is too low
	low_ceiling = $CrouchCeilingDetection.is_colliding()
	
	if dynamic_fov: # This may be changed to an AnimationPlayer
		update_camera_fov()
	
	if view_bobbing:
		headbob_animation(input_dir)

func handle_movement(delta, input_dir):
	var direction = input_dir.rotated(-HEAD.rotation.y)
	direction = Vector3(direction.x, 0, direction.y)
	move_and_slide()
	
	if in_air_momentum:
		if is_on_floor():
			if motion_smoothing:
				velocity.x = lerp(velocity.x, direction.x * speed, acceleration * delta)
				velocity.z = lerp(velocity.z, direction.z * speed, acceleration * delta)
			else:
				velocity.x = direction.x * speed
				velocity.z = direction.z * speed
	else:
		if motion_smoothing:
			velocity.x = lerp(velocity.x, direction.x * speed, acceleration * delta)
			velocity.z = lerp(velocity.z, direction.z * speed, acceleration * delta)
		else:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed

func update_camera_fov():
	if state == "sprinting":
		CAMERA.fov = lerp(CAMERA.fov, 85.0, 0.3)
	else:
		CAMERA.fov = lerp(CAMERA.fov, 75.0, 0.3)


func headbob_animation(moving):
	if moving and is_on_floor():
		var use_headbob_animation : String
		match state:
			"normal","crouching":
				use_headbob_animation = "walk"
			"sprinting":
				use_headbob_animation = "sprint"
		
		var was_playing : bool = false
		if HEADBOB_ANIMATION.current_animation == use_headbob_animation:
			was_playing = true
		
		HEADBOB_ANIMATION.play(use_headbob_animation, 0.25)
		HEADBOB_ANIMATION.speed_scale = (current_speed / base_speed) * 1.75
		if !was_playing:
			HEADBOB_ANIMATION.seek(float(randi() % 2)) # Randomize the initial headbob direction
			# Let me explain that piece of code because it looks like it does the opposite of what it actually does.
			# The headbob animation has two starting positions. One is at 0 and the other is at 1.
			# randi() % 2 returns either 0 or 1, and so the animation randomly starts at one of the starting positions.
			# This code is extremely performant but it makes no sense.
		
	else:
		if HEADBOB_ANIMATION.is_playing():
			HEADBOB_ANIMATION.play("RESET", 0.25)
			HEADBOB_ANIMATION.speed_scale = 1

func _process(delta):
	$UserInterface/DebugPanel.add_property("FPS", Performance.get_monitor(Performance.TIME_FPS), 0)
	var status : String = state
	if !is_on_floor():
		status += " in the air"
	$UserInterface/DebugPanel.add_property("State", status, 4)
	
	if pausing_enabled:
		if Input.is_action_just_pressed(PAUSE):
			match Input.mouse_mode:
				Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				Input.MOUSE_MODE_VISIBLE:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if player.position.y < -20:
		get_tree().change_scene_to_file("res://Scenes/End Screen.tscn")
	
	HEAD.rotation.x = clamp(HEAD.rotation.x, deg_to_rad(-90), deg_to_rad(90))

	if ray.is_colliding():
		check_collisions()
	else:
		pass

	was_on_floor = is_on_floor() # This must always be at the end of physics_process
	
func check_collisions():
	var collider = ray.get_collider()
	if collider:
		if collider.is_in_group("Doors") and !collider.door_locked:
			interaction_notifier.visible = true
			if Input.is_action_just_pressed("interact"):
				var door_node = collider
				while door_node and not door_node.has_method("open"):
					door_node = door_node.get_parent()
				if door_node and door_node.has_method("open"):
					door_node.open()
					
		elif collider.is_in_group("Doors") and collider.door_locked and !has_key:
			locked.visible = true
			
		elif collider.is_in_group("Doors") and collider.door_locked and has_key:
			unlock.visible = true
			if Input.is_action_just_pressed("interact"):
				collider.door_locked = false
				unlock.visible = false
				has_key = false
		
		else:
			interaction_notifier.visible = false
			locked.visible = false
			unlock.visible = false
	else:
		interaction_notifier.visible = false
		locked.visible = false
		unlock.visible = false
