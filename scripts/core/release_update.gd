extends Node
## One anonymous, bounded request per normal game launch.

signal changed

const Run = preload("res://scripts/core/run_state.gd")
const FEED := "https://api.github.com/repos/guylfe/waystone/releases/latest"
const RELEASES := "https://github.com/guylfe/waystone/releases/"
const ASSETS := {"Windows": "Waystone-Windows.zip", "Android": "Waystone-Android.apk"}
const TAG_PATTERN := "^v(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})\\z"
const LOOPBACK := "^http://127\\.0\\.0\\.1:[0-9]{1,5}/releases/latest\\z"

var tag := ""
var _started := false
var _test_feed := ""
var _test_platform := ""
var _test_open: Callable

func check_on_launch() -> void:
	if _started: return
	var platform := _test_platform if not _test_feed.is_empty() else OS.get_name()
	if not ASSETS.has(platform) or (DisplayServer.get_name() == "headless" and _test_feed.is_empty()): return
	_started = true
	var http := HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.use_threads = true
	http.timeout = 5.0
	http.body_size_limit = 256 * 1024
	http.max_redirects = 0
	add_child(http)
	var address := FEED if _test_feed.is_empty() else _test_feed
	var error := http.request(address, [
		"Accept: application/vnd.github+json", "User-Agent: Waystone",
		"X-GitHub-Api-Version: 2026-03-10",
	], HTTPClient.METHOD_GET)
	if error == OK:
		var response: Array = await http.request_completed
		if response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200:
			var bytes: PackedByteArray = response[3]
			var json := JSON.new()
			if json.parse(bytes.get_string_from_utf8()) == OK:
				tag = eligible_tag(json.data, Run.GAME_VERSION, platform)
	http.queue_free()
	if not tag.is_empty(): changed.emit()

static func eligible_tag(release: Variant, installed: String, platform: String) -> String:
	if not ASSETS.has(platform) or not release is Dictionary: return ""
	if release.get("draft") != false or release.get("prerelease") != false: return ""
	var candidate: Variant = release.get("tag_name")
	if not candidate is String: return ""
	var installed_version := _version("v" + installed)
	var offered_version := _version(candidate)
	if installed_version == Vector3i(-1, -1, -1) or offered_version <= installed_version: return ""
	var assets: Variant = release.get("assets")
	if not assets is Array: return ""
	var filename: String = ASSETS[platform]
	var download := RELEASES + "download/%s/%s" % [candidate, filename]
	for asset in assets:
		if not asset is Dictionary or asset.get("name") != filename or asset.get("state") != "uploaded": continue
		var size: Variant = asset.get("size")
		if (size is float or size is int) and size > 0 and asset.get("browser_download_url") == download:
			return candidate
	return ""

static func _version(value: String) -> Vector3i:
	var match_result := RegEx.create_from_string(TAG_PATTERN).search(value)
	if match_result == null: return Vector3i(-1, -1, -1)
	return Vector3i(int(match_result.get_string(1)), int(match_result.get_string(2)), int(match_result.get_string(3)))

func open_release() -> void:
	if tag.is_empty(): return
	var page := RELEASES + "tag/" + tag
	if _test_open.is_valid(): _test_open.call(page)
	else: OS.shell_open(page)

func dismiss() -> void:
	if tag.is_empty(): return
	tag = ""
	changed.emit()

func set_test_feed(address: String, platform: String, open_page: Callable) -> void:
	if not OS.is_debug_build() or DisplayServer.get_name() != "headless" or not OS.get_cmdline_user_args().has("--update-loopback"):
		return
	if _started or RegEx.create_from_string(LOOPBACK).search(address) == null: return
	_test_feed = address
	_test_platform = platform
	_test_open = open_page
