extends CharacterBody3D

signal boss_defeated
signal phase_changed(new_phase: String)
signal core_exposure_changed(is_open: bool, duration: float)
signal hit_resolved(result: Dictionary)

enum State {
	INTRO,
	P1_CLOSED, P1_OPEN, TRANSITION_70,
	P2_CLOSED, P2_OPEN, TRANSITION_35,
	P3_CLOSED, P3_OPEN, FINAL_REARM,
	FINAL_OPEN,
	DEAD
}

var current_state: State = State.INTRO
var hp: float = 1476.0
var max_hp: float = 1476.0

const GATE_70: float = 1033.2
const GATE_35: float = 516.6
const GATE_10: float = 147.6

var state_timer: float = 1.5
var pattern_count: int = 0
var recoveries_completed: int = 0

# Core exposure tracking
var is_core_exposed: bool = false
var exposure_time_remaining: float = 0.0
var missed_openings: int = 0
var rearm_well_active: bool = false

# Visual nodes
var body_root: Node3D
var core_mesh: MeshInstance3D
var core_col: CollisionShape3D
var body_col: CollisionShape3D
var shutter_left: MeshInstance3D
var shutter_right: MeshInstance3D
var crown_branches: Node3D

var danger_nodes:Array[Node]=[]
var hit_receipts:Dictionary={}
var last_hit_result: Dictionary = {}
var attack_phase:="wait"
var attack_clock:=0.0
var attack_target:=Vector3.ZERO
var attack_kind:="thorn"
# Evasion is an announced decision made between attacks, never an arrow reaction.
const EVADE_WARNING := 0.42
const EVADE_DURATION := 0.48
const EVADE_COOLDOWN := 5.0
const EVADE_DISTANCE := 1.55
var dodge_goal_x := 0.0
var dodge_warning_remaining := 0.0
var dodge_time_remaining := 0.0
var dodge_cooldown := 0.0
var dodge_direction := 1.0
var arena_anchor := Vector3.ZERO
var lateral_limits := Vector2(-3.6, 3.6)
var recent_attacks: Array[String] = []
var attack_cooldowns := {"thorn": 0.0, "ground": 0.0, "ring": 0.0}
var intent_label: Label3D
var combat_clock:=0.0
var completed:=false
var arms:Array[Node3D]=[]
var game: Node
var target_player: Node3D

func _ready() -> void:
	collision_layer = 8 # Layer 4 (Enemies)
	collision_mask = 1 | 2 # Layer 1 (Terrain) | Layer 2 (Player)
	_build_3d_body()
	arena_anchor = global_position
	_refresh_lateral_limits()
	intent_label = Label3D.new()
	intent_label.name = "BossIntent"
	intent_label.position = Vector3(0, 4.15, 0)
	intent_label.font_size = 42
	intent_label.pixel_size = 0.009
	intent_label.outline_size = 9
	intent_label.modulate = Color("ffe0a3")
	intent_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	intent_label.no_depth_test = true
	intent_label.visible = false
	add_child(intent_label)

