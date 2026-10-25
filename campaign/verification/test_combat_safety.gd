extends SceneTree
const GameScene=preload("res://campaign/main.tscn")
const Briar=preload("res://campaign/combat/briar_slime.gd")
const Director=preload("res://campaign/combat/threat_director.gd")
var failures:Array[String]=[]
func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error(message)
func _init() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	var game=GameScene.instantiate();game.test_mode=true;root.add_child(game)
	await process_frame
	game.profile.data.bow_level=100;game.profile.data.arrow_level=100;game.profile.data.character_level=100
	game.start_stage(55,true);await process_frame;game.state="playing";game.set_process(false)
	var hero=game.hero;hero.set_physics_process(false);hero.current_hp=160
	var enemy=game.stage.combat_manager.enemies_alive[0];enemy.set_physics_process(false)
	enemy.global_position=hero.global_position+Vector3(0,0,-1)
	enemy.current_state=enemy.State.APPROACH;enemy._physics_process(.01)
	check(enemy.current_state==enemy.State.TELEGRAPH,"Melee reserves a visible windup")
	var committed:Vector3=enemy.committed_target
	hero.global_position+=Vector3(4,0,0)
	enemy._physics_process(.2)
	check(enemy.committed_target==committed,"Attack does not track player during windup")
	enemy._physics_process(1);enemy._physics_process(.01)
	check(hero.current_hp==160,"Leaving the committed attack avoids damage")
	enemy.committed_target=hero.global_position;enemy.global_position=hero.global_position+Vector3(0,0,-1)
	enemy._deliver_attack();check(hero.current_hp==148,"Committed melee deals its authored 12 damage")
	hero.start_dodge();hero._physics_process(.1)
	check(hero.is_dodging and hero.is_invulnerable,"Dodge reaches its timed invulnerability window")
	hero.take_player_damage(12,enemy);check(hero.current_hp==148,"Dodge window prevents damage")
	game.state="paused";var old_timer:float=enemy.state_timer;var old_pos:Vector3=enemy.global_position
	enemy._physics_process(1)
	check(enemy.state_timer==old_timer and enemy.global_position==old_pos,"Paused enemy cannot advance or attack")
	hero.take_player_damage(50,enemy);check(hero.current_hp==148,"Paused player cannot take damage")
	# Start a genuine attack so every internal leap flag and collision mask follows
	# the normal transition. Rewinding an airborne actor creates an impossible state.
	var briar=Briar.new();briar.game=game;briar.target_player=hero;game.stage.add_child(briar);briar.set_physics_process(false)
	game.state="playing";hero.is_invulnerable=true
	briar.global_position=hero.global_position+Vector3(0,0,-3)
	briar._commit_attack();briar._physics_process(briar.windup_time+.001)
	var start:Vector3=briar.global_position;briar._physics_process(.15)
	check(briar.global_position.y>start.y+.1 and briar.global_position.distance_to(start)>.2 and not briar.attack_delivered,"Briar physically leaps before applying its landing attack")
	game.state="paused"
	var briar_pos:Vector3=briar.global_position;briar._physics_process(.1)
	check(briar.global_position==briar_pos,"Paused leaping slime cannot teleport")
	game.state="playing";hero.is_invulnerable=false
	briar._physics_process(.1);check(hero.current_hp==148,"Leap cannot apply damage before landing")
	hero.is_invulnerable=true
	for i in range(200):
		briar._physics_process(.01)
		if briar.current_state!=briar.State.ATTACK:break
	check(briar.attack_delivered and briar.current_state==briar.State.RECOVER,"Leap lands once then enters a punishable recovery")
	var director=Director.new();var a=Node.new();var b=Node.new();var c=Node.new()
	check(director.reserve_attack(a) and not director.reserve_attack(b) and not director.reserve_attack(c),"Threat director limits simultaneous attackers")
	director.release_attack(a);check(not director.reserve_attack(c) and director.reserve_attack(b),"Resolved attacks pass fairly to the next waiting creature")
	director.clear();a.free();b.free();c.free()
	# A quick touch must commit now, with no draw/zoom and no second shot on release.
	hero.is_dodging=false;hero.dodge_cooldown=0;hero.shot_cooldown=0;hero.cancel_draw();hero.camera.fov=65
	game.arrows=10;game.power_armed=false
	var before_shots:int=game.shots
	game.touch_controller.size=Vector2(1280,720)
	var geo:Dictionary=game.touch_controller.geometry()
	game.touch_controller.aim=false;game.touch_controller.contact(40,geo.draw,true)
	check(game.shots==before_shots+1 and not hero.drawing and not hero.touch_aim and not hero.aim_held,"Quick SHOOT fires immediately without aim")
	game.touch_controller.contact(40,geo.draw,false);hero._physics_process(.02)
	check(game.shots==before_shots+1 and is_equal_approx(hero.camera.fov,65),"Quick release neither fires twice nor zooms camera")
	print("COMBAT SAFETY CHECKS: ","PASS" if failures.is_empty() else failures)
	game.stop_audio();game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
