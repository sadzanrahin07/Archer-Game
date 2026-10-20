extends SceneTree
# Economic/eligibility model only. No geometry or assumed successful shots are tested.
const Profile=preload("res://campaign/profile.gd")
const Catalog=preload("res://campaign/catalog.gd")
var p=Profile.new()
var definitions:Array=[]
var replay_runs:=0
var stage_clears:=0
var replay_clears:=0
var earned_coins:=0
var clock_budget:=0.0
var checkpoints:Array=[]
var blocked:Array=[]
var profile_path:="/tmp/archer_campaign_economy_simulation_C.json"
func _initialize() -> void:run.call_deferred()
func entries(kind:String)->Array:return Catalog.BOWS if kind=="bow" else Catalog.ARROWS
func eligible_best(kind:String)->int:
	var best:=0
	var options:Array=entries(kind)
	for id in range(options.size()):
		if p.completed_chapters()>=int(options[id].unlock_chapter) and int(options[id].tier_index)>int(options[best].tier_index):best=id
	return best
func buy_and_equip()->void:
	# Buy the highest eligible tier. Reserve the cheaper missing item first;
	# this avoids endlessly spending the shop savings on old gear upgrades.
	var wanted:Array=[]
	for kind in ["bow","arrow"]:
		var id:=eligible_best(kind)
		if not p.is_owned(kind,id):wanted.append({"kind":kind,"id":id,"price":int(entries(kind)[id].price)})
	wanted.sort_custom(func(a,b):return int(a.price)<int(b.price))
	for item in wanted:
		if p.can_buy(str(item.kind),int(item.id)):assert(p.buy_equipment(str(item.kind),int(item.id)))
	for kind in ["bow","arrow"]:
		var best:=0
		for id in range(entries(kind).size()):
			if p.is_owned(kind,id) and int(entries(kind)[id].tier_index)>int(entries(kind)[best].tier_index):best=id
		if int(p.data["equipped_"+kind])!=best:
			assert(p.equip_bow(best) if kind=="bow" else p.equip_arrow(best))
func reserve_coins()->int:
	var reserve:=0
	for kind in ["bow","arrow"]:
		var id:=eligible_best(kind)
		if not p.is_owned(kind,id):
			var price:=int(entries(kind)[id].price)
			reserve=price if reserve==0 else mini(reserve,price)
	return reserve
func spend()->void:
	buy_and_equip()
	for action in range(500):
		var reserve:=reserve_coins()
		var budget:=maxi(0,int(p.data.coins)-reserve)
		var choices:Array=[]
		if p.can_upgrade_character() and p.character_upgrade_cost()<=budget:
			choices.append({"kind":"character","efficiency":(0.008/(1.0+0.008*(p.level()-1)))/float(p.character_upgrade_cost())})
		for kind in ["bow","arrow"]:
			if p.can_upgrade(kind) and p.upgrade_cost(kind)<=budget:
				var gain:=0.004 if kind=="bow" else 0.003
				var lv:=int(p.data[kind+"_level"])
				choices.append({"kind":kind,"efficiency":(gain/(1.0+gain*(lv-1)))/float(p.upgrade_cost(kind))})
		if choices.is_empty():return
		choices.sort_custom(func(a,b):return float(a.efficiency)>float(b.efficiency))
		var kind:String=choices[0].kind
		assert(p.upgrade_character() if kind=="character" else p.upgrade(kind))
	assert(false,"Upgrade loop bound exceeded")
func clear_chapter(chapter:int,replay:bool)->void:
	var first:=chapter*5
	assert(p.start_run(first)==first)
	for id in range(first,first+5):
		assert(p.run_selected_stage()==id)
		assert(p.power()+0.000001>=float(definitions[id].get("required_power",0)),"Replay must be feasible with its actual equipped loadout")
		var payment:Dictionary=p.reward(id,2,0.8,float(definitions[id].seconds)*0.4,p.current_run_transaction()+":stage:"+str(id),{"q":66.0,"precision":0.6})
		assert(payment.saved)
		earned_coins+=int(payment.coins);stage_clears+=1
		if replay:replay_clears+=1
		clock_budget+=float(definitions[id].seconds)
		spend()
func replay_feasible_chapter()->int:
	for chapter in range(p.completed_chapters()-1,-1,-1):
		var feasible:=true
		for id in range(chapter*5,chapter*5+5):
			if p.power()<float(definitions[id].get("required_power",0)):feasible=false
		if feasible:return chapter
	return -1
func run()->void:
	p.save_path=profile_path
	definitions=JSON.parse_string(FileAccess.get_file_as_string("res://campaign/stages.json"))
	assert(p.data.character==1 and p.data.costume==Catalog.STARTER_COSTUME)
	for chapter in range(20):
		spend()
		var required:=0.0
		for stage_id in range(chapter*5,chapter*5+5):required=maxf(required,float(definitions[stage_id].get("required_power",0)))
		var before_runs:=replay_runs
		var start_power:=p.power()
		while p.power()+0.000001<required:
			var replay_chapter:=replay_feasible_chapter()
			assert(replay_chapter>=0,"Impossible gate: no already-cleared feasible chapter can fund upgrades")
			assert(replay_runs<250,"250replayrun bound reached")
			clear_chapter(replay_chapter,true);replay_runs+=1
		if replay_runs>before_runs:blocked.append({"chapter":chapter+1,"required_power":required,"entry_power":start_power,"after_replays":p.power(),"extra_chapter_runs":replay_runs-before_runs})
		clear_chapter(chapter,false)
		var checkpoint:Dictionary={"chapter":chapter+1,"skin_level":p.level(),"power":p.power(),"coins":int(p.data.coins),"bow":p.bow_name(),"bow_level":int(p.data.bow_level),"arrow":p.arrow_name(),"arrow_level":int(p.data.arrow_level),"replays_total":replay_runs}
		checkpoints.append(checkpoint)
		print("ECONOMY CHAPTER ",JSON.stringify(checkpoint))
	assert(p.completed_chapters()==20 and int(p.data.unlocked)==99)
	assert(replay_runs<=12,"Economy must not create a prolonged forced replay wall")
	var report:Dictionary={"completed_chapters":p.completed_chapters(),"stage_clears":stage_clears,"extra_chapter_runs":replay_runs,"extra_stage_clears":replay_clears,"earned_coins":earned_coins,"coins_spent":120+earned_coins-int(p.data.coins),"coins_left":int(p.data.coins),"earned_xp":int(p.data.xp),"final_skin_level":p.level(),"final_power":p.power(),"clock_budget_seconds":clock_budget,"estimated_minutes_at_60percent_clock_plus_ready_and_finalhold":(clock_budget*0.6+float(stage_clears)*4.3)/60.0,"blocked_chapters":blocked,"checkpoints":checkpoints,"policy":"Highest eligible tier, save for cheaper missing shop item before upgrading. Among affordable XP-qualified upgrades, buy best relative damage per coin. ErinBase only. All clears2stars. Replay highest completed chapter whose stages meet actual equipped power. No injected coins/XP/levels/ownership."}
	var file:=FileAccess.open("/tmp/archer_campaign_economy_report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CAMPAIGN ECONOMY SIMULATION PASS ",JSON.stringify(report))
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix):DirAccess.remove_absolute(profile_path+suffix)
	quit()
