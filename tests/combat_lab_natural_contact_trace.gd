extends SceneTree
const Lab = preload("res://scripts/experiments/combat_lab_catalog.gd")

func _init() -> void:
	var state = Lab.create("C","F2","warrior","full","energy",false)
	state.lab_input_neutral()
	var frames: Array = []
	for step in range(4):
		if step > 0:
			if not state.request_wait(0.5,true):
				push_error("Natural Wait refused")
				quit(1)
				return
		var world := Lab.authoritative(state)
		frames.append({"step":step,"time":state.simulation_time,"digest":Lab.digest(world),"world":world})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime"))
	FileAccess.open("res://.runtime/natural-contact-trace.json",FileAccess.WRITE).store_string(JSON.stringify(Lab.json_safe(frames),"\t"))
	print("NATURAL_CONTACT frames=",frames.size()," final_time=",state.simulation_time)
	quit(0)
