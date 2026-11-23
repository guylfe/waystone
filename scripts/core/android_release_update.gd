extends RefCounted

const INCOMPATIBLE := "Android package or signer does not match."
const UNAVAILABLE := "Could not open the Android installer."

static func install(asset: String, version: String, complete: Callable) -> void:
	var runtime := Engine.get_singleton("AndroidRuntime")
	var java := Engine.get_singleton("JavaClassWrapper")
	if runtime == null or java == null:
		complete.call(UNAVAILABLE, true)
		return
	var activity: Variant = runtime.getActivity()
	if activity == null:
		complete.call(UNAVAILABLE, true)
		return
	var path := ProjectSettings.globalize_path(asset)
	var manager: Variant = activity.getPackageManager()
	var sdk: int = java.wrap("android.os.Build$VERSION").SDK_INT
	var package: String = activity.getPackageName()
	var flags := 0x08000000 if sdk >= 28 else 0x40 # GET_SIGNING_CERTIFICATES / GET_SIGNATURES
	var installed: Variant = manager.getPackageInfo(package, flags)
	var offered: Variant = manager.getPackageArchiveInfo(path, flags)
	if installed == null or offered == null or java.get_exception() != null:
		complete.call(INCOMPATIBLE, false)
		return
	var installed_signers := _signers(installed, sdk, java)
	var offered_signers := _signers(offered, sdk, java)
	var offered_name: Variant = _field(offered, "packageName")
	var offered_version: Variant = _field(offered, "versionName")
	if offered_name == null or offered_name.toString() != package or offered_version == null or offered_version.toString() != version \
			or _version_code(offered, sdk) <= _version_code(installed, sdk) \
			or installed_signers.is_empty() or installed_signers != offered_signers:
		complete.call(INCOMPATIBLE, false)
		return

	var Intent: Variant = java.wrap("android.content.Intent")
	var Uri: Variant = java.wrap("android.net.Uri")
	var intent: Variant
	var message: String
	if sdk >= 26 and not manager.canRequestPackageInstalls():
		intent = Intent.Intent("android.settings.MANAGE_UNKNOWN_APP_SOURCES", Uri.parse("package:" + package))
		message = "Allow Waystone to install updates, then try again."
	else:
		var file: Variant = java.wrap("java.io.File").File(path)
		var provider: Variant = java.wrap("androidx.core.content.FileProvider")
		if provider == null:
			complete.call(UNAVAILABLE, true)
			return
		var uri: Variant = provider.getUriForFile(activity, package + ".fileprovider", file)
		if uri == null or java.get_exception() != null:
			complete.call(UNAVAILABLE, true)
			return
		intent = Intent.Intent("android.intent.action.INSTALL_PACKAGE")
		intent.setDataAndType(uri, "application/vnd.android.package-archive")
		intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
		# Grant this private file only to a system installer, never a third-party handler.
		var targets: Variant = manager.queryIntentActivities(intent, 0x00110000) # MATCH_SYSTEM_ONLY | MATCH_DEFAULT_ONLY
		if targets == null or targets.isEmpty():
			complete.call(UNAVAILABLE, true)
			return
		var info: Variant = _field(targets.get(0), "activityInfo")
		var installer_package: Variant = _field(info, "packageName")
		var installer_activity: Variant = _field(info, "name")
		if installer_package == null or installer_activity == null:
			complete.call(UNAVAILABLE, true)
			return
		intent.setClassName(installer_package.toString(), installer_activity.toString())
		message = "Confirm in the Android installer, or retry here."
	var on_ui := func() -> void:
		activity.startActivity(intent)
		var result := message if java.get_exception() == null else UNAVAILABLE
		complete.call_deferred(result, true)
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(on_ui))

# JavaClassWrapper exposes methods and static constants. Android's PackageInfo
# and ResolveInfo expose these values as public instance fields.
static func _field(object: Variant, field_name: String) -> Variant:
	if object == null: return null
	var field: Variant = object.getClass().getField(field_name)
	return field.get(object) if field != null else null

static func _version_code(info: Variant, sdk: int) -> int:
	if sdk >= 28: return info.getLongVersionCode()
	var field: Variant = info.getClass().getField("versionCode")
	return field.getInt(info) if field != null else -1

static func _signers(info: Variant, sdk: int, java: Object) -> PackedStringArray:
	var result := PackedStringArray()
	if sdk >= 28:
		var signing: Variant = _field(info, "signingInfo")
		if signing == null: return result
		var signatures: Variant = signing.getApkContentsSigners()
		if signatures == null: return result
		for signer in signatures:
			if signer == null: return PackedStringArray()
			result.append(signer.toCharsString())
	else:
		var signatures: Variant = _field(info, "signatures")
		if signatures == null: return result
		var array: Variant = java.wrap("java.lang.reflect.Array")
		for index in range(array.getLength(signatures)):
			var signer: Variant = array.get(signatures, index)
			if signer == null: return PackedStringArray()
			result.append(signer.toCharsString())
	result.sort()
	return result
