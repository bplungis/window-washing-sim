extends CharacterBody3D

## First-person player controller for the window washer.

@export var move_speed: float = 3.0
@export var mouse_sensitivity: float = 0.002
@export var reach_distance: float = 2.5

@onready var camera: Camera3D = $Camera3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var tool_pivot: Node3D = $Camera3D/ToolPivot

# State
var _is_using_tool: bool = false
var _current_window: WindowSurface = null
var _last_hit_uv: Vector2 = Vector2.ZERO
var _mouse_captured: bool = false


func _ready() -> void:
	# Capture mouse for FPS controls
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true

	# Configure raycast to hit windows (layer 3 = bit 4)
	raycast.target_position = Vector3(0, 0, -reach_distance)
	raycast.collision_mask = 4  # Layer 3

	# Connect to tool changes for visual feedback
	GameManager.tool_changed.connect(_on_tool_changed)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and _mouse_captured:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.2, PI / 2.2)

	# Toggle mouse capture with Escape
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _mouse_captured:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_mouse_captured = false
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_mouse_captured = true

	# Tool selection via number keys (only if unlocked)
	if event.is_action_pressed("tool_1"):
		_try_select_tool_by_index(0)
	elif event.is_action_pressed("tool_2"):
		_try_select_tool_by_index(1)
	elif event.is_action_pressed("tool_3"):
		_try_select_tool_by_index(2)
	elif event.is_action_pressed("tool_4"):
		_try_select_tool_by_index(3)
	elif event.is_action_pressed("tool_5"):
		_try_select_tool_by_index(4)

	# Soap selection via F1-F4 (only if unlocked)
	if event.is_action_pressed("soap_1"):
		_try_select_soap_by_index(0)
	elif event.is_action_pressed("soap_2"):
		_try_select_soap_by_index(1)
	elif event.is_action_pressed("soap_3"):
		_try_select_soap_by_index(2)
	elif event.is_action_pressed("soap_4"):
		_try_select_soap_by_index(3)

	# Scroll wheel to cycle tools
	if event.is_action_pressed("scroll_up"):
		GameManager.cycle_tool(-1)
	elif event.is_action_pressed("scroll_down"):
		GameManager.cycle_tool(1)


func _physics_process(delta: float) -> void:
	# Movement
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	input_dir = input_dir.normalized()
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * 5.0 * delta)

	# Simple gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	# Tool usage
	_handle_tool(delta)


func _handle_tool(delta: float) -> void:
	var is_pressing := Input.is_action_pressed("use_tool")

	# Check what the raycast is hitting
	if raycast.is_colliding():
		var collider := raycast.get_collider()
		if collider is WindowSurface:
			var window: WindowSurface = collider as WindowSurface
			var hit_point := raycast.get_collision_point()
			var uv := window.world_to_uv(hit_point)
			_last_hit_uv = uv

			# Show tool highlight
			window.material.set_shader_parameter("tool_uv", uv)
			var tool_data: Dictionary = GameManager.get_tool_data()
			window.material.set_shader_parameter("tool_radius", tool_data["width"] * 0.5)

			if is_pressing:
				if not _is_using_tool:
					_is_using_tool = true
					AudioManager.start_tool_sound(GameManager.current_tool)

				# Apply tool
				var removed := window.apply_tool_at_uv(uv, delta)

				# Update progress
				var cleanliness := window.get_cleanliness()
				GameManager.progress_updated.emit(cleanliness)

				# Check for job completion
				if cleanliness >= 98.0:
					_complete_current_window(window)

			elif _is_using_tool:
				_stop_tool()

			_current_window = window
		else:
			_clear_window_highlight()
			if _is_using_tool:
				_stop_tool()
	else:
		_clear_window_highlight()
		if _is_using_tool:
			_stop_tool()


func _stop_tool() -> void:
	_is_using_tool = false
	AudioManager.stop_tool_sound()


func _clear_window_highlight() -> void:
	if _current_window != null:
		_current_window.clear_tool_highlight()
		_current_window = null


func _complete_current_window(window: WindowSurface) -> void:
	_stop_tool()
	var cleanliness := window.get_cleanliness()
	GameManager.complete_job(cleanliness)
	AudioManager.play_complete()


func _try_select_tool_by_index(idx: int) -> void:
	if idx < 0 or idx >= GameManager.tool_order.size():
		return
	var tool_id: String = GameManager.tool_order[idx]
	if GameManager.is_tool_unlocked(tool_id):
		GameManager.set_tool(tool_id)


func _try_select_soap_by_index(idx: int) -> void:
	if idx < 0 or idx >= GameManager.soap_order.size():
		return
	var soap_id: String = GameManager.soap_order[idx]
	if GameManager.is_soap_unlocked(soap_id):
		GameManager.set_soap(soap_id)


func _on_tool_changed(_tool_id: String) -> void:
	AudioManager.play_click()
	# If actively using tool, switch the sound
	if _is_using_tool:
		AudioManager.stop_tool_sound()
		AudioManager.start_tool_sound(_tool_id)
