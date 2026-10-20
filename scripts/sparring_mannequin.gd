extends CharacterBody3D

signal health_changed(current_hp, max_hp)
signal training_started
signal training_ended

@export var max_health: float = 100.0
var current_health: float = 100.0
var is_training_active: bool = false
var is_alive: bool = true
var is_attacking: bool = false
var is_stunned: bool = false
var is_blocking: bool = false

var player_ref: Node3D = null
var spawn_position: Vector3 = Vector3.ZERO
var attack_cooldown: float = 0.0
var block_timer: float = 0.0

var anim_player: AnimationPlayer = null
@onready var hp_bar_mesh: Node3D = $HealthBarBillboard
@onready var hp_label: Label3D = $HealthBarBillboard/HpLabel
@onready var name_label: Label3D = $HealthBarBillboard/NameLabel
var snd_hit: AudioStreamPlayer3D = null
var snd_swing: AudioStreamPlayer3D = null

var katana_blade: Node3D = null

func _ready() -> void:
	anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	add_to_group("TrainingMannequin")
	add_to_group("Hittable")
	spawn_position = global_position
	current_health = max_health
	
	_setup_audio()
	_setup_katana()
	_setup_animation()
	_update_hp_display()
	
	if anim_player:
		_play_anim("A2/Armature|Armature|Armature|Sword_Idle")

func _setup_animation() -> void:
	if not anim_player:
		return
	var skel = find_child("GeneralSkeleton", true, false) as Skeleton3D
	if not skel:
		return
	anim_player.root_node = anim_player.get_path_to(skel.get_parent())
	for anim_name in anim_player.get_animation_list():
		var anim = anim_player.get_animation(anim_name)
		var t = 0
		while t < anim.get_track_count():
			var pth = str(anim.track_get_path(t))
			if pth.begins_with("Armature") or pth == "Armature":
				anim.remove_track(t)
			else:
				if pth.begins_with("%GeneralSkeleton"):
					var new_pth = pth.replace("%GeneralSkeleton", "GeneralSkeleton")
					anim.track_set_path(t, NodePath(new_pth))
				t += 1

func _setup_audio() -> void:
	snd_hit = AudioStreamPlayer3D.new()
	snd_hit.name = "SndHit"
	var hit_path = "res://Sound effects/musicholder-sword-sound-260274.mp3"
	snd_hit.stream = load(hit_path) if ResourceLoader.exists(hit_path) else load("res://sounds/dummy_hit.wav")
	snd_hit.unit_size = 10.0
	snd_hit.max_distance = 60.0
	add_child(snd_hit)
	
	snd_swing = AudioStreamPlayer3D.new()
	snd_swing.name = "SndSwing"
	var swing_path = "res://Sound effects/oxidvideos-sword-swing-sfx-407574.mp3"
	snd_swing.stream = load(swing_path) if ResourceLoader.exists(swing_path) else load("res://sounds/sword_swing_1.wav")
	snd_swing.unit_size = 8.0
	snd_swing.max_distance = 50.0
	add_child(snd_swing)

func _setup_katana() -> void:
	var skel = find_child("GeneralSkeleton", true, false) as Skeleton3D
	if not skel:
		return
	var hand_att = BoneAttachment3D.new()
	hand_att.name = "RightHandBlade"
	hand_att.bone_name = "RightHand"
	skel.add_child(hand_att)
	
	var k_mesh = load("res://models/katana_sword_mesh.res") as Mesh
	if k_mesh:
		katana_blade = MeshInstance3D.new()
		katana_blade.name = "DummyKatana"
		katana_blade.mesh = k_mesh
		katana_blade.rotation_degrees = Vector3(-90, 0, 0)
		hand_att.add_child(katana_blade)

