extends Node3D

## Main game scene controller.
## Manages job flow, window setup, environment, and UI screens.

@onready var player: CharacterBody3D = $Player
@onready var window_anchor: Node3D = $WindowAnchor
@onready var hud: CanvasLayer = $HUD
@onready var environment_node: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $DirectionalLight3D

# UI screens
@onready var title_screen: Control = $UIScreens/TitleScreen
@onready var job_complete_screen: Control = $UIScreens/JobCompleteScreen

# Job state
var current_job_index: int = 0
var current_window: WindowSurface = null

# Preloads
var window_scene: PackedScene = preload("res://scenes/window_surface.tscn")


func _ready() -> void:
	# Show title screen
	_show_title_screen()

	GameManager.job_completed.connect(_on_job_completed)


func _show_title_screen() -> void:
	title_screen.visible = true
	job_complete_screen.visible = false
	hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set_physics_process(false)


func _start_game() -> void:
	title_screen.visible = false
	hud.visible = true
	current_job_index = 0
	_load_job(current_job_index)


func _load_job(index: int) -> void:
	var job: Dictionary = Levels.get_job(index)

	# Remove old window if any
	if current_window != null:
		current_window.queue_free()
		current_window = null

	# Spawn new window
	current_window = window_scene.instantiate() as WindowSurface
	var win_size: Vector2 = job.get("window_size", Vector2(2.0, 2.5))
	current_window.window_width = win_size.x
	current_window.window_height = win_size.y
	window_anchor.add_child(current_window)

	# Position window on the wall
	current_window.position = Vector3(0, win_size.y * 0.5 + 0.5, 0)

	# Generate dirt
	current_window.setup_dirt(job["dirt"], index * 12345 + 42)

	# Position player in front of window
	player.position = Vector3(0, 0, 2.0)
	player.rotation = Vector3.ZERO

	# Start the job
	GameManager.start_job(job)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.set_physics_process(true)
	job_complete_screen.visible = false


func _on_job_completed(results: Dictionary) -> void:
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Show completion screen
	job_complete_screen.visible = true
	_update_completion_ui(results)


func _update_completion_ui(results: Dictionary) -> void:
	var clean_label: Label = job_complete_screen.get_node("Panel/VBox/CleanValue")
	var streak_label: Label = job_complete_screen.get_node("Panel/VBox/StreakValue")
	var time_label: Label = job_complete_screen.get_node("Panel/VBox/TimeValue")
	var earned_label: Label = job_complete_screen.get_node("Panel/VBox/EarnedValue")
	var next_btn: Button = job_complete_screen.get_node("Panel/VBox/NextButton")

	clean_label.text = "%.1f%%" % results["cleanliness"]
	if current_window:
		streak_label.text = "%.1f%%" % current_window.get_streak_free()
	else:
		streak_label.text = "—"

	var elapsed: float = results["time_elapsed"]
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	time_label.text = "%d:%02d" % [minutes, seconds]
	earned_label.text = "$%.2f" % results["earned"]

	next_btn.pressed.connect(_on_next_job_pressed, CONNECT_ONE_SHOT)


func _on_next_job_pressed() -> void:
	current_job_index += 1
	if current_job_index >= Levels.get_job_count():
		current_job_index = 0  # Loop back
	_load_job(current_job_index)


func _on_start_button_pressed() -> void:
	_start_game()
