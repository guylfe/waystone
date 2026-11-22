extends HTTPRequest
## A release integration supplies its approved endpoint and authentication.
## The normal game has no sender until that integration is configured.

const Queue = preload("res://scripts/core/run_comment_queue.gd")
const TEST_HOST := "http://127.0.0.1:"

func deliver(queue: Queue, id: String, endpoint: String, authorization: String = "") -> Error:
	var payload := queue.payload(id)
	if payload.is_empty(): return ERR_FILE_NOT_FOUND
	if not queue.receipt(id).is_empty(): return OK
	var port := endpoint.get_slice("/", 2).trim_prefix("127.0.0.1:")
	var local_test := OS.is_debug_build() and OS.get_cmdline_user_args().has("--loopback") and endpoint.begins_with(TEST_HOST) and port.is_valid_int()
	if not endpoint.begins_with("https://") and not local_test: return ERR_INVALID_PARAMETER
	if not authorization.is_empty() and local_test: return ERR_INVALID_PARAMETER

	timeout = 15.0
	body_size_limit = 4096
	max_redirects = 0
	var headers := PackedStringArray([
		"Content-Type: application/json", "Accept: application/json", "Idempotency-Key: " + id,
	])
	if not authorization.is_empty(): headers.append("Authorization: " + authorization)
	var error := request(endpoint, headers, HTTPClient.METHOD_POST, payload)
	if error != OK: return error
	var response: Array = await request_completed
	if response[0] != RESULT_SUCCESS: return ERR_CONNECTION_ERROR
	var status := int(response[1])
	if status != 200 and status != 201: return FAILED
	var body: PackedByteArray = response[3]
	return queue.acknowledge(id, JSON.parse_string(body.get_string_from_utf8()))
