extends RefCounted
# One measured allocation used by layout, drawing and input. Explicit units also
# support labelled headless density models; production supplies MenuMetrics.unit.
static func paragraph(text: String, width: float, font_size: int) -> TextParagraph:
	var p:=TextParagraph.new()
	p.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
	p.width=maxf(1,width)
	p.add_string(text,ThemeDB.fallback_font,font_size)
	return p

static func build(board, u: float) -> Dictionary:
	var area:Rect2=board.board_rect
	var gap:=8*u
	var width:=maxf(1,area.size.x-2*gap)
	var font:=roundi(12*u)
	var xp:=paragraph(board._hud_location_text(),width,font)
	var log:=paragraph(board._hud_log_text(),width,font)
	# Reserve all three ordinary selection hints, so selecting/cancelling/refusing
	# does not move the action under a finger. Longer unrelated logs still wrap.
	var log_height:=log.get_size().y
	for method in ["pointer","keyboard","controller"]:
		log_height=maxf(log_height,paragraph(board._commit_shot_selection_text(method),width,font).get_size().y)
	var log_rect:=Rect2(Vector2(area.position.x+gap,area.end.y-gap-log_height),Vector2(width,log_height))
	var xp_rect:=Rect2(Vector2(log_rect.position.x,log_rect.position.y-gap-xp.get_size().y),Vector2(width,xp.get_size().y))
	var attack_size:Vector2=board.attack_rect.size
	var row_height:=maxf(64*u,attack_size.y)
	var row_top:=xp_rect.position.y-gap-row_height
	var commit:=Rect2(Vector2(area.position.x+gap,row_top),Vector2(156,64)*u)
	var attack:=Rect2(Vector2(area.end.x-attack_size.x-gap,row_top+(row_height-attack_size.y)*0.5),attack_size)
	var idle_text:="Held: press a labelled button to use it" if board.controller.palette_open else "Hold for spell / item shortcuts"
	var idle:=paragraph(idle_text,width-48*u,roundi(16*u))
	var idle_height:=maxf(30*u,idle.get_size().y)+16*u
	var idle_rect:=Rect2(Vector2(area.position.x+gap,row_top-gap-idle_height),Vector2(width,idle_height))
	var action:String=board.controller.targeting_action
	var committed_target:=action in ["","commit_shot"]
	# Full commitment/price/input remain in the log and Character help. The pad
	# panel repeats only the benefit and commands, keeping the central field clear
	# at supported high-density portrait sizes without reducing font/target minima.
	var label:String="Full shot +25%" if committed_target else "Concussion flask" if action=="adopted" else board.state.spell_label(action)
	var title:=paragraph(label if committed_target else label+" · TIME STOPPED",width-16*u,roundi(17*u))
	var column:=(width-32*u)/3
	var hints:Array=[]
	var hint_height:=0.0
	for text in ["Choose" if committed_target else "Place marker","Commit" if committed_target else "Use here","Cancel"]:
		var p:=paragraph(text,column,roundi(14*u));hints.append(p);hint_height=maxf(hint_height,p.get_size().y)
	var dense:=width/u<300
	var title_inset:=4.0 if dense else 8.0
	var hint_offset:=8.0 if dense else 16.0
	var hint_label_offset:=24.0 if dense else 26.0
	var target_height:=title.get_size().y+hint_height+(36 if dense else 54)*u
	var target_rect:=Rect2(Vector2(area.position.x+gap,row_top-gap-target_height),Vector2(width,target_height))
	# Put the opaque guidance below the action row, away from the ordinary central
	# target marker. Reserve its tallest state so arming/cancelling cannot move input.
	var context_height:=maxf(idle_height,target_height)
	row_top=xp_rect.position.y-2*gap-context_height-row_height
	commit.position.y=row_top
	attack.position.y=row_top+(row_height-attack_size.y)*0.5
	idle_rect.position.y=xp_rect.position.y-gap-idle_height
	target_rect.position.y=xp_rect.position.y-gap-target_height
	# A narrow client measured in density units has insufficient room to stack a
	# second opaque guidance panel under the buttons. Dock guidance to the fixed
	# top edge instead, leaving the central field between it and the bottom HUD.
	# This depends only on available space, never on a selected target's position.
	if dense and board.view_mode=="isometric":
		commit.position.y=xp_rect.position.y-gap-row_height
		attack.position.y=commit.position.y+(row_height-attack_size.y)*0.5
		var toolbar_bottom:=area.position.y
		for name in ["sheet_button_rect","view_rect","map_rect","reset_rect","survey_end_rect"]:
			toolbar_bottom=maxf(toolbar_bottom,Rect2(board.get(name)).end.y)
		idle_rect.position.y=toolbar_bottom+gap
		target_rect.position.y=toolbar_bottom+gap
	return {"unit":u,"font":font,"commit":commit,"attack":attack,"xp":xp_rect,"log":log_rect,"xp_paragraph":xp,"log_paragraph":log,
		"idle":idle_rect,"idle_paragraph":idle,"targeting":target_rect,"title_paragraph":title,"hint_paragraphs":hints,"hint_column":column,"hint_keys":["rsc" if committed_target else "rs","a","b"],"title_inset":title_inset,"hint_offset":hint_offset,"hint_label_offset":hint_label_offset}
