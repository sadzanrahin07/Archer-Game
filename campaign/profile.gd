extends RefCounted

const Catalog = preload("res://campaign/catalog.gd")
const SAVE := "user://archer_campaign.json"
var save_path := SAVE
var character_testing_enabled := Catalog.TEST_UNLOCK_CHARACTERS
var data: Dictionary = {
	"economy_revision":2,"base_outfit_revision":1,"version":3,"character":1,"costume":2,"selected":0,"unlocked":0,"xp":0,"coins":120,
	"owned_characters":[1],"purchased_characters":[],"owned_costumes":[2],"purchased_costumes":[],"character_xp":{},"skin_progress":{},
	"equipped_bow":0,"bow_level":1,"bow_levels":[1,1,1,1],"bow_xp":[0,0,0,0],"owned_bows":[0],"purchased_bows":[],
	"equipped_arrow":0,"arrow_level":1,"arrow_levels":[1,1,1,1],"arrow_xp":[0,0,0,0],"owned_arrows":[0],"purchased_arrows":[],
	"stage_badges":{},"stars":{},"bests":{},"reward_tiers":{},"chapter_rewards":{},"transactions":{},"attempt_counter":0,"last_reward":{},"chapter_run":{},"power":"normal",
	"settings":{"bg_sound":true,"game_sound":true,"bg_volume":0.5,"game_volume":0.7,"volume":0.7,"sensitivity":1.0,"assist":true,"fullscreen":false,"reduced_motion":false,"touch_controls":OS.has_feature("android") or OS.has_feature("ios")}
}

func _init() -> void:
	sync_unlocks()

func load_profile() -> void:
	for path in [save_path,save_path+".bak"]:
		if not FileAccess.file_exists(path):continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or int(parsed.get("version",0)) not in [1,2,3] or not parsed.get("stars") is Dictionary or not parsed.get("settings") is Dictionary:continue
		var defaults: Dictionary = data.duplicate(true)
		data.merge(parsed,true)
		var settings: Dictionary = defaults.settings.duplicate(true)
		settings.merge(data.settings,true);data.settings=settings
		if int(parsed.get("version",0))==1:_migrate_legacy(parsed)
		if int(parsed.get("version",0))<3:_migrate_to_v3(parsed)
		if not parsed.has("base_outfit_revision"):
			data.character=1;data.costume=Catalog.STARTER_COSTUME;data.base_outfit_revision=1
		_sanitize()
		_apply_campaign_economy(parsed)
		return

func _migrate_to_v3(old: Dictionary) -> void:
	# Enforce that only Erin Base (character 1, costume 2), Training Bow (0), and Standard Arrow (0) are starter-free.
	var valid_chars: Array = [1]
	for c in _integer_ids(old.get("purchased_characters", []), Catalog.CHARACTERS.size()):
		if not valid_chars.has(c): valid_chars.append(c)
	data.owned_characters = valid_chars
	data.purchased_characters = _integer_ids(old.get("purchased_characters", []), Catalog.CHARACTERS.size())

	var valid_costumes: Array = [Catalog.STARTER_COSTUME]
	for c in _integer_ids(old.get("purchased_costumes", []), Catalog.COSTUMES.size()):
		if not valid_costumes.has(c): valid_costumes.append(c)
	data.owned_costumes = valid_costumes
	data.purchased_costumes = _integer_ids(old.get("purchased_costumes", []), Catalog.COSTUMES.size())

	var valid_bows: Array = [0]
	for b in _integer_ids(old.get("purchased_bows", []), Catalog.BOWS.size()):
		if not valid_bows.has(b): valid_bows.append(b)
	data.owned_bows = valid_bows
	data.purchased_bows = _integer_ids(old.get("purchased_bows", []), Catalog.BOWS.size())

	var valid_arrows: Array = [0]
	for a in _integer_ids(old.get("purchased_arrows", []), Catalog.ARROWS.size()):
		if not valid_arrows.has(a): valid_arrows.append(a)
	data.owned_arrows = valid_arrows
	data.purchased_arrows = _integer_ids(old.get("purchased_arrows", []), Catalog.ARROWS.size())

	if not data.owned_characters.has(int(data.character)): data.character = 1
	if not data.owned_costumes.has(int(data.costume)): data.costume = Catalog.STARTER_COSTUME
	if not data.owned_bows.has(int(data.equipped_bow)):
		data.equipped_bow = 0
		data.bow_level = int(data.bow_levels[0]) if data.bow_levels.size() > 0 else 1
	if not data.owned_arrows.has(int(data.equipped_arrow)):
		data.equipped_arrow = 0
		data.arrow_level = int(data.arrow_levels[0]) if data.arrow_levels.size() > 0 else 1
	data.version = 3

