extends RefCounted

const DIRECTORY := "user://run-comments"
const MAX_TEXT := 2000
const MAX_PAYLOAD_BYTES := 65536

var directory: String

func _init(path: String = DIRECTORY) -> void:
	directory = path

static func new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

static func valid_id(id: String) -> bool:
	return id.length() == 32 and id == id.to_lower() and id[0] not in ["+", "-"] and id.is_valid_hex_number(false)

func enqueue(id: String, text: String, context: Dictionary) -> Error:
	if not valid_id(id) or text.strip_edges().is_empty() or text.length() > MAX_TEXT: return ERR_INVALID_PARAMETER
	var record := JSON.stringify({"schema": 1, "id": id, "text": text, "context": context})
	if record.to_utf8_buffer().size() > MAX_PAYLOAD_BYTES: return ERR_INVALID_DATA
	return _write_once(_note_path(id), record)

func pending_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if not DirAccess.dir_exists_absolute(directory): return ids
	for filename in DirAccess.get_files_at(directory):
		var id := filename.trim_suffix(".json")
		if filename.ends_with(".json") and valid_id(id) and receipt(id).is_empty(): ids.append(id)
	return ids

func payload(id: String) -> String:
	if not valid_id(id): return ""
	var file := FileAccess.open(_note_path(id), FileAccess.READ)
	if file == null or file.get_length() > MAX_PAYLOAD_BYTES: return ""
	return file.get_as_text()

func receipt(id: String) -> String:
	var record := payload(id)
	if record.is_empty(): return ""
	var file := FileAccess.open(directory.path_join(id + ".receipt"), FileAccess.READ)
	if file == null or file.get_length() > 4096: return ""
	return _verified_reference(id, record, JSON.parse_string(file.get_as_text()))

func acknowledge(id: String, response: Variant) -> Error:
	var record := payload(id)
	if record.is_empty(): return ERR_FILE_NOT_FOUND
	var reference := _verified_reference(id, record, response)
	if reference.is_empty(): return ERR_INVALID_DATA
	var receipt_path := directory.path_join(id + ".receipt")
	var confirmed := JSON.stringify({"id": id, "sha256": record.sha256_text(), "reference": reference})
	# A damaged or interrupted receipt must not permanently prevent a retry.
	if FileAccess.file_exists(receipt_path) and receipt(id).is_empty():
		var error := DirAccess.remove_absolute(receipt_path)
		if error != OK: return error
	return _write_once(receipt_path, confirmed)

func _verified_reference(id: String, record: String, response: Variant) -> String:
	if not response is Dictionary or response.get("id") != id or response.get("sha256") != record.sha256_text(): return ""
	var reference: Variant = response.get("reference")
	if not reference is String or reference.strip_edges().is_empty() or reference.length() > 512: return ""
	return reference

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
