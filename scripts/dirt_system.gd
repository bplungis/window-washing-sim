class_name DirtSystem
extends RefCounted

## Manages the dirt layer for a single window surface.
## The dirt state is stored as an Image where:
##   R channel = grime amount (0-1)
##   G channel = grease amount (0-1)
##   B channel = mineral/hard water amount (0-1)
##   A channel = paint/tough deposit amount (0-1)
##
## A second Image tracks wetness/soap state:
##   R channel = water amount (0-1)
##   G channel = soap amount (0-1)
##   B channel = soap type encoded (0.0=general, 0.33=degreaser, 0.66=mineral, 1.0=bio)
##   A channel = bio dirt amount (0-1) -- overflow from main dirt image

var width: int
var height: int

var dirt_image: Image          # Dirt amounts per pixel
var wetness_image: Image       # Water/soap state per pixel
var dirt_texture: ImageTexture # GPU texture updated from dirt_image
var wetness_texture: ImageTexture

# Track total dirt for progress calculation
var initial_total_dirt: float = 0.0
var _needs_texture_update: bool = false
var _update_timer: float = 0.0

const SOAP_TYPE_MAP: Dictionary = {
	"general": 0.0,
	"degreaser": 0.33,
	"mineral": 0.66,
	"bio": 1.0,
}

const SOAP_TYPE_REVERSE: Dictionary = {
	0.0: "general",
	0.33: "degreaser",
	0.66: "mineral",
	1.0: "bio",
}

# Drip simulation
const DRIP_SPEED: float = 0.5   # Pixels per second that water drips down
const WATER_EVAP_RATE: float = 0.02  # Water evaporation per second


func _init(w: int = 256, h: int = 256) -> void:
	width = w
	height = h

	dirt_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	wetness_image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	dirt_image.fill(Color(0, 0, 0, 0))
	wetness_image.fill(Color(0, 0, 0, 0))

	dirt_texture = ImageTexture.create_from_image(dirt_image)
	wetness_texture = ImageTexture.create_from_image(wetness_image)


