extends SceneTree
var game: Node
var failures: Array[String] = []

func _initialize():
	run.call_deferred()

func check(ok: bool, msg: String):
	if not ok:
		failures.append(msg)
		push_error("FAIL: " + msg)

func run():
	game = load("res://campaign/main.tscn").instantiate()
	game.test_mode = true
	game.profile.save_path = "/tmp/test-store-controls.json"
	root.size = Vector2i(1280, 720)
	root.add_child(game)
	await process_frame

	# 1. TEST STORE & COLLECTION SEPARATION AND UNLOCKED PURCHASES
	game.profile.data.unlocked = 14 # Chapter 3
	game.profile.data.coins = 5000
	game.shop_mode = "store"
	game.inventory_tab = "bow"
	game.show_inventory()
	for i in range(4): await process_frame

	# Elven Bow (id 1, unlocks at chapter 3, cost 1200)
	check(game.profile.is_unlocked("bow", 1), "Elven Bow is unlocked at chapter 3")
	check(game.profile.can_buy("bow", 1), "Can buy Elven Bow with 5000 coins")

	# Select item in-place without rebuilding scroll container
	var scroll: ScrollContainer = null
	for sc in game.ui.find_children("*", "ScrollContainer", true, false):
		if sc.has_meta("is_items_scroll") or sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			scroll = sc
			break
	check(scroll != null, "Found items ScrollContainer")
	var scroll_instance_id := scroll.get_instance_id()

	# Select bow 1
	game.preview_item = 1
	var tiles: Dictionary = {}
	# Buy Elven bow
	var initial_coins: int = game.profile.data.coins
	var bought: bool = game.profile.buy_equipment("bow", 1)
	check(bought, "Successfully purchased Elven Bow")
	check(game.profile.data.coins == initial_coins - 1200, "Coins deducted correctly")
	check(game.profile.is_owned("bow", 1), "Elven Bow is owned")

	# Verify collection only shows owned items
	game.shop_mode = "collection"
	game.show_inventory()
	for i in range(4): await process_frame
	for sc in game.ui.find_children("*", "ScrollContainer", true, false):
		if sc.has_meta("is_items_scroll") or sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			scroll = sc
			break
	var owned_bow_count := 0
	for child in scroll.get_child(0).get_children():
		if child is Button: owned_bow_count += 1
	check(owned_bow_count == game.profile.data.owned_bows.size(), "Collection shows exact owned count")

	# 2. TEST TOUCH CONTROLS ON BOTH SIDES & NO DEAD ZONES
	game.profile.data.settings.touch_controls = true
	game.start_stage(10)
	game.state = "playing"
	for i in range(6): await process_frame

	var touch = game.touch_controller
	var geo: Dictionary = touch.geometry()

	# Test touch look on far left side (e.g. x=250, y=300)
	touch.contact(90, Vector2(250, 300), true)
	check(touch.roles.get(90) == "look", "Far left look works")
	touch.contact(90, Vector2(250, 300), false)

	# Test touch look on lower left side (e.g. x=250, y=550) - was previously dead zone!
	touch.contact(91, Vector2(250, 550), true)
	check(touch.roles.get(91) == "look", "Lower left look works (dead zone eliminated)")
	touch.contact(91, Vector2(250, 550), false)

	# Test touch look on mid-right side
	touch.contact(92, Vector2(900, 350), true)
	check(touch.roles.get(92) == "look", "Right look works")
	touch.contact(92, Vector2(900, 350), false)

	# Test AIM button & arrow visibility
	touch.contact(93, geo.aim, true)
	check(touch.aim == true, "AIM button toggled on")
	touch._process(0)
	check(game.hero.touch_aim == true, "Hero touch_aim is true")
	for i in range(2): await process_frame
	check(game.hero.bow_arrow_node.visible == true, "Arrow is visible when AIM is active")
	touch.contact(93, geo.aim, false)

	# Test Instant Shoot button
	var shots_before: int = game.shots
	touch.contact(94, geo.draw, true)
	check(game.shots == shots_before + 1, "Shoot button fires instantly on contact")
	touch.contact(94, geo.draw, false)

	# 3. TEST DAMAGE ZONES & ROCK STREAK
	var stone = game.stage.targets[game.stage.targets.size() - 1]
	check(stone.material_kind in ["stone", "rune", "master"], "Stage 10 has stone rock target")
	var pwr: float = game.current_definition.recommended_power
	var c_pos: Vector3 = stone.global_position + Vector3(0, 0, 0.1)

	# Hit 1 & 2 survive
	stone.campaign_hit(c_pos, pwr, {"shot_id": 991})
	check(not stone.completed, "Rock survives hit 1")
	stone.campaign_hit(c_pos, pwr, {"shot_id": 992})
	check(not stone.completed, "Rock survives hit 2")
	# Hit 3 center destroys
	stone.campaign_hit(c_pos, pwr, {"shot_id": 993})
	check(stone.completed, "Rock destroyed on 3rd consecutive center hit")

	game.stop_audio()
	game.queue_free()
	await process_frame

	print("ALL STORE, CONTROLS, AND GAMEPLAY TESTS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