func set_training_active(active: bool) -> void:
	is_training_active = active
	if is_training_active:
		print("Sparring Mannequin: Training session STARTED!")
		if not is_alive:
			_revive()
		else:
			_play_anim("A2/Armature|Armature|Armature|Sword_Idle")
	else:
		print("Sparring Mannequin: Training session ENDED.")
		is_attacking = false
		is_blocking = false
		is_stunned = false
		_play_anim("A2/Armature|Armature|Armature|Idle")

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
		
	if not player_ref:
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player_ref = players[0]
		else:
			player_ref = get_parent().find_child("Player", true, false)
			
	if not is_training_active:
		var dist_spawn = global_position.distance_to(spawn_position)
		if dist_spawn > 0.5:
			var dir = (spawn_position - global_position).normalized()
			dir.y = 0.0
			velocity.x = dir.x * 2.0
			velocity.z = dir.z * 2.0
			look_at(global_position + dir, Vector3.UP)
			move_and_slide()
		else:
			velocity = Vector3.ZERO
		return
		
	if not player_ref:
		return
		
	if is_stunned or is_attacking:
		move_and_slide()
		return
		
	var to_player = player_ref.global_position - global_position
	to_player.y = 0.0
	var dist = to_player.length()
	
	if to_player.length_squared() > 0.01:
		var target_yaw = atan2(-to_player.x, -to_player.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 6.0)
		
	attack_cooldown -= delta
	block_timer -= delta
	
	if dist > 2.2:
		var move_dir = to_player.normalized()
		velocity.x = move_dir.x * 2.8
		velocity.z = move_dir.z * 2.8
		if not is_attacking and not is_blocking:
			_play_anim("A2/Armature|Armature|Armature|Walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		
		if attack_cooldown <= 0.0:
			var roll = randf()
			if roll < 0.25 and not is_blocking:
				_do_block()
			else:
				_do_attack()
		elif not is_blocking and not is_attacking:
			_play_anim("A2/Armature|Armature|Armature|Sword_Idle")
			
	if not is_on_floor():
		velocity.y -= 15.0 * delta
	else:
		velocity.y = 0.0
		
	move_and_slide()

func _do_attack() -> void:
	is_attacking = true
	attack_cooldown = randf_range(1.6, 2.8)
	
	var attacks = [
		"A2/Armature|Armature|Sword_Regular_A",
		"A2/Armature|Armature|Sword_Regular_B",
		"A2/Armature|Armature|Armature|Sword_Attack"
	]
	var chosen = attacks[randi() % attacks.size()]
	_play_anim(chosen)
	
	if snd_swing and snd_swing.stream:
		snd_swing.pitch_scale = randf_range(0.9, 1.1)
		snd_swing.play()
		
	get_tree().create_timer(0.28).timeout.connect(func():
		if is_alive and is_attacking and player_ref:
			var d = global_position.distance_to(player_ref.global_position)
			if d <= 2.4:
				if player_ref.has_method("take_hit"):
					player_ref.take_hit(12.0, "katana_slash", self)
	)
	
	get_tree().create_timer(0.75).timeout.connect(func():
		is_attacking = false
	)

func _do_block() -> void:
	is_blocking = true
	block_timer = 1.0
	attack_cooldown = 1.8
	_play_anim("A2/Armature|Armature|Sword_Block")
	get_tree().create_timer(0.9).timeout.connect(func():
		is_blocking = false
	)

func take_damage(dmg: float, attack_kind: String = "sword", attacker: Node = null) -> void:
	if not is_alive:
		return
		
	if is_blocking:
		dmg *= 0.25
		_spawn_damage_text("PARRY!", Color(0.3, 0.8, 1.0))
		if snd_hit:
			snd_hit.pitch_scale = 1.6
			snd_hit.play()
		return
		
	current_health = maxf(0.0, current_health - dmg)
	_update_hp_display()
	_spawn_damage_text(str(int(dmg)), Color(1.0, 0.25, 0.2))
	
	if snd_hit and snd_hit.stream:
		snd_hit.pitch_scale = randf_range(0.95, 1.15)
		snd_hit.play()
		
	if current_health <= 0.0:
		_die()
	else:
		_play_hit_reaction()

func on_hit(hit_pos: Vector3, arrow: Node = null) -> void:
	take_damage(25.0, "arrow", arrow)

func _play_hit_reaction() -> void:
	is_stunned = true
	is_attacking = false
	is_blocking = false
	
	var reactions = [
		"A2/Armature|Armature|Armature|Hit_Chest",
		"A2/Armature|Armature|Armature|Hit_Head",
		"A2/Armature|Armature|Hit_Knockback"
	]
	var r = reactions[randi() % reactions.size()]
	_play_anim(r)
	
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_alive:
			is_stunned = false
	)

func _die() -> void:
	is_alive = false
	is_attacking = false
	is_blocking = false
	is_stunned = false
	velocity = Vector3.ZERO
	
	_play_anim("A2/Armature|Armature|Armature|Death01")
	_spawn_damage_text("KNOCKOUT!", Color(1.0, 0.85, 0.1))
	
	get_tree().create_timer(3.8).timeout.connect(_revive)

func _revive() -> void:
	if is_alive:
		return
	print("Sparring Mannequin: Reviving and standing back up!")
	is_alive = true
	current_health = max_health
	_update_hp_display()
	
	_play_anim("A2/Armature|Armature|LayToIdle")
	_spawn_damage_text("READY!", Color(0.3, 1.0, 0.4))
	
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_training_active:
			_play_anim("A2/Armature|Armature|Armature|Sword_Idle")
		else:
			_play_anim("A2/Armature|Armature|Armature|Idle")
	)

func _update_hp_display() -> void:
	if hp_label:
		hp_label.text = "%d / %d" % [int(current_health), int(max_health)]
	if hp_bar_mesh:
		var pct = clampf(current_health / max_health, 0.0, 1.0)
		var fill = hp_bar_mesh.get_node_or_null("Fill")
		if fill:
			fill.scale.x = maxf(0.001, pct)
			fill.position.x = -0.5 * (1.0 - pct)
			var mat = fill.get_active_material(0) as StandardMaterial3D
			if mat:
				if pct > 0.5:
					mat.albedo_color = Color(0.2, 0.85, 0.3)
				elif pct > 0.25:
					mat.albedo_color = Color(0.95, 0.75, 0.2)
				else:
					mat.albedo_color = Color(0.9, 0.2, 0.2)

func _spawn_damage_text(txt: String, col: Color) -> void:
	var lbl = Label3D.new()
	lbl.text = txt
	lbl.modulate = col
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.outline_render_priority = 2
	lbl.font_size = 48
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	get_parent().add_child(lbl)
	lbl.global_position = global_position + Vector3(0, 2.2, 0)
	
	var tw = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

func _play_anim(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name, 0.15)
