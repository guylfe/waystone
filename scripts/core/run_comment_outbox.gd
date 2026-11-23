extends Node
## Owns delivery across boards and modes. The durable queue owns the note and receipt.

signal changed
signal issue_sent(issue_number: int)

const Queue = preload("res://scripts/core/run_comment_queue.gd")
const Delivery = preload("res://scripts/core/run_comment_delivery.gd")
const CONFIG_SECTION := "feedback"
const CONFIG_PATH := "user://run-comment-delivery.cfg"
const RETRY_MIN := 2.0
const RETRY_MAX := 60.0

var queue := Queue.new()
var endpoint := ""
var _token := ""
var pending := PackedStringArray()
var sent_count := 0
var local_count := 0
var latest_issue_number := 0
var latest_reference := ""
var _running := false
var _delay := RETRY_MIN
var _settings_version := 0
var _rejected := false
var _transport := Delivery.new()
var _retry := Timer.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_transport.use_threads = true
	add_child(_transport)
	_retry.one_shot = true
	_retry.ignore_time_scale = true
	add_child(_retry)
	_retry.timeout.connect(_drain)
	var settings := ConfigFile.new()
	if settings.load(CONFIG_PATH) == OK:
		var address := String(settings.get_value(CONFIG_SECTION, "endpoint", ""))
		var token := String(settings.get_value(CONFIG_SECTION, "token", ""))
		if Delivery.valid_configuration(address, token):
			endpoint = address
			_token = token
	note_saved()

func configure(address: String, token: String) -> Error:
	address = address.strip_edges()
	if not address.is_empty():
		address = Delivery.service_endpoint(address)
		if address.is_empty(): return ERR_INVALID_PARAMETER
	# An empty token keeps the stored credential only for this exact address.
	if address == endpoint and token.is_empty(): token = _token
	if not Delivery.valid_configuration(address, token): return ERR_INVALID_PARAMETER
	if address == endpoint and token == _token: return OK
	var settings := ConfigFile.new()
	# Keep pre-publication relay settings on disk for compatibility. They
	# authorize a different protocol and are never loaded by this client.
	if FileAccess.file_exists(CONFIG_PATH) and settings.load(CONFIG_PATH) != OK:
		settings = ConfigFile.new()
	settings.set_value(CONFIG_SECTION, "endpoint", address)
	settings.set_value(CONFIG_SECTION, "token", token)
	var temporary := CONFIG_PATH + ".tmp"
	var error := settings.save(temporary)
	if error == OK: error = DirAccess.rename_absolute(temporary, CONFIG_PATH)
	if error != OK:
		if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
		return error
	endpoint = address
	_token = token
	_settings_version += 1
	_delay = RETRY_MIN
	_rejected = false
	_retry.stop()
	note_saved()
	return OK

func note_saved() -> void:
	pending.clear()
	sent_count = 0
	local_count = 0
	latest_issue_number = 0
	latest_reference = ""
	var latest_issue_time := -1
	var latest_legacy_time := -1
	var legacy_reference := ""
	for id in queue.saved_ids():
		var receipt := queue.receipt(id)
		if receipt.is_empty():
			if queue.submission(id).is_empty(): local_count += 1
			else: pending.append(id)
			continue
		var confirmed_at := FileAccess.get_modified_time(queue.directory.path_join(id + ".receipt"))
		if receipt.has("issueNumber"):
			sent_count += 1
			if confirmed_at > latest_issue_time or (confirmed_at == latest_issue_time and receipt.issueNumber > latest_issue_number):
				latest_issue_time = confirmed_at
				latest_issue_number = receipt.issueNumber
				latest_reference = receipt.issueUrl
		else:
			local_count += 1
			if confirmed_at >= latest_legacy_time:
				latest_legacy_time = confirmed_at
				legacy_reference = receipt.reference
	if latest_reference.is_empty(): latest_reference = legacy_reference
	changed.emit()
	if not endpoint.is_empty() and not pending.is_empty() and not _running and _retry.is_stopped():
		_retry.start(0.1)

func summary() -> String:
	var details := "%d queued · %d sent · %d local" % [pending.size(), sent_count, local_count]
	if latest_issue_number > 0: details = issue_label(latest_issue_number) + "\n" + details
	return details

static func issue_label(issue_number: int) -> String:
	return "Sent as GitHub issue #%d" % issue_number

func delivery_status() -> String:
	if endpoint.is_empty(): return "Set up Delivery to send queued feedback."
	if _rejected: return "The service rejected this token. Check Delivery settings."
	if not pending.is_empty(): return "Queued feedback retries automatically."
	return ""

func _drain() -> void:
	if endpoint.is_empty() or pending.is_empty(): return
	_running = true
	var settings_version := _settings_version
	var failed := false
	for id in pending.duplicate():
		var result := await _transport.deliver(queue, id, endpoint, _token)
		if result == OK:
			var issue_number := int(queue.receipt(id).get("issueNumber", 0))
			if issue_number > 0: issue_sent.emit(issue_number)
		if settings_version != _settings_version: break
		failed = failed or result != OK
		_rejected = result == ERR_UNAUTHORIZED
		# An unreachable or unauthorized relay affects the whole queue.
		if _rejected or result in [ERR_CONNECTION_ERROR, ERR_CANT_CONNECT, ERR_CANT_RESOLVE]: break
		if result == OK: note_saved()
	_running = false
	if failed and settings_version == _settings_version:
		_retry.start(_delay)
		_delay = minf(_delay * 2.0, RETRY_MAX)
	else:
		_delay = RETRY_MIN
	note_saved()
