extends PanelContainer
## Transient Character navigation and captured touch. Transactions stay in RunState.
const Metrics = preload("res://scripts/presentation/menu_metrics.gd")
var board
var signature := ""
var geometry := ""
var scroll: ScrollContainer
var content: VBoxContainer
var shell: VBoxContainer
var tracks_grid: GridContainer
var history: Array[Dictionary] = []
var views: Dictionary = {}
var pointers: Dictionary = {}
var primary := -1
var touch_navigation := false
var current_view := ""
var variant := 0 # measured full -> compact -> paged
var page := 0
var settle := 0
var u := 1.0
var restore_offset := 0
# Explicit geometry model for headless checks; production always uses platform metrics.
var density_model := 0.0

func _ready() -> void:
	clip_contents=true

func measure_unit() -> float:
	if density_model>0:
		var t := get_viewport().get_final_transform()
		return density_model/maxf(0.1,minf(t.x.length(),t.y.length()))
	return Metrics.unit(board)

func geometry_key() -> String:
	return str([board._display_safe_layout_rect(),get_viewport().get_final_transform(),measure_unit()])

func view_key(value: Dictionary) -> String:
	return str([value.get("kind","summary"),value.get("track_id",""),value.get("slot",""),Dictionary(value.get("stage",{})).get("id","")])

func remember(preserve_scroll: bool=false) -> void:
	if current_view.is_empty(): return
	var focused := get_viewport().gui_get_focus_owner()
	var offset := scroll.scroll_vertical if is_instance_valid(scroll) else 0
	views[current_view]={"offset":maxi(offset,restore_offset) if preserve_scroll else offset,
		"focus":str(focused.get_meta("menu_id","")) if focused!=null and is_ancestor_of(focused) else board.controller.focus_id,
		"native":focused!=null and is_ancestor_of(focused)}

func reset() -> void:
	cancel_touches(); history.clear(); views.clear(); current_view=""; signature=""; page=0; variant=0; touch_navigation=false

func open_view(value: Dictionary) -> void:
	remember(); history.append(board.sheet_detail.duplicate(true)); board.sheet_detail=value

func open_upgrade(id: String) -> void:
	if not board.state.available_level_up_options().has(id): return
	remember(); history.append(board.sheet_detail.duplicate(true))
	board._open_sheet_upgrade_confirmation(id)
	board.sheet_detail["track_id"]=id
	board.sheet_detail["track"]=track_name(id, str(board.sheet_detail.get("track","Track")))

func back_view() -> void:
	remember(); cancel_touches()
	board.sheet_detail=history.pop_back() if not history.is_empty() else {}

func cancel_touches() -> void:
	for index in pointers: pointers[index]["valid"]=false
	primary=-1

