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
	var shop_container: VBoxContainer = job_complete_screen.get_node("Panel/VBox/ShopContainer")
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

	# Build shop section
	_build_shop_ui(shop_container)

	next_btn.pressed.connect(_on_next_job_pressed, CONNECT_ONE_SHOT)


func _build_shop_ui(container: VBoxContainer) -> void:
	# Clear previous shop items
	for child in container.get_children():
		child.queue_free()

	var purchasable_tools := GameManager.get_purchasable_tools()
	var purchasable_soaps := GameManager.get_purchasable_soaps()

	if purchasable_tools.is_empty() and purchasable_soaps.is_empty():
		container.visible = false
		return

	container.visible = true

	var header := Label.new()
	header.text = "-- SHOP --"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	container.add_child(header)

	var balance_label := Label.new()
	balance_label.text = "Balance: $%.2f" % GameManager.total_money
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.add_theme_font_size_override("font_size", 13)
	container.add_child(balance_label)

	for tool_id in purchasable_tools:
		var tool_data: Dictionary = GameManager.TOOLS[tool_id]
		var price: float = tool_data.get("price", 0.0)
		var can_afford := GameManager.total_money >= price

		var btn := Button.new()
		btn.text = "$%.0f - %s" % [price, tool_data["name"]]
		btn.tooltip_text = tool_data["description"]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 13)
		btn.disabled = not can_afford
		btn.pressed.connect(_on_shop_buy_tool.bind(tool_id, container))
		container.add_child(btn)

	for soap_id in purchasable_soaps:
		var soap_data: Dictionary = GameManager.SOAPS[soap_id]
		var price: float = soap_data.get("price", 0.0)
		var can_afford := GameManager.total_money >= price

		var btn := Button.new()
		btn.text = "$%.0f - %s Soap" % [price, soap_data["name"]]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 13)
		btn.disabled = not can_afford
		btn.pressed.connect(_on_shop_buy_soap.bind(soap_id, container))
		container.add_child(btn)


func _on_shop_buy_tool(tool_id: String, shop_container: VBoxContainer) -> void:
	if GameManager.purchase_tool(tool_id):
		AudioManager.play_complete()
		_build_shop_ui(shop_container)
		# Update the earned label to reflect new balance
		var earned_label: Label = job_complete_screen.get_node("Panel/VBox/EarnedValue")
		earned_label.text = earned_label.text  # keep as-is, balance shown in shop


func _on_shop_buy_soap(soap_id: String, shop_container: VBoxContainer) -> void:
	if GameManager.purchase_soap(soap_id):
		AudioManager.play_complete()
		_build_shop_ui(shop_container)


func _on_next_job_pressed() -> void:
	current_job_index += 1
	if current_job_index >= Levels.get_job_count():
		current_job_index = 0  # Loop back
	_load_job(current_job_index)


func _on_start_button_pressed() -> void:
	_start_game()
