extends SceneTree

const Queue = preload("res://scripts/core/run_comment_queue.gd")
const Delivery = preload("res://scripts/core/run_comment_delivery.gd")
const REFERENCE := "https://github.com/example/waystone/issues/42"

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
	var context := {"mode": "expedition", "seed": "9223372036854775807"}
	var text := "שביל\nAn exact second line."
	check(Queue.valid_id(id) and Queue.new_id() != id, "independent stable IDs")
	check(queue.pending_ids().is_empty(), "fresh outbox")
	check(queue.enqueue("../escape", text, context) == ERR_INVALID_PARAMETER, "reject unsafe ID")
	check(queue.enqueue(id, " \n ", context) == ERR_INVALID_PARAMETER, "empty draft rejected")
	check(queue.enqueue(id, "a".repeat(Queue.MAX_TEXT + 1), context) == ERR_INVALID_PARAMETER, "oversize text rejected")
	check(queue.enqueue(id, text, context) == OK, "enqueue")
	var restart := Queue.new(queue.directory)
	check(restart.pending_ids() == PackedStringArray([id]), "pending survives new queue instance")
	var payload := restart.payload(id)
	var digest := payload.sha256_text()
	var parsed: Dictionary = JSON.parse_string(payload)
	check(parsed.id == id and parsed.text == text and parsed.context == context, "Unicode, newlines and exact 64-bit seed")
	check(restart.enqueue(id, text, context) == OK, "identical save is idempotent")
	check(restart.enqueue(id, "changed content", context) == ERR_ALREADY_EXISTS and restart.payload(id) == payload, "saved payload stays immutable")
	check(restart.acknowledge(id, {"id": Queue.new_id(), "sha256": digest, "reference": "test"}) == ERR_INVALID_DATA, "mismatched ID stays pending")
	check(restart.acknowledge(id, {"id": id, "sha256": "wrong", "reference": "test"}) == ERR_INVALID_DATA, "mismatched payload stays pending")
	check(restart.acknowledge(id, {"id": id, "sha256": digest, "reference": ""}) == ERR_INVALID_DATA, "empty reference stays pending")
	var sidecar := FileAccess.open(restart.directory.path_join(id + ".receipt"), FileAccess.WRITE)
	sidecar.store_string("{}")
	sidecar.close()
	check(restart.pending_ids().has(id), "damaged receipt is retryable")
	if OS.get_cmdline_user_args().has("--loopback"):
		await _exercise_http(restart, id, payload)
	else:
		check(restart.acknowledge(id, {"id": id, "sha256": digest, "reference": REFERENCE}) == OK, "verified response persisted")
	check(Queue.new(queue.directory).receipt(id) == REFERENCE, "receipt survives new queue instance")
	check(queue.pending_ids().is_empty() and queue.payload(id) == payload, "successful note leaves pending but keeps local bytes")
	print("Run comment queue: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func _exercise_http(queue: Queue, id: String, payload: String) -> void:
	var listening := listener.listen(0, "127.0.0.1")
	check(listening == OK, "local receiver binds")
	if listening != OK: return
	_serve_loopback()
	var endpoint := "http://127.0.0.1:%d/comments" % listener.get_local_port()
	var transport := Delivery.new()
	root.add_child(transport)
	check(Delivery.valid_configuration("https://relay.example.invalid/comments", "test-fixture"), "HTTPS with player token accepted")
	check(not Delivery.valid_configuration("https://relay.example.invalid/comments", ""), "HTTPS requires player token")
	check(not Delivery.valid_configuration("https://relay.example.invalid/comments", "line\r\nbreak"), "reject header delimiters")
	check(not Delivery.valid_configuration("http://relay.example.invalid/comments", "test-fixture"), "reject non-loopback plaintext")
	check(not Delivery.valid_configuration("http://127.0.0.1:80@relay.example.invalid/comments", ""), "reject disguised non-loopback")
	check(await transport.deliver(queue, id, endpoint, "forbidden") == ERR_INVALID_PARAMETER, "credentials excluded from plaintext loopback")
	check(await transport.deliver(queue, id, endpoint) == ERR_CONNECTION_ERROR, "lost response remains pending")
	check(queue.pending_ids().has(id) and receiver.get(id) == payload, "first remote write happened before response was lost")
	check(await transport.deliver(queue, id, endpoint) == ERR_INVALID_DATA, "successful HTTP status with wrong hash stays pending")
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
		check(record is Dictionary and Queue.valid_id(request_id) and record.id == request_id, "receiver sees idempotency ID in header and payload")
		check(not receiver.has(request_id) or receiver[request_id] == body, "retry sent the same body bytes")
		receiver[request_id] = body
		if requests > 1:
			var digest := "wrong" if requests == 2 else String(receiver[request_id]).sha256_text()
			var ack := JSON.stringify({"id": request_id, "sha256": digest, "reference": REFERENCE})
			var response := "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: %d\r\n\r\n%s" % [ack.to_utf8_buffer().size(), ack]
			peer.put_data(response.to_utf8_buffer())
		peer.disconnect_from_host()
