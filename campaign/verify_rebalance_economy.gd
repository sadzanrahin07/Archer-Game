extends SceneTree
func _initialize():run.call_deferred()
func run():
 var g=load("res://campaign/game.gd").new()
 var p=g.profile;p.save_path="/tmp/archer-economy-v3.json"
 var defs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://campaign/stages.json"))
 var replay_count:=0;var maximum_replays:=0
 for d in defs:
  var attempts:=0
  while true:
   for kind in ["bow","arrow"]:
    var wanted:int=int(d.required_tier) if kind=="bow" else [0,2,1,3][int(d.required_tier)]
    if p.can_buy(kind,wanted):
     p.buy_equipment(kind,wanted)
     if kind=="bow":p.equip_bow(wanted)
     else:p.equip_arrow(wanted)
   while p.level()<int(d.required_character_level) and p.can_upgrade_character():p.upgrade_character()
   for kind in ["bow","arrow"]:
    while int(p.data[kind+"_level"])<int(d.required_gear_level) and p.can_upgrade(kind):p.upgrade(kind)
   if g.loadout_requirement(d).is_empty():break
   assert(int(d.id)>0,"Starter level cannot be gated")
   var previous:int=int(d.id)-1
   assert(g.loadout_requirement(defs[previous]).is_empty(),"Replay must be possible")
   var paid:Dictionary=p.reward(previous,2,.8,10,"economy-replay-%d"%replay_count)
   assert(paid.saved);attempts+=1;replay_count+=1
   assert(attempts<500,"Economy blocked")
  maximum_replays=maxi(maximum_replays,attempts)
  p.start_run(int(d.id))
  assert(p.reward(int(d.id),2,.8,10,"economy-first-%d"%d.id).saved)
 print("ECONOMY PASS: 100 stages funded entirely by rewards; ",replay_count," replay clears, maximum ",maximum_replays," at any gate; balance ",p.data.coins)
 g.free();quit()
