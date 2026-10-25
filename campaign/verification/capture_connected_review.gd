extends SceneTree
var game:Node3D
func _init() -> void:
	run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	game=load("res://campaign/main.tscn").instantiate();game.test_mode=true;root.add_child(game)
	await process_frame
	game.profile.data.bow_level=100;game.profile.data.arrow_level=100;game.profile.data.character_level=100
	game.profile.data.trial_proofs={"55":true,"65":true,"75":true,"85":true,"95":true}
	game.profile.data.power="ultimate"
	for id in [0,38,55,75,99]:
		game.start_stage(id,true);game.state="playing"
		for frame in range(8):await process_frame
		await RenderingServer.frame_post_draw
		var image:Image=root.get_texture().get_image()
		var path:String="/Users/sadzanrahin/Documents/Codex/2026-10-13/i-x20/outputs/godot-upgrade-2026-10-22/review-stage-%03d.png"%(id+1)
		print("RENDERED ",path," status ",image.save_png(path))
	game.stop_audio();game.queue_free();await process_frame;quit()
