extends SceneTree
const Profile=preload("res://campaign/profile.gd")
var game:Node
var failures:Array[String]=[]
func _initialize():run.call_deferred()
func check(condition:bool,message:String) -> void:
	if not condition:failures.append(message);push_error(message)
func run():
	game=load("res://campaign/main.tscn").instantiate();game.test_mode=true
	game.profile=Profile.new();game.profile.save_path="/tmp/archer_landscape_qa.json"
	game.profile.data.coins=120
	root.add_child(game)
	for entry in [[Vector2i(1280,720),false],[Vector2i(640,360),false],[Vector2i(1024,768),false],[Vector2i(2560,1080),false],[Vector2i(844,390),true],[Vector2i(932,430),true],[Vector2i(1366,1024),true],[Vector2i(800,600),true]]:
		root.size=entry[0];game.profile.data.settings.touch_controls=entry[1]
		game._refresh_layout();await process_frame;await process_frame
		for page_name in ["home","characters","levels","inventory","settings"]:
			match page_name:
				"home":game.show_home()
				"characters":game.show_characters()
				"levels":game.show_levels()
				"inventory":game.inventory_tab="bow";game.show_inventory()
				"settings":game.show_settings()
			for frame in range(6):await process_frame
			audit(page_name,str(entry[0]));check(not game.menu_builder.portrait,"UI must retain landscape composition")
		game.start_stage(0,true);game.state="playing"
		for frame in range(6):await process_frame
		audit("hud",str(entry[0]))
		if entry[1]:
			var geo:Dictionary=game.touch_controller.geometry()
			for key in ["stick","draw","aim","run","jump"]:
				check(Rect2(Vector2.ZERO,game.ui.size).has_point(geo[key]),"Touch control outside landscape viewport: "+key)
		var prior_bow:int=game.profile.data.bow_level;var prior_arrow:int=game.profile.data.arrow_level
		game.profile.data.bow_level=60;game.profile.data.arrow_level=60
		game.start_stage(59,true);game.state="playing"
		check(game.is_combat(),"Combat HUD fixture meets its mastery entry requirement")
		for frame in range(6):await process_frame
		audit("combat hud",str(entry[0]))
		check(not game.hud_ammo.is_visible_in_tree(),"Combat legacy information card is hidden")
		if entry[1]:
			var combat_geo:Dictionary=game.touch_controller.geometry()
			for key in ["stick","draw","aim","run","dodge","jump"]:
				check(Rect2(Vector2.ZERO,game.ui.size).has_point(combat_geo[key]),"Combat control outside landscape viewport: "+key)
		game.show_pause();for frame in range(6):await process_frame
		audit("pause",str(entry[0]))
		game.resume_game();game.state="playing";game.finish(false,"Time expired")
		await create_timer(2.6).timeout
		for frame in range(8):await process_frame
		audit("results",str(entry[0]))
		game.profile.data.bow_level=prior_bow;game.profile.data.arrow_level=prior_arrow
		print("LANDSCAPE LAYOUT CHECK ",entry[0]," touch=",entry[1])
	root.size=Vector2i(844,390);game.profile.data.settings.touch_controls=true;game.show_home();game._refresh_layout()
	game.profile.data.owned_characters=[0,1,2,3];game.profile.data.owned_costumes=[0,1,2,3,4,5]
	game.profile.data.owned_bows=[0,1,2,3];game.profile.data.owned_arrows=[0,1,2,3];game.profile.data.coins=999999
	for character in range(4):
		game._choose_character(character)
		for frame in range(8):await process_frame
		audit("character "+str(character),"844x390")
		check(game.profile.data.character==character,"Each separate character must be selectable")
	for skin in range(6):
		game.profile.equip_costume(skin);game._spawn_hero();game.show_characters()
		for frame in range(8):await process_frame
		audit("Savi skin "+str(skin),"844x390")
		check(game.profile.data.character==1 and game.profile.data.costume==skin,"Each Savi skin must remain within Savi / Erin")
	print("CHARACTER AND SKIN UI CHECK: four separate characters, six Savi skin states")
	game.profile.level_for(1,5)
	game.profile.data.skin_progress[game.profile.skin_key_for(1,5)].level=100;game.profile.data.bow_level=100;game.profile.data.arrow_level=100;game.profile.data.character_level=100
	game.profile.data.character=1;game.profile.data.costume=5
	game._spawn_hero();game.show_characters()
	for frame in range(6):await process_frame
	audit("max-level character and skin carousel","844x390")
	game.start_stage(0,true);game.state="playing"
	game.arrows=10;game.select_power("burst")
	for frame in range(12):await physics_frame
	var controls:Control=game.touch_controller;var geo:Dictionary=controls.geometry();var scale_value:float=game.ui_scale
	audit("max-level power HUD","844x390")
	emit_touch(7,geo.power*scale_value,true);emit_touch(7,geo.power*scale_value,false)
	check(game.power_armed,"Touch POWER must arm the next shot")
	check(not game.hero.drawing and game.shots==0,"Touch POWER must not fire or draw on its own")
	game.power_armed=false;game.select_power("normal")
	emit_touch(0,geo.stick*scale_value,true)
	emit_drag(0,(geo.stick+Vector2(0,-55*geo.factor))*scale_value,Vector2(0,-55*geo.factor)*scale_value)
	for frame in range(15):await physics_frame
	check(game.hero.touch_move.y< -0.5,"Left stick must move the player")
	var old_yaw:float=game.hero.yaw
	var look:=Vector2(game.ui.size.x*0.55,game.ui.size.y*0.5)
	emit_touch(1,look*scale_value,true);emit_drag(1,(look+Vector2(35,-12))*scale_value,Vector2(35,-12)*scale_value)
	check(game.hero.yaw<old_yaw,"Right drag must rotate the camera")
	emit_touch(8,geo.aim*scale_value,true);emit_touch(8,geo.aim*scale_value,false)
	emit_touch(2,geo.draw*scale_value,true)
	for frame in range(75):await physics_frame
	check(game.hero.drawing,"Hold DRAW must draw the bow")
	var before:Vector3=game.hero.global_position
	for frame in range(30):await physics_frame
	check(game.hero.global_position.distance_to(before)<0.01,"Drawing must plant feet while stick is held")
	var shots:int=game.shots
	emit_touch(2,geo.draw*scale_value,false)
	check(game.shots==shots+1,"Releasing DRAW must fire exactly once")
	emit_touch(0,geo.stick*scale_value,false);emit_touch(1,look*scale_value,false)
	for frame in range(3):await physics_frame
	check(game.hero.touch_move==Vector2.ZERO,"Releasing movement finger must stop movement")
	game.hero.shot_cooldown=0;emit_touch(3,geo.draw*scale_value,true)
	for frame in range(10):await physics_frame
	emit_touch(3,geo.draw*scale_value,false,true);check(game.shots==shots+1,"Canceled touch must not fire")
	emit_touch(4,geo.stick*scale_value,true);game.show_pause()
	check(controls.roles.is_empty() and controls.move_vector==Vector2.ZERO,"Pause releases all active fingers")
	print("LANDSCAPE MULTITOUCH CHECK: move, look, planted aim, exact release, cancellation, pause")
	game.show_home();game.stop_audio();await create_timer(0.25).timeout
	game.queue_free();await process_frame;await process_frame
	if failures.is_empty():print("LANDSCAPE UI VERIFICATION PASS");quit(0)
	else:print("LANDSCAPE UI FAILURES ",failures);quit(1)
