shader_type canvas_item;

// Access the screen texture to read the current frame buffer.
// filter_linear_mipmap_anisotropic: Enables high-quality texture filtering with mipmaps.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap_anisotropic, repeat_disable;

// Horizontal pass strength (0.0 to 1.0). Controls horizontal blur contribution.
uniform float hpass : hint_range(0.0, 1.0, 0.1) = 1.0;

// Vertical pass strength (0.0 to 1.0). Controls vertical blur contribution.
uniform float vpass : hint_range(0.0, 1.0, 0.1) = 1.0;

// Base unit scale for the blur effect.
uniform vec2 unit = vec2(1., 1.);

// The number of blur iterations/layers. Higher values mean smoother but more expensive blur.
uniform int radius : hint_range(0, 65, 1) = 65;

// Scales the blur radius. Lower values make the glow tighter/smaller.
uniform float radius_scale : hint_range(0.1, 1.0, 0.1) = 0.3;

// Controls the brightness/intensity of the final glow.
uniform float intensity : hint_range(0.0, 30.0, 0.1) = 6.0;

// Additive blending mode makes the glow add light to the scene rather than replacing it.
render_mode blend_add;

// Helper function to sample the texture with a threshold.
// Only pixels brighter than (1.0, 1.0, 1.0) contribute to the glow.
// This ensures only "bright" objects glow.
vec4 textureThresholded(sampler2D _texture, vec2 _uv, float _bias) {
	// Sample the texture at a specific LOD bias (mipmap level).
	vec4 pixel = textureLod(_texture, _uv, _bias);

	// Threshold check: if the pixel is not bright enough (<= 1.0 in all channels), ignore it.
	// This assumes HDR rendering or values > 1.0 for glowing objects.
	if ( pixel.r <= 1. && pixel.g <= 1. && pixel.b <= 1. ) {
		pixel.rgb = vec3(0.);
	}

	return pixel;
}

void fragment() {
	// Sample the original pixel from the screen.
	vec4 pixel = textureThresholded(screen_texture, SCREEN_UV, 0.);
	
	if (radius != 0) {
		vec4 blurred = vec4(0., 0., 0., 1.);

		// Gaussian-like weights for the blur accumulation.
		// These weights decrease as the index increases, giving more importance to closer samples.
		const float[65] w = { 0.0064,0.0063,0.0062,0.0061,0.0060,0.0059,0.0058,0.0057,0.0056,0.0055,0.0054,0.0053,0.0052,0.0051,0.0050,0.0049,0.0048,0.0047,0.0046,0.0045,0.0044,0.0043,0.0042,0.0041,0.0040,0.0039,0.0038,0.0037,0.0036,0.0035,0.0034,0.0033,0.0032,0.0031,0.0030,0.0029,0.0028,0.0027,0.0026,0.0025,0.0024,0.0023,0.0022,0.0021,0.0020,0.0019,0.0018,0.0017,0.0016,0.0015,0.0014,0.0013,0.0012,0.0011,0.0010,0.0009,0.0008,0.0007,0.0006,0.0005,0.0004,0.0003,0.0002,0.0001,0.0000 };

		// Calculate the size of a single pixel in UV coordinates.
		float px = 1. / float(textureSize(screen_texture, 0).x) * unit.x;
		float py = 1. / float(textureSize(screen_texture, 0).y) * unit.y;

		// Iterate through the blur radius layers.
		for(int i = 0; i < radius; i++) {
			// Scale the current radius 'r' by the user-defined scale factor.
			// This allows shrinking the overall glow size.
			float r = float(i + 1) * radius_scale;
			
			// Calculate Level of Detail (LOD) / Mipmap level.
			// We distribute 8 samples around the circumference of radius 'r'.
			// Circumference C = 2 * PI * r.
			// Gap between samples = C / 8 ≈ 0.785 * r.
			// Multiply by unit length to account for scaling.
			float gap = max(1.0, (r * 0.785) * length(unit));
			
			// Calculate the mipmap level 'k' based on the gap size.
			// log2(gap) gives the theoretical mipmap level where one pixel covers 'gap' distance.
			// Subtracting 1.0 (bias) forces sampling from a higher resolution (sharper) mipmap.
			// This makes the glow more converged/tight and less blocky.
			float k = log2(gap) - 1.0;
			k = max(0.0, k);
			
			// Calculate rotation angle for this layer.
			// Each layer is rotated slightly to stagger samples and reduce artifacts.
			float base_angle = float(i);
			float angle_step = 3.1415927 * 2.0 / 8.0; // 45 degrees in radians.

			// Perform 8 samples in different directions for this radius layer.
			// This replaces a simple linear blur with a radial/bokeh-like blur.
			for(int j = 0; j < 8; j++) {
				float angle = base_angle + float(j) * angle_step;
				vec2 dir = vec2(cos(angle), sin(angle));
				
				// Calculate the UV offset: Direction * Radius * PixelSize * PassStrength.
				vec2 offset = dir * r * vec2(px, py) * vec2(hpass, vpass);
				
				// Accumulate the sampled color, weighted by the distance weight 'w[i]'.
				blurred += textureThresholded(screen_texture, SCREEN_UV + offset, k) * w[i];
			}
		}

		// Normalize the blurred result.
		// Divide by radius to average the accumulation.
		// Divide by 'intensity' (effectively multiplying by intensity) to boost brightness.
		// Note: The logic here is effectively: blurred = (blurred / radius) * intensity.
		// Since we divide by (radius / intensity), it equals blurred * intensity / radius.
		blurred /= float(radius) / intensity;
		pixel += blurred;

	} else {
		// If radius is 0, no glow is applied.
		pixel = vec4(0., 0., 0., 1.);
	}

	// Output the final color.
	COLOR = pixel;
}