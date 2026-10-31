class_name ExpeditionEconomy
extends RefCounted
const Catalog = preload("res://scripts/core/expedition_catalog.gd")
const Coordinator = preload("res://scripts/core/expedition_coordinator.gd")

static func safety_denial(state) -> String:
	if state.expedition.is_empty(): return "No Expedition is active."
	if state.death_pending or state.trial_complete: return "This Expedition has ended."
	if not state.is_player_ready(): return "Finish your current action before trading or equipping."
	if not state.projectiles.is_empty(): return "Wait for the projectiles to clear before trading or equipping."
	for hazard in state.hazards:
		if int(hazard.get("source_id",0))!=0: return "Leave the hostile hazards before trading or equipping."
	for enemy in state.enemies:
		if bool(enemy.get("reserve",false)) or not state._enemy_is_streamed(enemy): continue
		if String(enemy.get("awareness","idle"))=="alerted" or Vector2(enemy["pos"]).distance_to(state.player_pos)<650: return "Nearby or alerted enemies prevent trading and equipping."
	return ""

static func safe(state) -> bool:
	return safety_denial(state).is_empty()

static func merchant_denial(state) -> String:
	if state.expedition.is_empty() or not state.expedition_markers.has("merchant"): return "No merchant is available here."
	if state.player_pos.distance_to(Vector2(state.expedition_markers["merchant"]))>=150: return "Move closer to trade with the merchant."
	return safety_denial(state)

static func at_merchant(state) -> bool:
	return merchant_denial(state).is_empty()

static func stock(state) -> Array:
	if state.expedition.is_empty(): return []
	var index := int(state.expedition["biome"])
	var rows := Catalog.merchant_stock(index, state.loadout_id)
	for row in rows:
		var key := "%d:%s" % [index,row["id"]]
		row["quantity"] -= int(state.expedition["purchases"].get(key,0))
	return rows

static func purchase(state, item_id: String) -> bool:
	if not at_merchant(state): return false
	for row in stock(state):
		if row["id"]!=item_id or int(row["quantity"])<=0: continue
		if int(state.expedition["crowns"])<int(row["price"]): return false
		# Purchase creates a real ground item so a full belt never loses the goods.
		# Deduction, stock and item share one snapshot and never require a second
		# confirmation write. Reopening a merchant does not recreate stock.
		var key := "%d:%s" % [state.expedition["biome"],item_id]
		var number := int(state.expedition["purchases"].get(key,0))+1
		state.expedition["crowns"] -= int(row["price"])
		state.expedition["purchases"][key] = number
		state._add_pickup({"id":"purchase_%s_%d" % [key,number],"item_id":item_id,"count":1,"pos":state.player_pos+Vector2(65,0),"layer":state.current_layer,"area_id":state.current_area_id})
		Coordinator.record(state.expedition,"purchase",{"item":item_id,"price":row["price"]})
		state.changed.emit()
		return true
	return false

static func comparison(state, item_id: String) -> String:
	if not Catalog.EQUIPMENT.has(item_id): return ""
	var item: Dictionary = Catalog.EQUIPMENT[item_id]
	var old_id := String(state.expedition["equipment"].get(item["slot"],""))
	var old: Dictionary = Catalog.EQUIPMENT.get(old_id,{"label":"Starting equipment","description":"No equipment bonuses"})
	return "%s: %s\nReplaces %s: %s\nRequires safety and readiness. Replaced gear stays on the ground. No healing on equip." % [item["label"],item["description"],old["label"],old["description"]]

static func equip(state, pickup_id: String) -> bool:
	if not safe(state): return false
	for pickup in state.world_pickups:
		if pickup["id"]!=pickup_id or String(pickup.get("layer",state.current_layer))!=state.current_layer or Vector2(pickup["pos"]).distance_to(state.player_pos)>state.PICKUP_RANGE: continue
		if int(pickup.get("guard_site",-1))>=0 and not state._area_is_clear(int(pickup["guard_site"])): return false
		var item_id := String(pickup["item_id"])
		if not Catalog.EQUIPMENT.has(item_id): return false
		var item: Dictionary = Catalog.EQUIPMENT[item_id]
		var slot := String(item["slot"])
		var old_id := String(state.expedition["equipment"].get(slot,""))
		var old: Dictionary = Catalog.EQUIPMENT.get(old_id,{"stats":{}})
		for entry in [[old,-1],[item,1]]:
			var stats: Dictionary = entry[0]["stats"]
			for stat in stats:
				var delta := int(stats[stat])*int(entry[1])
				state.player_attributes[stat] = int(state.player_attributes.get(stat,0))+delta
				if stat=="health": state.player_max_hp += delta
				if stat=="energy": state.player_max_energy += delta
		state.player_hp = mini(state.player_hp,state.player_max_hp)
		state.player_energy = minf(state.player_energy,state.player_max_energy)
		state._refresh_player_posture_capacity(false)
		state.expedition["equipment"][slot] = item_id
		state.equipment_slots[slot] = item["label"]
		state._remove_pickup(String(pickup["id"]))
		if not old_id.is_empty(): state._drop_belt_item({"id":old_id,"count":1})
		Coordinator.record(state.expedition,"equip",{"item":item_id,"replaced":old_id})
		state.changed.emit()
		return true
	return false

static func modifier(state, key: String) -> float:
	var result := 1.0
	if state.expedition.is_empty(): return result
	for id in state.expedition["equipment"].values():
		result *= float(Catalog.EQUIPMENT[id].get(key,1.0))
	return result

static func adopt(state, id: String) -> bool:
	if id not in ["trapper","sapper"] or not at_merchant(state): return false
	if int(state.expedition["biome"])!=1 or not bool(state.expedition["writ"]) or state.expedition["discipline"]!="": return false
	state.expedition["discipline"] = id
	state.expedition["writ"] = false
	state.track_ranks["adopted"] = 2
	Coordinator.record(state.expedition,"discipline_adopted",{"discipline":id})
	state.changed.emit()
	return true
