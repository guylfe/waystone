extends "res://tests/commit_shot_input_test.gd"
# Paired copy regression through normal-root input, current rule and cost owners.
func help_case(route:String,rules:String):
	await setup(rules,"isometric")
	var s=board.state
	var cost:float=s.energy_cost(18)
	var time:float=s.simulation_time;var spent:float=s.energy_spent_total
	await select(route)
	var hint:String=s.message
	check(board.selected_action=="commit_shot","routed selection "+route)
	if rules=="energy":check(hint.contains("%.1f Energy" % cost),"actual scaled price "+route+str(cost)+" "+hint)
	else:check(hint.contains("no Energy debit") and not hint.contains("18 base Energy"),"Recovery price truth "+route+hint)
	if route=="keyboard":check(hint.contains("[G]") and hint.contains("[Tab]") and hint.contains("[Enter]") and not hint.contains("tap a"),"keyboard-specific controls")
	elif route=="touch":check(hint.contains("tap") and not hint.contains("[G]") and not hint.contains("[Enter]"),"touch-specific controls")
	else:check(hint.contains("[A]") and hint.contains("[B]") and hint.contains("right-stick click") and not hint.contains("[G]") and not hint.contains("tap a"),"pad-specific controls")
	check(s.simulation_time==time and s.energy_spent_total==spent,"copy selection remains free/frozen")
	if route=="keyboard":await keytap(KEY_G)
	elif route=="touch":await tap(board.commit_shot_rect.get_center())
	else:await pad(JOY_BUTTON_B)
	check(board.selected_action=="" and s.simulation_time==time and s.energy_spent_total==spent,"cancel remains free/frozen")
	records.append({"route":route,"rules":rules,"cost_owner":cost,"hint":hint,"time":time,"spent":spent})
	await finish()
func run():
	for route in ["touch","keyboard","pad"]:
		await help_case(route,"energy");await help_case(route,"recovery")
	var f=FileAccess.open("user://commit-shot-help-results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"));f.close()
	print("COMMIT SHOT HELP ",checks," checks / ",records.size()," cases / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
