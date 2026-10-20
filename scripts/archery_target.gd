extends StaticBody3D

@onready var boss_mesh: MeshInstance3D = get_node_or_null("TargetBoss")
@onready var col_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")

var default_rot_x: float = 0.0
var is_knocked_down: bool = false
var knockdown_tween: Tween = null

func _ready() -> void:
	add_to_group("ArcheryTarget")
	add_to_group("Hittable")
	default_rot_x = rotation.x

func on_hit(hit_pos: Vector3, _arrow_source: Node = null) -> int:
	if is_knocked_down:
		return 0
		
	is_knocked_down = true
	
	var score = 2
	var label_text = "+2 WHITE"
	var text_color = Color(0.9, 0.9, 0.9)
	
	if boss_mesh:
		var center_pos = boss_mesh.global_position
		var dist = hit_pos.distance_to(center_pos)
		
		if dist < 0.12:
			score = 10
			label_text = "+10 BULLSEYE! ★"
			text_color = Color(1.0, 0.85, 0.15)
		elif dist < 0.24:
			score = 8
			label_text = "+8 RED"
			text_color = Color(1.0, 0.3, 0.3)
		elif dist < 0.35:
			score = 6
			label_text = "+6 BLUE"
			text_color = Color(0.3, 0.7, 1.0)
		elif dist < 0.45:
			score = 4
			label_text = "+4 BLACK"
			text_color = Color(0.5, 0.5, 0.5)
			
	# Target hit sound is played cleanly by arrow_projectile (target_hit.wav); no extra sounds
	_spawn_score_billboard(hit_pos, label_text, text_color)
	
	if col_shape:
		col_shape.set_deferred("disabled", true)
		
	if knockdown_tween and knockdown_tween.is_valid():
		knockdown_tween.kill()
		
	knockdown_tween = create_tween()
	var target_fall_rot_x = default_rot_x + deg_to_rad(86.0)
	
	# Initial backward drop to ground (silent; no thud sounds per requirements)
	knockdown_tween.tween_property(self, "rotation:x", target_fall_rot_x, 0.42)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)
		
	# Rest on ground for 3.2 seconds, then smoothly stand back up
	knockdown_tween.tween_interval(3.2)
	knockdown_tween.tween_property(self, "rotation:x", default_rot_x, 0.75)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
		
	knockdown_tween.tween_callback(_on_reset_upright)
		
	return score

func _on_reset_upright() -> void:
	is_knocked_down = false
	if col_shape:
		col_shape.set_deferred("disabled", false)
		
	for child in get_children():
		if "Arrow" in child.name and child is Node3D:
			child.queue_free()

func _spawn_score_billboard(pos: Vector3, txt: String, col: Color) -> void:
	var lbl = Label3D.new()
	lbl.text = txt
	lbl.modulate = col
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	lbl.outline_render_priority = 1
	lbl.font_size = 44
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	get_parent().add_child(lbl)
	lbl.global_position = pos + Vector3(0, 0.35, 0)
	
	var tw = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 1.1, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.3).set_delay(0.4)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)
