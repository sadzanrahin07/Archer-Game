extends SceneTree
const GameScene=preload("res://campaign/main.tscn")
const Projectile=preload("res://campaign/projectile.gd")
var failures:Array[String]=[]
var game:Node3D

func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error(message)

func _init() -> void:
	run.call_deferred()

func run() -> void:
	game=GameScene.instantiate();game.test_mode=true;root.add_child(game)
	await process_frame
	game.profile.data.bow_level=100;game.profile.data.arrow_level=100;game.profile.data.character_level=100
	game.profile.data.trial_proofs={"55":true,"65":true,"75":true,"85":true,"95":true}
	for id in range(100):
		game.start_stage(id,true)
		await process_frame
		await physics_frame
		check(game.stage.targets.size()==game.definitions[id].materials.size(),"Authored target count ID%d"%id)
		check(game.stage.stage_id==id,"Stable scene ID%d"%id)
		if game.is_combat():check(game.stage.targets.is_empty(),"Enemy fight contains no archery targets ID%d"%id)
		if id<55:check(not game.is_combat(),"No early monsters ID%d"%id)
		if not game.definitions[id].enemy_waves.is_empty():
			check(game.is_combat(),"Combat connected ID%d"%id)
			check(game.stage.combat_manager.total_waves==game.definitions[id].enemy_waves.size(),"Authored waves ID%d"%id)
		if id in [0,14,55,65,75,85,95,99]:print("BUILT SCENE ",id," targets ",game.stage.targets.size()," combat ",game.is_combat())
	for chain_id in [3,38]:
		game.start_stage(chain_id,true);await process_frame;game.state="playing"
		var chain_arrow=Projectile.new();chain_arrow.game=game;chain_arrow.owner_body=game.hero;chain_arrow.power=61.5;chain_arrow.shot_id=500+chain_id;chain_arrow.score_id="qa-chain-%d"%chain_id
		chain_arrow.position=game.stage.spawn+Vector3(0,1.45,0);chain_arrow.velocity=Vector3(0,0,-game.profile.flight_speed())
		game.airborne=1;game.stage.add_child(chain_arrow)
		for frame in range(30):await physics_frame
		check(game.max_thread_chain>=3,"Real normal projectile threads aligned %s orbs"%("moving" if chain_id==38 else "static"))
	game.start_stage(55,true);await process_frame;game.state="playing"
	var manager=game.stage.combat_manager
	check(manager.enemies_alive.size()==1 and manager.total_enemies_expected==1,"First trial introduces one slime")
	var enemy=manager.enemies_alive[0]
	check(enemy.hp==94 and enemy.combat_visuals_mode=="reference_3d_v2" and not enemy.direction_sprite.visible,"Fixed reference HP and animated 3D bodies connected")
	game.hero.current_hp=160;game.hero.is_invulnerable=true
	game.selected_power="burst";game.power_armed=true;game.arrows=2;game.focus_meter=100
	var volley:Dictionary=game.begin_volley()
	check(volley.ammo==3 and game.arrows==1 and game.shots==1 and game.airborne==3 and game.focus_meter==65,"One-arrow Burst commits one release and three pending bolts")
	game.arrows=0;game.hero.aim_held=true;game.hero.touch_aim=true;game._check_quiver_empty()
	check(not game.hero.aim_held and not game.hero.touch_aim and game.state=="playing","Empty aim clears without premature combat failure")
	manager.supply_cooldown=0;game.hero.position=manager.supply_anchor.global_position;manager._physics_process(.02)
	check(game.arrows>=6,"Zero-ammo supply needs no kill or arrow")
	game.start_stage(99,true);await process_frame;game.state="playing";game.hero.is_invulnerable=true
	var boss=game.stage.combat_manager.boss
	check(is_instance_valid(boss),"Final stage instantiates Hollow Crown, not a slime")
	boss.set_physics_process(false)
	boss._physics_process(1.6)
	var saw_natural_open:=false
	for tick in range(900):
		boss._physics_process(1.0/60)
		for hazard in boss.danger_nodes:
			if is_instance_valid(hazard) and not hazard.is_queued_for_deletion():hazard._physics_process(1.0/60)
		if boss.is_core_exposed:saw_natural_open=true;break
	check(saw_natural_open and boss.pattern_count>=2,"Boss attacks then naturally exposes core")
	boss.campaign_hit(boss.global_position,99999,{"shot_id":1})
	check(is_equal_approx(boss.hp,boss.GATE_70),"First phase cannot be skipped")
	boss._physics_process(1.1);boss.campaign_hit(boss.global_position,99999,{"shot_id":2})
	check(is_equal_approx(boss.hp,boss.GATE_35),"Second phase cannot be skipped")
	boss._physics_process(1.1);boss.campaign_hit(boss.global_position,99999,{"shot_id":3})
	check(is_equal_approx(boss.hp,boss.GATE_10),"Normal damage stops at ten percent")
	for miss in range(3):
		game.arrows=0;game.focus_meter=0;boss.collect_rearm_well(game.hero)
		check(game.arrows>=6 and game.focus_meter==100,"Final rearm recovery %d"%miss)
		boss._enter_state(boss.State.FINAL_OPEN);boss._physics_process(4.21)
		check(boss.rearm_well_active and not boss.is_core_exposed,"Missed finisher repeats rather than deadlocking")
	boss.collect_rearm_well(game.hero);boss._enter_state(boss.State.FINAL_OPEN)
	boss.campaign_hit(boss.core_col.global_position,99999,{"power_key":"ultimate","draw_ratio":0.0,"shot_id":90})
	check(not boss.completed,"Instant Aurora cannot bypass charged boss finisher")
	# Send a real swept projectile into the visible physical core.
	var arrow=Projectile.new();arrow.game=game;arrow.owner_body=game.hero
	arrow.power=184.5;arrow.ability={"key":"ultimate","draw_ratio":1.0,"damage":3.0};arrow.shot_id=100;arrow.score_id="qa-final"
	arrow.position=boss.core_col.global_position+Vector3(0,0,2);arrow.velocity=Vector3(0,0,-80)
	game.airborne=1;game.stage.add_child(arrow)
	for frame in range(12):await physics_frame
	check(boss.completed and boss.hp==0,"Real Aurora projectile can finish the physical core")
	print("CONNECTED SCENE CHECKS: ","PASS" if failures.is_empty() else failures)
	game.stop_audio();game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
