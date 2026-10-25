extends SceneTree

const GameScene=preload("res://campaign/main.tscn")
var failures:Array[String]=[]
var releases:Array[Dictionary]=[]

func check(value:bool,message:String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _init() -> void:run.call_deferred()

func _record_release(power_key:String,quick:bool) -> void:
	releases.append({"key":power_key,"quick":quick})

func run() -> void:
	root.size=Vector2i(1280,720)
	var game=GameScene.instantiate()
	game.test_mode=true
	root.add_child(game)
	await process_frame
	game.profile.save_path="/tmp/arrowglade-player-motion-test.json"
	game.profile.data.bow_level=100
	game.profile.data.arrow_level=100
	game.profile.data.character_level=100
	game.start_stage(55,true)
	await process_frame
	game.state="playing"
	game.set_process(false)
	game.stage.combat_manager.set_physics_process(false)
	for enemy in game.stage.combat_manager.enemies_alive:enemy.set_physics_process(false)
	var hero=game.hero
	hero.set_physics_process(false)
	hero.attack_release.connect(_record_release)
	game.arrows=30
	game.power_armed=false

	# A compatible, authored skeletal roll is present and retargeted to this rig.
	check(hero.anim_player.has_animation("shared/dodge"),"Player imports the authored Roll animation")
	var roll:Animation=hero.anim_player.get_animation("shared/dodge")
	check(roll.loop_mode==Animation.LOOP_NONE and roll.get_track_count()>20,"Dodge uses a complete non-looping skeletal action")
	var leg:int=hero.skeleton.find_bone("LeftUpperLeg")
	hero.anim_player.play("shared/dodge",0)
	hero.anim_player.seek(roll.length*.20,true)
	var early:Quaternion=hero.skeleton.get_bone_pose_rotation(leg)
	hero.anim_player.seek(roll.length*.65,true)
	var late:Quaternion=hero.skeleton.get_bone_pose_rotation(leg)
	check(early.angle_to(late)>.25,"Authored dodge visibly articulates the legs across its action")

	# Touch and keyboard produce camera-relative direction; camera orientation stays independent.
	hero.yaw=.75
	hero.pitch=-.15
	hero.last_move_dir=Vector3.ZERO
	hero.touch_move=Vector2.RIGHT
	hero.drawing=true
	hero.aim_held=true
	game.touch_controller.aim=true
	game.power_armed=true
	var yaw_before:float=hero.yaw
	var pitch_before:float=hero.pitch
	hero.start_dodge()
	var expected:Vector3=Vector3.RIGHT.rotated(Vector3.UP,yaw_before)
	check(hero.dodge_dir.is_equal_approx(expected),"Touch dodge follows the current movement direction in camera space")
	check(hero.last_pose=="dodge" and is_equal_approx(hero.anim_player.speed_scale,roll.length/hero.DODGE_DURATION),"Dodge action is timed to the physical dash")
	check(not hero.drawing and not hero.aim_held and not hero.touch_aim and not game.touch_controller.aim and not game.power_armed,"Dodge cancels bow draw, aim, touch aim and armed power")
	var shots_before:int=game.shots
	hero._fire()
	hero._fire(true)
	hero.instant_shoot()
	check(game.shots==shots_before and releases.is_empty(),"All fire paths reject shots and release VFX while dodging")
	hero._physics_process(.10)
	check(hero.is_dodging and hero.is_invulnerable and hero.last_pose=="dodge","Dodge maintains its action pose and timed immunity during movement")
	check(is_equal_approx(hero.yaw,yaw_before) and is_equal_approx(hero.pitch,pitch_before),"Dodge does not turn the camera toward its travel direction")
	game.state="paused"
	var timer:float=hero.dodge_timer
	var cooldown:float=hero.dodge_cooldown
	hero._physics_process(.3)
	check(is_equal_approx(hero.dodge_timer,timer) and is_equal_approx(hero.dodge_cooldown,cooldown),"Pause freezes dodge duration and cooldown together")
	game.state="playing"
	hero._physics_process(.31)
	check(not hero.is_dodging and not hero.is_invulnerable,"Dodge exits its action and invulnerability reliably")

	hero.dodge_cooldown=0
	hero.touch_move=Vector2.ZERO
	hero.last_move_dir=Vector3.ZERO
	Input.action_press("move_left")
	hero.start_dodge()
	Input.action_release("move_left")
	check(hero.dodge_dir.is_equal_approx(Vector3.LEFT.rotated(Vector3.UP,hero.yaw)),"Keyboard dodge follows movement input")
	hero.is_dodging=false
	hero.dodge_cooldown=0
	hero.last_move_dir=Vector3(0,0,-1)
	hero.start_dodge()
	check(hero.dodge_dir.is_equal_approx(Vector3(0,0,-1)),"No current input reuses the last movement direction")
	hero.is_dodging=false
	hero.dodge_cooldown=0
	hero.last_move_dir=Vector3.ZERO
	hero.start_dodge()
	check(hero.dodge_dir.is_equal_approx(Vector3(sin(hero.yaw),0,cos(hero.yaw))),"An idle first dodge retreats backward relative to the camera")
	hero.is_dodging=false
	hero.is_invulnerable=false
	hero.dodge_cooldown=0
	hero.cancel_draw()
	hero._fire()
	check(game.shots==shots_before,"A stale release after cancel cannot commit a new volley")

	# Combat keeps enough peripheral view even with late-game mastery or stationary flag.
	game.current_chapter=19
	hero.stationary=true
	hero.aim_held=true
	hero.camera.fov=40
	hero._physics_process(.1)
	check(is_equal_approx(hero.camera.fov,40),"Late-game combat aim stays at 40 degrees rather than forcing sniper zoom")
	hero.stationary=false
	hero.cancel_draw()

	# Actual shooting while moving keeps authored upper-body recoil and lower-body steps.
	for gait in ["walk","run"]:
		check(hero.anim_player.has_animation("shared/release_"+gait),"Moving bow release exists for "+gait)
		var clip:Animation=hero.anim_player.get_animation("shared/release_"+gait)
		var has_upper:bool=false
		var has_lower:bool=false
		for track in range(clip.get_track_count()):
			var path:String=str(clip.track_get_path(track))
			if path.ends_with(":LeftUpperLeg"):has_lower=true
			if path.ends_with(":RightUpperArm"):has_upper=true
		check(has_upper and has_lower and clip.loop_mode==Animation.LOOP_NONE,"Moving "+gait+" release combines authored bow and leg tracks")
	hero.shot_cooldown=0
	hero.camera.fov=65
	hero.touch_move=Vector2.RIGHT
	var projectiles_before:int=game.stage.get_child_count()
	hero.instant_shoot()
	check(game.shots==shots_before+1 and game.stage.get_child_count()>projectiles_before,"Quick shot commits a real projectile immediately")
	check(not hero.drawing and not hero.aim_held and not hero.touch_aim and is_equal_approx(hero.camera.fov,65),"Quick shot adds no draw state or aim zoom")
	check(is_equal_approx(hero.shot_cooldown,.42) and hero.last_pose=="release_walk","Quick shot has a responsive cooldown and keeps a moving release pose")
	check(releases.size()==1 and releases[0].quick and releases[0].key=="normal","Successful quick shot emits exactly one explicit release signal")
	hero._physics_process(.08)
	check(hero.last_pose=="release_walk" and hero.quick_release_left>0 and is_equal_approx(hero.camera.fov,65),"Walking cannot overwrite the release and quick shot still leaves the camera unzoomed")
	hero._fire()
	check(game.shots==shots_before+1 and releases.size()==1,"Releasing quick-shot input never fires twice")
	hero.shot_cooldown=0
	hero.quick_release_left=0
	hero._start_draw()
	hero.draw_elapsed=game.profile.draw_time()
	hero._fire()
	check(game.shots==shots_before+2 and releases.size()==2 and not releases[1].quick,"Charged shot still commits with its distinct release signal")
	game.arrows=0
	hero.shot_cooldown=0
	hero.instant_shoot()
	check(game.shots==shots_before+2 and releases.size()==2,"An empty quiver cannot fire or emit release VFX")

	print("PLAYER COMBAT MOTION: ","PASS" if failures.is_empty() else failures)
	game.stop_audio()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
