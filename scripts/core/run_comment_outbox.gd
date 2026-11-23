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
var rejected_count := 0
var latest_issue_number := 0
var latest_reference := ""
var _running := false
var _delay := RETRY_MIN
var _retry_at := 0.0
var _rejected_reports := {}
var _invalid_count := 0
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
			_rejected = not endpoint.is_empty() and settings.get_value(CONFIG_SECTION, "rejected", false) == true
			_retry_at = float(settings.get_value(CONFIG_SECTION, "retry_at", 0.0))
			if not is_finite(_retry_at): _retry_at = 0.0
	note_saved()

func configure(address: String, token: String) -> Error:
	address = address.strip_edges()
	token = token.strip_edges()
	if address.is_empty() and not token.is_empty(): address = Delivery.DEFAULT_ENDPOINT
	if not address.is_empty():
		address = Delivery.service_endpoint(address)
		if address.is_empty(): return ERR_INVALID_PARAMETER
	# An empty code keeps the stored credential only for this exact address.
	if address == endpoint and token.is_empty(): token = _token
	if not Delivery.valid_configuration(address, token): return ERR_INVALID_PARAMETER
	if address == endpoint and token == _token: return OK
	var retry_at := _retry_at if address == endpoint else 0.0
	var error := _write_configuration(address, token, false, retry_at)
	if error != OK: return error
	endpoint = address
	_token = token
	_settings_version += 1
	_delay = RETRY_MIN
	_rejected = false
	_retry_at = retry_at
	_retry.stop()
	note_saved()
	return OK

func _write_configuration(address: String, token: String, rejected: bool, retry_at: float) -> Error:
	var settings := ConfigFile.new()
	# Keep pre-publication relay settings on disk for compatibility. They
	# authorize a different protocol and are never loaded by this client.
	if FileAccess.file_exists(CONFIG_PATH) and settings.load(CONFIG_PATH) != OK:
		settings = ConfigFile.new()
	settings.set_value(CONFIG_SECTION, "endpoint", address)
	settings.set_value(CONFIG_SECTION, "token", token)
	settings.set_value(CONFIG_SECTION, "rejected", rejected)
	settings.set_value(CONFIG_SECTION, "retry_at", retry_at)
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
	_invalid_count = 0
	latest_issue_number = 0
	latest_reference = ""
	var latest_issue_time := -1
	var latest_legacy_time := -1
	var legacy_reference := ""
	for id in queue.saved_ids():
		var receipt := queue.receipt(id)
		if receipt.is_empty():
			var rejection := int(_rejected_reports.get(id, 0))
			if rejection == 0: rejection = queue.rejection(id)
			if rejection != 0:
				rejected_count += 1
				if rejection == 400: _invalid_count += 1
			elif queue.submission(id).is_empty(): local_count += 1
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
	_schedule()

func _schedule() -> void:
	if endpoint.is_empty() or pending.is_empty() or _rejected or _running or not _retry.is_stopped(): return
	_retry.start(maxf(0.1, _retry_at - Time.get_unix_time_from_system()))

func summary() -> String:
	var details := "%d %s · %d sent · %d local" % [pending.size(), "paused" if _rejected else "queued", sent_count, local_count]
	if rejected_count > 0: details += " · %d rejected" % rejected_count
	if latest_issue_number > 0: details = issue_label(latest_issue_number) + "\n" + details
	return details

static func issue_label(issue_number: int) -> String:
	return "Sent as GitHub issue #%d" % issue_number

func delivery_status() -> String:
	var messages := PackedStringArray()
	if endpoint.is_empty(): messages.append("Enter your Waystone playtester code to send queued feedback.")
	elif _rejected: messages.append("Delivery paused. Enter a new Waystone playtester code.")
	elif not pending.is_empty(): messages.append("Queued feedback retries automatically.")
	if _invalid_count > 0: messages.append("%d report(s) had invalid details." % _invalid_count)
	var conflicts := rejected_count - _invalid_count
	if conflicts > 0: messages.append("%d report(s) had a report ID or enrollment conflict." % conflicts)
	if rejected_count > 0: messages.append("The notes are saved on this device. Contact the playtest organizer before resending.")
	return "\n".join(messages)

func _drain() -> void:
	if endpoint.is_empty() or pending.is_empty() or _rejected: return
	if Time.get_unix_time_from_system() < _retry_at:
		_schedule()
		return
	_running = true
	var settings_version := _settings_version
	var failed := false
	var deadline := 0.0
	for id in pending.duplicate():
		var result := await _transport.deliver(queue, id, endpoint, _token)
		if result.error == OK:
			var issue_number := int(queue.receipt(id).get("issueNumber", 0))
			if issue_number > 0: issue_sent.emit(issue_number)
		if settings_version != _settings_version: break
		if result.error == ERR_UNAUTHORIZED:
			_rejected = true
			break
		if result.status in [400, 409]:
			_rejected_reports[id] = result.status
			queue.reject(id, result.status)
			continue
		if result.error == OK: continue
		failed = true
		deadline = maxf(deadline, result.retry_at)
		# A server-directed wait or connectivity failure pauses the whole outbox.
		if result.status in Delivery.DEFERRED_STATUSES or result.error in [ERR_CONNECTION_ERROR, ERR_CANT_CONNECT, ERR_CANT_RESOLVE]:
			break
	_running = false
	if settings_version == _settings_version:
		var previous_retry_at := _retry_at
		_retry_at = maxf(Time.get_unix_time_from_system() + _delay, deadline) if failed and not _rejected else 0.0
		_delay = minf(_delay * 2.0, RETRY_MAX) if failed and not _rejected else RETRY_MIN
		if _rejected or _retry_at != previous_retry_at:
			_write_configuration(endpoint, _token, _rejected, _retry_at)
	note_saved()
