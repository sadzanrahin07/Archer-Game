extends SceneTree
func _initialize():run.call_deferred()
func run():
 var game=load("res://campaign/main.tscn").instantiate();game.test_mode=true;game.profile.save_path="/tmp/power-grid-qa.json";root.add_child(game);await process_frame
 var failures:Array=[]
 for level in [1,19,20,49,50,59,60,69,70,79,80,89,90,99,100]:
  game.profile.data.bow_level=level;game.profile.data.arrow_level=level;game.show_collection();await process_frame
  var controls:Array=game.ui.find_children("Power_*","Button",true,false)
  if controls.size()!=7:failures.append("Seven powers visible at %d"%level)
  for button in controls:
   var key:String=button.name.trim_prefix("Power_")
   if button.disabled==game.profile.power_is_unlocked(key):failures.append("Lock mismatch %s / %d"%[key,level])
 game.profile.data.bow_level=100;game.profile.data.arrow_level=19;game.show_collection();await process_frame
 for button in game.ui.find_children("Power_*","Button",true,false):
  if not button.disabled:failures.append("Lower equipped component must gate all powers")
 game.stop_audio();game.queue_free();await process_frame
 print("POWER GRID: ","PASS" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)
