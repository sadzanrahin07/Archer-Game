extends SceneTree

var game: Node

func _initialize():
	run.call_deferred()

func run():
	game = load("res://campaign/main.tscn").instantiate()
	root.size = Vector2i(640, 360)
	root.add_child(game)
	for i in range(12): await process_frame

	for stage_id in range(30):
		game.start_stage(stage_id, true)
		game.ui.visible = false
		if is_instance_valid(game.touch_layer): game.touch_layer.visible = false
		game.hero._play_pose("draw")
		for f in range(5): await process_frame
		await RenderingServer.frame_post_draw
		var img = root.get_texture().get_image()
		var out_path = "res://campaign/stages/previews/stage_%02d.png" % stage_id
		img.save_png(out_path)
		print("Generated: ", out_path)

	game.stop_audio()
	game.queue_free()
	await process_frame
	print("ALL 30 STAGE PREVIEWS GENERATED SUCCESSFULLY")
	quit(0)
