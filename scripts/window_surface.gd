class_name WindowSurface
extends StaticBody3D

## A cleanable window surface. Manages its dirt system and shader.

@export var window_width: float = 2.0
@export var window_height: float = 2.5
@export var dirt_resolution: int = 256  ## Pixels per axis for dirt tracking

var dirt_system: DirtSystem
var material: ShaderMaterial

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	# Set up collision on the window layer (layer 3)
	collision_layer = 4  # Bit 3
	collision_mask = 0

	# Initialize dirt system
	dirt_system = DirtSystem.new(dirt_resolution, dirt_resolution)

	# Create mesh
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(window_width, window_height)
	# Orient as vertical surface (default PlaneMesh faces up, we rotate the node)
	mesh_instance.mesh = plane_mesh

	# Create collision
	var shape := BoxShape3D.new()
	shape.size = Vector3(window_width, window_height, 0.01)
	collision_shape.shape = shape

	# Load and apply shader material
	material = ShaderMaterial.new()
	var shader := load("res://shaders/window_dirt.gdshader") as Shader
	material.shader = shader

	# Set dirt and wetness textures
	material.set_shader_parameter("dirt_texture", dirt_system.dirt_texture)
	material.set_shader_parameter("wetness_texture", dirt_system.wetness_texture)

	mesh_instance.material_override = material


func _process(delta: float) -> void:
	dirt_system.update(delta)
	dirt_system.flush_textures()

	# Update shader textures
	material.set_shader_parameter("dirt_texture", dirt_system.dirt_texture)
	material.set_shader_parameter("wetness_texture", dirt_system.wetness_texture)


## Initialize this window with a dirt configuration.
func setup_dirt(dirt_config: Dictionary, seed_val: int = 0) -> void:
	dirt_system.generate_dirt(dirt_config, seed_val)
	dirt_system.flush_textures()


## Apply the current tool at a UV position on this window.
## Returns amount of dirt removed.
func apply_tool_at_uv(uv: Vector2, delta: float) -> float:
	var tool_data: Dictionary = GameManager.get_tool_data()
	var soap_data: Dictionary = GameManager.get_soap_data()
	var soap_id: String = GameManager.current_soap

	# Update tool highlight position in shader
	material.set_shader_parameter("tool_uv", uv)
	material.set_shader_parameter("tool_radius", tool_data["width"] * 0.5)

	return dirt_system.apply_tool(uv, tool_data, soap_data, soap_id, delta)


## Clear the tool highlight (when not hovering).
func clear_tool_highlight() -> void:
	material.set_shader_parameter("tool_uv", Vector2(-1, -1))


## Get current cleanliness percentage.
func get_cleanliness() -> float:
	return dirt_system.get_cleanliness()


## Get streak-free score.
func get_streak_free() -> float:
	return dirt_system.get_streak_free_score()


## Convert a world-space hit point to UV coordinates on this window.
func world_to_uv(world_point: Vector3) -> Vector2:
	# Transform world point to local space
	var local_point := to_local(world_point)

	# PlaneMesh is oriented in XZ plane by default, but we rotate the node
	# to make it vertical. The UV mapping depends on orientation.
	# For a plane rotated to face -Z (vertical window), local coords:
	# X maps to U, Y maps to V
	var u := (local_point.x / window_width) + 0.5
	var v := (local_point.z / window_height) + 0.5

	return Vector2(clampf(u, 0.0, 1.0), clampf(v, 0.0, 1.0))
