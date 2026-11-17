extends "res://scripts/presentation/character_menu.gd"

const Preview = preload("res://scripts/campaign/progression_preview.gd")

func open_upgrade(id: String) -> void:
	if board.state.next_track_stage(id).is_empty(): return
	remember(); history.append(board.sheet_detail.duplicate(true))
	board._open_sheet_upgrade_confirmation(id)
	board.sheet_detail["preview_token"]=Preview.fingerprint(board.state)
	board.sheet_detail["preview_conditions"]=preview_conditions()
	board.sheet_detail["track_id"]=id
	board.sheet_detail["track"]=track_name(id, str(board.sheet_detail.get("track","Track")))

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
	var next := JSON.stringify([data,board.sheet_detail,board.sheet_repack_slot,board.state.expedition.get("discipline",""),board.state.carried_xp,board.state.player_hp,board.state.is_player_ready(),board.state.trial_complete,board.state.player_pos,board.state.current_layer])
	if next!=signature:
		if current_view==key: remember(layout_changed)
		current_view=key; signature=next; cancel_touches(); build(data,area)
	elif settle>0:
		settle-=1
		if settle==0:
			set_meta("layout_supported", shell.get_combined_minimum_size().y + 24 * u <= area.size.y + 1)
			if is_instance_valid(scroll): scroll.scroll_vertical = restore_offset
			restore_focus()
	board.sheet_panel_rect=area

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
	scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.follow_focus=true; shell.add_child(scroll)
	content=box(scroll); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if board.sheet_detail.is_empty(): summary(data,area.size.x/u-24)
	else: detail(data,board.sheet_detail)
	if str(board.sheet_detail.get("kind","")) in ["upgrade","track_choice"]: confirmation_footer(data)
	var links:=box(shell,true,4)
	command(links,"category:equipment","Equipment & belt",func(): open_view({"kind":"equipment_hub"}))
	command(links,"category:combat","Stats & abilities",func(): open_view({"kind":"stats_hub"}))
	restore_offset=int(Dictionary(views.get(current_view,{})).get("offset",0))
	settle=4

func category(id: String) -> String:
	if id=="adopted": return "Adopted discipline"
	var index: int=board.state.character_track_order().find(id)
	return ["Weapon","Defense","Temperament","Main Class","Subclass"][index] if index>=0 and index<5 else "Track"

func track_status(data: Dictionary, track: Dictionary) -> String:
	var reasons: Array[String]=[]
	if track.id=="adopted" and str(board.state.expedition.get("discipline","")).is_empty(): return "Discipline undiscovered"
	var stage: Dictionary=track.next_stage
	if stage.is_empty(): return "Complete"
	if not board.state.is_player_ready(): reasons.append("Finish current action")
	if board.state.trial_complete: reasons.append("Run complete")
	if board.state.mode_id==board.state.ModeRulesScript.CAMPAIGN_LAB and board.state.nearby_waystone().is_empty(): reasons.append("Reach a Waystone")
	if int(stage.get("gate",0))>int(data.character_level)+1: reasons.append("Next purchase must reach level "+str(stage.gate))
	if data.level_up_xp<data.level_up_cost: reasons.append("Need %s more %s XP" % [data.level_up_cost-data.level_up_xp,"secured" if board.state.mode_id==board.state.ModeRulesScript.CAMPAIGN_LAB else "carried"])
	if reasons.is_empty() and not Array(data.level_up_options).has(track.id): reasons.append("Level up unavailable in current context")
	return " · ".join(reasons) if not reasons.is_empty() else "Upgrade available"

func preview_conditions() -> Dictionary:
	return {"learned spells":board.state.player_spells.duplicate(),"selected spell":board.state.selected_spell,"secured XP":board.state.secured_xp,"carried XP":board.state.carried_xp,"level":board.state.character_level(),"location":board.state.player_pos,"ready":board.state.is_player_ready(),"cost":board.state.next_upgrade_cost(),"ranks":board.state.track_ranks.duplicate(true),"choices":board.state.track_choices.duplicate(true)}

func stale_reason(value: Dictionary) -> String:
	var old: Dictionary=value.get("preview_conditions",{})
	var current:=preview_conditions()
	for key in current:
		if old.get(key)!=current[key]: return "%s changed: %s → %s. Refresh and select again." % [str(key).capitalize(),str(old.get(key)),str(current[key])]
	return "Character effects or purchase conditions changed. Refresh and select again."

