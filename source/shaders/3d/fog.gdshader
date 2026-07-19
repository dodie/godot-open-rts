shader_type spatial;
render_mode unshaded;

uniform vec4 color : source_color = vec4(1.0);
uniform float max_density_height = 0.0;
uniform float min_density_height = 1.0;
uniform float max_height = 9999.0;
uniform float min_height = -9999.0;
uniform sampler2D depth_texture : hint_depth_texture;

void vertex()
{
  POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment()
{
  ALBEDO = color.rgb;

  // depth is encoded on the first channel and is <0; 1>
  float depth = textureLod(depth_texture, SCREEN_UV, 0.0).x;
  // Compatibility uses OpenGL's <-1; 1> clip-space depth. The Vulkan renderers
  // use <0; 1> clip-space depth.
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
  float clip_space_depth = depth * 2.0 - 1.0;
#else
  float clip_space_depth = depth;
#endif
  vec3 normalized_device_coordinates = vec3(SCREEN_UV * 2.0 - 1.0, clip_space_depth);
  // move depth point from projection space to world space
  // * note that INV_PROJECTION_MATRIX is broken atm. so, let's use inverse(PROJECTION_MATRIX)
  vec4 world_position =
      INV_VIEW_MATRIX * inverse(PROJECTION_MATRIX) * vec4(normalized_device_coordinates, 1.0);
  world_position.xyz /= world_position.w;
  ALPHA = smoothstep(min_density_height, max_density_height, world_position.y);
  if (world_position.y < min_height || world_position.y > max_height)
  {
    ALPHA = 0.0;
  }
}
