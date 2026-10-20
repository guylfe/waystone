extends SceneTree
const Policy = preload("res://tests/combat_lab_policy_trace.gd")
const Lab = preload("res://scripts/experiments/combat_lab_catalog.gd")
var failures: Array = []
var results: Array = []

func replay(source: Dictionary, variant: String, prefix: String = "replay-") -> Dictionary:
	var initial: Dictionary = source["initial"]
	var trace = Policy.Trace.new(variant,initial["fixture"],initial["resources"],initial["loadout"])
	for input in source["inputs"]:
		if input["kind"] == "abandon_funnel": continue
		trace.submit(input["kind"],Vector2(float(input["direction"][0]),float(input["direction"][1])),float(input["value"]))
	var result: Dictionary = trace.finish(prefix+source["summary"]["name"])
	result["original_digest"] = source["summary"]["final_digest"]
	result["matches"] = result["final_digest"] == result["original_digest"]
	return result

func _init() -> void:
	var directory := DirAccess.open("res://.runtime/policy-traces")
	var files := directory.get_files()
	for filename in files:
		if filename.begins_with("replay-") or filename.begins_with("fixed-C-") or filename.contains("large-floor"): continue
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.runtime/policy-traces/"+filename))
		var result := replay(source,source["initial"]["variant"])
		results.append(result)
		if not result["matches"]: failures.append(filename+" exact input replay mismatch")
	var fixed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.runtime/policy-traces/F2-purposeful-C.json"))
	for variant in ["A","B","G","E"]:
		var result := replay(fixed,variant,"fixed-C-")
		result["comparison"] = "unchanged C purposeful inputs across variants; no equality requirement"
		results.append(result)
	var file := FileAccess.open("res://.runtime/replay-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(Lab.json_safe({"failures":failures,"results":results}),"\t"))
	for failure in failures: print("FAILED: ",failure)
	print("REPLAY runs=",results.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