func _migrate_legacy(old: Dictionary) -> void:
	# Version1 had a global QA unlock flag, so its character ownership alone is not evidence of purchase.
	var legitimate: Array = [1]
	if _has_id(old.get("owned_characters",[0]),0):legitimate.append(0) # Preserve the former free Enola.
	for character in [2,3]:
		var old_gate: int = int(character) * 5 - 1
		if _has_id(old.get("purchased_characters",[]),int(character)) or _legacy_chapter_complete(old,old_gate):legitimate.append(character)
	data.owned_characters=legitimate
	data.purchased_characters=_integer_ids(old.get("purchased_characters",[]),Catalog.CHARACTERS.size())
	data.owned_costumes=_integer_ids(old.get("owned_costumes",[0]),Catalog.COSTUMES.size())
	if not data.owned_costumes.has(Catalog.STARTER_COSTUME):data.owned_costumes.append(Catalog.STARTER_COSTUME)
	data.skin_progress={}
	for character in range(Catalog.CHARACTERS.size()):
		var earned := int(old.get("character_xp",{}).get(str(character),int(old.get("xp",0)) if int(old.get("character",0))==character else 0))
		var progress: Dictionary = _legacy_progress(earned)
		if character==1:
			for skin in data.owned_costumes:data.skin_progress[skin_key_for(1,int(skin))]=progress.duplicate(true)
		else:data.skin_progress[skin_key_for(character)]=progress
	if not old.has("bow_levels"):
		data.bow_levels=[1,1,1,1];data.bow_levels[clampi(int(old.get("equipped_bow",0)),0,3)]=int(old.get("bow_level",1))
	if not old.has("arrow_levels"):
		data.arrow_levels=[1,1,1,1];data.arrow_levels[clampi(int(old.get("equipped_arrow",0)),0,3)]=int(old.get("arrow_level",1))
	data.reward_tiers=old.stars.duplicate(true)
	data.chapter_rewards={}
	for chapter in range(20):
		if _chapter_has_all_stars(chapter):data.chapter_rewards[str(chapter)]=true
	data.transactions={};data.last_reward={}
	var cursor:=clampi(int(old.get("selected",0)),0,Catalog.CAMPAIGN_STAGES-1)
	data.chapter_run={"active":true,"chapter":cursor/5,"stage":cursor%5,"failed":false,"transaction":"","stage_stars":[0,0,0,0,0]}
	data.version=2
	data.migration_note="Version1 paid gear/skins, coins and progress preserved; temporary character previews removed. Owned Savi skins inherit prior shared mastery once."

func _legacy_chapter_complete(old: Dictionary,last_stage: int) -> bool:
	for stage in range(last_stage-4,last_stage+1):
		if int(old.stars.get(str(stage),0))<1:return false
	return true

func _legacy_progress(earned: int) -> Dictionary:
	var remaining:=maxi(0,earned)
	var lv:=1
	while lv<20 and remaining>=150+50*(lv-1):
		remaining-=150+50*(lv-1);lv+=1
	return {"level":lv,"xp":remaining,"total_xp":maxi(0,earned)}

func _has_id(values: Variant,id: int) -> bool:
	if not values is Array:return false
	for value in values:
		if int(value)==id:return true
	return false

func _integer_ids(values: Variant,count: int) -> Array:
	var result: Array=[]
	if not values is Array:return result
	for value in values:
		var id:=int(value)
		if id>=0 and id<count and not result.has(id):result.append(id)
	return result

