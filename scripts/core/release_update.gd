extends Node
## Anonymous release discovery, verified downloads and platform handoff.

signal changed
signal install_ready

const Run = preload("res://scripts/core/run_state.gd")
const Windows = preload("res://scripts/core/windows_release_update.gd")
const Android = preload("res://scripts/core/android_release_update.gd")
const FEED := "https://api.github.com/repos/guylfe/waystone/releases/latest"
const RELEASES := "https://github.com/guylfe/waystone/releases/"
const ASSETS := {"Windows": "Waystone-Windows.zip", "Android": "Waystone-Android.apk"}
const MAX_ASSET_SIZE := 256 * 1024 * 1024
const TAG_PATTERN := "^v(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})\\z"
const DIGEST_PATTERN := "^sha256:([a-fA-F0-9]{64})\\z"
const ASSET_HOST := "^https://(?:release-assets|objects)\\.githubusercontent\\.com/[^\\s#]+\\z"
const LOOPBACK := "^http://127\\.0\\.0\\.1:[0-9]{1,5}/releases/latest\\z"
const CACHE := "user://release-update"

enum Phase { OFFER, DOWNLOADING, READY, INSTALLING }

var tag := ""
var status := ""
var phase := Phase.OFFER
var _offer := {}
var _started := false
var checking := false
var _manual_result := false
var _platform := ""
var _partial := ""
var _verified := ""
var _download: HTTPRequest
var _attempt := 0
var _test_feed := ""
var _test_platform := ""
var _test_install: Callable

func check_on_launch() -> void:
	if _started: return
	if _test_feed.is_empty() and (OS.has_feature("editor") or DisplayServer.get_name() == "headless"): return
	_platform = OS.get_name() if _test_feed.is_empty() else _test_platform
	if not ASSETS.has(_platform): return
	_started = true
	if _platform == "Windows" and _test_feed.is_empty():
		status = Windows.take_failure()
		if not status.is_empty(): changed.emit()
	_discover()

func check_for_updates() -> void:
	if phase != Phase.OFFER or not tag.is_empty(): return
	_platform = OS.get_name() if _test_feed.is_empty() else _test_platform
	if not ASSETS.has(_platform):
		status = "Updates are available on Windows and Android."
		changed.emit()
		return
	_manual_result = true
	status = "Checking for updates…"
	changed.emit()
	if not checking: _discover()

func _discover() -> void:
	if checking: return
	checking = true
	var result := "Could not check for updates. Try again."
	var http := _request_node(5.0, 256 * 1024)
	var error := http.request(FEED if _test_feed.is_empty() else _test_feed, [
		"Accept: application/vnd.github+json", "User-Agent: Waystone",
		"X-GitHub-Api-Version: 2026-03-10",
	])
	if error == OK:
		var response: Array = await http.request_completed
		if response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200:
			var bytes: PackedByteArray = response[3]
			var json := JSON.new()
			if json.parse(bytes.get_string_from_utf8()) == OK:
				var release: Variant = json.data
				if release is Dictionary and release.get("draft") == false and release.get("prerelease") == false:
					var latest := _version(str(release.get("tag_name", "")))
					if latest != Vector3i(-1, -1, -1) and latest <= _version("v" + Run.GAME_VERSION):
						result = "Waystone v%s is up to date." % Run.GAME_VERSION
				_offer = eligible_asset(release, Run.GAME_VERSION, _platform)
				tag = _offer.get("tag", "")
	http.queue_free()
	checking = false
	if _manual_result:
		status = result if tag.is_empty() else ""
		_manual_result = false
		changed.emit()
	elif not tag.is_empty(): changed.emit()

func _request_node(seconds: float, limit: int) -> HTTPRequest:
	var http := HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.use_threads = true
	http.timeout = seconds
	http.body_size_limit = limit
	http.max_redirects = 0
	add_child(http)
	return http

static func eligible_asset(release: Variant, installed: String, platform: String) -> Dictionary:
	if not ASSETS.has(platform) or not release is Dictionary: return {}
	if release.get("draft") != false or release.get("prerelease") != false: return {}
	var candidate: Variant = release.get("tag_name")
	if not candidate is String: return {}
	var installed_version := _version("v" + installed)
	var offered_version := _version(candidate)
	if installed_version == Vector3i(-1, -1, -1) or offered_version <= installed_version: return {}
	var assets: Variant = release.get("assets")
	if not assets is Array: return {}
	var filename: String = ASSETS[platform]
	var download := RELEASES + "download/%s/%s" % [candidate, filename]
	for asset in assets:
		if not asset is Dictionary or asset.get("name") != filename or asset.get("state") != "uploaded": continue
		var size: Variant = asset.get("size")
		if not (size is float or size is int) or size <= 0 or size > MAX_ASSET_SIZE or size != floorf(size): continue
		if asset.get("browser_download_url") != download: continue
		var digest: Variant = asset.get("digest")
		if not digest is String: continue
		var match_result := RegEx.create_from_string(DIGEST_PATTERN).search(digest)
		if match_result == null: continue
		return {"tag": candidate, "url": download, "size": int(size), "sha256": match_result.get_string(1).to_lower()}
	return {}

