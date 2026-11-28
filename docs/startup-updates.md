# Startup updates

Waystone checks for a newer stable release once per normal Windows or Android
launch. This anonymous HTTPS request goes to the official Waystone GitHub
repository. The check runs while the game loads or resumes, including when
the player is offline.

Setup shows the running version beside **Check for updates**. This checks again after choosing Later, and reports the result even when the current version is already installed. The Run and Survey menus also provide a manual check.

Setup shows **Update now** and **Later** for an eligible release. A resumed run
shows a brief notice after the current action. The same choices are available
in the Run menu and the Survey menu. **Later** hides the offer for this launch
and cancels an unfinished download. A verified update waits if the player
leaves the menu to continue playing. Open the menu and choose **Install
update** to continue. Waystone writes the active run before handing off to an
installer. If that write fails, the player can continue playing and retry.
Players on 0.3.9 use its **View on GitHub** action to install the first
release that contains the in-game installer.

On Windows, the game closes and relaunches from the same executable path after
replacement. The helper verifies the ZIP again, extracts its single
`Waystone.exe` into the same directory and atomically replaces the old
executable. `Waystone.exe.previous` retains the preceding executable. If
starting the new executable fails, the helper restores the old file and
relaunches it. An interruption during staging leaves the existing executable
available for the next launch. Existing saves and settings remain in the
standard per-user directory. The install folder must be writable by the
player and support Windows file replacement.

On Android, Waystone requires the same package name and current signing
certificates, an Android version code greater than the installed one, and a
version name matching the offered release. On Android 8 and later, the system
may ask the player to allow installs from Waystone. Return to the menu and
choose **Install update** after granting it. Android shows its own
confirmation and performs an in-place update that keeps app data. The player
can return to Waystone after declining or canceling and retry from the menu.

## Publishing compatible releases

The public latest-release response at `guylfe/waystone` must identify a stable
`vMAJOR.MINOR.PATCH` release. Upload `Waystone-Windows.zip` with exactly one
entry at the root named `Waystone.exe` and `Waystone-Android.apk` signed with
the existing certificate for `com.waystone.prototype`. Increase the Android
version code for each numbered release. The published asset needs a nonzero
size within 256 MiB, the canonical GitHub asset URL, and a GitHub
`sha256:` digest. Waystone downloads to app data and checks its size and SHA-256
before handing it off. The downloader follows one HTTPS redirect from GitHub
to its release asset host.

Use the existing `build-all.ps1` flow for both platforms. The Windows preset
embeds the replacement helper and the Android preset adds the permission
required to open the system installer. Confirm the exported APK has the
release package name, version code, and certificate fingerprint reported by
`apksigner verify --print-certs` for the previous official APK. The Android
adapter uses the non-exported Godot FileProvider and grants the installer read
access only to the verified APK.

## Verification

- `python tests/release_update_test.py <Godot-console.exe>` exercises the real
  startup scene, input, save, cancellation, and download checks against a
  loopback fixture with isolated app data.
- `python tests/windows_release_update_test.py <candidate Waystone.exe>
  <published Waystone-Windows.zip> <published GitHub SHA-256>` uses disposable
  Windows installs of genuine binaries. It checks replacement and relaunch,
  rollback after a launch failure, invalid downloads, and preservation of a
  save produced by the released binary.
- Physical Android installation requires an older and a newer APK with the
  same package and signer, plus a saved run to reopen. Test the permission
  prompt, cancel/retry, confirmation, and saved-run readback on an enrolled
  device before treating the native flow as verified.
