extends PanelContainer
const Metrics = preload("res://scripts/presentation/menu_metrics.gd")
var board
var signature := ""
var scroll: ScrollContainer
var content: VBoxContainer
var tracks_grid: GridContainer

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color=Color("102128")
	style.border_color=Color("58d2cf")
	style.set_border_width_all(2)
	style.content_margin_left=12; style.content_margin_right=12
	style.content_margin_top=12; style.content_margin_bottom=12
	add_theme_stylebox_override("panel",style)

func line(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text=text; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",17)
	parent.add_child(label)

func command(parent: Node, id: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text=text; button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y=48
	button.add_theme_font_size_override("font_size",17)
	button.set_meta("menu_id",id)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func sync(owner) -> void:
	board=owner
	visible=board.character_sheet_open
	if not visible: signature=""; return
	var area: Rect2 = Metrics.rect(board)
	position=area.position; size=area.size
	var data: Dictionary = board.state.character_sheet_data()
	var next := JSON.stringify([data,board.sheet_detail,board.sheet_repack_slot])
	if next != signature:
		signature=next
		var offset := scroll.scroll_vertical if is_instance_valid(scroll) else 0
		for child in get_children(): remove_child(child); child.queue_free()
		scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
		content=VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation",10)
		scroll.add_child(content)
		var context := "character:"+str(board.sheet_detail.get("kind","summary"))
		set_meta("menu_context",context)
		line(content,str(data.get("name","Character"))+" · Level "+str(board.state.character_level()))
		var level_context := str(data.get("level_up_context",""))
		if not level_context.is_empty():
			var source := "EXPEDITION" if level_context=="expedition" else "COMBAT SURVEY" if level_context=="survey" else "WAYSTONE"
			line(content,"LEVEL UP · "+source)
			line(content,"Spendable "+("secured" if level_context=="waystone" else "carried")+" XP · "+str(data.level_up_xp))
		if level_context.is_empty() or level_context=="waystone": line(content,"Carried XP · "+str(board.state.carried_xp))
		line(content,"HP "+str(board.state.player_hp)+" / "+str(board.state.player_max_hp)+" · Energy "+str(roundi(data.current_energy))+" / "+str(roundi(data.maximum_energy)))
		if board.sheet_detail.is_empty(): summary(data)
		else: detail(board.sheet_detail)
		command(content,"character:back","BACK",func(): board.controller.back(board))
		scroll.set_deferred("scroll_vertical",offset)
	if is_instance_valid(tracks_grid): tracks_grid.columns=3 if area.size.x/Metrics.unit(board)>=760 else 2 if area.size.x/Metrics.unit(board)>=560 else 1
	Metrics.apply(board,content)
	board.sheet_panel_rect=area

func summary(data: Dictionary) -> void:
	line(content,"EQUIPMENT")
	for slot in data.equipment:
		var item := str(data.equipment[slot])
		command(content,"equipment:"+str(slot),str(slot).capitalize()+" · "+item,func():
			board.sheet_detail={"kind":"equipment","slot":str(slot).capitalize(),"item":item})
	line(content,"ATTRIBUTES")
	var stats: Array[String]=[]
	for key in data.attributes: stats.append(str(key).capitalize()+" "+str(data.attributes[key]))
	line(content," · ".join(stats))
	var frame := str(data.weapon_frame)
	var form := "DRAW › RELEASE" if frame=="bow" else "FOUR COMPACT CUTS" if frame=="knife" else "SIX ALTERNATING CUTS" if frame=="twin_knives" else "CUT › RETURN › DRIVING CUT" if frame=="sword" else str(board.state.AttackGeometryScript.technique(str(board.CombatCatalogScript.weapon_frame(frame).get("basic_technique",""))).get("label",""))
	line(content,str(board.CombatCatalogScript.weapon_frame(frame).get("label",frame))+" · "+form)
	line(content,"Defense · "+str(data.defense).capitalize())
	var equipped := str(data.get("equipped_art",""))
	line(content,"ART · "+("LOCKED" if equipped=="" else "EQUIPPED · "+str(board.CombatCatalogScript.weapon_art(equipped).get("label",equipped))))
	for art in data.known_arts:
		var id := str(art)
		var art_button := command(content,"art:"+id,"Art · "+str(board.CombatCatalogScript.weapon_art(id).get("label",id))+(" · EQUIPPED" if id==equipped else " · Not equipped"),func():
			if board.state.can_swap_weapon_art(): board.state.equip_weapon_art(id))
		art_button.disabled=not board.state.can_swap_weapon_art()
	if str(data.get("level_up_context","")) == "":
		line(content,"BELT · Select two slots to repack")
		line(content,"Rejuvenation "+str(data.get("healing_charges",0))+" / "+str(data.get("healing_capacity",0)))
		for i in range(3):
			var slots: Array=data.get("consumable_slots",[])
			var slot: Dictionary=slots[i] if i<slots.size() else {}
			var item := str(slot.get("id",""))
			command(content,"belt:"+str(i),"Slot "+str(i+1)+" · "+("Empty" if item=="" else str(board.state.consumable_definition(item).get("label",item)))+" ×"+str(slot.get("count",0))+(" · selected" if board.sheet_repack_slot==i else ""),func():
				if board.sheet_repack_slot<0: board.sheet_repack_slot=i
				elif board.sheet_repack_slot==i: board.sheet_repack_slot=-1
				else:
					var first: int=board.sheet_repack_slot
					board.sheet_repack_slot=-1; board._close_character_for_action()
					board._begin_streamed_action(board.state.request_repack(first,i,false)))
	line(content,"TRACKS")
	tracks_grid=GridContainer.new(); tracks_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tracks_grid.add_theme_constant_override("h_separation",12); tracks_grid.add_theme_constant_override("v_separation",12)
	content.add_child(tracks_grid)
	for track in data.tracks:
		var card := VBoxContainer.new(); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tracks_grid.add_child(card)
		line(card,str(track.label)+" · Rank "+str(track.rank))
		if track.stages.is_empty(): line(card,"DISCIPLINE NOT YET FOUND")
		for index in range(track.stages.size()):
			var stage: Dictionary=track.stages[index]
			var actionable: bool=Array(data.get("level_up_options",[])).has(track.id) and stage.get("current",false)
			var status := "COMPLETED" if stage.get("completed",false) else "AVAILABLE · "+str(data.get("level_up_cost",0))+" XP" if actionable else "LOCKED · AVAILABLE FROM LEVEL "+str(stage.get("gate",0))
			var label := str(stage.label)
			if stage.get("completed",false) and str(stage.get("choice",""))!="":
				for option in stage.get("choices",[]):
					if str(option.id)==str(stage.choice): label=str(option.label); break
			command(card,"stage:"+str(track.id)+":"+str(index),label+" · "+status,func():
				if actionable: board._open_sheet_upgrade_confirmation(str(track.id))
				else: board.sheet_detail={"kind":"stage","track":str(track.label),"stage":stage.duplicate(true)})

func detail(value: Dictionary) -> void:
	var kind := str(value.get("kind",""))
	if kind=="equipment":
		line(content,str(value.slot)+" · "+str(value.item))
		# Preserve the existing inspection content; equipment explanations remain a
		# separate unadopted proposal in the lead's contract.
		line(content,"Properties will appear here when equipment enters the prototype.")
	else:
		var stage: Dictionary=value.get("stage",{})
		line(content,str(value.get("track",""))+" · "+str(stage.get("label","")))
		line(content,str(stage.get("description","")))
		if kind=="stage": line(content,"COMPLETED" if stage.get("completed",false) else "AVAILABLE FROM LEVEL "+str(stage.get("gate",0)))
		if kind=="track_choice":
			for option in value.get("options",[]):
				var choice := str(value.upgrade_id)+"|"+str(option.id)
				command(content,"choice:"+str(option.id),str(option.label)+(" · selected" if value.get("selected","")==choice else ""),func(): board.sheet_detail["selected"]=choice)
				line(content,str(option.get("description","")))
		if kind in ["upgrade","track_choice"]:
			line(content,"Permanent choice · "+str(value.get("cost",0))+" XP")
			var data: Dictionary=board.state.character_sheet_data()
			line(content,"COST "+str(value.get("cost",0))+" XP · REMAINING "+str(maxi(0,int(data.level_up_xp)-int(value.get("cost",0))))+" XP")
			var choice := str(value.get("selected","")) if kind=="track_choice" else str(value.get("upgrade_id",""))
			var confirm := command(content,"character:confirm","SPEND "+str(value.get("cost",0))+" XP",func():
				if not choice.is_empty() and board.state.choose_upgrade(choice):
					board.visual=board._presentation_snapshot(); board._mark_autosave(true); board.sheet_detail.clear())
			confirm.disabled=choice.is_empty()
