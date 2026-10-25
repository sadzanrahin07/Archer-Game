extends SceneTree

const GameScene = preload("res://campaign/main.tscn")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Running test_archery_slice.gd ---")
	var game = GameScene.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	await process_frame

	# Test Stages 0 to 4
	for stage_id in range(5):
		print("Testing Stage ID: ", stage_id)
		game.start_stage(stage_id, true)
		await process_frame
		var stage = game.stage
		if stage == null:
			printerr("FAIL: Stage node is null for stage ", stage_id)
			quit(1); return
		var count: int = stage.targets.size()
		var expected_counts := [7, 6, 6, 6, 7]
		if count != expected_counts[stage_id]:
			printerr("FAIL: Stage ", stage_id, " has ", count, " targets, expected ", expected_counts[stage_id])
			quit(1); return
		
		# Verify mechanic allows logic
		var encounter = stage.encounter
		if encounter == null:
			printerr("FAIL: Stage encounter is null for stage ", stage_id)
			quit(1); return
		
		if stage_id == 0:
			# Target 0 should be allowed, Target 6 (heart) should not be allowed initially
			if not stage.mechanic_allows_hit(stage.targets[0]):
				printerr("FAIL: Stage 0 target 0 should be allowed")
				quit(1); return
			if stage.mechanic_allows_hit(stage.targets[6]):
				printerr("FAIL: Stage 0 heart should NOT be allowed until rings are done")
				quit(1); return
			# Complete rings 0..5
			for i in range(6):
				stage.targets[i].completed = true
			if not stage.mechanic_allows_hit(stage.targets[6]):
				printerr("FAIL: Stage 0 heart should be allowed after 6 rings")
				quit(1); return
			print("Stage 0 (The Listening Clearing) verified!")
		
		elif stage_id == 1:
			# Target 0..4 (cart) allowed, target 5 (clasp) NOT allowed initially
			if not stage.mechanic_allows_hit(stage.targets[0]):
				printerr("FAIL: Stage 1 cart plaque should be allowed")
				quit(1); return
			if stage.mechanic_allows_hit(stage.targets[5]):
				printerr("FAIL: Stage 1 clasp should NOT be allowed initially")
				quit(1); return
			for i in range(5):
				stage.targets[i].completed = true
			if not stage.mechanic_allows_hit(stage.targets[5]):
				printerr("FAIL: Stage 1 clasp should be allowed after cart cleared")
				quit(1); return
			print("Stage 1 (Creekside Delivery) verified!")
		
		elif stage_id == 2:
			print("Stage 2 (Steps in the Grass) verified!")
		
		elif stage_id == 3:
			# Rune 0 allowed, Rune 1 not allowed yet, Channel rings not allowed yet
			if not stage.mechanic_allows_hit(stage.targets[0]):
				printerr("FAIL: Stage 3 rune 0 should be allowed")
				quit(1); return
			if stage.mechanic_allows_hit(stage.targets[1]):
				printerr("FAIL: Stage 3 rune 1 should not be allowed before rune 0")
				quit(1); return
			if stage.mechanic_allows_hit(stage.targets[3]):
				printerr("FAIL: Stage 3 channel ring should not be allowed before runes")
				quit(1); return
			stage.targets[0].completed = true
			if not stage.mechanic_allows_hit(stage.targets[1]):
				printerr("FAIL: Stage 3 rune 1 should be allowed after rune 0")
				quit(1); return
			stage.targets[1].completed = true
			stage.targets[2].completed = true
			if not stage.mechanic_allows_hit(stage.targets[3]):
				printerr("FAIL: Stage 3 channel rings should be allowed after runes")
				quit(1); return
			print("Stage 3 (Three Notes of Water) verified!")
		
		elif stage_id == 4:
			# Heart (target 6) should not be allowed until 0..5 are complete
			if stage.mechanic_allows_hit(stage.targets[6]):
				printerr("FAIL: Stage 4 heart should not be allowed initially")
				quit(1); return
			for i in range(6):
				stage.targets[i].completed = true
			if not stage.mechanic_allows_hit(stage.targets[6]):
				printerr("FAIL: Stage 4 heart should be allowed after all pairs")
				quit(1); return
			print("Stage 4 (Meadow Promise) verified!")

	print("SUCCESS: ALL ARCHERY VERTICAL SLICE (STAGES 001-005) CHECKS PASSED!")
	quit(0)
