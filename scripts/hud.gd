extends CanvasLayer

## In-game HUD showing tools, soaps, progress, and earnings.

@onready var job_label: Label = %JobLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var money_label: Label = %MoneyLabel
@onready var tool_container: HBoxContainer = %ToolContainer
@onready var soap_container: HBoxContainer = %SoapContainer
@onready var tool_name_label: Label = %ToolNameLabel
@onready var tool_desc_label: Label = %ToolDescLabel
@onready var crosshair: TextureRect = %Crosshair

var tool_buttons: Dictionary = {}
var soap_buttons: Dictionary = {}


func _ready() -> void:
	GameManager.tool_changed.connect(_on_tool_changed)
	GameManager.soap_changed.connect(_on_soap_changed)
	GameManager.progress_updated.connect(_on_progress_updated)
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.job_started.connect(_on_job_started)

	_setup_tool_buttons()
	_setup_soap_buttons()
	_update_tool_info(GameManager.current_tool)


func _setup_tool_buttons() -> void:
	# Clear any placeholder children
	for child in tool_container.get_children():
		child.queue_free()

	var idx := 1
	for tool_id in GameManager.tool_order:
		var tool_data: Dictionary = GameManager.TOOLS[tool_id]
		var btn := Button.new()
		btn.text = "%d: %s" % [idx, tool_data["name"]]
		btn.toggle_mode = true
		btn.button_pressed = (tool_id == GameManager.current_tool)
		btn.custom_minimum_size = Vector2(100, 40)
		btn.pressed.connect(_on_tool_button_pressed.bind(tool_id))

		# Style
		btn.add_theme_font_size_override("font_size", 13)
		tool_container.add_child(btn)
		tool_buttons[tool_id] = btn
		idx += 1


func _setup_soap_buttons() -> void:
	for child in soap_container.get_children():
		child.queue_free()

	# Add label
	var label := Label.new()
	label.text = "Soap (F1-F4): "
	label.add_theme_font_size_override("font_size", 13)
	soap_container.add_child(label)

	var fidx := 1
	for soap_id in GameManager.soap_order:
		var soap_data: Dictionary = GameManager.SOAPS[soap_id]
		var btn := Button.new()
		btn.text = "F%d: %s" % [fidx, soap_data["name"]]
		btn.toggle_mode = true
		btn.button_pressed = (soap_id == GameManager.current_soap)
		btn.custom_minimum_size = Vector2(110, 36)
		btn.pressed.connect(_on_soap_button_pressed.bind(soap_id))
		btn.add_theme_font_size_override("font_size", 12)

		soap_container.add_child(btn)
		soap_buttons[soap_id] = btn
		fidx += 1


func _on_tool_button_pressed(tool_id: String) -> void:
	GameManager.set_tool(tool_id)


func _on_soap_button_pressed(soap_id: String) -> void:
	GameManager.set_soap(soap_id)


func _on_tool_changed(tool_id: String) -> void:
	for tid in tool_buttons:
		tool_buttons[tid].button_pressed = (tid == tool_id)
	_update_tool_info(tool_id)


func _on_soap_changed(soap_id: String) -> void:
	for sid in soap_buttons:
		soap_buttons[sid].button_pressed = (sid == soap_id)


func _on_progress_updated(percent: float) -> void:
	progress_bar.value = percent


func _on_money_changed(total: float) -> void:
	money_label.text = "$%.2f" % total


func _on_job_started(job: Dictionary) -> void:
	job_label.text = job.get("name", "Window Job")
	progress_bar.value = 0.0


func _update_tool_info(tool_id: String) -> void:
	var tool_data: Dictionary = GameManager.TOOLS[tool_id]
	tool_name_label.text = tool_data["name"]
	tool_desc_label.text = tool_data["description"]