func _build_3d_body() -> void:
	var colossus_data = preload("res://campaign/combat/boss_visuals.gd").build_colossus(self)
	body_root = colossus_data["body_root"]
	core_mesh = colossus_data["core_mesh"]
	shutter_left = colossus_data["shutter_left"]
	shutter_right = colossus_data["shutter_right"]
	arms = colossus_data["arms"]
	crown_branches = colossus_data["crown_root"]

	# Main Body Collision
	body_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.35
	cap.height = 3.8
	body_col.shape = cap
	body_col.position = Vector3(0, 1.9, 0)
	add_child(body_col)

	# Core Collision (Visibly in front of chest along firing line)
	core_col = CollisionShape3D.new()
	var core_shape := SphereShape3D.new()
	core_shape.radius = 0.55
	core_col.shape = core_shape
	core_col.position = Vector3(0, 2.2, 1.45)
	add_child(core_col)

	_sync_core_collision()
	_update_core_visual()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD or not is_instance_valid(game) or not game.is_playing():
		return

	combat_clock+=delta
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	for kind in attack_cooldowns:
		attack_cooldowns[kind] = maxf(0.0, float(attack_cooldowns[kind]) - delta)
	_tick_evasion(delta)
	var winding: bool = attack_phase == "telegraph"
	for i in range(arms.size()):
		var arm := arms[i]
		if is_instance_valid(arm):
			var target_rx: float = -1.95 if winding else (0.85 if attack_phase == "recover" else 0.0)
			arm.rotation.x = lerpf(arm.rotation.x, target_rx, minf(1.0, delta * 12.0))
			if winding:
				arm.rotation.z = (1.0 if i == 0 else -1.0) * (0.28 + sin(combat_clock * 24.0) * 0.06)

	if is_instance_valid(body_root):
		body_root.rotation.x = lerpf(body_root.rotation.x, -0.10 if winding else (0.12 if attack_phase == "recover" else 0.0), minf(1.0, delta * 8.0))

	# Crown wisps orbit and levitation stance in Phase 2 & 3
	if is_instance_valid(crown_branches):
		crown_branches.rotation.y += delta * (2.8 if hp <= GATE_70 else 0.9)
	if hp <= GATE_70 and current_state != State.DEAD and is_instance_valid(body_root):
		body_root.position.y = lerpf(body_root.position.y, 0.95 + sin(combat_clock * 2.8) * 0.18, delta * 3.5)
	elif is_instance_valid(body_root):
		body_root.position.y = lerpf(body_root.position.y, 0.0, delta * 6.0)
	var lean := -dodge_direction * 0.16 if dodge_warning_remaining > 0.0 else 0.0
	body_root.rotation.z = lerpf(body_root.rotation.z, lean, minf(1.0, delta * 9.0))
	_sync_core_collision()
	state_timer -= delta

	# Check active exposure window
	if is_core_exposed:
		exposure_time_remaining = maxf(0.0, exposure_time_remaining - delta)
		if exposure_time_remaining <= 0:
			_close_core()

	match current_state:
		State.INTRO:
			if state_timer <= 0:
				_enter_state(State.P1_CLOSED)
		State.TRANSITION_70:
			if state_timer <= 0:
				_enter_state(State.P2_CLOSED)
		State.TRANSITION_35:
			if state_timer <= 0:
				_enter_state(State.P3_CLOSED)
		State.P1_CLOSED,State.P2_CLOSED,State.P3_CLOSED,State.FINAL_REARM:
			_advance_patterns(delta)

func _enter_state(new_state: State) -> void:
	current_state = new_state
	phase_changed.emit(State.keys()[current_state])
	attack_phase="wait";attack_clock=.7
	_cancel_evasion()
	_set_intent("")
	if new_state in [State.TRANSITION_70,State.TRANSITION_35]:
		_clear_danger()
		for child in get_parent().get_children():
			if child.get_script()==preload("res://campaign/combat/burn_effect.gd") and child.target==self:child.queue_free()

	match current_state:
		State.P1_CLOSED, State.P2_CLOSED, State.P3_CLOSED:
			_close_core()
			pattern_count = 0
			recoveries_completed = 0
			state_timer = 2.0
		State.P1_OPEN, State.P2_OPEN, State.P3_OPEN:
			_open_core(4.2)
		State.TRANSITION_70, State.TRANSITION_35:
			_close_core()
			state_timer = 1.0 # 1s transition invulnerability
		State.FINAL_REARM:
			_close_core()
			_clear_danger()
			rearm_well_active = true
			_set_intent("AURORA WELL · REFILL" if _needs_final_rearm() else "FINAL CORE · WAIT FOR OPENING")
			if is_instance_valid(game):
				game.feedback("Final 10% · Fully charged Aurora must strike the exposed core. Reach the Aurora Well to refill." if _needs_final_rearm() else "Final 10% · Fully charge Aurora and strike the core when it opens.")
			recoveries_completed=0;pattern_count=0
			state_timer = 2.0
		State.FINAL_OPEN:
			rearm_well_active = false
			_open_core(4.2)
			_set_intent("GOLD CORE · READY AURORA")
			game.feedback("Gold core exposed · Hold AURORA until READY · Release into the core")

