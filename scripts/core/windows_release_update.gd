extends RefCounted

const HELPER := "res://scripts/core/install_windows_update.ps1"
const FAILED := "The update could not be installed. Try again."

static func _failure_path() -> String:
	var identity := OS.get_executable_path().to_lower().sha256_text().left(16)
	return ProjectSettings.globalize_path("user://release-update/windows-%s.failed" % identity)

static func take_failure() -> String:
	var path := _failure_path()
	if not FileAccess.file_exists(path): return ""
	DirAccess.remove_absolute(path)
	return FAILED

static func start(asset: String, size: int, sha256: String) -> bool:
	var helper := FileAccess.get_file_as_string(HELPER)
	if helper.is_empty(): return false
	var root := OS.get_environment("SystemRoot")
	if root.is_empty(): return false
	var shell := root.path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
	if not FileAccess.file_exists(shell): return false
	var arguments := OS.get_cmdline_args()
	var user_arguments := OS.get_cmdline_user_args()
	if not user_arguments.is_empty():
		arguments.append("--")
		arguments.append_array(user_arguments)
	var config := JSON.stringify({
		"executable": OS.get_executable_path(),
		"processId": OS.get_process_id(),
		"asset": ProjectSettings.globalize_path(asset),
		"size": size,
		"sha256": sha256,
		"failure": _failure_path(),
		"arguments": arguments,
	})
	# A single encoded command keeps paths and original argument values out of shell syntax.
	var encoded_config := Marshalls.raw_to_base64(config.to_utf8_buffer())
	var command := "& {\n" + helper + "\n} '" + encoded_config + "'"
	var encoded_command := Marshalls.raw_to_base64(command.to_utf16_buffer())
	return OS.create_process(shell, ["-NoProfile", "-NonInteractive", "-EncodedCommand", encoded_command], false) > 0
