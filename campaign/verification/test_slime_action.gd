extends SceneTree
# Real collision-world regression checks for the two committed slime jump attacks.
const Moss=preload("res://campaign/combat/moss_slime.gd")
const Briar=preload("res://campaign/combat/briar_slime.gd")
const Director=preload("res://campaign/combat/threat_director.gd")

class GameHarness extends Node3D:
	var state:="playing"
	func is_playing() -> bool:return state=="playing"
	func play_sound(_path:String,_pitch:float=1.0,_volume:float=0) -> void:pass
	func target_scored(_score:int,_damage:float,_enemy:bool) -> void:pass

class HeroHarness extends CharacterBody3D:
	var game:Node
	var current_hp:=160.0
	var damage_events:=0
	var is_invulnerable:=false
	func take_player_damage(damage:float,_source:Node) -> void:
		if not game.is_playing() or is_invulnerable:return
		current_hp-=damage;damage_events+=1

var failures:Array[String]=[]
var game:GameHarness
var hero:HeroHarness
var director:RefCounted
var origin:=Vector3(0,.02,-3)
var goal:=Vector3(0,.02,0)

func _init() -> void:run.call_deferred()
func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error(message)

func spawn_slime(script:Script) -> Node:
	hero.global_position=goal;hero.current_hp=160;hero.damage_events=0;hero.is_invulnerable=false
	game.state="playing";director.clear()
	var enemy=script.new();enemy.game=game;enemy.target_player=hero;enemy.threat_director=director
	enemy.position=origin;game.add_child(enemy);enemy.set_physics_process(false)
	await physics_frame
	return enemy

func begin(enemy:Node) -> void:
	enemy._commit_attack();enemy._physics_process(enemy.windup_time+.001)
	check(enemy.current_state==enemy.State.ATTACK,"Windup must enter the leap state")

func land(enemy:Node) -> void:
	for i in range(300):
		enemy._physics_process(.01)
		if enemy.current_state!=enemy.State.ATTACK:return
	check(false,"A slime must finish its jump or terrain recovery within three seconds")

func clear_enemy(enemy:Node) -> void:
	enemy.queue_free();await process_frame;await physics_frame

