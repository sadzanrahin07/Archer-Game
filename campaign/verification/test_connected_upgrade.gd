extends SceneTree
const Profile=preload("res://campaign/profile.gd")
const Catalog=preload("res://campaign/catalog.gd")
var failures:Array[String]=[]

func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error(message)

func _init() -> void:
	for rating in [1,2,3]:
		var p=Profile.new();p.save_path="/tmp/arrowglade-v5-economy-%d.json"%rating
		check(p.data.coins==500,"Starting wallet")
		for id in range(100):
			var goal:int=Catalog.stage_gear_goal(id)
			for kind in ["bow","arrow","character"]:
				var current:int=p.character_mastery() if kind=="character" else int(p.data[kind+"_level"])
				while current<goal:
					var ok:bool=p.upgrade_item(kind,1 if kind=="character" else 0)
					check(ok,"%d-star funded %s before stage %d"%[rating,kind,id])
					if not ok:break
					current+=1
			var receipt:String="qa:%d:%d"%[rating,id]
			var reward:Dictionary=p.reward(id,rating,1.0,25,receipt)
			var wallet:int=p.data.coins
			var duplicate:Dictionary=p.reward(id,rating,1.0,25,receipt)
			check(p.data.coins==wallet and duplicate.get("duplicate",false),"Idempotent stage receipt")
			check(reward.saved,"Reward persisted")
		check(p.data.coins=={1:135500,2:304400,3:473300}[rating],"Actual profile wallet matches %d-star reference"%rating)
		check(p.power_is_unlocked("ultimate") and p.power_is_unlocked("burst"),"Trial rewards permanent at 100")
		print("ACTUAL ECONOMY ",rating," stars final wallet ",p.data.coins)
	var legacy=Profile.new();legacy.save_path="/tmp/arrowglade-v5-migration.json"
	var old:Dictionary=legacy.data.duplicate(true)
	old.version=3;old.coins=97;old.owned_bows=[0,1,2];old.bow_levels=[20,40,70,1];old.bow_level=40
	old.owned_arrows=[0,2];old.arrow_levels=[20,1,40,1];old.arrow_level=20
	old.skin_progress={"savi:2":{"level":65,"xp":0}};old.purchased_powers=["pressure"];old.stars={"65":1}
	legacy.data.merge(old,true);legacy._migrate_to_v4(old);legacy._sanitize()
	check(legacy.bow_mastery()==70 and legacy.arrow_mastery()==40 and legacy.character_mastery()==65,"Highest owned mastery migration")
	check(legacy.data.coins==97 and legacy.power_is_unlocked("pressure"),"Wallet and legacy power retained")
	check(legacy.has_trial_proof(65),"Existing trial clear proves entitlement")
	legacy.data.owned_bows=[0,1];legacy.data.bow_level=70;legacy.data.bow_levels=[70,70,70,70]
	check(legacy.equip_bow(1) and legacy.bow_mastery()==70,"Equipping never resets shared mastery")
	for definition in Catalog.BOWS+Catalog.ARROWS:check(ResourceLoader.exists(definition.mesh),"Equipment resource exists: "+str(definition.mesh))
	check(Catalog.ARROWS[1].name=="Runestone Arrow" and Catalog.ARROWS[2].name=="Hunter Arrow","Stable legacy arrow IDs")
	print("CONNECTED UPGRADE CHECKS: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
