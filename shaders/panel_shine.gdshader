shader_type canvas_item;

// Adds a subtle vertical gradient shine for Fluent Design effect
uniform float shine_intensity : hint_range(0.0, 1.0) = 0.12;
uniform float gradient_height : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// Get the current pixel color
	vec4 color = texture(TEXTURE, UV);

	// Create vertical gradient (brighter at top, fades down)
	// UV.y = 0 at top, 1 at bottom
	float gradient = smoothstep(gradient_height, 0.0, UV.y);

	// Apply subtle white shine overlay
	color.rgb += vec3(gradient * shine_intensity);

	COLOR = color;
}
