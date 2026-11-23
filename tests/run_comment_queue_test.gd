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
	var context := {"build": "development", "mode": "expedition", "seed": "9223372036854775807"}
	var text := "שביל\nAn exact second line."
	check(Queue.valid_report_id(id) and Queue.new_id() != id, "independent stable IDs")
	check(queue.pending_ids().is_empty(), "fresh outbox")
	check(queue.enqueue("../escape", text, context) == ERR_INVALID_PARAMETER, "reject unsafe ID")
	check(queue.enqueue(id, " \n ", context) == ERR_INVALID_PARAMETER, "empty draft rejected")
	check(queue.enqueue(id, "a".repeat(Queue.MAX_TEXT + 1), context) == ERR_INVALID_PARAMETER, "oversize text rejected")
	check(queue.enqueue(id, text, context, true) == OK, "enqueue public feedback")
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
	check(wire is Dictionary and wire.size() == 5 and wire.game == "waystone" and wire.reportId == id and wire.build == context.build and wire.note == text and wire.context == context, "wire contract preserves note and context")
	var local_id := Queue.new_id()
	check(restart.enqueue(local_id, text, context) == OK and restart.submission(local_id).is_empty(), "locally saved note is ineligible for transport")
	var legacy := JSON.stringify({"schema": 1, "id": LEGACY_ID, "text": text, "context": context})
	_write_fixture(restart.directory.path_join(LEGACY_ID + ".json"), legacy)
	check(restart.saved_ids().has(LEGACY_ID) and restart.pending_ids() == PackedStringArray([id]), "legacy queued notes stay on disk without public consent")
	_write_fixture(restart.directory.path_join(LEGACY_ID + ".receipt"), JSON.stringify({"id": LEGACY_ID, "sha256": legacy.sha256_text(), "reference": LEGACY_REFERENCE}))
	check(restart.receipt(LEGACY_ID).get("reference") == LEGACY_REFERENCE, "legacy receipt stays readable")
	for invalid_number in [null, "42", true, 0, -42, 41, 42.5, 9007199254740992]:
		check(restart.acknowledge(id, {"issueNumber": invalid_number, "issueUrl": REFERENCE}) == ERR_INVALID_DATA, "reject invalid issue number")
	for invalid_url in [null, 42, [], "", REFERENCE + "?a=b", REFERENCE + "/", REFERENCE + "#comment", REFERENCE.replace("/42", "/042"), REFERENCE.replace("guylfe", "example"), REFERENCE.replace("/issues/", "/pull/"), REFERENCE.replace("https://", "http://")]:
		check(restart.acknowledge(id, {"issueNumber": 42, "issueUrl": invalid_url}) == ERR_INVALID_DATA, "reject non-canonical issue URL")
	check(restart.acknowledge(local_id, {"issueNumber": 42, "issueUrl": REFERENCE}) == ERR_INVALID_DATA, "consent required to persist a public receipt")
	var sidecar := FileAccess.open(restart.directory.path_join(id + ".receipt"), FileAccess.WRITE)
	sidecar.store_string("{}")
	sidecar.close()
	check(restart.pending_ids().has(id), "damaged receipt is retryable")
	if OS.get_cmdline_user_args().has("--loopback"):
		await _exercise_http(restart, id, submission, local_id)
	else:
		check(restart.acknowledge(id, {"issueNumber": 42, "issueUrl": REFERENCE}) == OK, "verified response persisted")
	check(Queue.new(queue.directory).receipt(id) == {"issueNumber": 42, "issueUrl": REFERENCE}, "receipt survives new queue instance")
	check(queue.pending_ids().is_empty() and queue.payload(id) == payload, "successful note leaves pending but keeps local bytes")
	print("Run comment queue: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func _write_fixture(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func _exercise_http(queue: Queue, id: String, payload: String, local_id: String) -> void:
	var listening := listener.listen(0, "127.0.0.1")
	check(listening == OK, "local receiver binds")
	if listening != OK: return
	_serve_loopback()
	var endpoint := "http://127.0.0.1:%d/v1/feedback" % listener.get_local_port()
	var transport := Delivery.new()
	root.add_child(transport)
	check(Delivery.valid_configuration("https://relay.example.invalid/v1/feedback", "test-fixture"), "HTTPS with player token accepted")
	check(not Delivery.valid_configuration("https://relay.example.invalid/v1/feedback", ""), "HTTPS requires player token")
	check(not Delivery.valid_configuration("https://relay.example.invalid/v1/feedback", "line\r\nbreak"), "reject header delimiters")
	check(not Delivery.valid_configuration("http://relay.example.invalid/v1/feedback", "test-fixture"), "reject non-loopback plaintext")
	check(not Delivery.valid_configuration("http://127.0.0.1:80@relay.example.invalid/v1/feedback", ""), "reject disguised non-loopback")
	check(Delivery.service_endpoint("https://relay.example.invalid/") == "https://relay.example.invalid/v1/feedback", "origin resolves to the feedback endpoint")
	check(Delivery.service_endpoint("https://relay.example.invalid/comments").is_empty(), "reject legacy protocol paths")
	check(await transport.deliver(queue, local_id, endpoint) == ERR_INVALID_DATA and requests == 0, "transport refuses local-only notes")
	check(await transport.deliver(queue, LEGACY_ID, endpoint) == ERR_INVALID_DATA and requests == 0, "transport refuses legacy notes")
	check(await transport.deliver(queue, id, endpoint, "forbidden") == ERR_INVALID_PARAMETER, "credentials excluded from plaintext loopback")
	check(await transport.deliver(queue, id, endpoint) == ERR_CONNECTION_ERROR, "lost response remains pending")
	check(queue.pending_ids().has(id) and receiver.get(id) == payload, "first remote write happened before response was lost")
	check(await transport.deliver(queue, id, endpoint) == ERR_INVALID_DATA, "successful HTTP status with wrong issue number stays pending")
	check(queue.pending_ids().has(id), "wrong receipt did not remove pending")
	check(await transport.deliver(queue, id, endpoint) == OK, "read-back receipt confirms retry")
	check(receiver.size() == 1 and receiver.get(id) == payload and requests == 3, "same ID and bytes reached receiver each time")
	check(await transport.deliver(queue, id, endpoint) == OK and requests == 3, "acknowledged note skips network")
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
			var number := 43 if requests == 2 else 42
			var ack := JSON.stringify({"issueNumber": number, "issueUrl": REFERENCE})
			var response := "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: %d\r\n\r\n%s" % [ack.to_utf8_buffer().size(), ack]
			peer.put_data(response.to_utf8_buffer())
		peer.disconnect_from_host()