func _sanitize() -> void:
	# JSON numbers are floats; normalize ownership before Array.has/int comparisons.
	if not data.has("purchased_costumes") or not data.purchased_costumes is Array: data["purchased_costumes"] = []
	if not data.has("purchased_bows") or not data.purchased_bows is Array: data["purchased_bows"] = []
	if not data.has("purchased_arrows") or not data.purchased_arrows is Array: data["purchased_arrows"] = []
	data.purchased_characters=_integer_ids(data.get("purchased_characters",[]),Catalog.CHARACTERS.size())
	data.purchased_costumes=_integer_ids(data.purchased_costumes,Catalog.COSTUMES.size())
	data.purchased_bows=_integer_ids(data.purchased_bows,Catalog.BOWS.size())
	data.purchased_arrows=_integer_ids(data.purchased_arrows,Catalog.ARROWS.size())
	data.owned_characters=_integer_ids(data.owned_characters,Catalog.CHARACTERS.size())
	data.owned_costumes=_integer_ids(data.owned_costumes,Catalog.COSTUMES.size())
	data.owned_bows=_integer_ids(data.owned_bows,Catalog.BOWS.size())
	data.owned_arrows=_integer_ids(data.owned_arrows,Catalog.ARROWS.size())
	for dictionary_key in ["stage_badges","skin_progress","chapter_run","character_xp","reward_tiers","chapter_rewards","transactions","last_reward","bests"]:
		if not data[dictionary_key] is Dictionary:data[dictionary_key]={}
	data.coins=maxi(0,int(data.coins));data.xp=maxi(0,int(data.xp))
	data.character=clampi(int(data.character),0,Catalog.CHARACTERS.size()-1)
	data.costume=clampi(int(data.costume),0,Catalog.COSTUMES.size()-1)
	data.unlocked=clampi(int(data.unlocked),0,Catalog.CAMPAIGN_STAGES-1)
	data.selected=clampi(int(data.selected),0,int(data.unlocked))
	for kind in ["bow","arrow"]:
		var entries: Array = Catalog.BOWS if kind=="bow" else Catalog.ARROWS
		var owned_key := "owned_bows" if kind=="bow" else "owned_arrows"
		if not data[owned_key].has(0):data[owned_key].append(0)
		var levels: Array = data.get(kind+"_levels",[1]).duplicate()
		var xp_values: Array = data.get(kind+"_xp",[]).duplicate()
		while levels.size()<entries.size():levels.append(1)
		while xp_values.size()<entries.size():xp_values.append(0)
		for index in range(entries.size()):
			levels[index]=clampi(int(levels[index]),1,int(entries[index].max_level));xp_values[index]=maxi(0,int(xp_values[index]))
		data[kind+"_levels"]=levels;data[kind+"_xp"]=xp_values
		var equipped:=clampi(int(data["equipped_"+kind]),0,entries.size()-1)
		if not data[owned_key].has(equipped):equipped=0
		data["equipped_"+kind]=equipped;data[kind+"_level"]=levels[equipped]
	sync_unlocks()
	if not data.owned_characters.has(int(data.character)):data.character=1
	if not data.owned_costumes.has(int(data.costume)):data.costume=Catalog.STARTER_COSTUME
	if not data.chapter_run.is_empty():
		data.chapter_run.chapter=clampi(int(data.chapter_run.get("chapter",0)),0,19)
		data.chapter_run.stage=clampi(int(data.chapter_run.get("stage",0)),0,4)
		while data.chapter_run.get("stage_stars",[]).size()<5:data.chapter_run.stage_stars.append(0)
		if bool(data.chapter_run.get("active",false)):data.selected=int(data.chapter_run.chapter)*5+int(data.chapter_run.stage)
	if not power_is_unlocked(str(data.get("power","normal"))):data.power="normal"

func save_profile() -> bool:
	# A QA profile can unlock previews, but this never adds ownership to production saves.
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if not file:return false
	file.store_string(JSON.stringify(data));file.close()
	if FileAccess.file_exists(save_path):DirAccess.copy_absolute(save_path,save_path+".bak")
	return DirAccess.rename_absolute(save_path+".tmp",save_path)==OK

func _commit(before: Dictionary) -> bool:
	if save_profile():return true
	data=before;return false

func skin_key() -> String:
	return skin_key_for(int(data.character),int(data.costume))

func skin_key_for(character: int,costume: int=-1) -> String:
	if character==1:return "savi:"+str(int(data.costume) if costume<0 else costume)
	return "character:"+str(character)

func _record(key: String) -> Dictionary:
	if not data.skin_progress.has(key):data.skin_progress[key]={"level":1,"xp":0,"total_xp":0}
	return data.skin_progress[key]

func level() -> int:
	return level_for(int(data.character),int(data.costume))

func level_for(character: int,costume: int=-1) -> int:
	return clampi(int(_record(skin_key_for(character,costume)).get("level",1)),1,Catalog.CHARACTER_CAP)

func skin_level(costume: int) -> int:
	return level_for(1,costume)

func xp_in_level() -> int:
	return maxi(0,int(_record(skin_key()).get("xp",0)))

func xp_requirement() -> int:
	return 40+4*(level()-1)

func character_upgrade_requirement() -> int:
	return xp_requirement()

func character_upgrade_cost() -> int:
	return 0 if level()>=Catalog.CHARACTER_CAP else int(upgrade_info("character",int(data.character),int(data.costume)).cost)

func can_upgrade_character() -> bool:
	return bool(upgrade_info("character",int(data.character),int(data.costume)).ready)

func upgrade_character() -> bool:
	return upgrade_item("character",int(data.character),int(data.costume))

func mastery_level() -> int:
	var highest:=1
	for progress in data.skin_progress.values():highest=maxi(highest,int(progress.get("level",1)))
	return highest

func _skin_entry() -> Dictionary:
	return Catalog.COSTUMES[int(data.costume)] if int(data.character)==1 else Catalog.CHARACTERS[int(data.character)]

func character_power() -> float:
	return float(_skin_entry().base_power)*(1.0+0.012*(level()-1))

