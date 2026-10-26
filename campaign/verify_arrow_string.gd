extends SceneTree
var game:Node
const POWERS=["normal","burst","gale","pressure","fire","lightning","super_lightning","ultimate"]
func _initialize():run.call_deferred()
func exercise(character:int,move:Vector2,running:bool,key:String) -> void:
 game.profile.data.character=character;game.profile.data.costume=2;game.profile.data.equipped_arrow=character%4
 game._spawn_hero();game.start_stage(5,true);game.ready_left=0;game.state="playing";game.arrows=10
 game.selected_power=key;game.power_armed=key!="normal"
 var p=game.hero;p.aim_held=false;p.touch_aim=false;p.drawing=true;p.draw_elapsed=game.profile.draw_time();p.shot_cooldown=0
 p.touch_move=move;p.touch_sprint=running
 for i in range(3):await physics_frame
 p._update_equipment()
 var nock:Vector3=p.nock_world
 var head:Vector3=p.arrow_tip_world
 assert(p.bow_arrow_node.visible,"Drawn arrow must remain visible inside the spiral")
 var nocked_mesh:MeshInstance3D=p.bow_arrow_node
 var nocked_tip:Vector3=nocked_mesh.to_global(Vector3(0,nocked_mesh.mesh.get_aabb().end.y,0))
 assert(nocked_tip.distance_to(head)<.001,"Charge effect and real arrow tip must agree")
 p._fire()
 var count:=0
 for child in game.stage.get_children():
  if child.get_script()==load("res://campaign/projectile.gd"):
   child.set_physics_process(false)
   var model:MeshInstance3D=child.get_node("ArrowModel")
   assert(model.visible,"Physical arrow must be visible for every power")
   assert(model.mesh==load(child.mesh_path),"Keep the equipped arrow model")
   var tip:Vector3=model.to_global(Vector3(0,model.mesh.get_aabb().end.y,0))
   var tail:Vector3=model.to_global(Vector3(0,model.mesh.get_aabb().position.y,0))
   assert(tip.distance_to(child.global_position)<.001,"Projectile collision point must match the visible arrowhead")
   if count==0:
    assert(tail.distance_to(nock)<.04,"Arrow must leave the nocked position without a jump")
    assert(tip.distance_to(head)<.04,"Arrowhead must hand off from bow to flight")
   count+=1
 assert(count==(3 if key=="burst" else 1))
 assert(not p.bow_arrow_node.visible,"Nocked arrow must hand off to the projectile immediately")
 for i in range(15):
  await physics_frame
  p._update_equipment()
  var finger:Vector3=p._bone_world(p.right_finger if p.right_finger>=0 else p.right_hand).origin
  assert(p.nock_world.distance_to(finger)<.001,"String contact must stay on the animated hand through release")
  assert(not p.bow_arrow_node.visible,"No duplicate nocked arrow during release")
 for i in range(45):await physics_frame
 p._update_equipment()
 assert(p.string_hand_blend<.001,"String must settle after the hand finishes releasing")
 assert(p.nock_world.distance_to(p.bow_hand_node.to_global(p.bow_string_rest))<.001)
 print("ARROW + HANDOFF + STRING CONTACT + REST PASS: ",character," / ",key," / ",move," / run=",running)
func run():
 game=load("res://campaign/main.tscn").instantiate();game.test_mode=true;game.profile.save_path="/tmp/archer_arrow_string_qa.json"
 root.add_child(game);await process_frame
 game.profile.data.purchased_powers=POWERS.duplicate()
 game.profile.data.owned_characters=[0,1,2,3];game.profile.data.owned_costumes=[0,1,2,3,4,5]
 for key in POWERS:await exercise(0,Vector2.ZERO,false,key)
 for character in range(4):
  for kind in range(3):await exercise(character,Vector2.ZERO if kind==0 else Vector2(.5,0),kind==2,"pressure")
 await create_timer(1.7).timeout
 game.stop_audio();game.queue_free();await process_frame;await process_frame
 print("ARROW AND BOWSTRING REGRESSION PASS");quit()
