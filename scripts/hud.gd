extends CanvasLayer

## In-game HUD showing tools, soaps, progress, and earnings.
## Locked items show their price and can be clicked to purchase.

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
	GameManager.item_unlocked.connect(_on_item_unlocked)

	_build_tool_buttons()
	_build_soap_buttons()
	_update_tool_info(GameManager.current_tool)


func _build_tool_buttons() -> void:
	for child in tool_container.get_children():
		child.queue_free()
	tool_buttons.clear()

	var idx := 1
	for tool_id in GameManager.tool_order:
		var tool_data: Dictionary = GameManager.TOOLS[tool_id]
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(110, 40)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_tool_button_pressed.bind(tool_id))

		tool_container.add_child(btn)
		tool_buttons[tool_id] = btn
		idx += 1

	_refresh_tool_buttons()


func _build_soap_buttons() -> void:
	for child in soap_container.get_children():
		child.queue_free()
	soap_buttons.clear()

	var label := Label.new()
	label.text = "Soap: "
	label.add_theme_font_size_override("font_size", 13)
	soap_container.add_child(label)

	var fidx := 1
	for soap_id in GameManager.soap_order:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(120, 36)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_soap_button_pressed.bind(soap_id))

		soap_container.add_child(btn)
		soap_buttons[soap_id] = btn
		fidx += 1

	_refresh_soap_buttons()


func _refresh_tool_buttons() -> void:
	var idx := 1
	for tool_id in GameManager.tool_order:
		var btn: Button = tool_buttons.get(tool_id)
		if btn == null:
			continue
		var tool_data: Dictionary = GameManager.TOOLS[tool_id]
		var unlocked := GameManager.is_tool_unlocked(tool_id)
		var available := GameManager.is_tool_available(tool_id)

		if unlocked:
			btn.text = "%d: %s" % [idx, tool_data["name"]]
			btn.disabled = false
			btn.tooltip_text = tool_data["description"]
			btn.modulate = Color.WHITE
		elif available:
			var price: float = tool_data.get("price", 0.0)
			var can_afford := GameManager.total_money >= price
			btn.text = "$%.0f %s" % [price, tool_data["name"]]
			btn.disabled = false
			btn.tooltip_text = "Click to buy - %s" % tool_data["description"]
			btn.modulate = Color(0.6, 0.8, 0.6) if can_afford else Color(0.6, 0.6, 0.6)
		else:
			btn.text = "? ? ?"
			btn.disabled = true
			btn.tooltip_text = "Complete more jobs to reveal"
			btn.modulate = Color(0.4, 0.4, 0.4)

		btn.button_pressed = (tool_id == GameManager.current_tool and unlocked)
		idx += 1


func _refresh_soap_buttons() -> void:
	for soap_id in GameManager.soap_order:
		var btn: Button = soap_buttons.get(soap_id)
		if btn == null:
			continue
		var soap_data: Dictionary = GameManager.SOAPS[soap_id]
		var unlocked := GameManager.is_soap_unlocked(soap_id)
		var available := GameManager.is_soap_available(soap_id)

		if unlocked:
			btn.text = soap_data["name"]
			btn.disabled = false
			btn.tooltip_text = soap_data["name"]
			btn.modulate = Color.WHITE
		elif available:
			var price: float = soap_data.get("price", 0.0)
			var can_afford := GameManager.total_money >= price
			btn.text = "$%.0f %s" % [price, soap_data["name"]]
			btn.disabled = false
			btn.tooltip_text = "Click to buy"
			btn.modulate = Color(0.6, 0.8, 0.6) if can_afford else Color(0.6, 0.6, 0.6)
		else:
			btn.text = "? ? ?"
			btn.disabled = true
			btn.tooltip_text = "Complete more jobs to reveal"
			btn.modulate = Color(0.4, 0.4, 0.4)

		btn.button_pressed = (soap_id == GameManager.current_soap and unlocked)


func _on_tool_button_pressed(tool_id: String) -> void:
	if GameManager.is_tool_unlocked(tool_id):
		GameManager.set_tool(tool_id)
	elif GameManager.is_tool_available(tool_id):
		# Try to purchase
		if GameManager.purchase_tool(tool_id):
			AudioManager.play_complete()
			GameManager.set_tool(tool_id)
		else:
			AudioManager.play_click()
	_refresh_tool_buttons()


func _on_soap_button_pressed(soap_id: String) -> void:
	if GameManager.is_soap_unlocked(soap_id):
		GameManager.set_soap(soap_id)
	elif GameManager.is_soap_available(soap_id):
		if GameManager.purchase_soap(soap_id):
			AudioManager.play_complete()
			GameManager.set_soap(soap_id)
		else:
			AudioManager.play_click()
	_refresh_soap_buttons()


func _on_tool_changed(tool_id: String) -> void:
	_refresh_tool_buttons()
	_update_tool_info(tool_id)


func _on_soap_changed(_soap_id: String) -> void:
	_refresh_soap_buttons()


func _on_progress_updated(percent: float) -> void:
	progress_bar.value = percent


func _on_money_changed(_total: float) -> void:
	money_label.text = "$%.2f" % GameManager.total_money
	# Refresh buttons since affordability may have changed
	_refresh_tool_buttons()
	_refresh_soap_buttons()


func _on_job_started(job: Dictionary) -> void:
	job_label.text = job.get("name", "Window Job")
	progress_bar.value = 0.0
	# Refresh in case new items became available
	_refresh_tool_buttons()
	_refresh_soap_buttons()


func _on_item_unlocked(_item_type: String, _item_id: String) -> void:
	_refresh_tool_buttons()
	_refresh_soap_buttons()


func _update_tool_info(tool_id: String) -> void:
	var tool_data: Dictionary = GameManager.TOOLS[tool_id]
	if GameManager.is_tool_unlocked(tool_id):
		tool_name_label.text = tool_data["name"]
		tool_desc_label.text = tool_data["description"]
	else:
		tool_name_label.text = tool_data["name"] + " (Locked)"
		tool_desc_label.text = "$%.0f to purchase" % tool_data.get("price", 0.0)
