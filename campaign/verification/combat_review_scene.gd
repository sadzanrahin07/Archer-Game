extends Node
var game:Node3D
const OUTPUT="/Users/sadzanrahin/Documents/Codex/2026-10-13/i-x20/outputs/combat-fix-2026-10-23"
func _ready() -> void:run.call_deferred()
func capture(label:String) -> void:
 for frame in range(12):await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var picture:Image=get_viewport().get_texture().get_image()
 print("COMBAT REVIEW ",label," ",picture.save_png(OUTPUT+"/"+label+".png"))
func run() -> void:
 get_tree().root.size=Vector2i(1280,720)
 game=load("res://campaign/main.tscn").instantiate();game.test_mode=true;get_tree().root.add_child(game)
 await get_tree().process_frame
 game.profile.data.bow_level=100;game.profile.data.arrow_level=100;game.profile.data.character_level=100
 game.profile.data.trial_proofs={"55":true,"65":true,"75":true,"85":true,"95":true}
 game.profile.data.settings.touch_controls=true
 game.profile.data.power="ultimate"
 for id in [55,59,76,85,99]:
  game.start_stage(id,true);game.state="playing";game.hero.is_invulnerable=true
  await capture("native-stage-%03d"%(id+1))
 game.start_stage(55,true);game.state="playing";game.set_process(false)
 game.hero.set_physics_process(false);game.stage.process_mode=Node.PROCESS_MODE_DISABLED
 game.selected_power="ultimate";game.power_armed=true;game.hero.drawing=true;game.hero.aim_held=true;game.hero.draw_elapsed=game.profile.draw_time()
 game.hero._play_pose("draw");game.hero.anim_player.seek(game.hero.anim_player.get_animation("shared/draw").length,true)
 game.hero.skeleton.force_update_all_bone_transforms();game.hero._update_equipment()
 await capture("native-power-charge")
 game.hero.start_dodge();game.hero.anim_player.seek(game.hero.anim_player.get_animation("shared/dodge").length*.45,true)
 game.hero.skeleton.force_update_all_bone_transforms();game.hero._update_equipment()
 await capture("native-dodge-pose")
 game.stop_audio();game.queue_free();await get_tree().process_frame;get_tree().quit()
