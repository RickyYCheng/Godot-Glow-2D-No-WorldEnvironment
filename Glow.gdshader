shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float hpass : hint_range(0.0, 1.0, 0.1) = 1.0;
uniform float vpass : hint_range(0.0, 1.0, 0.1) = 1.0;
uniform int radius : hint_range(0, 65, 1) = 65;
uniform vec2 unit = vec2(1., 1.);
uniform float intensity : hint_range(0.0, 5.0, 0.1) = 1.0;
render_mode blend_add;

vec4 textureThresholded(sampler2D _texture, vec2 _uv, float _bias) {
	vec4 pixel = textureLod(_texture, _uv, _bias);

	if ( pixel.r <= 1. && pixel.g <= 1. && pixel.b <= 1. ) {
		pixel.rgb = vec3(0.);
	}

	return pixel;
}

void fragment() {
	vec4 pixel = textureThresholded(screen_texture, SCREEN_UV, 0.);
	
	if (radius != 0) {
		vec4 blurred = vec4(0., 0., 0., 1.);
		float[65] w = { 0.0064,0.0063,0.0062,0.0061,0.0060,0.0059,0.0058,0.0057,0.0056,0.0055,0.0054,0.0053,0.0052,0.0051,0.0050,0.0049,0.0048,0.0047,0.0046,0.0045,0.0044,0.0043,0.0042,0.0041,0.0040,0.0039,0.0038,0.0037,0.0036,0.0035,0.0034,0.0033,0.0032,0.0031,0.0030,0.0029,0.0028,0.0027,0.0026,0.0025,0.0024,0.0023,0.0022,0.0021,0.0020,0.0019,0.0018,0.0017,0.0016,0.0015,0.0014,0.0013,0.0012,0.0011,0.0010,0.0009,0.0008,0.0007,0.0006,0.0005,0.0004,0.0003,0.0002,0.0001,0.0000 };

		float px = 1. / float(textureSize(screen_texture, 0).x) * unit.x;
		float py = 1. / float(textureSize(screen_texture, 0).y) * unit.y;

		for(int i = 0; i < radius; i++) {
			float r = float(i + 1);
			
			// 计算 LOD
			// 在半径 r 的圆周上分布 8 个点
			// 圆周长 C = 2 * PI * r
			// 点间距 gap = C / 8 ≈ 0.785 * r
			// 乘以 unit 长度以适应缩放
			float gap = max(1.0, (r * 0.785) * length(unit));
			
			// 计算 mipmap 层级
			// 减去 1.0 的 bias 让辉光稍微收敛一点，避免过大
			float k = log2(gap) - 1.0;
			k = max(0.0, k);
			
			// 旋转角度，每层旋转 1 弧度，错开采样点
			float base_angle = float(i);
			float angle_step = 3.1415927 * 2.0 / 8.0; // 45度

			// 展开 8 个方向的采样，替代原来的不均匀采样
			for(int j = 0; j < 8; j++) {
				float angle = base_angle + float(j) * angle_step;
				vec2 dir = vec2(cos(angle), sin(angle));
				
				// 计算偏移: 方向 * 半径 * 像素大小 * pass系数
				vec2 offset = dir * r * vec2(px, py) * vec2(hpass, vpass);
				
				blurred += textureThresholded(screen_texture, SCREEN_UV + offset, k) * w[i];
			}
		}

		blurred /= float(radius) / 6.;
		pixel += blurred;

	} else {
		pixel = vec4(0., 0., 0., 1.);
	}

	COLOR = pixel;
}