extends SceneTree
# Run with the real project as --path and this absolute file as --script.
# Uses only /tmp/archer_result_regression_qa.json, never the player's profile.
const Profile=preload("res://campaign/profile.gd")
var game:Node
var qa_path:="/tmp/archer_result_regression_qa.json"
func _initialize() -> void:run.call_deferred()
func fresh():
	var p=Profile.new();p.save_path=qa_path
	p.data.settings.bg_sound=false;p.data.settings.game_sound=false
	return p
func start_playing(id:int=0) -> void:
	game.start_stage(id);game.ready_left=0;game.state="playing"
func wait_seconds(seconds:float):
	await create_timer(seconds,true).timeout
func run() -> void:
	game=load("res://campaign/main.tscn").instantiate()
	game.test_mode=true;game.profile=fresh();root.add_child(game)
	await process_frame
	game.test_mode=false
	# A failure's delay freezes with Pause, then delivers exactly once on Resume.
	start_playing()
	game.finish(false,"Regression failure")
	assert(game.state=="finishing")
	game.show_pause()
	await wait_seconds(0.80)
	assert(game.state=="paused" and not game.pending_result.is_empty())
	game.resume_game()
	assert(game.state=="finishing")
	await wait_seconds(0.80)
	assert(game.state=="results" and game.pending_result.is_empty())
	print("FAILURE PAUSE TIMER PASS")
	# Explicit Restart is different from Resume: it resets the active chapter cursor.
	game.show_home();game.profile=fresh()
	game.profile.start_run(0)
	for stage in range(2):game.profile.reward(stage,2,0.8,4.0,game.profile.current_run_transaction())
	assert(game.profile.run_selected_stage()==2)
	start_playing(2);game.show_pause();game.menu_builder._retry_level()
	assert(game.selected_stage==0 and game.profile.run_selected_stage()==0 and game.state=="ready")
	print("EXPLICIT CHAPTER RESTART PASS")
	# Power requirements belong to the resolved resumed stage, not the requested Stage1.
	game.show_home();game.profile=fresh()
	game.profile.start_run(0)
	for stage in range(2):game.profile.reward(stage,2,0.8,4.0,game.profile.current_run_transaction())
	var old0:Variant=game.definitions[0].get("required_power",0)
	var old2:Variant=game.definitions[2].get("required_power",0)
	game.definitions[0].required_power=0;game.definitions[2].required_power=9999
	game.start_stage(0)
	assert(game.page=="levels" and game.state=="menu" and game.profile.run_selected_stage()==2)
	game.definitions[0].required_power=old0;game.definitions[2].required_power=old2
	print("RESUMED STAGE LOADOUT GATE PASS")
	# Practice must leave the persisted campaign Continue cursor and active run alone.
	game.show_home();game.profile=fresh()
	game.profile.data.selected=5;game.profile.data.unlocked=5
	for stage in range(5):game.profile.data.stars[str(stage)]=1
	assert(game.profile.data.chapter_run.is_empty())
	game.start_stage(0,true)
	assert(game.selected_stage==0 and game.practice)
	assert(game.profile.data.selected==5 and game.profile.data.chapter_run.is_empty())
	game.show_home();assert(game.selected_stage==5)
	print("PRACTICE CAMPAIGN CURSOR PASS")
	# Going through Settings while paused must retain the pending cinematic state.
	game.profile=fresh();start_playing()
	game.shots=1;game.hits=1;game.precision_sum=1
	game.finish(true,"Regression final impact")
	game.show_pause();game.show_settings();game.show_pause()
	assert(game.prior_pause_state=="finishing")
	await wait_seconds(1.40)
	assert(game.state=="paused" and not game.pending_result.is_empty())
	game.resume_game();assert(game.state=="finishing")
	await wait_seconds(0.70);assert(game.state=="finishing")
	await wait_seconds(0.70);assert(game.state=="results")
	print("FINISHING PAUSE SETTINGS RESUME PASS")
	# A canceled failure timer cannot open a later success's results early.
	game.show_home();start_playing();game.finish(false,"Old canceled failure")
	game.show_home();start_playing();game.shots=1;game.hits=1;game.precision_sum=1
	game.finish(true,"New success")
	await wait_seconds(0.80)
	assert(game.state=="finishing" and not game.pending_result.is_empty())
	await wait_seconds(0.60)
	assert(game.state=="results" and game.last_result.reason=="New success")
	print("STALE RESULT TIMER GUARD PASS")
	game.show_home();game.stop_audio();await wait_seconds(0.30)
	game.queue_free();await process_frame;await process_frame;await wait_seconds(0.15)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(qa_path+suffix):DirAccess.remove_absolute(qa_path+suffix)
	print("RESULT AND RUN REGRESSION PASS")
	quit()
