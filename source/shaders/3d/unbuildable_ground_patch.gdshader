shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 color : source_color = vec4(0.24, 0.14, 0.08, 1.0);
uniform vec2 patch_size = vec2(1.0);
uniform float corner_radius = 0.45;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.22;
uniform float texture_scale = 2.0;
uniform float edge_fade_width = 0.12;
uniform int cutout_count = 0;
uniform vec4 cutouts[16];

varying vec2 position_local;
varying vec2 position_world;


float random(vec2 position)
{
	return fract(sin(dot(position, vec2(127.1, 311.7))) * 43758.5453123);
}


float value_noise(vec2 position)
{
	vec2 cell = floor(position);
	vec2 fraction = fract(position);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);

	float bottom_left = random(cell);
	float bottom_right = random(cell + vec2(1.0, 0.0));
	float top_left = random(cell + vec2(0.0, 1.0));
	float top_right = random(cell + vec2(1.0));
	return mix(
		mix(bottom_left, bottom_right, fraction.x),
		mix(top_left, top_right, fraction.x),
		fraction.y
	);
}


float rounded_rectangle_distance(vec2 position, vec2 half_size, float radius)
{
	vec2 corner = abs(position) - half_size + vec2(radius);
	return min(max(corner.x, corner.y), 0.0) + length(max(corner, vec2(0.0))) - radius;
}


void vertex()
{
	position_local = VERTEX.xz;
	position_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}


void fragment()
{
	vec2 half_size = patch_size * 0.5;
	float radius = min(corner_radius, min(half_size.x, half_size.y));
	float distance_to_edge = rounded_rectangle_distance(position_local, half_size, radius);

	float broad_noise = value_noise(position_world * texture_scale * 0.45);
	float medium_noise = value_noise(position_world * texture_scale * 1.15 + vec2(17.3, 4.1));
	float fine_noise = value_noise(position_world * texture_scale * 2.4);
	float speckles = smoothstep(0.72, 0.92, fine_noise);
	float variation = (
		(broad_noise - 0.5)
		+ (medium_noise - 0.5) * 0.45
		- speckles * 0.35
	);

	float edge_noise = (
		(value_noise(position_world * 0.75) - 0.5) * 0.18
		+ (value_noise(position_world * 2.7 + vec2(8.2, 3.7)) - 0.5) * 0.07
	);
	distance_to_edge += edge_noise - 0.13;

	vec3 surface_color = color.rgb * (1.0 + variation * texture_strength);

	ALBEDO = surface_color;
	ROUGHNESS = 1.0;
	ALPHA = color.a * (1.0 - smoothstep(0.0, edge_fade_width, distance_to_edge));

	for (int index = 0; index < 16; index++)
	{
		if (index >= cutout_count)
		{
			break;
		}
		vec2 position_from_cutout = position_world - cutouts[index].xy;
		vec2 position_in_missing_quadrant = position_from_cutout * cutouts[index].zw;
		float circle_distance = length(position_from_cutout) - corner_radius;
		float missing_quadrant_distance = -min(
			position_in_missing_quadrant.x,
			position_in_missing_quadrant.y
		);
		float rounded_join_distance = max(circle_distance, missing_quadrant_distance);
		float rounded_join_alpha = color.a * (
			1.0 - smoothstep(0.0, edge_fade_width, rounded_join_distance)
		);
		ALPHA = max(ALPHA, rounded_join_alpha);
	}
}