func next_effect(stage: Dictionary) -> String:
	var result:=Preview.description(board.state,stage)
	for option in stage.get("choices",[]): result+="\n"+str(option.label)+" · "+str(option.get("description",""))
	return result

func track_row(parent: Node, data: Dictionary, track: Dictionary) -> void:
	var id:=str(track.id)
	var count:=Array(track.stages).size() if id!="adopted" else 3
	var next:=str(track.next_stage.get("label","Complete"))
	var card:=command(parent,"track:"+id,"%s · %s · %s/%s investments\n%s\nNext: %s\n%s\n%s" % [category(id),track_name(id,str(track.label)),track.rank,count,track.description,next,next_effect(track.next_stage),track_status(data,track)],func(): open_view({"kind":"track","track_id":id}),104)
	card.alignment=HORIZONTAL_ALIGNMENT_LEFT
	var style:=StyleBoxFlat.new(); style.bg_color=Color("183139"); style.border_color=Color("467779"); style.set_border_width_all(1)
	style.content_margin_left=12*u; style.content_margin_right=12*u; style.content_margin_top=10*u; style.content_margin_bottom=10*u
	card.add_theme_stylebox_override("normal",style)

func summary(data: Dictionary, width: float) -> void:
	line(content,"Choose an investment · Main Class and Subclass develop in parallel")
	tracks_grid=GridContainer.new(); tracks_grid.columns=2 if width>=692 else 1
	tracks_grid.add_theme_constant_override("h_separation",roundi(12*u)); tracks_grid.add_theme_constant_override("v_separation",roundi(12*u)); content.add_child(tracks_grid)
	for track in data.tracks: track_row(tracks_grid,data,track)

func packages(data: Dictionary, track: Dictionary) -> void:
	line(content,"%s / %s shared investments · repeat either package" % [track.rank,track.stages.size()])
	line(content,"HISTORY")
	for stage in track.stages:
		if stage.completed:
			for option in stage.get("choices",[]):
				if option.id==stage.choice: line(content,str(stage.rank)+" · "+str(option.label))
	var stage: Dictionary=track.next_stage if not track.next_stage.is_empty() else track.stages.back()
	for option in stage.get("choices",[]):
		line(content,str(option.label)+" · "+str(option.description))
		if not track.next_stage.is_empty():
			for effect in Preview.preview(board.state,str(track.id),stage,str(option.id)): line(content,effect)
		command(content,"package:"+str(option.id),"Preview "+str(option.label),func():
			if track.next_stage.is_empty(): return
			open_upgrade(str(track.id)); board.sheet_detail["selected"]=str(track.id)+"|"+str(option.id)).disabled=track.next_stage.is_empty()

