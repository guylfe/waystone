extends Node
## Owns delivery across boards and modes. The durable queue owns the note and receipt.

signal changed
signal file_sent

const Queue = preload("res://scripts/core/run_comment_queue.gd")
const Delivery = preload("res://scripts/core/run_comment_delivery.gd")
const CONFIG_SECTION := "file_delivery"
const CONFIG_PATH := "user://run-comment-file-delivery.cfg"
const RETRY_MIN := 2.0
const RETRY_MAX := 60.0

var queue := Queue.new()
var endpoint := Delivery.DEFAULT_ENDPOINT
var pending := PackedStringArray()
var sent_count := 0
var local_count := 0
var rejected_count := 0
var _running := false
var _delay := RETRY_MIN
var _retry_at := 0.0
var _rejected_reports := {}
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
		_retry_at = float(settings.get_value(CONFIG_SECTION, "retry_at", 0.0))
		if not is_finite(_retry_at): _retry_at = 0.0
	note_saved()

func _write_retry_deadline() -> Error:
	var settings := ConfigFile.new()
	settings.set_value(CONFIG_SECTION, "retry_at", _retry_at)
	var temporary := CONFIG_PATH + ".tmp"
	var error := settings.save(temporary)
	if error == OK: error = DirAccess.rename_absolute(temporary, CONFIG_PATH)
	if error != OK and FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	return error

func note_saved() -> void:
	pending.clear()
	sent_count = 0
	local_count = 0
	rejected_count = 0
	for id in queue.saved_ids():
		var receipt := queue.receipt(id)
		if receipt.is_empty():
			var rejection := int(_rejected_reports.get(id, 0))
			if rejection == 0: rejection = queue.rejection(id)
			if rejection != 0:
				rejected_count += 1
			elif queue.submission(id).is_empty(): local_count += 1
			else: pending.append(id)
			continue
		if receipt.has("filePath") or receipt.has("issueNumber"): sent_count += 1
		else: local_count += 1
	changed.emit()
	_schedule()

func _schedule() -> void:
	if pending.is_empty() or _running or not _retry.is_stopped(): return
	_retry.start(maxf(0.1, _retry_at - Time.get_unix_time_from_system()))

func summary() -> String:
	var details := "%d queued · %d sent · %d local" % [pending.size(), sent_count, local_count]
	if rejected_count > 0: details += " · %d could not be sent" % rejected_count
	return details

func _drain() -> void:
	if pending.is_empty(): return
	if Time.get_unix_time_from_system() < _retry_at:
		_schedule()
		return
	_running = true
	var failed := false
	var deadline := 0.0
	for id in pending.duplicate():
		var result := await _transport.deliver(queue, id, endpoint)
		if result.error == OK:
			file_sent.emit()
			continue
		if result.status in [400, 409]:
			_rejected_reports[id] = result.status
			queue.reject(id, result.status)
			continue
		failed = true
		deadline = maxf(deadline, result.retry_at)
		# A server-directed wait or connectivity failure pauses the whole outbox.
		if result.status in Delivery.DEFERRED_STATUSES or result.error in [ERR_CONNECTION_ERROR, ERR_CANT_CONNECT, ERR_CANT_RESOLVE]:
			break
	_running = false
	var previous_retry_at := _retry_at
	_retry_at = maxf(Time.get_unix_time_from_system() + _delay, deadline) if failed else 0.0
	_delay = minf(_delay * 2.0, RETRY_MAX) if failed else RETRY_MIN
	if _retry_at != previous_retry_at: _write_retry_deadline()
	note_saved()
