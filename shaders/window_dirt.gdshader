shader_type spatial;

// Window dirt rendering shader.
// Composites dirt and wetness layers over a glass-like base material.

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Dirt layer texture (R=grime, G=grease, B=mineral, A=paint)
uniform sampler2D dirt_texture : hint_default_black, filter_linear;
// Wetness layer (R=water, G=soap, B=soap_type, A=bio)
uniform sampler2D wetness_texture : hint_default_black, filter_linear;

// Glass properties
uniform vec4 glass_color : source_color = vec4(0.85, 0.92, 0.95, 0.3);
uniform float glass_roughness : hint_range(0.0, 1.0) = 0.05;
uniform float glass_metallic : hint_range(0.0, 1.0) = 0.0;

// Dirt colors
uniform vec4 grime_color : source_color = vec4(0.35, 0.30, 0.25, 1.0);
uniform vec4 grease_color : source_color = vec4(0.45, 0.42, 0.28, 1.0);
uniform vec4 mineral_color : source_color = vec4(0.78, 0.78, 0.73, 1.0);
uniform vec4 paint_color : source_color = vec4(0.88, 0.86, 0.82, 1.0);
uniform vec4 bio_color : source_color = vec4(0.50, 0.52, 0.35, 1.0);

// Soap colors (indexed by soap type in B channel)
uniform vec4 soap_general_color : source_color = vec4(0.29, 0.62, 1.0, 0.3);
uniform vec4 soap_degreaser_color : source_color = vec4(1.0, 0.62, 0.26, 0.3);
uniform vec4 soap_mineral_color : source_color = vec4(0.65, 0.37, 0.92, 0.3);
uniform vec4 soap_bio_color : source_color = vec4(0.18, 0.84, 0.45, 0.3);

// Water properties
uniform vec4 water_color : source_color = vec4(0.7, 0.85, 1.0, 0.25);
uniform float water_distortion : hint_range(0.0, 0.1) = 0.02;

// Highlight for tool position
uniform vec2 tool_uv = vec2(-1.0, -1.0);
uniform float tool_radius = 0.05;
uniform vec4 tool_highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.15);

varying vec2 uv_coord;

void vertex() {
	uv_coord = UV;
}

void fragment() {
	vec2 uv = uv_coord;

	// Sample textures
	vec4 dirt = texture(dirt_texture, uv);
	vec4 wet = texture(wetness_texture, uv);

	float grime_amount = dirt.r;
	float grease_amount = dirt.g;
	float mineral_amount = dirt.b;
	float paint_amount = dirt.a;
	float bio_amount = wet.a;

	float water_amount = wet.r;
	float soap_amount = wet.g;
	float soap_type_val = wet.b;

	// Total dirt opacity
	float total_dirt = min(grime_amount + grease_amount + mineral_amount + paint_amount + bio_amount, 1.0);

	// Composite dirt color (weighted blend)
	vec3 dirt_col = vec3(0.0);
	float dirt_weight = max(grime_amount + grease_amount + mineral_amount + paint_amount + bio_amount, 0.001);
	dirt_col += grime_color.rgb * grime_amount;
	dirt_col += grease_color.rgb * grease_amount;
	dirt_col += mineral_color.rgb * mineral_amount;
	dirt_col += paint_color.rgb * paint_amount;
	dirt_col += bio_color.rgb * bio_amount;
	dirt_col /= dirt_weight;

	// Water distortion on UV for glass look
	vec2 water_uv_offset = vec2(
		sin(uv.y * 40.0 + TIME * 0.5) * water_distortion * water_amount,
		cos(uv.x * 40.0 + TIME * 0.3) * water_distortion * water_amount
	);

	// Base glass color with slight environment reflection feel
	vec3 base_color = glass_color.rgb;

	// Blend: glass -> dirt -> water/soap on top
	vec3 final_color = mix(base_color, dirt_col, total_dirt * 0.85);

	// Water overlay
	if (water_amount > 0.01) {
		vec3 water_tint = water_color.rgb;
		// Add soap color if present
		if (soap_amount > 0.05) {
			vec4 soap_col;
			if (soap_type_val < 0.17) {
				soap_col = soap_general_color;
			} else if (soap_type_val < 0.5) {
				soap_col = soap_degreaser_color;
			} else if (soap_type_val < 0.83) {
				soap_col = soap_mineral_color;
			} else {
				soap_col = soap_bio_color;
			}
			water_tint = mix(water_tint, soap_col.rgb, soap_amount * 0.6);
		}
		final_color = mix(final_color, water_tint, water_amount * 0.3);
	}

	// Tool highlight (crosshair/cursor area)
	if (tool_uv.x >= 0.0) {
		float dist_to_tool = distance(uv, tool_uv);
		if (dist_to_tool < tool_radius) {
			float highlight = (1.0 - dist_to_tool / tool_radius) * tool_highlight_color.a;
			final_color = mix(final_color, tool_highlight_color.rgb, highlight * 0.5);
		}
		// Thin ring at edge
		float ring = smoothstep(tool_radius, tool_radius - 0.003, dist_to_tool)
					- smoothstep(tool_radius - 0.003, tool_radius - 0.006, dist_to_tool);
		final_color = mix(final_color, vec3(1.0), ring * 0.6);
	}

	ALBEDO = final_color;

	// Glass-like properties: clean areas are smooth/reflective, dirty areas are rough
	ROUGHNESS = mix(glass_roughness, 0.8, total_dirt);
	METALLIC = glass_metallic;

	// Transparency: clean glass is semi-transparent, dirt is opaque
	ALPHA = mix(glass_color.a, 1.0, total_dirt * 0.7 + water_amount * 0.2);

	// Specular: clean wet glass is very reflective
	SPECULAR = mix(0.5, 0.8, water_amount) * (1.0 - total_dirt * 0.5);
}
