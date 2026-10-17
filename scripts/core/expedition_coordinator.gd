class_name ExpeditionCoordinator
extends RefCounted

const Catalog = preload("res://scripts/core/expedition_catalog.gd")

static func fresh() -> Dictionary:
	return {"generation":Catalog.GENERATION_VERSION, "biome":0, "completed":[], "used_waystones":[], "rewarded_encounters":[], "crowns":0, "writ":false, "discipline":"", "equipment":{}, "purchases":{}, "events":[], "departed":[], "victory":false}

static func record(progress: Dictionary, event: String, details: Dictionary = {}) -> void:
	var row := details.duplicate(true)
	row["event"] = event
	row["biome"] = int(progress["biome"])
	progress["events"].append(row)

static func defeat_boss(progress: Dictionary) -> bool:
	var index := int(progress["biome"])
	if progress["completed"].has(index): return false
	progress["completed"].append(index)
	progress["crowns"] += int(Catalog.BIOMES[index]["boss_crowns"])
	if index == 0: progress["writ"] = true
	record(progress, "boss_defeated")
	return true

static func use_waystone(progress: Dictionary) -> bool:
	var index := int(progress["biome"])
	if not progress["completed"].has(index) or progress["used_waystones"].has(index): return false
	progress["used_waystones"].append(index)
	record(progress, "waystone_used")
	return true

static func depart(progress: Dictionary) -> bool:
	var index := int(progress["biome"])
	if not progress["completed"].has(index) or bool(progress["victory"]): return false
	progress["departed"].append(index)
	record(progress, "departure", {"unused_waystone":not progress["used_waystones"].has(index)})
	if index == 2: progress["victory"] = true
	else: progress["biome"] = index + 1
	return true

static func validate(progress: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if progress.is_empty(): return errors # Explicit legacy generator, never a partial new save.
	for key in fresh():
		if not progress.has(key): errors.append("Expedition missing %s" % key)
		elif typeof(progress[key]) != typeof(fresh()[key]): errors.append("Expedition field %s has wrong type" % key)
	if not errors.is_empty(): return errors
	if int(progress["generation"]) != Catalog.GENERATION_VERSION: errors.append("Unknown expedition generation")
	if int(progress["biome"]) < 0 or int(progress["biome"]) > 2: errors.append("Invalid expedition biome")
	if int(progress["crowns"]) < 0: errors.append("Negative crowns")
	for key in ["completed","used_waystones","departed"]:
		var seen := {}
		for index in progress[key]:
			if not index is int or int(index)<0 or int(index)>int(progress["biome"]) or seen.has(index): errors.append("Invalid or duplicate %s entry" % key)
			seen[index] = true
	if String(progress["discipline"]) not in ["","trapper","sapper"]: errors.append("Unknown adopted discipline")
	for slot in progress["equipment"]:
		var id := String(progress["equipment"][slot])
		if not Catalog.EQUIPMENT.has(id) or String(Catalog.EQUIPMENT[id]["slot"])!=String(slot): errors.append("Invalid equipment slot")
	var purchase_limits := {}
	for index in range(3):
		for loadout in ["warrior","rogue_acrobat","rogue_sharpshooter","mage_elementalist"]:
			for row in Catalog.merchant_stock(index,loadout):
				if index<=int(progress["biome"]): purchase_limits["%d:%s" % [index,row["id"]]] = int(row["quantity"])
	for key in progress["purchases"]:
		var quantity = progress["purchases"][key]
		if not purchase_limits.has(key) or not quantity is int or int(quantity)<0 or int(quantity)>int(purchase_limits.get(key,0)):
			errors.append("Invalid purchase record")
	var reward_ids := {}
	for key in progress["rewarded_encounters"]:
		var valid := false
		for biome in range(int(progress["biome"])+1):
			for site in range(8):
				if key=="%d:%d" % [biome,site]: valid=true
		if not valid or reward_ids.has(key): errors.append("Invalid or duplicate encounter reward")
		reward_ids[key] = true
	if progress["discipline"]!="" and (int(progress["biome"])<1 or bool(progress["writ"])): errors.append("Invalid discipline grant")
	if bool(progress["writ"]) and not progress["completed"].has(0): errors.append("Writ before first boss")
	if bool(progress["victory"]) and (int(progress["biome"])!=2 or not progress["departed"].has(2)): errors.append("Invalid victory")
	for index in progress["used_waystones"]:
		if not progress["completed"].has(index): errors.append("Waystone used before boss")
	for index in progress["departed"]:
		if not progress["completed"].has(index): errors.append("Departure before boss")
		if int(index)==int(progress["biome"]) and not (int(index)==2 and bool(progress["victory"])): errors.append("Departure did not advance biome")
	for index in range(int(progress["biome"])):
		if not progress["departed"].has(index) or not progress["completed"].has(index): errors.append("Missing prior biome outcome")
	return errors

static func report(state) -> String:
	if state.expedition.is_empty(): return ""
	var progress: Dictionary = state.expedition
	var lines: Array[String] = ["WAYSTONE EXPEDITION REPORT", "Version: %s | Expedition generator: %d" % [state.GAME_VERSION,Catalog.GENERATION_VERSION], "Seed: %d | Character: %s | Rules: %s" % [state.run_seed,state.loadout_id,state.combat_rules], "Outcome: %s" % ("victory" if progress["victory"] else "death" if state.death_pending else "in progress"), "Biome: %s | Level: %d" % [Catalog.BIOMES[int(progress["biome"])]["name"],state.character_level()], "Health: %d/%d | Pouch: %d/5 | Crowns: %d" % [state.player_hp,state.player_max_hp,state.potions,progress["crowns"]], "Simulation time: %.2fs | Damage dealt: %d | Damage received: %d" % [state.simulation_time,state.damage_dealt,state.damage_received_total], "Equipment: %s | Adopted discipline: %s" % [progress["equipment"],progress["discipline"]], "Utility belt: %s" % str(state.consumable_slots), "Completed bosses: %s | Used Waystones: %s | Closed biomes: %s" % [progress["completed"],progress["used_waystones"],progress["departed"]], "Pouch uses: %d | Death source: %s" % [state.potions_used_total,state.survey_last_damage_source], "", "EVENTS (biome numbers are one-based)"]
	var responses := {}
	for row in progress["events"]:
		if row["event"]=="attack_outcome":
			var key := "%s / %s" % [row.get("enemy","unknown"),row.get("resolution","unknown")]
			responses[key] = int(responses.get(key,0))+1
			continue
		lines.append("Biome %d: %s" % [int(row["biome"])+1,JSON.stringify(row)])
	lines.append("\nDEFENSIVE OUTCOMES: %s" % str(responses))
	lines.append("\nPLAYER FEEDBACK\nFun: not rated\nFairness: not rated\nReadability: not rated\nNotes:\nAutomated completion is not a judgment of fun or fairness.")
	return "\n".join(lines)
