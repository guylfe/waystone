extends SceneTree

const Queue = preload("res://scripts/core/run_comment_queue.gd")
const Delivery = preload("res://scripts/core/run_comment_delivery.gd")
const REFERENCE := "https://github.com/guylfe/waystone/issues/42"
const LEGACY_ID := "0123456789abcdef0123456789abcdef"
const LEGACY_REFERENCE := "https://github.com/guylfe/waystone/blob/main/comments/legacy.json"

var checks := 0
var failures := 0
var listener := TCPServer.new()
var receiver: Dictionary = {}
var requests := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAILED: ", label)

func _run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/"):
		printerr("Requires isolated .runtime data.")
		quit(2)
		return
	var queue := Queue.new("user://tests/run-comment-queue-" + Queue.new_id())
	var id := Queue.new_id()
	var context := {"build": "survey-0.3.10-fixture", "source": "test-source", "game_version": "0.3.10", "mode": "expedition", "seed": "9223372036854775807"}
	var text := "שביל\nAn exact second line."
	check(Queue.valid_report_id(id) and Queue.new_id() != id, "independent stable IDs")
	check(queue.pending_ids().is_empty(), "fresh outbox")
	check(queue.enqueue("../escape", text, context) == ERR_INVALID_PARAMETER, "reject unsafe ID")
	check(queue.enqueue(id, " \n ", context) == ERR_INVALID_PARAMETER, "empty draft rejected")
	check(queue.enqueue(id, "a".repeat(Queue.MAX_TEXT + 1), context) == ERR_INVALID_PARAMETER, "oversize text rejected")
	_contract_limits(queue, context)
	check(queue.enqueue(id, text, context, true) == OK, "enqueue private feedback")
	var restart := Queue.new(queue.directory)
	check(restart.pending_ids() == PackedStringArray([id]), "pending survives new queue instance")
	var payload := restart.payload(id)
	var parsed: Dictionary = JSON.parse_string(payload)
	check(parsed.id == id and parsed.text == text and parsed.context == context, "Unicode, newlines and exact 64-bit seed")
	check(restart.enqueue(id, text, context, true) == OK, "identical save is idempotent")
	check(restart.enqueue(id, "changed content", context, true) == ERR_ALREADY_EXISTS and restart.payload(id) == payload, "saved payload stays immutable")
	check(restart.enqueue(id, text, context, false) == ERR_ALREADY_EXISTS, "existing consent is immutable")
	var submission := restart.submission(id)
	var wire: Variant = JSON.parse_string(submission)
	check(wire is Dictionary and wire.size() == 5 and wire.game == "waystone" and wire.reportId == id and wire.build == context.game_version and wire.note == text and wire.context == context, "wire contract preserves note and context")
	var local_id := Queue.new_id()
	check(restart.enqueue(local_id, text, context) == OK and restart.submission(local_id).is_empty(), "locally saved note is ineligible for transport")
	var legacy := JSON.stringify({"schema": 1, "id": LEGACY_ID, "text": text, "context": context})
	_write_fixture(restart.directory.path_join(LEGACY_ID + ".json"), legacy)
	check(restart.saved_ids().has(LEGACY_ID) and restart.pending_ids() == PackedStringArray([id]), "legacy queued notes stay on disk without public consent")
	_write_fixture(restart.directory.path_join(LEGACY_ID + ".receipt"), JSON.stringify({"id": LEGACY_ID, "sha256": legacy.sha256_text(), "reference": LEGACY_REFERENCE}))
	check(restart.receipt(LEGACY_ID).get("reference") == LEGACY_REFERENCE, "legacy receipt stays readable")
	var file_receipt := _file_receipt(id)
	for invalid in [{}, {"issueNumber": 42, "issueUrl": REFERENCE}, file_receipt.merged({"game": "other"}, true), file_receipt.merged({"reportId": local_id}, true), file_receipt.merged({"filePath": "other/" + id + ".json"}, true)]:
		check(restart.acknowledge(id, invalid) == ERR_INVALID_DATA, "reject unrelated or legacy server receipt")
	check(restart.acknowledge(local_id, _file_receipt(local_id)) == ERR_INVALID_DATA, "local-only notes cannot be acknowledged")
	var old_id := Queue.new_id()
	var old_body: Dictionary = wire.duplicate()
	old_body.reportId = old_id
	var old_note := JSON.stringify({"schema": 3, "id": old_id, "text": text, "context": context, "send_publicly": true, "submission": JSON.stringify(old_body)})
	_write_fixture(restart.directory.path_join(old_id + ".json"), old_note)
	check(restart.pending_ids().has(old_id) and restart.submission(old_id) == JSON.stringify(old_body), "previous release queue retries the original bytes and UUID")
	_write_fixture(restart.directory.path_join(old_id + ".receipt"), JSON.stringify({"id": old_id, "sha256": old_note.sha256_text(), "issueNumber": 42, "issueUrl": REFERENCE}))
	check(not restart.pending_ids().has(old_id), "previously acknowledged reports are never resent")
	var sidecar := FileAccess.open(restart.directory.path_join(id + ".receipt"), FileAccess.WRITE)
	sidecar.store_string("{}")
	sidecar.close()
	check(restart.pending_ids().has(id), "damaged receipt is retryable")
	if OS.get_cmdline_user_args().has("--loopback"):
		await _exercise_http(restart, id, submission, local_id)
	else:
		check(restart.acknowledge(id, file_receipt) == OK, "verified response persisted")
	check(Queue.new(queue.directory).receipt(id) == {"filePath": file_receipt.filePath}, "receipt survives new queue instance")
	check(queue.pending_ids().is_empty() and queue.payload(id) == payload, "successful note leaves pending but keeps local bytes")
	var rejected_id := Queue.new_id()
	check(queue.enqueue(rejected_id, text, context, true) == OK and queue.reject(rejected_id, 409) == OK, "permanent rejection can be persisted")
	check(restart.rejection(rejected_id) == 409 and restart.pending_ids().is_empty() and restart.receipt(rejected_id).is_empty(), "rejection survives restart without a sent receipt")
	check(not restart.payload(rejected_id).is_empty() and not restart.submission(rejected_id).is_empty(), "rejected note and exact submission are retained")
	print("Run comment queue: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func _contract_limits(queue: Queue, context: Dictionary) -> void:
	var emoji := String.chr(0x1f642)
	var boundary := emoji.repeat(1000)
	check(queue.enqueue(Queue.new_id(), boundary, context, false) == OK, "2,000 UTF-16 units are accepted")
	check(queue.enqueue(Queue.new_id(), boundary + "x", context, true) == ERR_INVALID_PARAMETER, "one UTF-16 unit over is rejected")
	check(Queue.truncate_note("x" + boundary) == "x" + emoji.repeat(999), "input truncation never splits a supplementary character")
	var large := context.duplicate(true)
	large["recent_messages"] = [{"text": String.chr(0x6c34).repeat(3000)}, {"text": "newest"}]
	large["game_version"] = "0" + "a".repeat(95)
	var id := Queue.new_id()
	check(queue.enqueue(id, boundary, large, true) == OK, "96-character version is accepted and context is trimmed")
	var wire: Dictionary = JSON.parse_string(queue.submission(id))
	var local: Dictionary = JSON.parse_string(queue.payload(id))
	check(wire.build == large.game_version and wire.context.build == context.build and wire.context.source == context.source, "version and source/build identities are retained")
	check(wire.context.recent_messages.size() == 1 and wire.context.recent_messages[0].text == "newest" and JSON.stringify(wire.context).to_utf8_buffer().size() <= Queue.MAX_CONTEXT_BYTES, "old optional context is pruned to the UTF-8 limit")
	check(local.context.recent_messages.size() == 2 and local.submission == queue.submission(id), "local context and exact public bytes are saved together")
	# Keep this fixture out of the delivery checks below.
	check(queue.reject(id, 400) == OK, "rejected fixture is excluded from pending")
	for invalid_version in ["a".repeat(97), "0.3:10", "0.3?10", ""]:
		var invalid := context.merged({"game_version": invalid_version}, true)
		check(queue.enqueue(Queue.new_id(), "example", invalid, true) == ERR_INVALID_DATA, "invalid build version rejected")
	var allowed_version := context.merged({"game_version": "Waystone 0.3.10-rc.1+dev (QA/1)"}, true)
	var version_id := Queue.new_id()
	check(queue.enqueue(version_id, "example", allowed_version, true) == OK and queue.reject(version_id, 400) == OK, "allow the service's build punctuation")
	var body_context := context.merged({"recent_messages": [{"text": "x".repeat(8100)}]}, true)
	var body_id := Queue.new_id()
	var escaped_note := "x" + String.chr(1).repeat(1999)
	check(queue.enqueue(body_id, escaped_note, body_context, true) == OK, "full platform note length with an escaped body is supported")
	var escaped_wire := queue.submission(body_id)
	check(escaped_wire.contains("\\u0001") and not escaped_wire.contains(String.chr(1)) and escaped_wire.to_utf8_buffer().size() <= Queue.MAX_REQUEST_BYTES, "strict JSON escaping stays within the full request budget")
	check(queue.reject(body_id, 400) == OK, "body budget fixture is excluded from delivery")
	var now := 1780000000.25
	check(is_equal_approx(Delivery.retry_deadline(["rEtRy-AfTeR: 122"], now), now + 122.0), "delta-seconds deadline reads case-insensitive header and exceeds fallback cap")
	var date := Time.get_unix_time_from_datetime_string("2026-11-23T18:30:00")
	for value in ["Mon, 23 Nov 2026 18:30:00 GMT", "Monday, 23-Nov-26 18:30:00 GMT", "Mon Nov 23 18:30:00 2026"]:
		check(Delivery.retry_deadline(["Retry-After: " + value], now) == date, "HTTP-date Retry-After is exact")
	check(Delivery.retry_deadline(["Retry-After: -2", "Retry-After: +6", "Retry-After: tomorrow"], now) == 0.0, "invalid waits fall back to local retry")

func _file_receipt(id: String) -> Dictionary:
	return {"game": "waystone", "reportId": id, "filePath": "playtest-feedback/" + id + ".json"}

func _write_fixture(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func _exercise_http(queue: Queue, id: String, payload: String, local_id: String) -> void:
	var listening := listener.listen(0, "127.0.0.1")
	check(listening == OK, "local receiver binds")
	if listening != OK: return
	_serve_loopback()
	var endpoint := "http://127.0.0.1:%d/v3/feedback" % listener.get_local_port()
	var transport := Delivery.new()
	root.add_child(transport)
	check(Delivery.valid_endpoint(Delivery.DEFAULT_ENDPOINT), "production endpoint is allowed")
	check(not Delivery.valid_endpoint("https://elsewhere.example/v3/feedback"), "foreign destination refused")
	check((await transport.deliver(queue, local_id, endpoint)).error == ERR_INVALID_DATA and requests == 0, "transport refuses local-only notes")
	check((await transport.deliver(queue, LEGACY_ID, endpoint)).error == ERR_INVALID_DATA and requests == 0, "transport refuses legacy notes")
	check((await transport.deliver(queue, id, endpoint)).error == ERR_CONNECTION_ERROR, "lost response remains pending")
	check(queue.pending_ids().has(id) and receiver.get(id) == payload, "first remote write happened before response was lost")
	check((await transport.deliver(queue, id, endpoint)).error == ERR_INVALID_DATA, "successful HTTP status with wrong file receipt stays pending")
	check(queue.pending_ids().has(id), "wrong receipt did not remove pending")
	check((await transport.deliver(queue, id, endpoint)).error == OK, "read-back receipt confirms retry")
	check(receiver.size() == 1 and receiver.get(id) == payload and requests == 3, "same ID and bytes reached receiver each time")
	check((await transport.deliver(queue, id, endpoint)).error == OK and requests == 3, "acknowledged note skips network")
	listener.stop()
	await process_frame
	transport.queue_free()

func _serve_loopback() -> void:
	while listener.is_listening():
		await process_frame
		if not listener.is_connection_available(): continue
		var peer := listener.take_connection()
		var request := PackedByteArray()
		var header_end := -1
		var body_length := 0
		var request_id := ""
		for frame in 360:
			await process_frame
			peer.poll()
			var available := peer.get_available_bytes()
			if available > 0: request.append_array(peer.get_data(available)[1])
			if header_end < 0:
				var headers := request.get_string_from_ascii()
				header_end = headers.find("\r\n\r\n")
				if header_end >= 0:
					for line in headers.left(header_end).split("\r\n"):
						if line.to_lower().begins_with("content-length:"): body_length = int(line.get_slice(":", 1).strip_edges())
						elif line.to_lower().begins_with("idempotency-key:"): request_id = line.get_slice(":", 1).strip_edges()
			if header_end >= 0 and request.size() >= header_end + 4 + body_length: break
		requests += 1
		var body := request.slice(header_end + 4).get_string_from_utf8()
		var record: Variant = JSON.parse_string(body)
		check(record is Dictionary and Queue.valid_id(request_id) and record.reportId == request_id and record.game == "waystone", "receiver sees idempotency ID in header and payload")
		check(not receiver.has(request_id) or receiver[request_id] == body, "retry sent the same body bytes")
		receiver[request_id] = body
		if requests > 1:
			var confirmed_id := Queue.new_id() if requests == 2 else request_id
			var ack := JSON.stringify(_file_receipt(confirmed_id))
			var response := "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: %d\r\n\r\n%s" % [ack.to_utf8_buffer().size(), ack]
			peer.put_data(response.to_utf8_buffer())
		peer.disconnect_from_host()
