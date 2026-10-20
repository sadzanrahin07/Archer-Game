extends SceneTree
const Profile = preload("res://campaign/profile.gd")
const Catalog = preload("res://campaign/catalog.gd")
var qa_path := "/tmp/archer_progression_qa.json"
func _initialize() -> void:
	run.call_deferred()

func fresh():
	var profile=Profile.new();profile.save_path=qa_path
	return profile

func run() -> void:
	var p=fresh()
	assert(p.data.character==1 and p.data.costume==2 and p.data.owned_characters==[1] and p.data.owned_costumes==[2])
	assert(not p.buy_character(0) and not p.buy_costume(0))
	p.data.coins=1000000
	assert(not p.upgrade_character() and not p.upgrade("bow"),"Coins cannot manufacture earned mastery")
	var rating: Dictionary=Profile.calculate_performance(false,10,10,10.0,10.0,10.0,10)
	assert(rating.stars==0)
	rating=Profile.calculate_performance(true,9,20,3.15,1.0,10.0,9)
	assert(rating.stars==1)
	rating=Profile.calculate_performance(true,6,10,3.6,7.6,10.0,3)
	assert(is_equal_approx(rating.q,60.2) and rating.stars==2)
	rating=Profile.calculate_performance(true,8,10,6.0,10.0,10.0,10)
	assert(rating.stars==2,"84.5 is below three-star Q threshold")
	rating=Profile.calculate_performance(true,9,10,7.2,10.0,10.0,5)
	assert(is_equal_approx(rating.q,85.0) and rating.stars==3)
	rating=Profile.calculate_performance(true,8,10,5.92,10.0,10.0,10)
	assert(rating.stars==2,"Precision requirement cannot be bypassed by time or efficiency")
	print("RATINGS PASS: failure, one/two/three-star and threshold guards")
	assert(p.start_run(4)==0)
	var tx:=p.current_run_transaction();var before:=int(p.data.coins)
	var reward: Dictionary=p.reward(0,1,0.45,1.0,tx)
	assert(reward.coins==150 and reward.xp==100 and p.run_selected_stage()==1)
	var duplicate: Dictionary=p.reward(0,1,0.45,1.0,tx)
	assert(duplicate["duplicate"] and p.data.coins==before+150)
	var reloaded=fresh();reloaded.load_profile()
	duplicate=reloaded.reward(0,1,0.45,1.0,tx)
	assert(duplicate["duplicate"] and reloaded.data.coins==p.data.coins)
	assert(p.fail_run()==0 and p.run_selected_stage()==0)
	assert(p.data.stars["0"]==1 and p.data.coins==before+150)
	assert(p.start_run(3)==0)
	reward=p.reward(0,3,1.0,8.0,p.current_run_transaction())
	assert(reward.coins==100 and reward.xp==50,"Improvement pays only missing first-clear tier")
	for id in range(1,5):
		assert(p.start_run(id)==id)
		reward=p.reward(id,2,0.8,5.0,p.current_run_transaction())
	assert(reward.chapter_bonus==400 and p.completed_chapters()==1 and p.run_selected_stage()==5)
	var chapter_bonus_before:=int(p.data.coins)
	p.start_run(0)
	for id in range(5):
		reward=p.reward(id,1,0.7,3.0,p.current_run_transaction())
	assert(reward.chapter_bonus==0 and p.data.coins>chapter_bonus_before)
	print("RUN AND TRANSACTION PASS: stage1 restart, banked rewards, reload dedup, tier delta, chapter bonus once")
	var own_record: Dictionary=p.data.skin_progress[p.skin_key()]
	var prelevel:=p.level();own_record.xp=p.xp_requirement()+13
	var cost:=p.character_upgrade_cost();before=int(p.data.coins)
	assert(p.upgrade_character() and p.level()==prelevel+1 and p.xp_in_level()==13 and p.data.coins==before-cost)
	assert(not p.upgrade_character())
	p.data.owned_costumes.append(1)
	assert(p.equip_costume(1) and p.level()==1 and p.xp_in_level()==0)
	p.data.skin_progress[p.skin_key()].xp=p.xp_requirement()
	assert(p.upgrade_character() and p.level()==2)
	assert(p.equip_costume(2) and p.level()==prelevel+1 and p.xp_in_level()==13)
	p.data.bow_xp[0]=p.upgrade_xp_requirement("bow")
	assert(p.upgrade("bow") and p.data.bow_level==2 and p.data.bow_xp[0]==0)
	p.data.bow_level=20;p.data.bow_levels[0]=20;p.data.bow_xp[0]=10000
	assert(p.max_level("bow")==20 and not p.upgrade("bow"))
	for chapter in range(15):
		for stage in range(chapter*5,chapter*5+5):p.data.stars[str(stage)]=2
	assert(p.completed_chapters()==15)
	assert(p.buy_equipment("bow",3) and p.buy_equipment("arrow",3))
	assert(p.equip_bow(3) and p.equip_arrow(3) and p.max_level("bow")==100 and p.max_level("arrow")==100)
	before=int(p.data.coins);assert(p.buy_equipment("bow",3) and p.data.coins==before)
	assert(p.buy_character(0) and p.buy_character(2) and p.buy_character(3))
	assert(not p.buy_costume(0),"Crimson needs mastery as well as completed chapters")
	p.data.skin_progress[p.skin_key()].level=50
	assert(p.buy_costume(0))
	assert(p.equip_costume(0) and p.level()==1,"Purchased Crimson starts at independent level1")
	print("SHOP AND MASTERYPASS: independent skins, coin+XP upgrade, tier caps, paid gates, Crimson double gate")
	var previous_power:=p.power();var previous_stability:=p.stability()
	p.data.skin_progress[p.skin_key()].level=100
	assert(p.power()>previous_power and p.stability()<previous_stability and p.accuracy()>0.98)
	for ability in Catalog.POWERS:
		assert(p.power_is_unlocked(str(ability.key)))
		assert(p.equip_power(str(ability.key)))
		assert(p.selected_power()==str(ability.key))
		assert(p.ability_stats().unlocked)
	assert(p.equip_costume(1) and p.selected_power()=="normal")
	p.data.skin_progress[p.skin_key()].level=20
	assert(p.power_is_unlocked("burst") and not p.power_is_unlocked("gale"))
	assert(p.equip_power("burst") and p.power_rank("burst")==1)
	p.data.skin_progress[p.skin_key()].level=60
	assert(p.power_rank("burst")==5 and p.ability_stats("burst").damage>0.55)
	print("POWERS PASS: Lv20/50/60/70/80/90/100, rank scaling, skin-switch recheck")
	assert(p.save_profile());reloaded=fresh();reloaded.load_profile()
	assert(reloaded.data.coins==p.data.coins and reloaded.level()==60 and reloaded.data.equipped_bow==3)
	# A fabricated v1 save exercises migration without opening the real player's save.
	var old: Dictionary={"version":1,"character":2,"costume":0,"selected":9,"unlocked":9,"xp":900,"coins":777,"owned_characters":[0,1,2,3],"owned_costumes":[0,1,5],"character_xp":{"1":900},"equipped_bow":3,"bow_level":7,"bow_levels":[1,2,3,7],"owned_bows":[0,3],"equipped_arrow":1,"arrow_level":4,"arrow_levels":[1,4],"owned_arrows":[0,1],"stars":{"0":1},"settings":{"bg_sound":false}}
	var file:=FileAccess.open(qa_path,FileAccess.WRITE);file.store_string(JSON.stringify(old));file.close()
	var migrated=fresh();migrated.load_profile()
	assert(migrated.data.version==2 and migrated.data.coins==777 and migrated.data.owned_bows.has(3) and migrated.data.bow_level==7)
	assert(migrated.data.owned_characters==[1,0] and migrated.data.character==1,"Temporary Maki/Jacky access is not preserved as purchases")
	assert(migrated.data.owned_costumes.has(0) and migrated.data.owned_costumes.has(1) and migrated.data.costume==2)
	assert(migrated.level_for(1,0)==5 and migrated.level_for(1,1)==5)
	assert(not migrated.data.settings.bg_sound and migrated.run_selected_stage()==9)
	print("MIGRATION PASS: paid ownership/coins/mastery/progress preserved, QA character access removed")
	# Full first-clear economy matches the authored 20chapter budget.
	var economy=fresh()
	for chapter in range(20):
		assert(economy.start_run(chapter*5)==chapter*5)
		for stage in range(chapter*5,chapter*5+5):
			var payment: Dictionary=economy.reward(stage,2,0.85,20.0,economy.current_run_transaction())
			assert(payment.saved)
	assert(economy.data.coins==132620 and economy.data.xp==47750)
	assert(economy.completed_chapters()==20 and economy.data.unlocked==99)
	var refused=fresh();refused.save_path="/this-directory-does-not-exist/archer-qa.json"
	refused.data.skin_progress[refused.skin_key()].xp=150
	var refused_before: Dictionary=refused.data.duplicate(true)
	assert(not refused.upgrade_character() and refused.data==refused_before,"A failed save must roll back the coin and XP debit")
	print("ECONOMY BUDGET PASS: 100first-clears at2stars earn132500coins/47750XP; save failures roll back atomically")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(qa_path+suffix):DirAccess.remove_absolute(qa_path+suffix)
	print("PROGRESSION VERIFICATION PASS")
	quit()