static func _version(value: String) -> Vector3i:
	var match_result := RegEx.create_from_string(TAG_PATTERN).search(value)
	if match_result == null: return Vector3i(-1, -1, -1)
	return Vector3i(int(match_result.get_string(1)), int(match_result.get_string(2)), int(match_result.get_string(3)))

func start_download() -> void:
	if tag.is_empty() or phase != Phase.OFFER: return
	var directory := CACHE.path_join(str(OS.get_process_id()) if _platform == "Windows" else "android")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_fail("Could not prepare the update.")
		return
	_verified = directory.path_join(ASSETS[_platform])
	_partial = _verified + ".part"
	DirAccess.remove_absolute(_partial)
	_attempt += 1
	var attempt := _attempt
	_set_phase(Phase.DOWNLOADING, "Downloading update…")
	var destination: String = _offer.url
	if not _test_feed.is_empty(): destination = _test_feed.get_base_dir().get_base_dir() + "/asset"
	for hop in range(2):
		_download = _request_node(180.0, _offer.size)
		_download.download_file = _partial
		if _download.request(destination, ["User-Agent: Waystone"], HTTPClient.METHOD_GET) != OK:
			_download.queue_free()
			_download = null
			break
		var response: Array = await _download.request_completed
		if attempt != _attempt: return
		_download.queue_free()
		_download = null
		if response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200:
			if not file_matches(_partial, _offer.size, _offer.sha256):
				_fail("Update verification failed.")
				return
			if DirAccess.rename_absolute(_partial, _verified) != OK:
				_fail("Could not stage the verified update.")
				return
			_set_phase(Phase.READY, "")
			install_ready.emit()
			return
		if hop != 0 or response[0] != HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: break
		destination = _redirect(response[2])
		if destination.is_empty(): break
	_fail("Download failed. Try again.")

func _redirect(headers: PackedStringArray) -> String:
	for header in headers:
		if not header.to_lower().begins_with("location:"): continue
		var url := header.substr(9).strip_edges()
		if _test_feed.is_empty():
			if RegEx.create_from_string(ASSET_HOST).search(url) != null: return url
		elif url == _test_feed.get_base_dir().get_base_dir() + "/cdn":
			return url
	return ""

static func file_matches(path: String, size: int, digest: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var actual_size := file.get_length()
	file.close()
	return actual_size == size and FileAccess.get_sha256(path) == digest

func install(save_run: Callable) -> void:
	if phase != Phase.READY: return
	if not save_run.call():
		_set_phase(Phase.READY, "Could not save the run. Try again.")
		return
	if _test_install.is_valid():
		_test_install.call(_verified)
		later()
		return
	if _platform == "Windows":
		if Windows.start(_verified, _offer.size, _offer.sha256):
			_set_phase(Phase.INSTALLING, "Restarting Waystone…")
			get_tree().quit()
		else:
			_set_phase(Phase.READY, "Could not start the installer. Try again.")
	else:
		_set_phase(Phase.INSTALLING, "Opening Android installer…")
		Android.install(_verified, tag.substr(1), _android_result)

func _android_result(message: String, retry: bool) -> void:
	if retry:
		_set_phase(Phase.READY, message)
	else:
		DirAccess.remove_absolute(_verified)
		_fail(message)

func later() -> void:
	if phase == Phase.INSTALLING: return
	_attempt += 1
	if is_instance_valid(_download):
		# Resume the suspended coroutine so it can observe the canceled attempt.
		_download.cancel_request()
		_download.request_completed.emit(HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedStringArray(), PackedByteArray())
		_download.queue_free()
		_download = null
	if not _partial.is_empty(): DirAccess.remove_absolute(_partial)
	# Android may still be reading the APK following an installer handoff.
	if not _verified.is_empty() and _platform != "Android": DirAccess.remove_absolute(_verified)
	tag = ""
	_offer = {}
	_set_phase(Phase.OFFER, "")

func _fail(message: String) -> void:
	if not _partial.is_empty(): DirAccess.remove_absolute(_partial)
	_set_phase(Phase.OFFER, message)

func _set_phase(value: Phase, message: String) -> void:
	phase = value
	status = message
	changed.emit()

func set_test_feed(address: String, platform: String, installer: Callable) -> void:
	if not OS.is_debug_build() or DisplayServer.get_name() != "headless" or not OS.get_cmdline_user_args().has("--update-loopback"):
		return
	if _started or RegEx.create_from_string(LOOPBACK).search(address) == null: return
	_test_feed = address
	_test_platform = platform
	_test_install = installer
