extends RefCounted

const DIRECTORY := "user://run-comments"
const MAX_TEXT := 2000
const MAX_CONTEXT_BYTES := 8192
const MAX_REQUEST_BYTES := 16384
const BUILD_VERSION := "^[A-Za-z0-9_.+ /()-]{1,96}\\z"
const MAX_PAYLOAD_BYTES := 65536
const ISSUE_URL_PREFIX := "https://github.com/guylfe/waystone/issues/"
const REPORT_ID := "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\\z"

var directory: String

func _init(path: String = DIRECTORY) -> void:
	directory = path

static func new_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20)]

static func valid_report_id(id: String) -> bool:
	return RegEx.create_from_string(REPORT_ID).search(id) != null

static func valid_id(id: String) -> bool:
	if id.length() == 32:
		return id == id.to_lower() and id[0] not in ["+", "-"] and id.is_valid_hex_number(false)
	return valid_report_id(id)

func enqueue(id: String, text: String, context: Dictionary, send_feedback: bool = false) -> Error:
	if not valid_report_id(id) or text.strip_edges().is_empty() or text.to_utf16_buffer().size() > 2 * MAX_TEXT:
		return ERR_INVALID_PARAMETER
	var note := {"schema": 4, "id": id, "text": text, "context": context, "send_feedback": send_feedback}
	if send_feedback:
		var build: Variant = context.get("game_version")
		if not build is String or RegEx.create_from_string(BUILD_VERSION).search(build) == null:
			return ERR_INVALID_DATA
		var report := {"game": "waystone", "reportId": id, "build": build, "note": text, "context": {}}
		# Subtract the rest of the envelope, excluding the two empty-context braces.
		var context_limit := mini(MAX_CONTEXT_BYTES, MAX_REQUEST_BYTES - _json_size(report) + 2)
		var wire_context := _bounded_context(context, context_limit)
		if _json_size(wire_context) > context_limit: return ERR_INVALID_DATA
		report["context"] = wire_context
		# Persist the exact consented request before the first attempt.
		note["submission"] = _json_text(report)
	var record := _json_text(note)
	if record.to_utf8_buffer().size() > MAX_PAYLOAD_BYTES: return ERR_INVALID_DATA
	return _write_once(_note_path(id), record)

static func truncate_note(text: String) -> String:
	if text.to_utf16_buffer().size() <= 2 * MAX_TEXT: return text
	var units := 0
	for index in text.length():
		units += 2 if text.unicode_at(index) > 0xffff else 1
		if units > MAX_TEXT: return text.left(index)
	return text

static func _bounded_context(context: Dictionary, limit: int) -> Dictionary:
	if _json_size(context) <= limit: return context
	var bounded := context.duplicate(true)
	for key in ["recent_messages", "recent_enemy_actions", "enemies"]:
		var entries: Variant = bounded.get(key)
		if not entries is Array: continue
		while not entries.is_empty() and _json_size(bounded) > limit:
			if key == "enemies": entries.pop_back()
			else: entries.pop_front()
	return bounded

static func _json_size(value: Dictionary) -> int:
	return _json_text(value).to_utf8_buffer().size()

static func _json_text(value: Dictionary) -> String:
	var encoded := JSON.stringify(value)
	# Godot leaves some C0 controls raw in compact strings. Escape only raw
	# controls so both the local record and request body are strict JSON.
	for code in range(1, 0x20):
		var control := String.chr(code)
		if encoded.contains(control):
			encoded = encoded.replace(control, "\\u%04x" % code)
	return encoded

func pending_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id in saved_ids():
		if not submission(id).is_empty() and receipt(id).is_empty() and rejection(id) == 0: ids.append(id)
	return ids

func saved_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if not DirAccess.dir_exists_absolute(directory): return ids
	for filename in DirAccess.get_files_at(directory):
		var id := filename.trim_suffix(".json")
		if filename.ends_with(".json") and valid_id(id): ids.append(id)
	return ids

func payload(id: String) -> String:
	if not valid_id(id): return ""
	var file := FileAccess.open(_note_path(id), FileAccess.READ)
	if file == null or file.get_length() > MAX_PAYLOAD_BYTES: return ""
	return file.get_as_text()

func submission(id: String) -> String:
	return _submission_for(id, JSON.parse_string(payload(id)))

static func _submission_for(id: String, note: Variant) -> String:
	if not valid_report_id(id) or not note is Dictionary: return ""
	if note.get("id") != id: return ""
	var consent: Variant = note.get("send_feedback") if note.get("schema") == 4 else note.get("send_publicly")
	if not consent is bool or not consent: return ""
	var schema: Variant = note.get("schema")
	if schema == 2: return _schema_two_submission(id, note)
	if schema != 3 and schema != 4: return ""
	var stored: Variant = note.get("submission")
	if not stored is String: return ""
	var body: Variant = JSON.parse_string(stored)
	if not body is Dictionary or body.get("game") != "waystone" or body.get("reportId") != id or body.get("note") != note.get("text"): return ""
	return stored

