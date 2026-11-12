extends RefCounted
# Presentation of existing committed state only; no future-choice prediction.
static func duellist(enemy: Dictionary) -> Dictionary:
	var action:Dictionary=enemy.get("action",{})
	var kind:=String(action.get("kind","idle"))
	var elapsed:=float(action.get("elapsed",0))
	var parry:="PARRY AVAILABLE"
	var detail:="Parry available while ready; swinging into its front may draw it."
	if kind=="parry_stance" and elapsed<=float(action.get("parry_end",0.42)):
		parry="PARRY ACTIVE";detail="Its front parry is active now."
	elif kind not in ["idle","move"]:
		parry="PARRY LOCKED";detail="Cannot start a parry during this commitment. Check readiness again after recovery."
	elif float(enemy.get("parry_cooldown",0))>0:
		parry="PARRY RECHARGING";detail="Parry temporarily unavailable; it recharges as world time advances."
	elif String(enemy.get("awareness","idle"))!="alerted":
		parry="PARRY UNAWARE";detail="It is not watching for an attack yet."
	var tell:="READY" if kind=="idle" else "MOVING" if kind=="move" else kind.replace("_"," ").to_upper()
	if kind=="melee":
		var technique:="THRUST" if String(action.get("technique_id",""))=="rapier_thrust" else "CUT"
		var active_end:=float(action.get("active_end",0))
		var duration:=float(action.get("duration",active_end))
		var phase:="WINDUP" if elapsed<float(action.get("startup",0)) else "STRIKING"
		if elapsed>active_end:
			var remaining:=maxf(0,duration-elapsed)
			var recovery:=maxf(0.001,duration-active_end)
			phase="RECOVERY EARLY" if remaining/recovery>0.6667 else "RECOVERY ENDING" if remaining/recovery<0.3334 else "RECOVERY"
		tell=technique+" · "+phase
	return {"tell":tell,"parry":parry,"detail":detail,"warning":"Thrust and cut leave different openings. Recovery may end before your attack lands, and parry may return. RECOVERING does not guarantee a safe full combo."}