## Generate dirt for a job configuration.
## dirt_config is a dictionary like:
## { "grime": 0.7, "grease": 0.3, "mineral": 0.2, "paint": 0.1, "bio": 0.15 }
## Values are coverage density (0-1).
func generate_dirt(dirt_config: Dictionary, seed_value: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else randi()

	dirt_image.fill(Color(0, 0, 0, 0))
	wetness_image.fill(Color(0, 0, 0, 0))

	# Generate each dirt type with noise-like patterns
	for x in range(width):
		for y in range(height):
			var grime := _noise_value(rng, x, y, 0.05) * dirt_config.get("grime", 0.0)
			var grease := _splatter_value(rng, x, y, 8.0) * dirt_config.get("grease", 0.0)
			var mineral := _streak_value(rng, x, y) * dirt_config.get("mineral", 0.0)
			var paint := _splatter_value(rng, x, y, 20.0) * dirt_config.get("paint", 0.0)
			var bio := _splatter_value(rng, x, y, 25.0) * dirt_config.get("bio", 0.0)

			dirt_image.set_pixel(x, y, Color(
				clampf(grime, 0.0, 1.0),
				clampf(grease, 0.0, 1.0),
				clampf(mineral, 0.0, 1.0),
				clampf(paint, 0.0, 1.0)
			))

			# Store bio in wetness A channel
			if bio > 0.01:
				var wet := wetness_image.get_pixel(x, y)
				wet.a = clampf(bio, 0.0, 1.0)
				wetness_image.set_pixel(x, y, wet)

	initial_total_dirt = _calculate_total_dirt()
	_update_textures()


## Apply a tool stroke at UV coordinates (0-1 range).
## Returns the amount of dirt removed (for feedback).
func apply_tool(uv: Vector2, tool_data: Dictionary, soap_data: Dictionary,
				current_soap_id: String, delta: float) -> float:
	var cx := int(uv.x * width)
	var cy := int(uv.y * height)
	var radius := int(tool_data["width"] * width * 0.5)
	var removed := 0.0

	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var px := cx + dx
			var py := cy + dy
			if px < 0 or px >= width or py < 0 or py >= height:
				continue

			# Circular brush
			var dist := sqrt(float(dx * dx + dy * dy))
			if dist > radius:
				continue

			var falloff := 1.0 - (dist / float(radius))
			falloff = falloff * falloff  # Quadratic falloff

			var dirt := dirt_image.get_pixel(px, py)
			var wet := wetness_image.get_pixel(px, py)

			# Apply water if tool sprays
			if tool_data.get("applies_water", false):
				wet.r = clampf(wet.r + 0.5 * delta * falloff, 0.0, 1.0)

			# Apply soap if tool applies soap
			if tool_data.get("applies_soap", false):
				wet.g = clampf(wet.g + 0.4 * delta * falloff, 0.0, 1.0)
				wet.b = SOAP_TYPE_MAP.get(current_soap_id, 0.0)

			# Determine soap type on this pixel
			var pixel_soap_id := _get_soap_type_from_value(wet.b)
			var has_soap := wet.g > 0.05

			# Calculate cleaning for each dirt type
			var dirt_types := ["grime", "grease", "mineral", "paint"]
			var channels := [dirt.r, dirt.g, dirt.b, dirt.a]
			var new_channels := channels.duplicate()

			for i in range(4):
				var dirt_type: String = dirt_types[i]
				var power: float = tool_data["effectiveness"].get(dirt_type, 0.0)

				# Soap boost
				if has_soap:
					var boost: float = soap_data["boost"].get(dirt_type, 1.0)
					# Use the soap actually on the surface, not necessarily the selected one
					if has_soap and pixel_soap_id != current_soap_id:
						var surface_soap: Dictionary = GameManager.SOAPS.get(pixel_soap_id, soap_data)
						boost = surface_soap["boost"].get(dirt_type, 1.0)
					power *= boost

				# Squeegee needs wet surface for most dirt
				if tool_data.get("requires_wet", false) and wet.r < 0.1 and not has_soap:
					power *= 0.15  # Much less effective on dry surface

				var removal := power * delta * falloff * tool_data["speed"]
				new_channels[i] = maxf(channels[i] - removal, 0.0)
				removed += channels[i] - new_channels[i]

			# Bio dirt (stored in wetness alpha)
			var bio_power: float = tool_data["effectiveness"].get("bio", 0.0)
			if has_soap:
				var bio_boost: float = soap_data["boost"].get("bio", 1.0)
				bio_power *= bio_boost
			var bio_removal := bio_power * delta * falloff * tool_data["speed"]
			var old_bio := wet.a
			wet.a = maxf(wet.a - bio_removal, 0.0)
			removed += old_bio - wet.a

			# Squeegee removes water
			if tool_data.get("removes_water", false):
				wet.r = maxf(wet.r - 0.8 * delta * falloff, 0.0)
				wet.g = maxf(wet.g - 0.6 * delta * falloff, 0.0)

			dirt_image.set_pixel(px, py, Color(
				new_channels[0], new_channels[1],
				new_channels[2], new_channels[3]
			))
			wetness_image.set_pixel(px, py, wet)

	_needs_texture_update = true
	return removed


## Simulate water dripping and evaporation.
func update(delta: float) -> void:
	_update_timer += delta
	if _update_timer < 0.1:  # Update physics at ~10Hz for performance
		return
	_update_timer = 0.0

	# Simple drip simulation: water moves down slowly
	# Process from bottom to top to avoid cascading in one frame
	for y in range(height - 2, -1, -1):
		for x in range(width):
			var wet := wetness_image.get_pixel(x, y)
			if wet.r > 0.05:
				# Some water drips down
				var drip_amount := minf(wet.r * 0.02, 0.05)
				wet.r -= drip_amount

				var below := wetness_image.get_pixel(x, y + 1)
				below.r = clampf(below.r + drip_amount, 0.0, 1.0)
				wetness_image.set_pixel(x, y + 1, below)

			# Evaporation
			wet.r = maxf(wet.r - WATER_EVAP_RATE * 0.1, 0.0)
			wet.g = maxf(wet.g - WATER_EVAP_RATE * 0.05, 0.0)  # Soap evaporates slower
			wetness_image.set_pixel(x, y, wet)

	_needs_texture_update = true


## Update GPU textures if dirty.
func flush_textures() -> void:
	if _needs_texture_update:
		dirt_texture.update(dirt_image)
		wetness_texture.update(wetness_image)
		_needs_texture_update = false


## Get cleanliness as a percentage (0-100).
func get_cleanliness() -> float:
	if initial_total_dirt <= 0.0:
		return 100.0
	var current := _calculate_total_dirt()
	return clampf((1.0 - current / initial_total_dirt) * 100.0, 0.0, 100.0)


## Check how streak-free the window is (less residual water = better).
func get_streak_free_score() -> float:
	var total_water := 0.0
	var pixel_count := 0
	for x in range(width):
		for y in range(height):
			var wet := wetness_image.get_pixel(x, y)
			total_water += wet.r + wet.g * 0.5
			pixel_count += 1
	if pixel_count == 0:
		return 100.0
	var avg_water := total_water / float(pixel_count)
	return clampf((1.0 - avg_water * 10.0) * 100.0, 0.0, 100.0)


func _calculate_total_dirt() -> float:
	var total := 0.0
	for x in range(width):
		for y in range(height):
			var d := dirt_image.get_pixel(x, y)
			var w := wetness_image.get_pixel(x, y)
			total += d.r + d.g + d.b + d.a + w.a  # Include bio
	return total


func _get_soap_type_from_value(val: float) -> String:
	if val < 0.17:
		return "general"
	elif val < 0.5:
		return "degreaser"
	elif val < 0.83:
		return "mineral"
	else:
		return "bio"


## Simple procedural noise for natural-looking dirt.
func _noise_value(rng: RandomNumberGenerator, x: int, y: int, scale: float) -> float:
	# Layered random with spatial coherence
	var nx := x * scale
	var ny := y * scale
	var val := sin(nx * 12.9898 + ny * 78.233) * 43758.5453
	val = val - floor(val)
	# Add some randomness
	val = val * 0.7 + rng.randf() * 0.3
	return clampf(val, 0.0, 1.0)


## Generates splatter-like patterns for paint, bird droppings, etc.
func _splatter_value(rng: RandomNumberGenerator, x: int, y: int, sparsity: float) -> float:
	# Random splatters: occasional high-density spots
	var chance := rng.randf() * sparsity
	if chance < 1.0:
		return rng.randf_range(0.6, 1.0)
	return 0.0


## Generates vertical streak patterns for hard water stains.
func _streak_value(rng: RandomNumberGenerator, x: int, y: int) -> float:
	# Vertical streaks from water running down
	var streak_x := sin(float(x) * 0.3) * 0.5 + 0.5
	var intensity := streak_x * (float(y) / float(height))
	intensity += rng.randf() * 0.1
	return clampf(intensity * 0.5, 0.0, 1.0) if rng.randf() < 0.4 else 0.0
