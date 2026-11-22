extends Node
## Owns delivery across boards and modes. The durable queue owns the note and receipt.

signal changed

const Queue = preload("res://scripts/core/run_comment_queue.gd")
const Delivery = preload("res://scripts/core/run_comment_delivery.gd")
const CONFIG_PATH := "user://run-comment-delivery.cfg"
const RETRY_MIN := 2.0
const RETRY_MAX := 60.0

var queue := Queue.new()
var endpoint := ""
var _token := ""
var pending := PackedStringArray()
var delivered_count := 0
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
		var address := String(settings.get_value("relay", "endpoint", ""))
		var token := String(settings.get_value("relay", "token", ""))
		if Delivery.valid_configuration(address, token):
			endpoint = address
			_token = token
	note_saved()

func configure(address: String, token: String) -> Error:
	address = address.strip_edges()
	# An empty token keeps the stored credential only for this exact address.
	if address == endpoint and token.is_empty(): token = _token
	if not Delivery.valid_configuration(address, token): return ERR_INVALID_PARAMETER
	if address == endpoint and token == _token: return OK
	var settings := ConfigFile.new()
	settings.set_value("relay", "endpoint", address)
	settings.set_value("relay", "token", token)
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
	delivered_count = 0
	latest_reference = ""
	var latest := -1
	for id in queue.saved_ids():
		var reference := queue.receipt(id)
		if reference.is_empty():
			pending.append(id)
			continue
		delivered_count += 1
		var confirmed_at := FileAccess.get_modified_time(queue.directory.path_join(id + ".receipt"))
		if confirmed_at >= latest:
			latest = confirmed_at
			latest_reference = reference
	changed.emit()
	if not endpoint.is_empty() and not pending.is_empty() and not _running and _retry.is_stopped():
		_retry.start(0.1)

func summary() -> String:
	var details := "%d queued · %d delivered" % [pending.size(), delivered_count]
	if endpoint.is_empty(): return details + "\nDelivery is off. Notes stay on this device."
	if _rejected: return details + "\nRelay rejected the token. Check Delivery settings."
	if not pending.is_empty(): return details + "\nDelivery retries automatically."
	return details

func _drain() -> void:
	if endpoint.is_empty() or pending.is_empty(): return
	_running = true
	var settings_version := _settings_version
	var failed := false
	for id in pending.duplicate():
		var result := await _transport.deliver(queue, id, endpoint, _token)
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
