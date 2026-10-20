extends Control

enum ReticleMode {
	HIDDEN,
	HIP_FIRE,   # Mode A: Crisp hip-fire crosshair & dot
	ADS_AIM     # Mode B: Large Precision Focus Circle Sight (Matching Image 1)
}

var current_mode: ReticleMode = ReticleMode.HIDDEN
var anim_alpha: float = 0.0
var circle_expand_anim: float = 0.0

# Archery Sight parameters
var sight_color: Color = Color(1.0, 1.0, 1.0, 0.95)
var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.55)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_mode(mode: ReticleMode) -> void:
	if current_mode != mode:
		current_mode = mode
		queue_redraw()

func _process(delta: float) -> void:
	var target_alpha: float = 0.0
	if current_mode != ReticleMode.HIDDEN:
		target_alpha = 1.0
		
	anim_alpha = move_toward(anim_alpha, target_alpha, 12.0 * delta)
	
	var target_expand: float = 1.0 if current_mode == ReticleMode.ADS_AIM else 0.0
	circle_expand_anim = lerpf(circle_expand_anim, target_expand, clampf(14.0 * delta, 0.0, 1.0))
	
	visible = anim_alpha > 0.01
	queue_redraw()

func _draw() -> void:
	if anim_alpha <= 0.01:
		return
		
	var center := size * 0.5
	var col := sight_color
	col.a *= anim_alpha
	var shadow := shadow_color
	shadow.a *= anim_alpha
	
	if current_mode == ReticleMode.ADS_AIM or circle_expand_anim > 0.02:
		# Large Precision Focus Aim Sight (Matching Reference Image 1)
		var base_radius: float = minf(size.x, size.y) * 0.25
		# Smooth bloom / expansion on entry
		var r: float = lerpf(base_radius * 0.45, base_radius, circle_expand_anim)
		var alpha_factor: float = anim_alpha * circle_expand_anim
		
		# 1. Subtle soft outer vignette to focus the player vision
		var vig_col = Color(0.0, 0.03, 0.06, 0.14 * alpha_factor)
		draw_rect(Rect2(Vector2.ZERO, size), vig_col, false, 24.0)
		
		# 2. Outer dark contrast shadow ring
		var shadow_col = shadow
		shadow_col.a *= circle_expand_anim
		draw_arc(center, r, 0.0, TAU, 96, shadow_col, 3.4, true)
		
		# 3. Main crisp white focus aim ring
		var ring_col = col
		ring_col.a *= circle_expand_anim
		draw_arc(center, r, 0.0, TAU, 96, ring_col, 2.4, true)
		
		# 4. Subtle inner soft glow ring
		var inner_glow = Color(1.0, 1.0, 1.0, 0.18 * alpha_factor)
		draw_arc(center, r - 1.6, 0.0, TAU, 96, inner_glow, 1.0, true)
		
		# 5. Center precision aiming pip (Target Bullseye Dot)
		draw_circle(center + Vector2(1, 1), 2.2, shadow_col)
		draw_circle(center, 1.8, ring_col)
		
	elif current_mode == ReticleMode.HIP_FIRE:
		# Mode A: Crisp over-the-shoulder hip-fire crosshair
		var ch_size: float = 10.0
		var ch_gap: float = 5.0
		var ch_col := Color(1.0, 1.0, 1.0, 0.88 * anim_alpha)
		var ch_shadow := Color(0.0, 0.0, 0.0, 0.55 * anim_alpha)
		
		# Shadow
		draw_line(center + Vector2(-ch_size - ch_gap, 1), center + Vector2(-ch_gap, 1), ch_shadow, 2.4)
		draw_line(center + Vector2(ch_gap, 1), center + Vector2(ch_size + ch_gap, 1), ch_shadow, 2.4)
		draw_line(center + Vector2(1, -ch_size - ch_gap), center + Vector2(1, -ch_gap), ch_shadow, 2.4)
		draw_line(center + Vector2(1, ch_gap), center + Vector2(1, ch_size + ch_gap), ch_shadow, 2.4)
		
		# White lines
		draw_line(center + Vector2(-ch_size - ch_gap, 0), center + Vector2(-ch_gap, 0), ch_col, 1.6)
		draw_line(center + Vector2(ch_gap, 0), center + Vector2(ch_size + ch_gap, 0), ch_col, 1.6)
		draw_line(center + Vector2(0, -ch_size - ch_gap), center + Vector2(0, -ch_gap), ch_col, 1.6)
		draw_line(center + Vector2(0, ch_gap), center + Vector2(0, ch_size + ch_gap), ch_col, 1.6)
		
		# Center precision dot
		draw_circle(center + Vector2(1, 1), 1.8, ch_shadow)
		draw_circle(center, 1.5, ch_col)
