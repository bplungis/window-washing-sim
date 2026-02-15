extends Node

## Global game state manager (autoload singleton).

signal tool_changed(tool_id: String)
signal soap_changed(soap_id: String)
signal progress_updated(percent: float)
signal job_started(job: Dictionary)
signal job_completed(results: Dictionary)
signal money_changed(total: float)

# --- Tool Definitions ---
enum ToolType { SQUEEGEE, SPONGE, STEEL_WOOL, SPRAY, RAZOR }

const TOOLS: Dictionary = {
	"squeegee": {
		"name": "Squeegee",
		"description": "Drags water and dissolved dirt off the glass. Your bread and butter.",
		"width": 0.25,        # Width in meters of the cleaning strip
		"speed": 1.0,         # How fast it cleans
		"removes_water": true,
		"requires_wet": true, # Only effective on wet/soapy surface
		"effectiveness": {
			"grime": 0.9,
			"grease": 0.3,
			"mineral": 0.1,
			"paint": 0.0,
			"bio": 0.4,
		}
	},
	"sponge": {
		"name": "Sponge",
		"description": "Applies soap and scrubs the surface. Essential prep work.",
		"width": 0.15,
		"speed": 0.7,
		"removes_water": false,
		"applies_soap": true,
		"effectiveness": {
			"grime": 0.5,
			"grease": 0.2,
			"mineral": 0.1,
			"paint": 0.0,
			"bio": 0.3,
		}
	},
	"steelwool": {
		"name": "Steel Wool",
		"description": "Scrapes off tough paint and adhesive residue. Use carefully!",
		"width": 0.06,
		"speed": 0.4,
		"removes_water": false,
		"effectiveness": {
			"grime": 0.3,
			"grease": 0.4,
			"mineral": 0.6,
			"paint": 0.8,
			"bio": 0.3,
		}
	},
	"spray": {
		"name": "Spray Bottle",
		"description": "Sprays water or soap solution onto the glass.",
		"width": 0.2,
		"speed": 1.5,
		"removes_water": false,
		"applies_water": true,
		"applies_soap": true,
		"spray_radius": 0.15,
		"effectiveness": {
			"grime": 0.1,
			"grease": 0.05,
			"mineral": 0.0,
			"paint": 0.0,
			"bio": 0.05,
		}
	},
	"razor": {
		"name": "Razor Blade",
		"description": "Precision scraping for paint, stickers, and dried deposits.",
		"width": 0.04,
		"speed": 0.3,
		"removes_water": false,
		"effectiveness": {
			"grime": 0.2,
			"grease": 0.3,
			"mineral": 0.9,
			"paint": 1.0,
			"bio": 0.2,
		}
	},
}

# --- Soap Definitions ---
const SOAPS: Dictionary = {
	"general": {
		"name": "General Purpose",
		"color": Color(0.29, 0.62, 1.0, 0.4),
		"boost": {
			"grime": 2.0,
			"grease": 1.2,
			"mineral": 1.0,
			"paint": 1.0,
			"bio": 1.3,
		}
	},
	"degreaser": {
		"name": "Degreaser",
		"color": Color(1.0, 0.62, 0.26, 0.4),
		"boost": {
			"grime": 1.2,
			"grease": 3.0,
			"mineral": 1.0,
			"paint": 1.0,
			"bio": 1.0,
		}
	},
	"mineral": {
		"name": "Mineral Remover",
		"color": Color(0.65, 0.37, 0.92, 0.4),
		"boost": {
			"grime": 1.0,
			"grease": 1.0,
			"mineral": 3.0,
			"paint": 1.5,
			"bio": 1.0,
		}
	},
	"bio": {
		"name": "Bio Cleaner",
		"color": Color(0.18, 0.84, 0.45, 0.4),
		"boost": {
			"grime": 1.3,
			"grease": 1.0,
			"mineral": 1.0,
			"paint": 1.0,
			"bio": 3.0,
		}
	},
}

