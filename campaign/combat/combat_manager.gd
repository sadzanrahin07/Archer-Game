extends Node3D

var game: Node
var stage: Node3D
var threat_director: RefCounted
var enemies_alive: Array[Node] = []
var wave_index := 0
var total_waves := 1
var total_enemies_expected := 2
var enemies_killed := 0

# Supply Drop Anchor
var supply_anchor: Node3D
var supply_cooldown := 0.0
var supply_active := false

const MossSlimeScript = preload("res://campaign/combat/moss_slime.gd")
const BriarSlimeScript = preload("res://campaign/combat/briar_slime.gd")
const SeedSpitterScript = preload("res://campaign/combat/seed_spitter.gd")
const BarkStalkerScript = preload("res://campaign/combat/bark_stalker.gd")
const MirrorWispScript = preload("res://campaign/combat/mirror_wisp.gd")
const RootWardenScript = preload("res://campaign/combat/root_warden.gd")
const ThreatDirectorScript = preload("res://campaign/combat/threat_director.gd")
const EncounterLayoutScript = preload("res://campaign/combat/encounter_layout.gd")

var encounter_layout: RefCounted
var pending_arrivals: Array = []
var wave_kills_at_start := 0

var authored_waves: Array = []
var boss: Node3D
var completed:=false
var wave_wait:=0.0

func setup(owner_game:Node,owner_stage:Node3D) -> void:
	game=owner_game;stage=owner_stage
	if stage.stage_id<55 or game.profile.power_level()<60:return
	threat_director=ThreatDirectorScript.new()
	_build_supply_anchor()
	if stage.stage_id < 99:
		encounter_layout = EncounterLayoutScript.new()
		encounter_layout.configure(stage.stage_id)
		encounter_layout.build(stage, self)
	else:
		_build_navigation()
	if stage.stage_id==99:
		boss=preload("res://campaign/combat/hollow_crown.gd").new()
		boss.game=game;boss.target_player=game.hero;boss.position=stage.spawn+Vector3(0,0,-14)
		stage.add_child(boss);boss.boss_defeated.connect(func(): completed=true;game.finish(true,"The Hollow Crown restored"))
		return
	_setup_waves_for_stage()
	_start_next_wave()

func _setup_waves_for_stage() -> void:
	var scripts:Dictionary={"moss_slime":MossSlimeScript,"briar_slime":BriarSlimeScript,"seed_spitter":SeedSpitterScript,"bark_stalker":BarkStalkerScript,"mirror_wisp":MirrorWispScript,"root_warden":RootWardenScript}
	var waves: Array = stage.definition.get("enemy_waves", [])
	for w in range(waves.size()):
		var wave: Array = waves[w]
		var records: Array = []
		for i in range(wave.size()):
			var family: String = str(wave[i])
			var entrance: Dictionary = encounter_layout.entrance(stage.stage_id, w, i, wave.size(), family)
			entrance["script"] = scripts[family]; entrance["family"] = family
			records.append(entrance)
		authored_waves.append(records)
	total_waves=authored_waves.size();total_enemies_expected=0
	for wave in authored_waves:total_enemies_expected+=wave.size()

func _build_supply_anchor() -> void:
	supply_anchor = Node3D.new()
	supply_anchor.name = "SafeSupplyRefill"
	var spawn_pos:Vector3= stage.spawn if is_instance_valid(stage) and "spawn" in stage else Vector3.ZERO
	supply_anchor.position = spawn_pos + Vector3(0, 0, -4.5)
	add_child(supply_anchor)

	var pedestal := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.7
	cyl.height = 0.35
	pedestal.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.35, 0.28)
	pedestal.material_override = mat
	supply_anchor.add_child(pedestal)

	var quiver_marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.5, 0.25)
	quiver_marker.mesh = box
	quiver_marker.position.y = 0.4
	var qmat := StandardMaterial3D.new()
	qmat.albedo_color = Color("42d6c3")
	qmat.emission_enabled = true
	qmat.emission = Color("38bdae")
	qmat.emission_energy_multiplier = 1.2
	quiver_marker.material_override = qmat
	supply_anchor.add_child(quiver_marker)

	var label := Label3D.new()
	label.text = "SUPPLY"
	label.position.y = 0.9
	label.font_size = 36
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("6ee8d8")
	supply_anchor.add_child(label)
	supply_anchor.visible = false

func _physics_process(delta:float) -> void:
	if not is_instance_valid(game) or not game.is_playing() or completed:return
	if is_instance_valid(threat_director):threat_director.advance(delta)
	_advance_arrivals(delta)
	if wave_wait>0:
		wave_wait=maxf(0,wave_wait-delta)
		if wave_wait==0:_start_next_wave()
	supply_cooldown=maxf(0,supply_cooldown-delta)
	var final_well:bool=is_instance_valid(boss) and boss.rearm_well_active
	supply_anchor.visible=final_well or (game.arrows<=2 and supply_cooldown==0)
	if supply_anchor.visible and is_instance_valid(game.hero) and game.hero.global_position.distance_to(supply_anchor.global_position)<=2.0:
		if final_well:boss.collect_rearm_well(game.hero)
		else:game.arrows+=6
		supply_cooldown=8;supply_anchor.visible=false
		game.feedback("Aurora restored · 100 focus" if final_well else "Quiver restored · +6 arrows")

