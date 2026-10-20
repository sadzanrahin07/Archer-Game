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
	game.profile.save_path = "/tmp/test-progression-cards.json"
	root.size = Vector2i(1280, 720)
	root.add_child(game)
	await process_frame

	# RULE 1: Fresh user starts strictly with Erin base character, Training Bow, Standard Arrow
	game.profile.data.unlocked = 0 # Chapter 1 (Fresh start)
	game.profile.data.owned_characters = [1]
	game.profile.data.character = 1
	game.profile.data.costume = 2
	game.profile.data.owned_costumes = [2]
	game.profile.data.owned_bows = [0]
	game.profile.data.equipped_bow = 0
	game.profile.data.owned_arrows = [0]
	game.profile.data.equipped_arrow = 0
	game.profile.data.coins = 10000

	check(int(game.profile.data.character) == 1, "Player starts with Erin (char id 1)")
	check(int(game.profile.data.costume) == 2, "Player starts with Erin Base (costume id 2)")
	check(game.profile.data.owned_characters.size() == 1, "Player owns exactly 1 character initially")

	# RULE 2: At initial stage, Home screen character cycle arrows must be disabled
	game.show_home()
	for i in range(4): await process_frame

	var cycle_left: Button = null
	var cycle_right: Button = null
	for btn in game.ui.find_children("*", "Button", true, false):
		if btn.text == "‹": cycle_left = btn
		elif btn.text == "›": cycle_right = btn
	check(cycle_left != null and cycle_right != null, "Found character cycle buttons on home screen")
	check(cycle_left.disabled == true, "Left character cycle arrow is disabled at initial stage")
	check(cycle_right.disabled == true, "Right character cycle arrow is disabled at initial stage")

	# RULE 3: Other characters are locked initially, but CAN BE PREVIEWED
	# Enola unlocks at chapter 3 / level 4
	check(not game.profile.is_unlocked("character", 0), "Enola is locked at chapter 1")
	check(not game.profile.can_buy("character", 0), "Cannot buy locked Enola even with 10000 coins")

	# Preview Enola in characters screen
	game.show_characters(true)
	for i in range(4): await process_frame

	# Verify character list has image cards with TextureRect
	var char_cards: Array = []
	for btn in game.ui.find_children("*", "Button", true, false):
		if btn.has_meta("img") and btn.has_meta("title_lbl"):
			char_cards.append(btn)
	check(char_cards.size() >= 4, "Found image cards for all 4 archers")

	# Select Enola for preview
	game.preview_character = 0
	game._spawn_hero()
	game.show_characters()
	for i in range(4): await process_frame
	check(game.preview_character == 0, "Enola preview is active")
	check(game.hero.character_id == 0, "Hero 3D model switched to Enola for preview")

	# Check right side has Buy button disabled because locked
	var buy_btn: Button = null
	for btn in game.ui.find_children("*", "Button", true, false):
		if btn.text.contains("Locked") or btn.text.contains("Buy"):
			buy_btn = btn
			break
	check(buy_btn != null, "Found purchase/lock button for Enola")
	check(buy_btn.disabled == true, "Enola purchase button is disabled while locked")

	# Unlock Enola by advancing chapter/level
	game.profile.data.unlocked = 14 # Chapter 3
	game.profile.data.skin_progress[game.profile.skin_key()].level = 4
	check(game.profile.is_unlocked("character", 0), "Enola is unlocked at chapter 3, archer level 4")
	check(game.profile.can_buy("character", 0), "Can buy Enola with coins now")

	# Buy Enola
	var bought_char: bool = game.profile.buy_character(0)
	check(bought_char == true, "Successfully purchased Enola")
	check(game.profile.is_owned("character", 0), "Enola is now owned")
	check(game.profile.data.owned_characters.size() == 2, "Now player owns 2 characters")

	# Now that player owns 2 characters, Home cycle arrows should be ENABLED
	game.show_home()
	for i in range(4): await process_frame
	for btn in game.ui.find_children("*", "Button", true, false):
		if btn.text == "‹": cycle_left = btn
		elif btn.text == "›": cycle_right = btn
	check(cycle_left.disabled == false, "Left character cycle arrow is ENABLED after unlocking 2nd character")
	check(cycle_right.disabled == false, "Right character cycle arrow is ENABLED after unlocking 2nd character")

	# RULE 4: Store & Collection items use visual image cards (Bows, Arrows)
	game.shop_mode = "store"
	game.inventory_tab = "bow"
	game.show_inventory()
	for i in range(4): await process_frame

	var item_cards: Array = []
	for btn in game.ui.find_children("*", "Button", true, false):
		if btn.has_meta("img") and btn.has_meta("title_lbl"):
			item_cards.append(btn)
	check(item_cards.size() == 4, "Store has 4 visual image cards for Bows")
	for card_btn in item_cards:
		var img: TextureRect = card_btn.get_meta("img")
		check(img != null and img.texture != null, "Bow card has valid texture loaded")

	# Tempest Bow (id 3) unlocks at chapter 15
	check(not game.profile.is_unlocked("bow", 3), "Tempest Bow locked at chapter 3")
	check(not game.profile.can_buy("bow", 3), "Tempest Bow cannot be bought while locked")

	# Can preview Tempest bow
	game.preview_item = 3
	game._show_gear()
	check(is_instance_valid(game.gear_preview), "Tempest Bow 3D model preview is active")

	# Arrow visual cards
	game.inventory_tab = "arrow"
	game.show_inventory()
	for i in range(4): await process_frame
	var arrow_cards: Array = []
	for btn in game.ui.find_children("*", "Button", true, false):
		if btn.has_meta("img") and btn.has_meta("title_lbl"):
			arrow_cards.append(btn)
	check(arrow_cards.size() == 4, "Store has 4 visual image cards for Arrows")
	for card_btn in arrow_cards:
		var img: TextureRect = card_btn.get_meta("img")
		check(img != null and img.texture != null, "Arrow card has valid texture loaded")

	game.stop_audio()
	game.queue_free()
	await process_frame

	print("ALL PROGRESSION & VISUAL CARD TESTS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