func power() -> float:
	var arrow: Dictionary=Catalog.ARROWS[int(data.equipped_arrow)]
	var bow: Dictionary=Catalog.BOWS[int(data.equipped_bow)]
	return float(arrow.power)*(1.0+0.015*(int(data.arrow_level)-1))*float(bow.multiplier)*(1.0+0.015*(int(data.bow_level)-1))*character_power()

func draw_time() -> float:
	return lerpf(0.90,0.65,float(level()-1)/99.0)*float(Catalog.BOWS[int(data.equipped_bow)].draw)

func flight_speed() -> float:
	var bow: Dictionary=Catalog.BOWS[int(data.equipped_bow)]
	var upgrade_factor:=1.0+0.10*float(int(data.bow_level)-1)/float(int(bow.max_level)-1)
	return 35.0*float(bow.speed)*upgrade_factor

func stability() -> float:
	return maxf(0.25,1.0-0.0075*(level()-1))*float(_skin_entry().base_sway)

func accuracy() -> float:
	# Displayed control rating, never a random chance to hit or a homing multiplier.
	return clampf(0.55+0.43*float(level()-1)/99.0+(1.0-float(_skin_entry().base_sway))*0.10,0.0,0.99)

func recovery() -> float:
	return lerpf(8.0,15.0,float(level()-1)/99.0)

func upgrade_cost(kind: String) -> int:
	if kind not in ["bow","arrow"]:return 0
	return 0 if int(data[kind+"_level"])>=max_level(kind) else int(upgrade_info(kind,int(data["equipped_"+kind])).cost)

func max_level(kind: String) -> int:
	if kind in ["character","costume","skin"]:return Catalog.CHARACTER_CAP
	if kind not in ["bow","arrow"]:return 0
	var entries: Array=Catalog.BOWS if kind=="bow" else Catalog.ARROWS
	return int(entries[int(data["equipped_"+kind])].max_level)

func upgrade_xp_requirement(kind: String) -> int:
	if kind not in ["bow","arrow"]:return xp_requirement()
	return 30+3*(int(data[kind+"_level"])-1)

func upgrade_xp(kind: String) -> int:
	if kind not in ["bow","arrow"]:return xp_in_level()
	return int(data[kind+"_xp"][int(data["equipped_"+kind])])

func can_upgrade(kind:String) -> bool:
	return kind in ["bow","arrow"] and bool(upgrade_info(kind,int(data["equipped_"+kind])).ready)

func upgrade(kind:String) -> bool:
	if kind not in ["bow","arrow"]:return false
	return upgrade_item(kind,int(data["equipped_"+kind]))

func completed_chapters() -> int:
	var completed:=0
	for chapter in range(20):
		if not _chapter_has_all_stars(chapter):break
		completed+=1
	return completed

func _chapter_has_all_stars(chapter: int) -> bool:
	for stage in range(chapter*5,chapter*5+5):
		if int(data.stars.get(str(stage),0))<1:return false
	return true

func _shop_entries(kind: String) -> Array:
	match kind:
		"character":return Catalog.CHARACTERS
		"costume","skin":return Catalog.COSTUMES
		"bow":return Catalog.BOWS
		"arrow":return Catalog.ARROWS
	return []

func _ownership_key(kind: String) -> String:
	match kind:
		"character":return "owned_characters"
		"costume","skin":return "owned_costumes"
		"bow":return "owned_bows"
		"arrow":return "owned_arrows"
	return ""

func is_owned(kind: String,id: int) -> bool:
	var entries: Array=_shop_entries(kind)
	if id<0 or id>=entries.size():return false
	if character_testing_enabled and kind in ["character","costume","skin"]:return true
	return data[_ownership_key(kind)].has(id)

func current_chapter() -> int:
	return int(data.unlocked) / 5 + 1

func is_unlocked(kind: String, id: int) -> bool:
	var entries: Array = _shop_entries(kind)
	if id < 0 or id >= entries.size(): return false
	if is_owned(kind, id): return true
	var entry: Dictionary = entries[id]
	var req_chapter: int = int(entry.get("unlock_chapter", 0))
	var req_mastery: int = int(entry.get("mastery", 1))
	var req_level: int = int(entry.get("unlock_level", 1))
	var chap_ok: bool = req_chapter <= 0 or current_chapter() >= req_chapter or completed_chapters() >= (req_chapter - 1)
	var mastery_ok: bool = mastery_level() >= req_mastery
	var level_ok: bool = level() >= req_level
	return chap_ok and mastery_ok and level_ok

func can_buy(kind: String, id: int) -> bool:
	var entries: Array = _shop_entries(kind)
	if id < 0 or id >= entries.size(): return false
	if is_owned(kind, id): return true
	var entry: Dictionary = entries[id]
	return is_unlocked(kind, id) and int(data.coins) >= int(entry.price)