func line(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text=text; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",roundi(17*u))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func box(parent: Node, horizontal: bool=false, gap: float=8) -> BoxContainer:
	var node: BoxContainer=HBoxContainer.new() if horizontal else VBoxContainer.new()
	node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override("separation",roundi(gap*u)); parent.add_child(node)
	return node

func command(parent: Node, id: String, text: String, action: Callable, height: float=48) -> Button:
	var button := Button.new()
	button.text=text; button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size=Vector2(48,height)*u
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",roundi(17*u))
	button.set_meta("menu_id",id); button.set_meta("character_action",action)
	button.pressed.connect(action); parent.add_child(button)
	return button

func navigation_rows(node: Node=self, left: float=0.0, width: float=1.0) -> Array:
	# Follow the authored container topology, not button enumeration or distance
	# across rows. Lanes retain nested grid cells and their body/Upgrade slots.
	if node is Control and not node.is_visible_in_tree(): return []
	if node is BaseButton:
		return [] if node.disabled or node.get_meta("menu_skip",false) else [[{"control":node,"lane":left+width*0.5}]]
	var rows:Array=[]
	if node is GridContainer or node is HBoxContainer:
		var columns:int=node.columns if node is GridContainer else maxi(node.get_child_count(),int(node.get_meta("navigation_slots",0)))
		var children:=node.get_children()
		for first in range(0,children.size(),maxi(1,columns)):
			var band:Array=[]
			for column in mini(columns,children.size()-first):
				var cell:=navigation_rows(children[first+column],left+width*column/columns,width/columns)
				for row in cell.size():
					while band.size()<=row: band.append([])
					band[row].append_array(cell[row])
			for row in band:
				if not row.is_empty(): rows.append(row)
	else:
		for child in node.get_children(): rows.append_array(navigation_rows(child,left,width))
	return rows

func navigation_neighbor(control: Control, direction: Vector2) -> Control:
	var rows:=navigation_rows()
	for y in rows.size():
		for x in rows[y].size():
			if rows[y][x].control!=control: continue
			if direction.x!=0:
				return rows[y][clampi(x+int(direction.x),0,rows[y].size()-1)].control
			var next:int=clampi(y+int(direction.y),0,rows.size()-1)
			if next==y: return control
			var closest:Control=rows[next][0].control
			var distance:=INF
			for entry in rows[next]:
				var delta:float=absf(float(entry.lane)-float(rows[y][x].lane))
				# Equal missing-slot choices consistently prefer the left neighbor.
				if delta<distance-0.0001: distance=delta; closest=entry.control
			return closest
	return control

func sync(owner) -> void:
	board=owner
	if not board.character_sheet_open:
		if visible: remember(); cancel_touches()
		hide(); signature=""; return
	show(); u=measure_unit()
	var area := Metrics.rect_for_unit(board,u)
	var layout := geometry_key()
	var layout_changed := layout!=geometry
	if layout_changed:
		remember(true); cancel_touches(); geometry=layout; signature=""; variant=0; page=0
	position=area.position; size=area.size
	var data: Dictionary=board.state.character_sheet_data()
	var key := view_key(board.sheet_detail)
	var next := JSON.stringify([data,board.sheet_detail,board.sheet_repack_slot,board.state.expedition.get("discipline",""),board.state.carried_xp,board.state.player_hp,board.state.is_player_ready(),board.state.trial_complete])
	if next!=signature:
		if current_view==key: remember(layout_changed)
		current_view=key; signature=next; cancel_touches(); build(data,area)
	elif settle>0:
		settle-=1
		if settle==0:
			if board.sheet_detail.is_empty() and shell.get_combined_minimum_size().y+24*u>area.size.y+1 and variant<2:
				variant+=1; cancel_touches(); build(data,area)
			else:
				set_meta("layout_supported",shell.get_combined_minimum_size().y+24*u<=area.size.y+1)
				if is_instance_valid(scroll): scroll.scroll_vertical=restore_offset
				restore_focus()
	board.sheet_panel_rect=area

func restore_focus() -> void:
	var memory: Dictionary=views.get(current_view,{})
	board.controller.focus_id=str(memory.get("focus",board.controller.focus_id))
	if not memory.get("native",false): return
	for control in find_children("*","Button",true,false):
		if str(control.get_meta("menu_id",""))==memory.get("focus","") and not control.disabled:
			control.grab_focus(); return

func build(data: Dictionary, area: Rect2) -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	scroll=null; tracks_grid=null
	var style := StyleBoxFlat.new(); style.bg_color=Color("102128"); style.border_color=Color("58d2cf")
	style.set_border_width_all(2)
	style.content_margin_left=12*u; style.content_margin_right=12*u; style.content_margin_top=12*u; style.content_margin_bottom=12*u
	add_theme_stylebox_override("panel",style)
	shell=box(self,false,4 if variant>0 else 8)
	var header := box(shell,true)
	var title := line(header,str(data.name)+" · Level "+str(data.character_level))
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var back := command(header,"character:back","BACK",func(): board.controller.back(board))
	back.size_flags_horizontal=0; back.custom_minimum_size.x=72*u
	line(shell,"HP %s / %s · Energy %s / %s" % [board.state.player_hp,board.state.player_max_hp,roundi(data.current_energy),roundi(data.maximum_energy)])
	line(shell,xp_text(data))
	set_meta("menu_context","character:"+current_view)
	if board.sheet_detail.is_empty():
		content=box(shell,false,4 if variant>0 else 8)
		summary(data,area.size.x/u-24)
	else:
		scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.follow_focus=false; shell.add_child(scroll)
		content=box(scroll); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		# Reserve scrollbar width in the actual container, including narrow wrapping.
		content.size_flags_vertical=Control.SIZE_EXPAND_FILL
		detail(data,board.sheet_detail)
		if str(board.sheet_detail.get("kind","")) in ["upgrade","track_choice"]: confirmation_footer(data)
	restore_offset=int(Dictionary(views.get(current_view,{})).get("offset",0))
	settle=4

func xp_text(data: Dictionary) -> String:
	var context := str(data.level_up_context)
	var campaign: bool=board.state.mode_id==board.state.ModeRulesScript.CAMPAIGN_LAB
	var source := "WAYSTONE" if campaign else "COMBAT SURVEY" if board.state.is_measurement_mode() else "EXPEDITION"
	var account := "secured" if campaign else "carried"
	var status := "Level up available" if not data.level_up_options.is_empty() else "No eligible next stage" if not context.is_empty() else "Not ready" if not board.state.is_player_ready() else "Run complete" if board.state.trial_complete else "Reach a Waystone" if campaign and board.state.nearby_waystone().is_empty() else "Insufficient XP"
	return "LEVEL UP · %s · %s\nSpendable %s XP · %s · Cost %s XP" % [source,status,account,data.level_up_xp,data.level_up_cost]+("\nCarried XP · "+str(board.state.carried_xp) if campaign else "")

func track_name(id: String, fallback: String) -> String:
	if id=="adopted" and not str(board.state.expedition.get("discipline","")).is_empty(): return str(board.state.expedition.discipline).capitalize()
	return fallback

func track_status(data: Dictionary, track: Dictionary) -> String:
	if Array(data.level_up_options).has(track.id): return "Upgrade available"
	if track.id=="adopted" and str(board.state.expedition.get("discipline","")).is_empty(): return "Discipline not yet found"
	var stage: Dictionary=track.next_stage
	if stage.is_empty(): return "Complete" if int(track.rank)>0 else "No next stage"
	if int(stage.get("gate",0))>int(data.character_level)+1: return "Next level gate · "+str(stage.gate)
	return "Upgrade unavailable"

func track_row(parent: Node, data: Dictionary, track: Dictionary) -> void:
	var row := box(parent,true,8)
	row.set_meta("navigation_slots",2) # Keep the body lane when Upgrade is absent.
	var id := str(track.id)
	command(row,"track:"+id,track_name(id,str(track.label))+" · Rank "+str(track.rank)+"\n"+track_status(data,track),func(): open_view({"kind":"track","track_id":id}),56)
	if Array(data.level_up_options).has(id):
		var upgrade := command(row,"upgrade:"+id,"Upgrade",func(): open_upgrade(id))
		upgrade.size_flags_horizontal=0; upgrade.custom_minimum_size.x=88*u

func summary(data: Dictionary, width: float) -> void:
	if variant==0:
		tracks_grid=GridContainer.new(); tracks_grid.columns=2 if width>=692 else 1
		tracks_grid.add_theme_constant_override("h_separation",roundi(8*u)); tracks_grid.add_theme_constant_override("v_separation",roundi(8*u))
		content.add_child(tracks_grid)
		for track in data.tracks: track_row(tracks_grid,data,track)
	else:
		command(content,"category:tracks","Tracks & upgrades · "+str(data.tracks.size())+" tracks\n"+("Level up available · "+str(data.level_up_cost)+" XP" if not data.level_up_options.is_empty() else "Inspect ranks and next stages"),func(): open_view({"kind":"tracks"}),56)
	var categories := GridContainer.new(); categories.columns=2 if width>=280 else 1
	categories.add_theme_constant_override("h_separation",roundi(8*u)); categories.add_theme_constant_override("v_separation",roundi(4*u)); content.add_child(categories)
	var ids := ["equipment","attributes","combat","belt"]
	var equipped := 0
	for item in data.equipment.values():
		if str(item).to_lower() not in ["","empty"]: equipped+=1
	var summaries := ["Equipment\n%s / %s equipped" % [equipped,data.equipment.size()],"Attributes\n%s values" % data.attributes.size(),"Combat\nArt · "+("Locked" if str(data.equipped_art).is_empty() else "Equipped"),"Belt\nHealing %s / %s · %s slots" % [data.healing_charges,data.healing_capacity,data.consumable_slots.size()]]
	var per_page := categories.columns
	var pages := ceili(4.0/per_page)
	for i in ids.size():
		if variant==2 and i/per_page!=page: continue
		var id: String=ids[i]
		command(categories,"category:"+id,summaries[i],func(): open_view({"kind":id+"_list"}),52 if variant>0 else 64)
	if variant==2:
		var pager := box(content,true,4)
		command(pager,"category:previous","Previous · %s / %s" % [page+1,pages],func(): page=maxi(0,page-1); signature="").disabled=page==0
		command(pager,"category:next","Next · %s / %s" % [page+1,pages],func(): page=mini(pages-1,page+1); signature="").disabled=page==pages-1

func detail(data: Dictionary, value: Dictionary) -> void:
	var kind := str(value.get("kind",""))
	match kind:
		"tracks":
			for track in data.tracks: track_row(content,data,track)
		"track":
			for track in data.tracks:
				if str(track.id)!=str(value.track_id): continue
				line(content,track_name(str(track.id),str(track.label))+" · Rank "+str(track.rank))
				line(content,str(track.description)); line(content,track_status(data,track))
				if Array(data.level_up_options).has(track.id): command(content,"upgrade:"+str(track.id),"Upgrade · "+str(data.level_up_cost)+" XP",func(): open_upgrade(str(track.id)))
				if track.stages.is_empty() and not Dictionary(track.next_stage).is_empty():
					line(content,str(track.next_stage.label)); line(content,str(track.next_stage.description)); line(content,"Available from level "+str(track.next_stage.gate))
				for i in track.stages.size(): stage_button(data,track,i)
		"equipment_list":
			line(content,"EQUIPMENT")
			for slot in data.equipment:
				var item := str(data.equipment[slot]); var label := str(slot).capitalize()
				command(content,"equipment:"+str(slot),label+" · "+item,func(): open_view({"kind":"equipment","slot":label,"item":item}))
		"equipment":
			line(content,str(value.slot)+" · "+str(value.item))
			line(content,"Properties will appear here when equipment enters the prototype.")
		"attributes_list":
			line(content,"ATTRIBUTES")
			for key in data.attributes: line(content,str(key).capitalize()+" · "+str(data.attributes[key]))
		"combat_list": combat(data)
		"belt_list": belt(data)
		_:
			var stage: Dictionary=value.get("stage",{})
			line(content,str(value.get("track",""))+" · "+str(stage.get("label","")))
			line(content,str(value.get("track_description",""))); line(content,str(stage.get("description","")))
			if kind=="stage":
				line(content,"COMPLETED" if stage.get("completed",false) else "AVAILABLE FROM LEVEL "+str(stage.get("gate",0)))
				for option in stage.get("choices",[]):
					line(content,str(option.label)+(" · CHOSEN" if str(option.id)==str(stage.get("choice","")) else "")); line(content,str(option.get("description","")))
			if kind=="track_choice":
				for option in value.get("options",[]):
					var choice := str(value.upgrade_id)+"|"+str(option.id)
					command(content,"choice:"+str(option.id),str(option.label)+(" · selected" if value.get("selected","")==choice else ""),func(): board.sheet_detail["selected"]=choice)
					line(content,str(option.get("description","")))
			if kind in ["upgrade","track_choice"]:
				line(content,"Permanent choice for this run · "+str(value.get("cost",0))+" XP")
				line(content,"COST "+str(value.get("cost",0))+" XP · REMAINING "+str(maxi(0,int(data.level_up_xp)-int(value.get("cost",0))))+" XP")

func stage_button(data: Dictionary, track: Dictionary, index: int) -> void:
	var stage: Dictionary=track.stages[index]
	var actionable: bool=Array(data.level_up_options).has(track.id) and stage.get("current",false)
	var status := "COMPLETED" if stage.get("completed",false) else "AVAILABLE · "+str(data.level_up_cost)+" XP" if actionable else "LOCKED · AVAILABLE FROM LEVEL "+str(stage.get("gate",0))
	var label := str(stage.label)
	for option in stage.get("choices",[]):
		if stage.get("completed",false) and str(option.id)==str(stage.get("choice","")): label=str(option.label)
	command(content,"stage:"+str(track.id)+":"+str(index),label+" · "+status,func():
		if actionable: open_upgrade(str(track.id))
		else: open_view({"kind":"stage","track_id":str(track.id),"track":track_name(str(track.id),str(track.label)),"stage":stage.duplicate(true)}))

func combat(data: Dictionary) -> void:
	var frame := str(data.weapon_frame)
	var form := "DRAW › RELEASE" if frame=="bow" else "FOUR COMPACT CUTS" if frame=="knife" else "SIX ALTERNATING CUTS" if frame=="twin_knives" else "CUT › RETURN › DRIVING CUT" if frame=="sword" else str(board.state.AttackGeometryScript.technique(str(board.CombatCatalogScript.weapon_frame(frame).get("basic_technique",""))).get("label",""))
	line(content,str(board.CombatCatalogScript.weapon_frame(frame).get("label",frame))+" · "+form)
	line(content,"Defense · "+str(data.defense).capitalize())
	if board.state.uses_decision_commitments():
		line(content,"Ground taps choose a direction and commit one full stride, even nearby. Hold repeats strides. The movement cue shows the stride; terrain may stop travel. Tap a supply or interactable to use it within reach.")
	if frame=="bow" and board.state.loadout_id=="rogue_sharpshooter":
		var price:String=board._commit_shot_price_text()
		line(content,"Commit Shot · +25% full-shot damage. Select, then confirm a visible enemy. "+price+". Automatically finish remaining full draw and ordinary recovery. No hold, early release or voluntary cancel; ordinary interruption still applies.")
		line(content,"Touch: COMMIT SHOT, then enemy; tap selection again to cancel. Keyboard: G select/cancel, Tab enemy, Enter confirm. Controller: LB+A select, right-stick click enemy, A confirm / B cancel. Ordinary ATTACK / F / RT automatically draws, releases and recovers. Take Aim and learned arts remain separate.")
	if frame!="bow" and board.state.uses_decision_commitments():
		line(content,"Ordinary attack commits one cut and recovery. COMMIT COMBO / G / LB+left-stick-click selects the entire authored combo, then confirm a visible enemy. All cuts are prepaid; release cannot cancel. Normal interruption still applies.")
	var equipped := str(data.equipped_art)
	line(content,"ART · "+("LOCKED" if equipped.is_empty() else "EQUIPPED · "+str(board.CombatCatalogScript.weapon_art(equipped).get("label",equipped))))
	for art in data.known_arts:
		var id := str(art)
		command(content,"art:"+id,"Art · "+str(board.CombatCatalogScript.weapon_art(id).get("label",id))+(" · EQUIPPED" if id==equipped else " · Not equipped"),func():
			if board.state.can_swap_weapon_art(): board.state.equip_weapon_art(id)).disabled=not board.state.can_swap_weapon_art()

func belt(data: Dictionary) -> void:
	var allowed := str(data.level_up_context).is_empty()
	line(content,"BELT · Select two slots to repack" if allowed else "BELT · Repack unavailable during level up")
	line(content,"Rejuvenation "+str(data.healing_charges)+" / "+str(data.healing_capacity))
	for i in data.consumable_slots.size():
		var slot: Dictionary=data.consumable_slots[i]; var item := str(slot.get("id",""))
		command(content,"belt:"+str(i),"Slot "+str(i+1)+" · "+("Empty" if item.is_empty() else str(board.state.consumable_definition(item).get("label",item)))+" ×"+str(slot.get("count",0))+(" · selected" if board.sheet_repack_slot==i else ""),func():
			if not str(board.state.level_up_context()).is_empty(): return
			if board.sheet_repack_slot<0: board.sheet_repack_slot=i
			elif board.sheet_repack_slot==i: board.sheet_repack_slot=-1
			else:
				var first: int=board.sheet_repack_slot
				board.sheet_repack_slot=-1; board._close_character_for_action()
				board._begin_streamed_action(board.state.request_repack(first,i,false))).disabled=not allowed

func confirmation_current(value: Dictionary) -> bool:
	var id := str(value.get("upgrade_id",""))
	return board.state.available_level_up_options().has(id) and board.state.next_upgrade_cost()==int(value.get("cost",0)) and str(board.state.next_track_stage(id).get("id",""))==str(Dictionary(value.get("stage",{})).get("id",""))

func confirmation_footer(_data: Dictionary) -> void:
	var footer := box(shell,true)
	command(footer,"character:cancel","Cancel",func(): board.controller.back(board))
	var value: Dictionary=board.sheet_detail
	var choice := str(value.get("selected","")) if value.kind=="track_choice" else str(value.get("upgrade_id",""))
	command(footer,"character:confirm","SPEND "+str(value.get("cost",0))+" XP",func():
		if not choice.is_empty() and confirmation_current(value) and board.state.choose_upgrade(choice):
			board.visual=board._presentation_snapshot(); board._mark_autosave(true); back_view()).disabled=choice.is_empty() or not confirmation_current(value)

func hit_button(point: Vector2) -> Button:
	for node in find_children("*","Button",true,false):
		if node.disabled or not node.is_visible_in_tree() or not node.get_global_rect().has_point(point): continue
		var visible_rect: Rect2=node.get_global_rect(); var parent=node.get_parent()
		while parent!=null:
			if parent is Control and parent.clip_contents: visible_rect=visible_rect.intersection(parent.get_global_rect())
			parent=parent.get_parent()
		if visible_rect.has_point(point): return node
	return null

func route_touch(event: InputEvent) -> bool:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag): return false
	if board==null: return false
	if event is InputEventScreenTouch and event.pressed and board.character_sheet_open:
		var target := hit_button(event.position)
		if not pointers.is_empty(): cancel_touches()
		var valid := pointers.is_empty() and visible and geometry==geometry_key() and settle==0
		pointers[event.index]={"start":event.position,"last":event.position,"dragged":false,"valid":valid,"target":target,"view":current_view,"geometry":geometry}
		if valid: primary=event.index
		board.controller.release_actions(board); touch_navigation=true
		get_viewport().gui_release_focus()
	if not pointers.has(event.index): return board.character_sheet_open
	var pointer: Dictionary=pointers[event.index]
	if not board.character_sheet_open or geometry!=geometry_key() or current_view!=pointer.view: pointer.valid=false
	if event is InputEventScreenDrag:
		if Vector2(pointer.start).distance_to(event.position)>=6*u: pointer.dragged=true
		if pointer.valid and pointer.dragged and event.index==primary and is_instance_valid(scroll):
			scroll.scroll_vertical+=roundi(Vector2(pointer.last).y-event.position.y)
			restore_offset=scroll.scroll_vertical
		pointer.last=event.position
	elif not event.pressed:
		if Vector2(pointer.start).distance_to(event.position)>=6*u: pointer.dragged=true
		pointers.erase(event.index)
		if event.index==primary: primary=-1
		if pointer.valid and not pointer.dragged and not event.canceled and pointers.is_empty():
			var target=pointer.target
			if is_instance_valid(target) and hit_button(event.position)==target:
				board.controller.focus_id=str(target.get_meta("menu_id",""))
				target.get_meta("character_action").call()
	return true