func audit(page_name:String,resolution:String) -> void:
	var viewport_rect:=Rect2(Vector2.ZERO,Vector2(root.size))
	for node in game.ui.find_children("*","Control",true,false):
		if not node.is_visible_in_tree():continue
		var within_scroll:=false;var parent:Node=node.get_parent()
		while parent!=game.ui and parent!=null:
			if parent is ScrollContainer:within_scroll=true;break
			parent=parent.get_parent()
		var rect:Rect2=node.get_global_rect()
		if not within_scroll and (node is Container or (node is Label and not node.text.is_empty())):
			check(viewport_rect.grow(2).encloses(rect),page_name+" "+resolution+" container outside screen: "+str(node.get_class())+str(rect))
		if node is ScrollContainer and node.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED:
			for child in node.get_children():
				if child is Control:check(child.size.y<=node.size.y+1,page_name+" "+resolution+" horizontal carousel clips content")
		if node is Label and not node.text.is_empty():
			check(node.size.y+1>=node.get_minimum_size().y,page_name+" "+resolution+" text height clipped: "+node.text)
func emit_touch(id:int,pos:Vector2,pressed:bool,canceled:bool=false) -> void:
	var event:=InputEventScreenTouch.new();event.index=id;event.position=pos;event.pressed=pressed;event.canceled=canceled
	Input.parse_input_event(event);Input.flush_buffered_events()
func emit_drag(id:int,pos:Vector2,relative:Vector2) -> void:
	var event:=InputEventScreenDrag.new();event.index=id;event.position=pos;event.relative=relative
	Input.parse_input_event(event);Input.flush_buffered_events()