func eligibility_text(kind: String, id: int) -> String:
	var entries: Array = _shop_entries(kind)
	if id < 0 or id >= entries.size(): return "Unavailable"
	if is_owned(kind, id): return "Owned"
	var entry: Dictionary = entries[id]
	var req_chapter: int = int(entry.get("unlock_chapter", 0))
	var req_mastery: int = int(entry.get("mastery", 1))
	var req_level: int = int(entry.get("unlock_level", 1))
	var requirements: PackedStringArray = []
	if req_chapter > 0 and current_chapter() < req_chapter and completed_chapters() < (req_chapter - 1):
		requirements.append("Reach Chapter %d" % req_chapter)
	if mastery_level() < req_mastery:
		requirements.append("Mastery Lv. %d" % req_mastery)
	if level() < req_level:
		requirements.append("Archer Lv. %d" % req_level)
	if not requirements.is_empty():
		return " · ".join(requirements)
	if int(data.coins) < int(entry.price):
		return "%d coins (Need %d more)" % [int(entry.price), int(entry.price) - int(data.coins)]
	return "%d coins" % int(entry.price)

func sync_unlocks() -> void:
	if not data.owned_characters.has(1):data.owned_characters.append(1)
	if not data.owned_costumes.has(Catalog.STARTER_COSTUME):data.owned_costumes.append(Catalog.STARTER_COSTUME)
	_record(skin_key())

func _buy(kind: String,id: int) -> bool:
	if is_owned(kind,id):return true
	if not can_buy(kind,id):return false
	var before: Dictionary=data.duplicate(true)
	data.coins-=int(_shop_entries(kind)[id].price);data[_ownership_key(kind)].append(id)
	if kind=="character":
		if not data.purchased_characters.has(id):data.purchased_characters.append(id)
		_record(skin_key_for(id))
	elif kind in ["costume","skin"]:
		if not data.has("purchased_costumes"):data["purchased_costumes"]=[]
		if not data.purchased_costumes.has(id):data.purchased_costumes.append(id)
		_record(skin_key_for(1,id))
	elif kind=="bow":
		if not data.has("purchased_bows"):data["purchased_bows"]=[]
		if not data.purchased_bows.has(id):data.purchased_bows.append(id)
	elif kind=="arrow":
		if not data.has("purchased_arrows"):data["purchased_arrows"]=[]
		if not data.purchased_arrows.has(id):data.purchased_arrows.append(id)
	if kind in ["bow","arrow"]:
		var tier:int=int(_shop_entries(kind)[id].tier_index)
		data[kind+"_levels"][id]=maxi(int(data[kind+"_levels"][id]),Catalog.tier_start(tier))
		var previous:int=int(data["equipped_"+kind])
		if int(_shop_entries(kind)[previous].tier_index)<tier:
			data[kind+"_xp"][id]+=int(data[kind+"_xp"][previous]);data[kind+"_xp"][previous]=0
	return _commit(before)

func buy_character(id: int) -> bool:
	return _buy("character",id)

func buy_costume(id: int) -> bool:
	return _buy("costume",id)

func buy_equipment(kind: String,id: int) -> bool:
	return _buy(kind,id) if kind in ["bow","arrow"] else false

func equip_character(id: int) -> bool:
	if not is_owned("character",id):return false
	var before: Dictionary=data.duplicate(true)
	data.character=id;_record(skin_key());_reset_unavailable_power()
	return _commit(before)

func equip_costume(id: int) -> bool:
	if not is_owned("costume",id) or not is_owned("character",1):return false
	var before: Dictionary=data.duplicate(true)
	data.character=1;data.costume=id;_record(skin_key());_reset_unavailable_power()
	return _commit(before)

func equip_bow(index: int) -> bool:
	return _equip_item("bow",index)

func equip_arrow(index: int) -> bool:
	return _equip_item("arrow",index)

func _equip_item(kind: String,index: int) -> bool:
	if not is_owned(kind,index):return false
	var before: Dictionary=data.duplicate(true)
	data["equipped_"+kind]=index;data[kind+"_level"]=int(data[kind+"_levels"][index])
	return _commit(before)

func bow_name() -> String:
	return str(Catalog.BOWS[int(data.equipped_bow)].name)

func arrow_name() -> String:
	return str(Catalog.ARROWS[int(data.equipped_arrow)].name)

func power_level() -> int:
	# Both equipped weapon components must support the power; archer mastery is separate.
	return mini(int(data.bow_level),int(data.arrow_level))

func power_is_unlocked(key: String) -> bool:
	for definition in Catalog.POWERS:
		if str(definition.key)==key:return power_level()>=int(definition.level)
	return false