func detail(data: Dictionary, value: Dictionary) -> void:
	var kind := str(value.get("kind",""))
	match kind:
		"equipment_hub":
			command(content,"category:equipment_list","Equipment",func(): open_view({"kind":"equipment_list"}))
			belt(data)
		"stats_hub":
			for key in data.attributes: line(content,str(key).capitalize()+" · "+str(data.attributes[key]))
			combat(data)
		"tracks":
			for track in data.tracks: track_row(content,data,track)
		"track":
			for track in data.tracks:
				if str(track.id)!=str(value.track_id): continue
				line(content,track_name(str(track.id),str(track.label))+" · Rank "+str(track.rank))
				line(content,str(track.description)); line(content,track_status(data,track))
				if track.id=="adopted": line(content,"Discovery grants ranks I–II in Expedition. Mastery III is a purchase reaching level 9. No discipline discovery is promised in this regional Campaign.")
				if not track.next_stage.is_empty() and category(str(track.id))!="Temperament": command(content,"upgrade:"+str(track.id),"Preview next investment · "+str(data.level_up_cost)+" XP",func(): open_upgrade(str(track.id)))
				if track.stages.is_empty() and not Dictionary(track.next_stage).is_empty():
					line(content,str(track.next_stage.label)); line(content,str(track.next_stage.description)); line(content,"Available from level "+str(track.next_stage.gate))
				if category(str(track.id))=="Temperament": packages(data,track)
				else:
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
			line(content,str(value.get("track_description",""))); line(content,Preview.description(board.state,stage))
			if kind=="stage":
				line(content,"COMPLETED" if stage.get("completed",false) else "AVAILABLE FROM LEVEL "+str(stage.get("gate",0)))
				for option in stage.get("choices",[]):
					line(content,str(option.label)+(" · CHOSEN" if str(option.id)==str(stage.get("choice","")) else " · PERMANENT ALTERNATE NOT SELECTED" if stage.get("completed",false) else "")); line(content,str(option.get("description","")))
			if kind=="track_choice":
				for option in value.get("options",[]):
					var choice := str(value.upgrade_id)+"|"+str(option.id)
					command(content,"choice:"+str(option.id),str(option.label)+(" · selected" if value.get("selected","")==choice else ""),func(): board.sheet_detail["selected"]=choice)
					line(content,str(option.get("description","")))
			if kind in ["upgrade","track_choice"]:
				var selected:=str(value.get("selected",""))
				var option:=selected.get_slice("|",1) if selected.contains("|") else ""
				if kind=="upgrade" or not selected.is_empty():
					for effect in Preview.preview(board.state,str(value.upgrade_id),stage,option): line(content,effect)
				line(content,"Simulation timing; execution playback is 1.25×. Permanent investment for this character.")
				line(content,"Character level %s → %s · Track investments %s → %s" % [data.character_level,int(data.character_level)+1,board.state.track_total(str(value.upgrade_id)),board.state.track_total(str(value.upgrade_id))+1])
				for track in data.tracks:
					if track.id==value.upgrade_id: line(content,track_status(data,track))
				if value.get("preview_token","")!=Preview.fingerprint(board.state):
					line(content,stale_reason(value))
					command(content,"preview:refresh","Refresh preview",func():
						open_upgrade(str(value.upgrade_id)))
				line(content,("SECURED" if board.state.mode_id==board.state.ModeRulesScript.CAMPAIGN_LAB else "CARRIED")+" XP "+str(data.level_up_xp)+" · COST "+str(value.get("cost",0))+" XP · REMAINING "+str(maxi(0,int(data.level_up_xp)-int(value.get("cost",0))))+" XP")

func stage_button(data: Dictionary, track: Dictionary, index: int) -> void:
	var stage: Dictionary=track.stages[index]
	var actionable: bool=stage.get("current",false)
	var status := "COMPLETED" if stage.get("completed",false) else track_status(data,track) if actionable else "Requires previous stage · purchase reaching level "+str(stage.get("gate",0))
	var label := str(stage.label)
	for option in stage.get("choices",[]):
		if stage.get("completed",false) and str(option.id)==str(stage.get("choice","")): label=str(option.label)
	command(content,"stage:"+str(track.id)+":"+str(index),label+" · "+status,func():
		if actionable: open_upgrade(str(track.id))
		else: open_view({"kind":"stage","track_id":str(track.id),"track":track_name(str(track.id),str(track.label)),"stage":stage.duplicate(true)}))
	line(content,Preview.description(board.state,stage))

func confirmation_current(value: Dictionary) -> bool:
	var id := str(value.get("upgrade_id",""))
	return value.get("preview_token","")==Preview.fingerprint(board.state) and board.state.available_level_up_options().has(id) and board.state.next_upgrade_cost()==int(value.get("cost",0)) and str(board.state.next_track_stage(id).get("id",""))==str(Dictionary(value.get("stage",{})).get("id",""))

func confirmation_footer(_data: Dictionary) -> void:
	line(shell,"%s XP %s → %s · Level %s → %s" % ["Secured" if board.state.mode_id==board.state.ModeRulesScript.CAMPAIGN_LAB else "Carried",_data.level_up_xp,maxi(0,int(_data.level_up_xp)-int(_data.level_up_cost)),_data.character_level,int(_data.character_level)+1])
	var footer := box(shell,true)
	command(footer,"character:cancel","Cancel",func(): board.controller.back(board))
	var value: Dictionary=board.sheet_detail
	var choice := str(value.get("selected","")) if value.kind=="track_choice" else str(value.get("upgrade_id",""))
	command(footer,"character:confirm","SPEND "+str(value.get("cost",0))+" XP",func():
		if not choice.is_empty() and confirmation_current(value) and board.state.choose_upgrade(choice):
			board.visual=board._presentation_snapshot(); board._mark_autosave(true); back_view()).disabled=choice.is_empty() or not confirmation_current(value)
