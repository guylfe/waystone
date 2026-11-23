extends HTTPRequest
## Sends consented reports to the participant-authenticated feedback service.

const Queue = preload("res://scripts/core/run_comment_queue.gd")
const ROUTE := "/v1/feedback"
const DEFAULT_ENDPOINT := "https://guylfe-game-feedback.netlify.app" + ROUTE
const DEFERRED_STATUSES := [202, 429, 503]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

class Response:
	var error: Error
	var status: int
	var retry_at: float

	func _init(result: Error, http_status: int = 0, deadline: float = 0.0) -> void:
		error = result
		status = http_status
		retry_at = deadline
const HTTPS_ORIGIN := "^https://[A-Za-z0-9.-]+(?::[0-9]{1,5})?\\z"
const LOOPBACK_ORIGIN := "^http://127\\.0\\.0\\.1:[0-9]{1,5}\\z"
const PLAYTESTER_CODE := "^pt_[0-9a-f]{48}\\z"
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
	if endpoint == DEFAULT_ENDPOINT: return _matches(PLAYTESTER_CODE, token)
	if _is_loopback(endpoint.trim_suffix(ROUTE)): return token.is_empty()
	return _matches(BEARER, token)

static func _matches(pattern: String, value: String) -> bool:
	return RegEx.create_from_string(pattern).search(value) != null

static func retry_deadline(headers: PackedStringArray, now: float) -> float:
	var deadline := 0.0
	for header in headers:
		var separator := header.find(":")
		if separator < 0 or header.left(separator).to_lower() != "retry-after": continue
		var value := header.substr(separator + 1).strip_edges()
		if _matches("^[0-9]+\\z", value):
			var seconds := float(value)
			if is_finite(seconds): deadline = maxf(deadline, now + seconds)
		else:
			deadline = maxf(deadline, _http_date(value, now))
	return deadline

static func _http_date(value: String, now: float) -> float:
	var parts := value.split(" ", false)
	var date: PackedStringArray
	var clock: String
	if parts.size() == 6 and parts[0].ends_with(",") and parts[5] == "GMT":
		date = parts.slice(1, 4)
		clock = parts[4]
	elif parts.size() == 4 and parts[0].ends_with(",") and parts[3] == "GMT":
		date = parts[1].split("-")
		clock = parts[2]
		if date.size() != 3 or not _matches("^[0-9]{2}\\z", date[2]): return 0.0
		var current_year := int(Time.get_datetime_dict_from_unix_time(int(now)).year)
		var year := current_year - current_year % 100 + int(date[2])
		if year > current_year + 50: year -= 100
		elif year < current_year - 50: year += 100
		date[2] = str(year)
	elif parts.size() == 5:
		date = PackedStringArray([parts[2], parts[1], parts[4]])
		clock = parts[3]
	else:
		return 0.0
	if not _matches("^[0-9]{1,2}\\z", date[0]) or not _matches("^[0-9]{4}\\z", date[2]): return 0.0
	if not _matches("^[0-9]{2}:[0-9]{2}:[0-9]{2}\\z", clock): return 0.0
	var time := clock.split(":")
	var month := MONTHS.find(date[1]) + 1
	var day := int(date[0])
	var hour := int(time[0])
	var minute := int(time[1])
	var second := int(time[2])
	if month == 0 or day < 1 or day > 31 or hour > 23 or minute > 59 or second > 60: return 0.0
	return float(Time.get_unix_time_from_datetime_dict({"year": int(date[2]), "month": month, "day": day, "hour": hour, "minute": minute, "second": second}))

func deliver(queue: Queue, id: String, endpoint: String, token: String = "") -> Response:
	var payload := queue.submission(id)
	if payload.is_empty() or queue.rejection(id) != 0: return Response.new(ERR_INVALID_DATA)
	if not queue.receipt(id).is_empty(): return Response.new(OK)
	if endpoint.is_empty() or not valid_configuration(endpoint, token): return Response.new(ERR_INVALID_PARAMETER)

	timeout = 15.0
	body_size_limit = 4096
	max_redirects = 0
	var headers := PackedStringArray([
		"Content-Type: application/json", "Accept: application/json", "Idempotency-Key: " + id,
	])
	if not token.is_empty(): headers.append("Authorization: Bearer " + token)
	var error := request(endpoint, headers, HTTPClient.METHOD_POST, payload)
	if error != OK: return Response.new(error)
	var response: Array = await request_completed
	var status := int(response[1])
	if status == 401 or status == 403: return Response.new(ERR_UNAUTHORIZED, status)
	if status in [400, 409]: return Response.new(ERR_INVALID_DATA, status)
	if status in DEFERRED_STATUSES:
		return Response.new(ERR_BUSY, status, retry_deadline(response[2], Time.get_unix_time_from_system()))
	if response[0] != RESULT_SUCCESS: return Response.new(ERR_CONNECTION_ERROR, status)
	if status != 200 and status != 201: return Response.new(FAILED, status)
	var body: PackedByteArray = response[3]
	return Response.new(queue.acknowledge(id, JSON.parse_string(body.get_string_from_utf8())), status)
