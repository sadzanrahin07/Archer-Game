extends SceneTree

var game: Node

func _initialize():
	run.call_deferred()

func run():
	game = load("res://campaign/main.tscn").instantiate()
	root.size = Vector2i(1280, 720)
	root.add_child(game)
	for i in range(12): await process_frame

	# 1. Capture Home
	game.show_home()
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://campaign/home-preview.png")

	# 2. Capture Store (Bows)
	game.show_store()
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://campaign/store-bows-preview.png")

	# 3. Capture Store (Archers)
	game.inventory_tab = "character"
	game.show_store()
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://campaign/store-archers-preview.png")

	# 4. Capture Collection
	game.inventory_tab = "bow"
	game.show_collection()
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://campaign/collection-preview.png")

	# 5. Capture Levels / Journey
	game.show_levels()
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://campaign/levels-preview.png")

	# 6. Capture Settings
	game.show_settings()
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://campaign/settings-preview.png")

	game.stop_audio()
	game.queue_free()
	await process_frame
	print("ALL CAPTURED")
	quit(0)
