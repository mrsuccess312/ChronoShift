shader_type canvas_item;

// Adds a subtle vertical gradient shine for Fluent Design effect
uniform float shine_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float gradient_position : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	// Get the current pixel color
	vec4 color = texture(TEXTURE, UV);

	// Create vertical gradient (brighter at top, darker at bottom)
	float gradient = smoothstep(0.0, gradient_position, 1.0 - UV.y);

	// Apply subtle shine overlay
	vec3 shine = vec3(1.0) * gradient * shine_intensity;
	color.rgb += shine * color.a;

	COLOR = color;
}