func _reset_unavailable_power() -> void:
	if not power_is_unlocked(str(data.power)):data.power="normal"

func power_unlocks() -> Array:
	var result: Array=[]
	for definition in Catalog.POWERS:
		var item: Dictionary=definition.duplicate(true)
		item.unlocked=power_level()>=int(item.level);item.rank=power_rank(str(item.key));result.append(item)
	return result

func power_rank(key: String) -> int:
	for definition in Catalog.POWERS:
		if str(definition.key)==key:
			if power_level()<int(definition.level):return 0
			if key in ["normal","ultimate"]:return 1
			return mini(6,1+(power_level()-int(definition.level))/10)
	return 0

func ability_stats(key: String="") -> Dictionary:
	if key.is_empty():key=selected_power()
	for definition in Catalog.POWERS:
		if str(definition.key)==key:
			var result: Dictionary=definition.duplicate(true)
			var rank:=power_rank(key)
			result.rank=rank;result.unlocked=rank>0
			if key not in ["normal","ultimate"]:
				result.damage=float(result.damage)*(1.0+0.04*maxi(0,rank-1))
				result.speed=float(result.speed)*(1.0+0.02*maxi(0,rank-1))
				result.secondary=float(result.secondary)*(1.0+0.04*maxi(0,rank-1))
			return result
	return Catalog.POWERS[0].duplicate(true)

func selected_power() -> String:
	var current := str(data.get("power", "normal"))
	if current != "normal" and power_is_unlocked(current):
		return current
	var best := "normal"
	for definition in Catalog.POWERS:
		var k := str(definition.key)
		if k != "normal" and power_is_unlocked(k):
			best = k
	if best != "normal":
		data.power = best
	return best

func equip_power(key: String) -> bool:
	if not power_is_unlocked(key):return false
	var before: Dictionary=data.duplicate(true)
	data.power=key;data.power_chosen=true;return _commit(before)

static func calculate_performance(completed: bool,hits: int,shots: int,precision_sum: float,remaining: float,total_time: float,min_arrows: int) -> Dictionary:
	var a:=clampf(float(hits)/float(maxi(1,shots)),0.0,1.0)
	var p:=clampf(precision_sum/float(maxi(1,hits)),0.0,1.0)
	var t:=clampf(remaining/maxf(0.001,total_time),0.0,1.0)
	var e:=clampf(float(min_arrows)/float(maxi(1,shots)),0.0,1.0)
	var q:=40.0*a+30.0*p+20.0*t+10.0*e
	var stars:=0
	if completed:
		stars=1
		if q>=60.0 and a>=0.60:stars=2
		if q>=85.0 and a>=0.80 and p>=0.75:stars=3
	return {"stars":stars,"q":q,"accuracy":a,"precision":p,"time":t,"efficiency":e}

func stage_ready(stage: int) -> bool:
	return stage>=0 and stage<Catalog.CAMPAIGN_STAGES and stage/5<=completed_chapters()

func _next_attempt() -> String:
	data.attempt_counter=int(data.attempt_counter)+1
	return "run:%d:%d:%d"%[int(data.attempt_counter),int(data.chapter_run.get("chapter",0)),int(data.chapter_run.get("stage",0))]

func start_run(stage: int) -> int:
	stage=clampi(stage,0,Catalog.CAMPAIGN_STAGES-1)
	if data.stars.has(str(stage)) and stage<run_selected_stage():
		data.chapter_run.transaction=_next_attempt();save_profile();return stage
	var chapter:=mini(stage/5,completed_chapters())
	var run: Dictionary=data.chapter_run
	var before: Dictionary=data.duplicate(true)
	if run.is_empty() or not bool(run.get("active",false)) or int(run.get("chapter",-1))!=chapter:
		data.chapter_run={"active":true,"chapter":chapter,"stage":0,"failed":false,"transaction":"","stage_stars":[0,0,0,0,0]}
		data.chapter_run.transaction=_next_attempt();data.last_reward={}
	elif str(run.get("transaction","")).is_empty():data.chapter_run.transaction=_next_attempt()
	data.chapter_run.failed=false
	data.selected=run_selected_stage()
	if not _commit(before):return int(before.selected)
	return int(data.selected)

func run_selected_stage() -> int:
	if not data.chapter_run.is_empty() and bool(data.chapter_run.get("active",false)):return int(data.chapter_run.chapter)*5+int(data.chapter_run.stage)
	return int(data.selected)

func current_run_transaction() -> String:
	return str(data.chapter_run.get("transaction",""))

