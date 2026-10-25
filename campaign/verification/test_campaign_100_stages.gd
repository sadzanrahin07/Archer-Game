extends SceneTree

const ProfileScript = preload("res://campaign/profile.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("=== STARTING 100-STAGE CAMPAIGN VERIFICATION (PHASE 7) ===")
	var failed := false

	var stages_file = FileAccess.open("res://campaign/stages.json", FileAccess.READ)
	if stages_file == null:
		printerr("FAIL: Unable to open res://campaign/stages.json"); quit(1); return
	
	var stages = JSON.parse_string(stages_file.get_as_text())
	if typeof(stages) != TYPE_ARRAY:
		printerr("FAIL: stages.json is not an array"); quit(1); return

	if stages.size() != 100:
		printerr("FAIL: Expected 100 stages, found: ", stages.size()); failed = true

	var seen_ids := {}
	var chapters := {}

	for s in stages:
		var sid = int(s.get("id", -1))
		if sid < 0 or sid > 99:
			printerr("FAIL: Invalid stage ID: ", sid); failed = true
		if seen_ids.has(sid):
			printerr("FAIL: Duplicate stage ID: ", sid); failed = true
		seen_ids[sid] = true

		var cnum = int(s.get("chapter_number", sid / 5 + 1))
		chapters[cnum] = int(chapters.get(cnum, 0)) + 1

		# Verify stage name and scene description exist
		var sname: String = str(s.get("name", ""))
		if sname.is_empty():
			printerr("FAIL: Stage %d missing name" % sid); failed = true
		var sdesc: String = str(s.get("scene_desc", ""))
		if sdesc.is_empty():
			printerr("FAIL: Stage %d missing scene_desc" % sid); failed = true

		# Early-game guarantee: no combat in IDs 0–54
		if sid < 55:
			var mode: String = str(s.get("mode", ""))
			if mode == "combat":
				printerr("FAIL: Stage %d (below 55) must NOT have combat mode! Got: %s" % [sid, mode]); failed = true

	# Check 20 chapters x 5 stages
	if chapters.size() != 20:
		printerr("FAIL: Expected 20 chapters, got: ", chapters.size()); failed = true
	for c in range(1, 21):
		if int(chapters.get(c, 0)) != 5:
			printerr("FAIL: Chapter %d has %d stages, expected 5" % [c, int(chapters.get(c, 0))]); failed = true

	# Verify Stage 55 gate with M59
	var profile = ProfileScript.new()
	profile.save_path="/tmp/arrowglade-legacy-test_campaign_100_stages.json" # Isolated; never read or write the player save.
	profile.data.stars = {}
	for i in range(55): profile.data.stars[str(i)] = 1
	profile.data.bow_level = 59
	profile.data.arrow_level = 59
	profile.data.character_level = 59

	if profile.stage_ready(55):
		printerr("FAIL: Stage 55 ready at M59"); failed = true
	var reason = profile.get_stage_lock_reason(55)
	if not reason.contains("Mastery 60"):
		printerr("FAIL: Stage 55 lock reason must mention Mastery 60, got: ", reason); failed = true

	# Check Chapter 20 Stage 5 (ID 99) Hollow Crown
	for i in range(99): profile.data.stars[str(i)] = 1
	profile.data.bow_level = 99
	profile.data.arrow_level = 100
	profile.data.character_level = 100
	if profile.stage_ready(99):
		printerr("FAIL: Final battle (Stage 99) should be blocked when Bow is 99"); failed = true
	var h_reason = profile.get_stage_lock_reason(99)
	if not h_reason.contains("Level 100"):
		printerr("FAIL: Stage 99 lock reason must mention Level 100, got: ", h_reason); failed = true

	profile.data.bow_level = 100
	if not profile.stage_ready(99):
		printerr("FAIL: Stage 99 should be ready when B=A=C=100"); failed = true

	print("PASS: All 100 stages verified: unique IDs 0–99, 20 chapters x 5, early-game guarantee (0-54 pure archery), and strict trial gates.")

	if failed:
		printerr("
>>> 100-STAGE CAMPAIGN VERIFICATION FAILED <<<")
		quit(1)
	else:
		print("
>>> ALL 100-STAGE CAMPAIGN TESTS PASSED SUCCESSFULLY! <<<")
		quit(0)
