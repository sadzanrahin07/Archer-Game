extends SceneTree
var game:Node
var failures:Array[String]=[]
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 if not ok:failures.append(message);push_error(message)
func run():
 game=load("res://campaign/main.tscn").instantiate();game.test_mode=true;game.profile.save_path="/tmp/layout-v3.json";root.add_child(game)
 for resolution in [Vector2i(1280,720),Vector2i(844,390),Vector2i(640,360),Vector2i(1024,768)]:
  root.size=resolution;game.profile.data.settings.touch_controls=resolution.x<1000
  game._refresh_layout()
  for frame in range(6):await process_frame
  game.show_home()
  for frame in range(6):await process_frame
  audit("home",str(resolution))
  game.show_levels()
  for frame in range(6):await process_frame
  audit("levels",str(resolution))
  for mode in ["store","collection"]:
   game.shop_mode=mode
   for tab in ["bow","arrow","costumes","character"]:
    game.inventory_tab=tab;game.preview_item=-1;game.show_inventory()
    for frame in range(6):await process_frame
    audit(mode+tab,str(resolution))
  game.show_characters()
  for frame in range(6):await process_frame
  audit("characters",str(resolution))
  game.start_stage(0,true);game.state="playing"
  game.profile._record(game.profile.skin_key()).level=100
  game.profile.data.bow_level=100;game.profile.data.arrow_level=100
  game._show_hud()
  for frame in range(6):await process_frame
  audit("max-level HUD",str(resolution))
  game.show_home()
 game.stop_audio();game.queue_free();await process_frame
 print("LAYOUT V3: ","PASS" if failures.is_empty() else failures)
 quit(0 if failures.is_empty() else 1)
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