func fail_run() -> int:
	var before: Dictionary=data.duplicate(true)
	var chapter:=int(data.chapter_run.get("chapter",int(data.selected)/5))
	data.chapter_run={"active":true,"chapter":chapter,"stage":int(data.chapter_run.get("stage",int(data.selected)%5)),"failed":true,"transaction":"","stage_stars":[0,0,0,0,0]}
	data.chapter_run.transaction=_next_attempt();data.selected=chapter*5+int(data.chapter_run.stage);data.last_reward={}
	if not _commit(before):return int(before.selected)
	return int(data.selected)

func failure_run() -> int:
	return fail_run()

func reward(id: int,stars: int,accuracy_value: float,remaining: float,transaction_id: String="",performance: Dictionary={}) -> Dictionary:
	if id<0 or id>=Catalog.CAMPAIGN_STAGES or stars<1:return {"xp":0,"coins":0,"saved":true,"stars":0}
	stars=clampi(stars,1,3)
	if transaction_id.is_empty():
		if int(data.last_reward.get("stage",-1))==id:transaction_id=str(data.last_reward.get("transaction",""))
		elif not current_run_transaction().is_empty():transaction_id=current_run_transaction()+":stage:"+str(id)
		else:
			data.attempt_counter=int(data.attempt_counter)+1;transaction_id="award:%d:%d"%[int(data.attempt_counter),id]
	if data.transactions.has(transaction_id):
		var paid: Dictionary=data.transactions[transaction_id].duplicate(true);paid["duplicate"]=true;return paid
	var before: Dictionary=data.duplicate(true)
	var key:=str(id);var chapter:=id/5+1
	var first: bool = not data.stars.has(key)
	var paid_tier:=int(data.reward_tiers.get(key,data.stars.get(key,0)))
	var base:=Catalog.stage_coin_base(chapter)
	var multipliers: Array=[0.0,1.0,1.5,2.0]
	var coins:=0;var xp:=0
	if first:
		coins=int(base*float(multipliers[stars]))+50;xp=100+15*(chapter-1)+25*(stars-1)
	elif stars>paid_tier:
		coins=int(base*(float(multipliers[stars])-float(multipliers[paid_tier])));xp=25*(stars-paid_tier)
	else:
		coins=int(base*float(multipliers[stars])*0.35);xp=int((100+15*(chapter-1)+25*(stars-1))*0.5)
	data.stars[key]=maxi(stars,int(data.stars.get(key,0)))
	data.reward_tiers[key]=maxi(stars,paid_tier)
	var chapter_bonus:=0;var chapter_xp:=0
	if id%5==4 and _chapter_has_all_stars(chapter-1) and not data.chapter_rewards.has(str(chapter-1)):
		chapter_bonus=400*chapter;chapter_xp=100*chapter;data.chapter_rewards[str(chapter-1)]=true
	coins+=chapter_bonus;xp+=chapter_xp
	data.coins+=coins;data.xp+=xp
	var progress: Dictionary=_record(skin_key())
	progress.xp=int(progress.xp)+xp;progress.total_xp=int(progress.get("total_xp",0))+xp
	data.character_xp[str(data.character)]=int(data.character_xp.get(str(data.character),0))+xp
	for kind in ["bow","arrow"]:
		var index:=int(data["equipped_"+kind]);data[kind+"_xp"][index]=int(data[kind+"_xp"][index])+xp
	data.unlocked=maxi(int(data.unlocked),mini(id+1,Catalog.CAMPAIGN_STAGES-1))
	var old: Dictionary=data.bests.get(key,{})
	var q:=float(performance.get("q",accuracy_value*100.0))
	if q>float(old.get("q",-1.0)):
		data.bests[key]={"remaining":remaining,"accuracy":accuracy_value,"q":q,"performance":performance.duplicate(true),"assist":bool(data.settings.get("assist",true)),"skin":skin_key(),"bow":int(data.equipped_bow),"arrow":int(data.equipped_arrow)}
	if not data.chapter_run.is_empty() and bool(data.chapter_run.get("active",false)) and int(data.chapter_run.chapter)==chapter-1 and int(data.chapter_run.stage)==id%5:
		data.chapter_run.stage_stars[id%5]=stars
		if id%5==4:
			data.chapter_run.active=false;data.selected=mini(id+1,Catalog.CAMPAIGN_STAGES-1)
		else:
			data.chapter_run.stage=id%5+1;data.chapter_run.transaction=_next_attempt();data.selected=id+1
	var earned:Array=data.stage_badges.get(key,[])
	for badge in performance.get("badges",[]):
		if not earned.has(badge):earned.append(badge)
	data.stage_badges[key]=earned
	data.last_reward={"stage":id,"transaction":transaction_id}
	var result: Dictionary={"xp":xp,"coins":coins,"saved":true,"stars":stars,"chapter_bonus":chapter_bonus,"chapter_xp":chapter_xp,"chapter_complete":id%5==4,"transaction":transaction_id,"duplicate":false,"next_stage":run_selected_stage()}
	data.transactions[transaction_id]=result.duplicate(true)
	if data.transactions.size()>512:data.transactions.erase(data.transactions.keys()[0])
	if not _commit(before):return {"xp":0,"coins":0,"saved":false,"stars":stars}
	return result

