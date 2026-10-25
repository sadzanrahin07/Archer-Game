extends Node
const OUTPUT="/Users/sadzanrahin/Documents/Codex/2026-10-13/i-x20/outputs/combat-fix-2026-10-24"
var game:Node3D
func _ready() -> void:run.call_deferred()
func capture(label:String) -> void:
 for frame in range(10):await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var picture:Image=get_viewport().get_texture().get_image()
 print("NATIVE V4 ",label," ",picture.save_png(OUTPUT+"/"+label+".png"))
func step(frames:int) -> void:
 for frame in range(frames):
  await get_tree().physics_frame
  game.hero._physics_process(1.0/60)
func run() -> void:
 get_tree().root.size=Vector2i(1280,720)
 game=load("res://campaign/main.tscn").instantiate();game.test_mode=true;get_tree().root.add_child(game)
 await get_tree().process_frame
 game.profile.data.bow_level=100;game.profile.data.arrow_level=100;game.profile.data.character_level=100
 game.profile.data.trial_proofs={"55":true,"65":true,"75":true,"85":true,"95":true}
 game.profile.data.settings.touch_controls=true;game.profile.data.power="ultimate"
 game.start_stage(99,true);game.state="playing";game.set_process(false)
 game.hero.set_physics_process(false);game.stage.combat_manager.set_physics_process(false)
 var boss=game.stage.combat_manager.boss;boss.set_physics_process(false)
 await step(8)
 boss.hp=boss.GATE_10;boss._enter_state(boss.State.FINAL_OPEN)
 await capture("native-v4-final-core")
 game.begin_power_charge("ultimate","review")
 await step(ceili(game.profile.draw_time()*60)+1)
 await capture("native-v4-aurora-ready")
 game.end_power_charge("review")
 await capture("native-v4-power-release")
 game.hero.shot_cooldown=0;game.hero.cancel_draw();game.power_armed=false
 game.hero.request_jump();await step(10)
 await capture("native-v4-jump")
 await step(60)
 game.arrows=0;game.touch_controller.move_vector=Vector2(0,-1);game.hero.touch_move=Vector2(0,-1)
 await step(18)
 await capture("native-v4-empty-walk")
 game.stop_audio();game.queue_free();await get_tree().process_frame;get_tree().quit()
