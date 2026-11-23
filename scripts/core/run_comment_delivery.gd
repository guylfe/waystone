extends HTTPRequest
## Sends consented reports to the participant-authenticated feedback service.

const Queue = preload("res://scripts/core/run_comment_queue.gd")
const ROUTE := "/v1/feedback"
const HTTPS_ORIGIN := "^https://[A-Za-z0-9.-]+(?::[0-9]{1,5})?\\z"
const LOOPBACK_ORIGIN := "^http://127\\.0\\.0\\.1:[0-9]{1,5}\\z"
const BEARER := "^[A-Za-z0-9._~+/-]+=*\\z"

static func service_endpoint(address: String) -> String:
	var origin := address.strip_edges().trim_suffix(ROUTE).trim_suffix("/")
	if not _matches(HTTPS_ORIGIN, origin) and not _is_loopback(origin): return ""
	return origin + ROUTE

static func _is_loopback(origin: String) -> bool:
	return OS.is_debug_build() and DisplayServer.get_name() == "headless" and OS.get_cmdline_user_args().has("--loopback") and _matches(LOOPBACK_ORIGIN, origin)

static func valid_configuration(endpoint: String, token: String) -> bool:
	if endpoint.is_empty(): return token.is_empty()
	if endpoint.length() > 512 or token.length() > 4096 or service_endpoint(endpoint) != endpoint: return false
	if _is_loopback(endpoint.trim_suffix(ROUTE)): return token.is_empty()
	return _matches(BEARER, token)

static func _matches(pattern: String, value: String) -> bool:
	return RegEx.create_from_string(pattern).search(value) != null

func deliver(queue: Queue, id: String, endpoint: String, token: String = "") -> Error:
	var payload := queue.submission(id)
	if payload.is_empty(): return ERR_INVALID_DATA
	if not queue.receipt(id).is_empty(): return OK
	if endpoint.is_empty() or not valid_configuration(endpoint, token): return ERR_INVALID_PARAMETER

	timeout = 15.0
	body_size_limit = 4096
	max_redirects = 0
	var headers := PackedStringArray([
		"Content-Type: application/json", "Accept: application/json", "Idempotency-Key: " + id,
	])
	if not token.is_empty(): headers.append("Authorization: Bearer " + token)
	var error := request(endpoint, headers, HTTPClient.METHOD_POST, payload)
	if error != OK: return error
	var response: Array = await request_completed
	if response[0] != RESULT_SUCCESS: return ERR_CONNECTION_ERROR
	var status := int(response[1])
	if status == 401 or status == 403: return ERR_UNAUTHORIZED
	if status != 200 and status != 201: return FAILED
	var body: PackedByteArray = response[3]
	return queue.acknowledge(id, JSON.parse_string(body.get_string_from_utf8()))
