shader_type canvas_item;

// Solid outline around a sprite's opaque pixels, so obstacles stand out from decorations.
// The quad is grown by `width` so the outline isn't clipped at the (tightly cropped) texture edge.

uniform vec4 outline_color : source_color = vec4(1.0, 0.33, 0.33, 1.0);
uniform float width = 4.0; // in texture pixels

const int SAMPLES = 12;

void vertex() {
	VERTEX += (UV * 2.0 - 1.0) * width;
	UV = (UV - 0.5) * (1.0 + 2.0 * width * TEXTURE_PIXEL_SIZE) + 0.5;
}

// 1 inside the original texture, 0 outside (the texture would otherwise clamp its edge pixels).
float inside(vec2 uv) {
	vec2 within = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return within.x * within.y;
}

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);
	sprite.a *= inside(UV);
	float around = 0.0;
	for (int i = 0; i < SAMPLES; i++) {
		float angle = 6.2831853 * float(i) / float(SAMPLES);
		vec2 uv = UV + vec2(cos(angle), sin(angle)) * width * TEXTURE_PIXEL_SIZE;
		around = max(around, texture(TEXTURE, uv).a * inside(uv));
	}
	vec4 outline = vec4(outline_color.rgb, outline_color.a * around);
	COLOR = mix(outline, vec4(sprite.rgb, 1.0), sprite.a);
	COLOR.a = max(sprite.a, outline.a);
}
