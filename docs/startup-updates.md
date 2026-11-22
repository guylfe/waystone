# Startup update checks

This describes regular Waystone 0.3.9. [Current state](current-state.md)
owns publication and device status.

On a normal Windows or Android launch, Waystone makes one anonymous HTTPS
request to the official [latest stable GitHub release](https://docs.github.com/en/rest/releases/releases#get-the-latest-release).
The request is independent of the comment relay. It sends no run data or
player credential. The game loads and resumes while the request runs.
Unreachable, invalid and unsuccessful responses leave play uninterrupted.

If the release advertises a newer numeric `vMAJOR.MINOR.PATCH` and the
appropriate uploaded asset, the setup screen shows **View on GitHub** and
**Dismiss**. A resumed run shows a brief notice after the current action,
with both options available in the Run or Survey menu. **View on GitHub**
opens the standard release page. **Dismiss** hides the notice for this
launch. Download and installation are manual.

## Publication

Publish regular releases to `guylfe/waystone` with their matching
`vMAJOR.MINOR.PATCH` tags. The game looks for `Waystone-Windows.zip`
(containing the standalone `Waystone.exe`) and `Waystone-Android.apk`.
The published release and asset must be publicly readable. The app checks
the uploaded asset name, nonzero size, and canonical GitHub download URL
for the current platform. It does not fetch the installer.

## Verification

Run `python tests/release_update_test.py <Godot-console.exe>` from the repo.
The runner uses the real startup scene with disposable app data and a
loopback GitHub fixture. It captures the official URL requested by player
input without opening a browser. Real GitHub publication, device startup
and downloading the official assets are separately verified.
