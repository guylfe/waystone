extends RefCounted

const DIRECTORY := "user://run-comments"
const MAX_TEXT := 2000
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

func enqueue(id: String, text: String, context: Dictionary, send_publicly: bool = false) -> Error:
	if not valid_report_id(id) or not _valid_note(text): return ERR_INVALID_PARAMETER
	var note := {"schema": 2, "id": id, "text": text, "context": context, "send_publicly": send_publicly}
	var record := JSON.stringify(note)
	if record.to_utf8_buffer().size() > MAX_PAYLOAD_BYTES: return ERR_INVALID_DATA
	if send_publicly and _submission_for(id, note).is_empty(): return ERR_INVALID_DATA
	return _write_once(_note_path(id), record)

func pending_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id in saved_ids():
		if not submission(id).is_empty() and receipt(id).is_empty(): ids.append(id)
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
	if note.get("schema") != 2 or note.get("id") != id: return ""
	if not note.get("send_publicly") is bool or not note.send_publicly: return ""
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
		var issue_number := verified_issue_number(saved)
		if issue_number > 0:
			return {"issueNumber": issue_number, "issueUrl": saved.issueUrl}
	return {}

func acknowledge(id: String, response: Variant) -> Error:
	var record := payload(id)
	if record.is_empty(): return ERR_FILE_NOT_FOUND
	if _submission_for(id, JSON.parse_string(record)).is_empty(): return ERR_INVALID_DATA
	var issue_number := verified_issue_number(response)
	if issue_number == 0: return ERR_INVALID_DATA
	var receipt_path := directory.path_join(id + ".receipt")
	var confirmed := JSON.stringify({
		"id": id, "sha256": record.sha256_text(),
		"issueNumber": issue_number, "issueUrl": response.issueUrl,
	})
	# A damaged or interrupted receipt must not permanently prevent a retry.
	if FileAccess.file_exists(receipt_path) and receipt(id).is_empty():
		var error := DirAccess.remove_absolute(receipt_path)
		if error != OK: return error
	return _write_once(receipt_path, confirmed)

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