func _open_core(duration: float = 4.2) -> void:
	is_core_exposed = true
	exposure_time_remaining = duration
	_update_core_visual()
	core_exposure_changed.emit(true, duration)
	# Animate shutters open with slide and hinge rotation
	if is_instance_valid(shutter_left) and is_instance_valid(shutter_right):
		var tw := create_tween()
		if tw:
			tw.set_parallel(true)
			tw.tween_property(shutter_left, "position:x", 0.72, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(shutter_right, "position:x", -0.72, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(shutter_left, "rotation:y", -0.32, 0.45)
			tw.tween_property(shutter_right, "rotation:y", 0.32, 0.45)
	_spawn_vent_burst()

func _spawn_vent_burst() -> void:
	if not is_instance_valid(core_mesh): return
	var parent_stage = get_parent()
	if not is_instance_valid(parent_stage): return
	var pos := core_mesh.global_position
	for i in range(8):
		var mote := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = randf_range(0.04, 0.09)
		sm.height = sm.radius * 2.0
		mote.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.7, 0.95, 1.0, 0.8)
		mat.emission_enabled = true
		mat.emission = Color("a0eeff")
		mat.emission_energy_multiplier = 2.5
		mote.material_override = mat
		parent_stage.add_child(mote)
		mote.global_position = pos + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), 0.1)
		var dest := mote.global_position + Vector3(randf_range(-0.8, 0.8), randf_range(-0.4, 0.8), randf_range(0.6, 1.6))
		var tw := mote.create_tween()
		if tw:
			tw.set_parallel(true)
			tw.tween_property(mote, "global_position", dest, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
			tw.chain().tween_callback(mote.queue_free)

func _close_core() -> void:
	if is_core_exposed and current_state == State.FINAL_OPEN:
		missed_openings += 1
		rearm_well_active = true # Enable safe rearm well on missed final opening
	is_core_exposed = false
	exposure_time_remaining = 0.0
	_update_core_visual()
	core_exposure_changed.emit(false, 0.0)
	# Animate shutters closed
	if is_instance_valid(shutter_left) and is_instance_valid(shutter_right):
		var tw := create_tween()
		if tw:
			tw.set_parallel(true)
			tw.tween_property(shutter_left, "position:x", 0.28, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(shutter_right, "position:x", -0.28, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(shutter_left, "rotation:y", 0.0, 0.38)
			tw.tween_property(shutter_right, "rotation:y", 0.0, 0.38)
	
	if current_state == State.FINAL_OPEN:
		_enter_state(State.FINAL_REARM)
	elif current_state in [State.P1_OPEN,State.P2_OPEN,State.P3_OPEN]:
		var next_state:State=State.P1_CLOSED if hp>GATE_70 else (State.P2_CLOSED if hp>GATE_35 else State.P3_CLOSED)
		_enter_state(next_state)

# CollisionShape3D must remain a direct child of the CharacterBody3D. Mirror the
# animated chest transform so a shot at the visible heart hits the same volume.
func _sync_core_collision() -> void:
	if is_instance_valid(core_col) and is_instance_valid(core_mesh):
		core_col.global_position = core_mesh.global_position

func _update_core_visual() -> void:
	if not is_instance_valid(core_mesh):
		return
	var material: StandardMaterial3D = core_mesh.material_override
	var color := Color("ffd67a") if current_state == State.FINAL_OPEN else Color("a0eeff")
	if not is_core_exposed:
		color = Color("805128")
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = 2.8 if is_core_exposed else 0.2

func _needs_final_rearm() -> bool:
	if not is_instance_valid(game):
		return false
	return game.arrows < 1 or game.focus_meter < 100.0 or game.ultimate_used

func combat_status() -> Dictionary:
	var final_phase := hp <= GATE_10 + 0.01 and not completed
	var objective := "Core exposed · Aim at the cyan heart" if is_core_exposed else "Core closed · Body hits deal 25% damage"
	if final_phase:
		if is_core_exposed:
			objective = "Core exposed · Hold AURORA until READY · Hit the gold heart"
		elif _needs_final_rearm() and rearm_well_active:
			objective = "Final 10% · Reach Aurora Well to refill · Wait for the core"
		else:
			objective = "Final 10% · Wait for core exposure · Fully charged Aurora required"
	return {"core_exposed": is_core_exposed, "finisher_phase": final_phase,
		"rearm_required": final_phase and rearm_well_active and _needs_final_rearm(),
		"objective": objective, "exposure_remaining": exposure_time_remaining,
		"hp": hp, "max_hp": max_hp, "state": State.keys()[current_state]}

func collect_rearm_well(_hero: Node3D) -> bool:
	if not rearm_well_active:
		return false
	rearm_well_active = false
	_set_intent("FINAL CORE · WAIT FOR OPENING")
	if is_instance_valid(game):
		game.arrows = maxi(int(game.arrows), 6)
		game.ultimate_used = false
		game.focus_meter = 100.0
		game.power_timers.erase("ultimate")
		game.power_timers.erase("aurora")
		game.power_global_lock = 0.0
		if game.has_method("feedback"):
			game.feedback("Aurora Well restored · 6 arrows minimum · 100 focus · Wait for the core, then fully charge Aurora")
	return true

func _is_core_contact(hit_pos: Vector3, context: Dictionary) -> bool:
	if not is_core_exposed or not is_instance_valid(core_col):
		return false
	# A swept ray knows which boss shape it struck. A nearby trunk impact must
	# not become a weak-spot hit just because it is close to the heart.
	if context.has("hit_shape"):
		var shape_index := int(context.hit_shape)
		if shape_index >= 0:
			return shape_owner_get_owner(shape_find_owner(shape_index)) == core_col
	# Secondary/legacy callers do not have a physics shape result.
	_sync_core_collision()
	return core_col.global_position.distance_to(hit_pos) <= 0.57

func _record_hit(accepted: bool, reason: String, text: String, before: float, core_hit: bool, context: Dictionary, finisher: bool = false) -> bool:
	last_hit_result = {"accepted": accepted, "reason": reason, "message": text,
		"hp_before": before, "hp_after": hp, "damage": maxf(0.0, before - hp),
		"core_hit": core_hit, "finisher": finisher, "state": State.keys()[current_state],
		"shot_id": context.get("shot_id", -1)}
	hit_resolved.emit(last_hit_result.duplicate(true))
	if reason!="duplicate" and is_instance_valid(game) and game.has_method("play_sound"):
		game.play_sound("res://sounds/target_hit.wav" if accepted else "res://sounds/dummy_hit.wav",1.15 if core_hit else .8,-15)
	if reason != "duplicate" and current_state != State.DEAD and is_instance_valid(game) and game.has_method("feedback"):
		game.feedback(text)
	return accepted

func campaign_hit(hit_pos: Vector3, incoming_damage: float, shot_context: Dictionary = {}) -> bool:
	var before := hp
	if is_instance_valid(game) and not game.is_playing():return _record_hit(false,"paused","Combat paused",before,false,shot_context)
	var receipt := str(shot_context.get("event_id", shot_context.get("shot_id", -1)))
	if receipt != "-1" and hit_receipts.has(receipt):
		return _record_hit(false, "duplicate", "Arrow already resolved", before, false, shot_context)
	if receipt != "-1":
		hit_receipts[receipt] = true
	if current_state in [State.INTRO, State.TRANSITION_70, State.TRANSITION_35, State.DEAD]:
		return _record_hit(false, "transition" if current_state != State.DEAD else "defeated", "Crown reforming · Wait for the core", before, false, shot_context)

	var is_core_hit := _is_core_contact(hit_pos, shot_context)
	var power_key := str(shot_context.get("power_key", "normal"))
	var draw_ratio := float(shot_context.get("draw_ratio", 0.0))
	var is_direct := bool(shot_context.get("direct", true)) and not bool(shot_context.get("aoe", false)) and not bool(shot_context.get("secondary", false))
	if hp <= GATE_10 + 0.01:
		hp = GATE_10
		var reason := ""
		var text := ""
		if not is_core_exposed:
			reason = "core_closed"
			text = "Final 10% · Core closed · Wait for the gold heart to open"
		elif not is_core_hit:
			reason = "aim_core"
			text = "Final 10% · Aim at the exposed gold heart"
		elif not is_direct:
			reason = "direct_hit_required"
			text = "Final 10% · Aurora must strike the core directly"
		elif power_key not in ["aurora", "ultimate"]:
			reason = "aurora_required"
			text = "Final seal · Hold AURORA until READY · Release into the gold core"
		elif draw_ratio < 0.95:
			reason = "full_draw_required"
			text = "Aurora was not fully charged · Hold the draw until READY"
		else:
			var profile = game.profile if is_instance_valid(game) else null
			if profile == null or profile.bow_mastery() < 100 or profile.arrow_mastery() < 100 or profile.character_mastery() < 100:
				reason = "mastery_required"
				text = "Final Aurora requires Bow, Arrow and Archer mastery 100"
		if not reason.is_empty():
			return _record_hit(false, reason, text, before, is_core_hit, shot_context)
		_execute_redemption_finish()
		return _record_hit(true, "redeemed", "The Hollow Crown redeemed", before, true, shot_context, true)

	var delivered_damage := maxf(0.0, incoming_damage) * (1.0 if is_core_hit else 0.25)
	var gate := GATE_70 if hp > GATE_70 else (GATE_35 if hp > GATE_35 else GATE_10)
	hp = maxf(gate, hp - delivered_damage)
	var actual_damage := before - hp
	if actual_damage <= 0.0:
		return _record_hit(false, "no_damage", "Arrow dealt no damage", before, is_core_hit, shot_context)
	if is_instance_valid(game):
		game.target_scored(3 if is_core_hit else 2, actual_damage, true)
		if is_instance_valid(game.combat_hud) and game.combat_hud.has_method("popup_damage"):
			game.combat_hud.popup_damage(hit_pos, actual_damage, is_core_hit, power_key)
	var gate_reached := is_equal_approx(hp, gate)
	if gate_reached:
		_enter_state(State.TRANSITION_70 if gate == GATE_70 else (State.TRANSITION_35 if gate == GATE_35 else State.FINAL_REARM))
	var text := "%s · %.1f damage" % ["Core hit" if is_core_hit else "Armored body", actual_damage]
	if gate_reached:
		text += " · Final 10%: fully charged Aurora on exposed core" if gate == GATE_10 else " · Phase changed"
	elif not is_core_exposed:
		text += " · Core closed, 25% damage"
	return _record_hit(true, "phase_gate" if gate_reached else ("core_damage" if is_core_hit else "body_damage"), text, before, is_core_hit, shot_context)

func _execute_redemption_finish() -> void:
	hp = 0.0
	current_state = State.DEAD
	completed=true
	_cancel_evasion()
	_set_intent("")
	_clear_danger()
	is_core_exposed = false
	collision_layer = 0
	collision_mask = 0
	boss_defeated.emit()
	
	# Redemption visuals: soft living green leaves and aurora radiance
	if is_instance_valid(core_mesh):
		var mat: StandardMaterial3D = core_mesh.material_override
		if mat:
			mat.albedo_color = Color("7ae89d")
			mat.emission = Color("5af5b8")
			mat.emission_energy_multiplier = 3.5

	if is_instance_valid(game):
		if game.has_method("feedback"):
			game.feedback("🌟 The Hollow Crown Redeemed!")


func _clear_danger() -> void:
	for node in danger_nodes:
		if is_instance_valid(node):node.queue_free()
	danger_nodes.clear()

func _advance_patterns(delta: float) -> void:
	danger_nodes = danger_nodes.filter(func(node): return is_instance_valid(node) and not node.is_queued_for_deletion())
	attack_clock -= delta
	if attack_clock > 0.0:
		return
	if attack_phase == "wait":
		# Each complete hazard resolves before the next tell or a guaranteed opening.
		if not danger_nodes.is_empty():
			attack_clock = 0.1
			return
		if current_state == State.FINAL_REARM and rearm_well_active and _needs_final_rearm():
			# Refill only when needed; a ready archer can earn the next opening.
			attack_clock = 0.15
			return
		if recoveries_completed >= 2:
			if current_state != State.FINAL_REARM or not _needs_final_rearm():
				attack_phase = "opening"
				attack_clock = 0.6
				_set_intent("CORE OPENING")
				game.feedback("Core opening · Draw and release")
				return
		if not is_instance_valid(target_player):
			attack_clock = 0.15
			return
		attack_kind = _choose_attack()
		if attack_kind.is_empty():
			attack_clock = 0.15
			return
		attack_target = target_player.global_position + Vector3(0, 0.7, 0)
		attack_phase = "telegraph"
		attack_clock = 1.05 if attack_kind == "thorn" else 1.35
		recent_attacks.append(attack_kind)
		if recent_attacks.size() > 3:
			recent_attacks.pop_front()
		attack_cooldowns[attack_kind] = 5.0 if attack_kind == "ring" else 3.0
		if attack_kind != "thorn":
			var hazard = preload("res://campaign/combat/boss_hazard.gd").new()
			hazard.game = game
			hazard.kind = attack_kind
			hazard.damage = 22 if attack_kind == "ground" else 20
			hazard.warning = attack_clock
			hazard.position = Vector3(attack_target.x, global_position.y + 0.03, attack_target.z) if attack_kind == "ground" else global_position + Vector3(0, 0.03, 0)
			get_parent().add_child(hazard)
			danger_nodes.append(hazard)
			_set_intent("ROOT STRIKE · MOVE" if attack_kind == "ground" else "ROOT WAVE · DODGE")
			game.feedback("Roots marked your position · Keep moving" if attack_kind == "ground" else "Root wave incoming · Dodge through the ring")
		else:
			_set_intent("THORN AIMED · SIDESTEP")
			game.feedback("Thorn aimed · Move sideways")
			_plan_evasion()
	elif attack_phase == "telegraph":
		_cancel_evasion()
		if attack_kind == "thorn":
			var thorn = preload("res://campaign/combat/enemy_seed.gd").new()
			get_parent().add_child(thorn)
			thorn.damage = 18
			thorn.speed = 10
			var origin := global_position + Vector3(0, 2, 1)
			# A distant arrow lane must still reach its committed target.
			thorn.max_life = clampf(origin.distance_to(attack_target) / thorn.speed + 0.35, 1.6, 4.5)
			thorn.setup(origin, attack_target - origin, self)
			danger_nodes.append(thorn)
		attack_phase = "recover"
		attack_clock = 0.9
		_set_intent("RECOVERING")
	elif attack_phase == "recover":
		pattern_count += 1
		recoveries_completed += 1
		attack_phase = "wait"
		attack_clock = 0.3
		_set_intent("")
	elif attack_phase == "opening":
		if current_state == State.FINAL_REARM:
			_enter_state(State.FINAL_OPEN)
		else:
			_enter_state(State.P1_OPEN if hp > GATE_70 else (State.P2_OPEN if hp > GATE_35 else State.P3_OPEN))

func _choose_attack() -> String:
	var offset := target_player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var scores := {"thorn": 6.0 if distance > 10.0 else 2.0, "ground": 5.0 if distance <= 10.0 else 3.0}
	if hp <= GATE_70 and distance <= 12.0:
		scores["ring"] = 7.0 if distance < 6.0 else 2.0
	var best := ""
	var best_score := -INF
	for kind in ["thorn", "ground", "ring"]:
		if not scores.has(kind) or float(attack_cooldowns[kind]) > 0.0:
			continue
		var score: float = scores[kind]
		for i in range(recent_attacks.size()):
			if recent_attacks[i] == kind:
				score -= 7.0 if i == recent_attacks.size() - 1 else 1.0
		if score > best_score:
			best_score = score
			best = kind
	return best

func _plan_evasion() -> void:
	if is_core_exposed or dodge_cooldown > 0.0:
		return
	var offset := target_player.global_position - global_position
	offset.y = 0.0
	if offset.length() < 6.0:
		return
	_refresh_lateral_limits()
	var side := -1.0 if offset.x > 0.25 else 1.0
	if absf(offset.x) <= 0.25:
		side = 1.0 if pattern_count % 2 == 0 else -1.0
	for candidate in [side, -side]:
		var goal := clampf(global_position.x + candidate * EVADE_DISTANCE, lateral_limits.x, lateral_limits.y)
		if absf(goal - global_position.x) < 0.75:
			continue
		if not _point_is_visible(Vector3(goal, global_position.y + 2.2, global_position.z)):
			continue
		dodge_goal_x = goal
		dodge_direction = signf(goal - global_position.x)
		dodge_warning_remaining = EVADE_WARNING
		dodge_time_remaining = EVADE_DURATION
		dodge_cooldown = EVADE_COOLDOWN
		var screen_direction := dodge_direction
		var camera = target_player.get("camera")
		if camera is Camera3D:
			var start_screen: Vector2 = camera.unproject_position(global_position + Vector3(0, 2.2, 0))
			var end_screen: Vector2 = camera.unproject_position(Vector3(goal, global_position.y + 2.2, global_position.z))
			screen_direction = signf(end_screen.x - start_screen.x)
		_set_intent("← CROWN STEPS LEFT" if screen_direction < 0.0 else "CROWN STEPS RIGHT →")
		game.feedback("Crown steps left · Thorn aimed" if screen_direction < 0.0 else "Crown steps right · Thorn aimed")
		return

func _tick_evasion(delta: float) -> void:
	if is_core_exposed or current_state not in [State.P1_CLOSED, State.P2_CLOSED, State.P3_CLOSED, State.FINAL_REARM] or attack_phase != "telegraph":
		_cancel_evasion()
		return
	if dodge_warning_remaining > 0.0:
		# The warning consumes this tick. A long frame cannot skip the readable tell.
		dodge_warning_remaining = maxf(0.0, dodge_warning_remaining - delta)
		return
	if dodge_time_remaining <= 0.0:
		return
	var step_time := minf(delta, dodge_time_remaining)
	dodge_time_remaining = maxf(0.0, dodge_time_remaining - delta)
	var next_x := move_toward(global_position.x, dodge_goal_x, EVADE_DISTANCE / EVADE_DURATION * step_time)
	var motion := Vector3(next_x - global_position.x, 0, 0)
	move_and_collide(motion)
	velocity = Vector3.ZERO

func _cancel_evasion() -> void:
	dodge_warning_remaining = 0.0
	dodge_time_remaining = 0.0
	velocity = Vector3.ZERO

func _refresh_lateral_limits() -> void:
	lateral_limits = Vector2(arena_anchor.x - 3.6, arena_anchor.x + 3.6)
	var arena := get_parent()
	if is_instance_valid(arena) and arena.get("safe_bounds") is Rect2:
		var bounds: Rect2 = arena.safe_bounds
		# Leave room for the trunk collision and an escape path along the walls.
		lateral_limits.x = maxf(lateral_limits.x, bounds.position.x + 1.5)
		lateral_limits.y = minf(lateral_limits.y, bounds.end.x - 1.5)

func _point_is_visible(point: Vector3) -> bool:
	if not is_instance_valid(target_player):
		return false
	var camera = target_player.get("camera")
	if not camera is Camera3D:
		return true
	if camera.is_position_behind(point) or not camera.is_position_in_frustum(point):
		return false
	var screen: Vector2 = camera.unproject_position(point)
	var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
	var margin := minf(56.0, viewport_rect.size.x * 0.08)
	return viewport_rect.grow(-margin).has_point(screen)

func _set_intent(text: String) -> void:
	if is_instance_valid(intent_label):
		# Keep the banner in the aimed camera even when the archer approaches.
		var near_player := is_instance_valid(target_player) and target_player.global_position.distance_to(global_position) < 7.0
		intent_label.position.y = 3.0 if near_player else 4.15
		intent_label.text = text
		intent_label.visible = not text.is_empty()

func can_receive_hit() -> bool:
	return not completed

func campaign_secondary_hit(damage:float,event_id:int) -> bool:
	return campaign_hit(global_position+Vector3(0,1,0),damage,{"shot_id":event_id,"secondary":true})