func _start_next_wave() -> void:
	if wave_index >= total_waves:
		_check_trial_victory()
		return
	var current_wave_defs: Array = authored_waves[wave_index]
	wave_index += 1
	wave_kills_at_start = enemies_killed
	for record in current_wave_defs:
		var arrival: Dictionary = record.duplicate()
		var entrance_position: Vector3 = stage.spawn + arrival.pos
		var occupied: bool = is_instance_valid(game.hero) and game.hero.global_position.distance_to(entrance_position) < 2.5
		if float(arrival.delay) <= 0 and int(arrival.after_kills) == 0 and not occupied:
			_spawn_enemy(arrival)
		else:
			arrival["marker"] = _arrival_marker(arrival)
			pending_arrivals.append(arrival)
	if is_instance_valid(game) and game.has_method("feedback"):
		game.feedback("Wave %d/%d · %s" % [wave_index, total_waves, encounter_layout.title])

func _arrival_marker(record: Dictionary) -> Node3D:
	var marker := Node3D.new(); marker.name = "MarkedEnemyEntrance"
	marker.position = stage.spawn + record.pos; add_child(marker)
	var ring := MeshInstance3D.new(); var shape := TorusMesh.new()
	shape.inner_radius = .83; shape.outer_radius = .93; shape.rings = 24; shape.ring_segments = 6
	ring.mesh = shape; ring.position.y = .035; marker.add_child(ring)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("8ee8cf"); mat.emission_enabled = true; mat.emission = mat.albedo_color; mat.emission_energy_multiplier = .65
	ring.material_override = mat
	var label := Label3D.new(); label.name = "Countdown"; label.position.y = 1.55; label.font_size = 36; label.pixel_size = .007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.modulate = Color("b9f7df"); marker.add_child(label)
	_update_arrival_label(record, marker, is_instance_valid(game.hero) and game.hero.global_position.distance_to(marker.global_position) < 2.5)
	return marker

func _update_arrival_label(record: Dictionary, marker: Node3D, occupied: bool) -> void:
	var remaining_kills: int = maxi(0, int(record.after_kills) - (enemies_killed - wave_kills_at_start))
	var label: Label3D = marker.get_node("Countdown")
	if occupied: label.text = "ENTRY · STEP CLEAR"
	elif remaining_kills > 0: label.text = "ENTRY · AFTER %d FALL%s" % [remaining_kills, "S" if remaining_kills > 1 else ""]
	else: label.text = "ENTRY · %.1fs" % maxf(0, float(record.delay))

func _advance_arrivals(delta: float) -> void:
	for i in range(pending_arrivals.size() - 1, -1, -1):
		var record: Dictionary = pending_arrivals[i]
		var eligible: bool = enemies_killed - wave_kills_at_start >= int(record.after_kills)
		if eligible: record.delay = maxf(0, float(record.delay) - delta)
		var marker: Node3D = record.marker
		var occupied: bool = is_instance_valid(game.hero) and game.hero.global_position.distance_to(marker.global_position) < 2.5
		_update_arrival_label(record, marker, occupied)
		if not eligible or float(record.delay) > 0 or occupied: continue
		pending_arrivals.remove_at(i); marker.queue_free(); _spawn_enemy(record)

func _spawn_enemy(record: Dictionary) -> void:
	var script_cls = record["script"]
	var enemy = script_cls.new()
	enemy.game = game
	enemy.family = str(record.get("family", "moss_slime"))
	var reference: int = mini(100, 60 + 5 * maxi(0, stage.stage_id / 5 + 1 - 12))
	var multipliers: Dictionary = {"moss_slime": 2.25, "briar_slime": 3.0, "seed_spitter": 2.0, "bark_stalker": 2.75, "mirror_wisp": 2.0, "root_warden": 5.0}
	enemy.hp = ceilf((12 + .5 * (reference - 1)) * float(multipliers[enemy.family])); enemy.max_hp = enemy.hp
	enemy.target_player = game.hero
	enemy.threat_director = threat_director
	enemy.enemy_defeated.connect(_on_enemy_defeated)
	enemy.position = stage.spawn + record["pos"]
	stage.add_child(enemy)
	enemies_alive.append(enemy)

func _on_enemy_defeated(enemy:Node) -> void:
	if not enemies_alive.has(enemy):return
	enemies_alive.erase(enemy);enemies_killed+=1
	if enemies_alive.is_empty() and pending_arrivals.is_empty():
		if wave_index<total_waves:wave_wait=1.2
		else:_check_trial_victory()

func on_target_completed(_index: int) -> void:
	_check_trial_victory()

func _check_trial_victory() -> void:
	if completed or is_instance_valid(boss) or not game.is_playing():return
	if not pending_arrivals.is_empty() or enemies_killed<total_enemies_expected or wave_index<total_waves:return
	for target in stage.targets:
		if not target.completed:return
	completed=true;game.finish(true,"The glade is safe")


func _build_navigation() -> void:
	var region:=NavigationRegion3D.new()
	var mesh:=NavigationMesh.new()
	var bounds:Rect2=stage.safe_bounds.grow(-1.5)
	var y:float=stage.spawn.y
	mesh.vertices=PackedVector3Array([Vector3(bounds.position.x,y,bounds.position.y),Vector3(bounds.end.x,y,bounds.position.y),Vector3(bounds.end.x,y,bounds.end.y),Vector3(bounds.position.x,y,bounds.end.y)])
	mesh.add_polygon(PackedInt32Array([0,3,2,1]))
	region.navigation_mesh=mesh;add_child(region)

func status_text() -> String:
	if is_instance_valid(boss):return "Hollow Crown · %d%% · %s"%[ceili(100*boss.hp/boss.max_hp),"CORE OPEN" if boss.is_core_exposed else "Read the attack tell"]
	var arrivals: String = " · %d marked entr%s" % [pending_arrivals.size(), "ies" if pending_arrivals.size() != 1 else "y"] if not pending_arrivals.is_empty() else ""
	return "Wave %d/%d · %d/%d creatures purified%s" % [wave_index, total_waves, enemies_killed, total_enemies_expected, arrivals]