# --- Dirt Type Definitions ---
const DIRT_TYPES: Dictionary = {
	"grime": {
		"name": "General Grime",
		"color": Color(0.35, 0.30, 0.25, 0.7),
		"description": "Everyday dust and dirt buildup.",
	},
	"grease": {
		"name": "Grease & Fingerprints",
		"color": Color(0.45, 0.40, 0.20, 0.5),
		"description": "Oily smudges and fingerprints.",
	},
	"mineral": {
		"name": "Hard Water Stains",
		"color": Color(0.75, 0.75, 0.70, 0.6),
		"description": "Calcium and mineral deposits from water.",
	},
	"paint": {
		"name": "Paint Splatter",
		"color": Color(0.85, 0.85, 0.80, 0.9),
		"description": "Dried paint spots. Requires scraping.",
	},
	"bio": {
		"name": "Bird Droppings & Sap",
		"color": Color(0.55, 0.55, 0.40, 0.8),
		"description": "Organic matter. Use bio cleaner.",
	},
}

# --- Game State ---
var current_tool: String = "squeegee"
var current_soap: String = "general"
var total_money: float = 0.0
var current_job: Dictionary = {}
var job_start_time: float = 0.0
var is_playing: bool = false

# Ordered arrays for cycling through tools/soaps
var tool_order: Array = ["squeegee", "sponge", "steelwool", "spray", "razor"]
var soap_order: Array = ["general", "degreaser", "mineral", "bio"]


func _ready() -> void:
	pass


func set_tool(tool_id: String) -> void:
	if TOOLS.has(tool_id):
		current_tool = tool_id
		tool_changed.emit(tool_id)


func set_soap(soap_id: String) -> void:
	if SOAPS.has(soap_id):
		current_soap = soap_id
		soap_changed.emit(soap_id)


func cycle_tool(direction: int) -> void:
	var idx := tool_order.find(current_tool)
	idx = wrapi(idx + direction, 0, tool_order.size())
	set_tool(tool_order[idx])


func cycle_soap(direction: int) -> void:
	var idx := soap_order.find(current_soap)
	idx = wrapi(idx + direction, 0, soap_order.size())
	set_soap(soap_order[idx])


func start_job(job: Dictionary) -> void:
	current_job = job
	job_start_time = Time.get_ticks_msec() / 1000.0
	is_playing = true
	job_started.emit(job)


func complete_job(cleanliness: float) -> void:
	is_playing = false
	var elapsed := (Time.get_ticks_msec() / 1000.0) - job_start_time
	var base_pay: float = current_job.get("base_pay", 50.0)

	# Bonus for high cleanliness
	var clean_multiplier := cleanliness / 100.0
	var earned := base_pay * clean_multiplier

	# Time bonus (faster = more bonus, but capped)
	var par_time: float = current_job.get("par_time", 120.0)
	if elapsed < par_time:
		earned += base_pay * 0.2  # 20% time bonus

	total_money += earned
	money_changed.emit(total_money)

	var results := {
		"cleanliness": cleanliness,
		"time_elapsed": elapsed,
		"earned": earned,
		"total_money": total_money,
	}
	job_completed.emit(results)


func get_tool_data() -> Dictionary:
	return TOOLS[current_tool]


func get_soap_data() -> Dictionary:
	return SOAPS[current_soap]


## Calculate the effective cleaning power for a given dirt type
## considering current tool + soap combination.
func get_cleaning_power(dirt_type: String, has_soap: bool, soap_type: String = "") -> float:
	var tool_data: Dictionary = TOOLS[current_tool]
	var base_power: float = tool_data["effectiveness"].get(dirt_type, 0.0)

	if has_soap and soap_type != "":
		var soap_data: Dictionary = SOAPS.get(soap_type, SOAPS["general"])
		var boost: float = soap_data["boost"].get(dirt_type, 1.0)
		base_power *= boost

	return clampf(base_power * tool_data["speed"], 0.0, 1.0)