func account_level() -> int:
	return mini(100,1+floori(sqrt(float(data.xp)/180.0)))

func account_progress() -> Dictionary:
	var current:=account_level()
	var floor_xp:=180*(current-1)*(current-1)
	var next_xp:=180*current*current
	return {"level":current,"xp":maxi(0,int(data.xp)-floor_xp),"required":next_xp-floor_xp}

# Preview upgrades never change the equipped loadout. Training XP discounts coins;
# it is not a second mandatory currency that can deadlock progression.
func upgrade_info(kind:String,id:int,costume:int=-1) -> Dictionary:
	var lv:int=level_for(id,costume) if kind=="character" else int(data[kind+"_levels"][id])
	var entry:Dictionary=Catalog.CHARACTERS[id] if kind=="character" else (Catalog.BOWS[id] if kind=="bow" else Catalog.ARROWS[id])
	var cap:int=int(entry.max_level)
	var xp:int=int(_record(skin_key_for(id,costume)).get("xp",0)) if kind=="character" else int(data[kind+"_xp"][id])
	var requirement:int=40+4*(lv-1) if kind=="character" else 30+3*(lv-1)
	var base_cost:int=Catalog.upgrade_price(kind,lv,int(entry.get("tier_index",0)))
	var trained:bool=xp>=requirement
	var cost:int=ceili(base_cost*.75) if trained else base_cost
	var owned:bool=is_owned(kind,id) and (kind!="character" or id!=1 or is_owned("costume",int(data.costume) if costume<0 else costume))
	return {"level":lv,"cap":cap,"xp":xp,"requirement":requirement,"cost":cost,"trained":trained,"owned":owned,"ready":owned and lv<cap and int(data.coins)>=cost}

func upgrade_item(kind:String,id:int,costume:int=-1) -> bool:
	if kind not in ["bow","arrow","character"]:return false
	var entries:Array=Catalog.CHARACTERS if kind=="character" else (Catalog.BOWS if kind=="bow" else Catalog.ARROWS)
	if id<0 or id>=entries.size():return false
	var info:Dictionary=upgrade_info(kind,id,costume)
	if not info.ready:return false
	var before:Dictionary=data.duplicate(true)
	data.coins-=int(info.cost)
	if kind=="character":
		var progress:Dictionary=_record(skin_key_for(id,costume));progress.level=int(info.level)+1
		if info.trained:progress.xp=int(progress.xp)-int(info.requirement)
	else:
		data[kind+"_levels"][id]=int(info.level)+1
		if info.trained:data[kind+"_xp"][id]-=int(info.requirement)
		if int(data["equipped_"+kind])==id:data[kind+"_level"]=int(info.level)+1
	return _commit(before)

func _apply_campaign_economy(old:Dictionary) -> void:
	if int(old.get("economy_revision",0))>=2:return
	var adjustment:int=0
	for stage_key in data.stars:
		var id:int=int(stage_key)
		if id<0 or id>=Catalog.CAMPAIGN_STAGES:continue
		var chapter:int=id/5+1
		var stars:int=clampi(int(data.stars[stage_key]),0,3)
		var multiplier:float=[0.0,1.0,1.5,2.0][stars]
		adjustment+=int(Catalog.stage_coin_base(chapter)*multiplier)-int((100+20*(chapter-1))*multiplier)
	data.coins+=maxi(0,adjustment)
	for kind in ["bow","arrow"]:
		var entries:Array=Catalog.BOWS if kind=="bow" else Catalog.ARROWS
		for id in data["owned_"+kind+"s"]:
			data[kind+"_levels"][int(id)]=maxi(int(data[kind+"_levels"][int(id)]),Catalog.tier_start(int(entries[int(id)].tier_index)))
		var best:int=0
		for id in data["owned_"+kind+"s"]:
			if int(entries[int(id)].tier_index)>int(entries[best].tier_index):best=int(id)
		for id in data["owned_"+kind+"s"]:
			if int(entries[int(id)].tier_index)<int(entries[best].tier_index) and int(data[kind+"_levels"][int(id)])>=int(entries[int(id)].max_level):
				data[kind+"_xp"][best]+=int(data[kind+"_xp"][int(id)]);data[kind+"_xp"][int(id)]=0
		data[kind+"_level"]=int(data[kind+"_levels"][int(data["equipped_"+kind])])
	data.economy_revision=2
	data.economy_adjustment={"coins":adjustment,"reason":"Previously cleared stages repriced for the new upgrade economy"}