func run() -> void:
	game=GameHarness.new();root.add_child(game);director=Director.new()
	var floor_body:=StaticBody3D.new();floor_body.collision_layer=1;floor_body.collision_mask=0
	var floor_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new();floor_box.size=Vector3(40,1,40)
	floor_shape.shape=floor_box;floor_shape.position.y=-.5;floor_body.add_child(floor_shape);game.add_child(floor_body)
	hero=HeroHarness.new();hero.game=game;hero.collision_layer=2;hero.collision_mask=1
	var hero_shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.6
	hero_shape.shape=capsule;hero_shape.position.y=.8;hero.add_child(hero_shape);game.add_child(hero)
	await physics_frame;await physics_frame

	# The visible warning belongs to the committed destination, not the moving attacker.
	var enemy=await spawn_slime(Moss)
	enemy._commit_attack()
	var marker:Vector3=enemy.telegraph_mesh.global_position
	check(marker.distance_to(goal+Vector3.UP*.025)<.03,"Landing marker must be centered on the committed destination")
	check(is_equal_approx(enemy.telegraph_mesh.mesh.outer_radius,enemy.leap_hit_radius),"Marker edge must match the damaging landing radius")
	hero.global_position+=Vector3(4,0,0);enemy._physics_process(.2);enemy._physics_process(.001)
	check(enemy.telegraph_mesh.global_position==marker and enemy.committed_target.distance_to(goal)<.01,"Windup cannot track the player's later movement")
	check(enemy.body_mesh.scale.y<.95,"Windup visibly compresses the slime before launching")
	enemy._physics_process(1);land(enemy)
	check(hero.damage_events==0,"Leaving the committed landing circle avoids the attack")
	check(Vector2(enemy.global_position.x-goal.x,enemy.global_position.z-goal.z).length()<.15,"Dodged slime lands at its committed location")
	await clear_enemy(enemy)

	# The player body must not stop the leap short; exactly one impact deals damage.
	enemy=await spawn_slime(Moss);begin(enemy)
	enemy._physics_process(.18)
	check(enemy.global_position.y>.3 and not enemy.attack_delivered,"A slime travels through a real airborne arc before its impact")
	check(hero.damage_events==0,"No damage is applied while the slime is airborne")
	land(enemy)
	check(enemy.current_state==enemy.State.RECOVER and enemy.attack_delivered,"Ground impact enters the punishable recovery state")
	check(hero.damage_events==1 and hero.current_hp==148,"A landed Moss attack delivers its authored 12 damage once")
	check(enemy.global_position.distance_to(goal)<.16,"Player collision cannot stop the attack remotely before its destination")
	check(enemy.collision_mask==3 and not enemy.telegraph_mesh.visible,"Landing restores normal body collision and clears its warning")
	enemy._physics_process(.001)
	check(enemy.body_mesh.scale.y<.8,"Landing visibly compresses the slime on impact")
	for i in range(45):enemy._physics_process(.01)
	check(absf(enemy.body_mesh.scale.y-1)<.04 and hero.damage_events==1,"Recovery settles naturally without repeating landing damage")
	await clear_enemy(enemy)

	# Dodge invulnerability still wins when the hero remains inside the landing circle.
	enemy=await spawn_slime(Briar);begin(enemy);hero.is_invulnerable=true;land(enemy)
	check(enemy.attack_delivered and hero.damage_events==0,"Dodge invulnerability avoids an otherwise valid Briar landing")
	await clear_enemy(enemy)

	# Pausing freezes the arc, timing, marker and body pose together.
	enemy=await spawn_slime(Briar);begin(enemy);enemy._physics_process(.15)
	game.state="paused"
	var before_pos:Vector3=enemy.global_position;var before_timer:float=enemy.state_timer
	var before_scale:Vector3=enemy.body_mesh.scale;var before_marker:Vector3=enemy.telegraph_mesh.global_position
	enemy._physics_process(1)
	check(enemy.global_position==before_pos and enemy.state_timer==before_timer,"Pause freezes slime collision movement and attack timing")
	check(enemy.body_mesh.scale==before_scale and enemy.telegraph_mesh.global_position==before_marker and hero.damage_events==0,"Pause freezes combat presentation and prevents damage")
	game.state="playing";land(enemy)
	check(enemy.attack_delivered and hero.damage_events==1,"A paused attack resumes once and lands normally")
	await clear_enemy(enemy)

	# Static terrain intercepts the swept arc; it never authorizes damage behind a wall.
	enemy=await spawn_slime(Briar)
	var wall:=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
	var wall_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(5,4,.35)
	wall_shape.shape=box;wall_shape.position=Vector3(0,2,-1.5);wall.add_child(wall_shape);game.add_child(wall)
	await physics_frame;await physics_frame
	begin(enemy);land(enemy)
	check(enemy.leap_blocked and enemy.global_position.z< -1.5,"A real terrain wall stops the swept leap on the attacker's side")
	check(hero.damage_events==0,"A blocked landing cannot damage the hero behind terrain")
	check(enemy.current_state==enemy.State.RECOVER and not enemy.telegraph_mesh.visible,"A blocked attack finishes in recovery without leaving a warning")
	await clear_enemy(enemy);wall.queue_free();await process_frame;await physics_frame

	# Timer expiry or old committed coordinates cannot create a remote hit.
	enemy=await spawn_slime(Moss);enemy.committed_target=goal
	enemy._deliver_attack()
	check(hero.damage_events==0,"A committed destination alone never permits remote melee damage")
	enemy.global_position=Vector3(0,2.5,0);enemy._deliver_attack()
	check(hero.damage_events==0,"A slime above the hero cannot cause a false grounded impact")
	await clear_enemy(enemy)

	# Death cancels pending attack movement and the destination marker immediately.
	enemy=await spawn_slime(Briar);begin(enemy);enemy._physics_process(.1)
	enemy._die();enemy._physics_process(1)
	check(enemy.current_state==enemy.State.DEAD and not enemy.telegraph_mesh.visible and not enemy.leap_active,"Death cancels an airborne attack and its warning")
	check(hero.damage_events==0 and enemy.collision_layer==0,"An interrupted slime cannot land a post-death hit")
	print("SLIME ACTION CHECKS: ","PASS" if failures.is_empty() else failures)
	game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