static func _schema_two_submission(id: String, note: Dictionary) -> String:
	# Existing queued UUIDs must retain the exact 0.3.10 wire representation,
	# even when the new service would reject a field under its current limits.
	var text: Variant = note.get("text")
	var context: Variant = note.get("context")
	if not _valid_note(text) or not context is Dictionary: return ""
	var build: Variant = context.get("build")
	if not build is String or build.strip_edges().is_empty() or build.length() > 120: return ""
	var body := JSON.stringify({"game": "waystone", "reportId": id, "build": build, "note": text, "context": context})
	return body if body.to_utf8_buffer().size() <= MAX_PAYLOAD_BYTES else ""

static func _valid_note(note: Variant) -> bool:
	return note is String and not note.strip_edges().is_empty() and note.length() <= MAX_TEXT

func receipt(id: String) -> Dictionary:
	var record := payload(id)
	if record.is_empty(): return {}
	var file := FileAccess.open(directory.path_join(id + ".receipt"), FileAccess.READ)
	if file == null or file.get_length() > 4096: return {}
	var saved: Variant = JSON.parse_string(file.get_as_text())
	if not saved is Dictionary or saved.get("id") != id or saved.get("sha256") != record.sha256_text(): return {}
	var note: Variant = JSON.parse_string(record)
	if note is Dictionary and note.get("schema") == 1:
		# Keep pre-publication receipts readable without enrolling their notes.
		var reference: Variant = saved.get("reference")
		if reference is String and not reference.strip_edges().is_empty() and reference.length() <= 512:
			return {"reference": reference}
	elif not _submission_for(id, note).is_empty():
		if _valid_file_receipt(id, saved): return {"filePath": saved.filePath}
		if note.get("schema") == 4: return {}
		var issue_number := verified_issue_number(saved)
		if issue_number > 0:
			return {"issueNumber": issue_number, "issueUrl": saved.issueUrl}
	return {}

func acknowledge(id: String, response: Variant) -> Error:
	var record := payload(id)
	if record.is_empty(): return ERR_FILE_NOT_FOUND
	if _submission_for(id, JSON.parse_string(record)).is_empty(): return ERR_INVALID_DATA
	if not _valid_file_receipt(id, response): return ERR_INVALID_DATA
	var receipt_path := directory.path_join(id + ".receipt")
	var confirmed := JSON.stringify({
		"id": id, "sha256": record.sha256_text(),
		"game": "waystone", "reportId": id, "filePath": response.filePath,
	})
	# A damaged or interrupted receipt must not permanently prevent a retry.
	if FileAccess.file_exists(receipt_path) and receipt(id).is_empty():
		var error := DirAccess.remove_absolute(receipt_path)
		if error != OK: return error
	return _write_once(receipt_path, confirmed)

func reject(id: String, status: int) -> Error:
	var body := submission(id)
	if body.is_empty() or status not in [400, 409]: return ERR_INVALID_PARAMETER
	var path := _rejection_path(id)
	if FileAccess.file_exists(path) and rejection(id) == 0:
		var error := DirAccess.remove_absolute(path)
		if error != OK: return error
	return _write_once(path, JSON.stringify({"sha256": body.sha256_text(), "status": status}))

func rejection(id: String) -> int:
	if not valid_report_id(id): return 0
	var file := FileAccess.open(_rejection_path(id), FileAccess.READ)
	if file == null or file.get_length() > 512: return 0
	var saved: Variant = JSON.parse_string(file.get_as_text())
	if not saved is Dictionary: return 0
	var status: Variant = saved.get("status")
	if status != 400 and status != 409: return 0
	var body := submission(id)
	if body.is_empty() or saved.get("sha256") != body.sha256_text(): return 0
	return int(status)

func _rejection_path(id: String) -> String:
	return directory.path_join(id + ".v3.rejected")

static func _valid_file_receipt(id: String, response: Variant) -> bool:
	return response is Dictionary and response.get("game") == "waystone" and response.get("reportId") == id and response.get("filePath") == "playtest-feedback/" + id + ".json"

# Only for locally persisted receipts from the previous release.
static func verified_issue_number(response: Variant) -> int:
	if not response is Dictionary: return 0
	var number: Variant = response.get("issueNumber")
	if not number is int and not number is float: return 0
	# Godot parses JSON numbers as floats. Require an exact, positive integer.
	if not is_finite(number) or number < 1 or number > 9007199254740991 or number != floor(number):
		return 0
	var issue_number := int(number)
	var url: Variant = response.get("issueUrl")
	return issue_number if url is String and url == ISSUE_URL_PREFIX + str(issue_number) else 0

func _note_path(id: String) -> String:
	return directory.path_join(id + ".json")

func _write_once(path: String, content: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK: return error
	if FileAccess.file_exists(path):
		return OK if FileAccess.get_file_as_string(path) == content else ERR_ALREADY_EXISTS
	var temporary := path + "." + new_id() + ".pending"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	if not file.store_string(content):
		error = file.get_error()
		file.close()
		DirAccess.remove_absolute(temporary)
		return error if error != OK else ERR_FILE_CANT_WRITE
	file.flush()
	error = file.get_error()
	file.close()
	if error == OK: error = DirAccess.rename_absolute(temporary, path)
	if error != OK: DirAccess.remove_absolute(temporary)
	return error
