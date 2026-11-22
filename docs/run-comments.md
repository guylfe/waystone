# Mid-run comments

Status as of 2026-11-22. Local capture candidate based on regular Waystone 0.3.8
at `83e4087`. [Current state](current-state.md) owns release and device status.

## Capture and input

Open **Menu → Comment** in Expedition, Campaign, Campaign Lab, Boss Lab, and
ordinary Combat Survey. For an experimental Survey, use **Survey menu → Comment**.
The regular Run menu waits for the current commitment to finish as usual.
**F8** opens the editor immediately, including during a committed action.

Type a multiline comment and choose **Save comment**. On Windows, **Ctrl+Enter**
saves and **Esc** cancels. Controller Start opens the appropriate menu. Use the
D-pad or left stick and A to open the editor and choose an action. B cancels.
The controller workflow uses a keyboard to compose. On Android, tap the editor
to open the software keyboard, or type with a connected keyboard.

The world freezes when the editor opens. Save and Cancel both return to the
previous view, including a paused Survey or Run menu. Live gameplay resumes
any committed action. A fresh press is required to repeat held gameplay input.
Cancel discards the draft. If a save fails, the editor retains the text,
opening snapshot and ID for another attempt.

## Local records

Each successful save creates `user://run-comments/<id>.json`. The UI confirms
the local save. Notes remain available across game exits and mode changes, even
when the corresponding run is abandoned. The game stores the note separately
from all run saves and Survey reports.

The versioned JSON holds the note ID, text up to 2,000 characters, and a bounded
context captured when the editor opens. Context includes game and build
identity, entry mode, seed, location, simulation tick, the player, and up to eight
closest visible living enemies on the current layer. It records positions,
health, posture, conditions and action timing. Expedition adds the biome index.
The regional Campaign records the area ID and name and terrain layer. Survey
and Boss Lab add room identity and up to eight existing enemy action events.
Up to eight recent game messages are held in memory and start fresh on load.
The capture excludes raw process and device logs, personal filesystem paths,
credentials, and serialized saves.

## Delivery integration

This candidate saves locally. Production sending requires an approved destination
and authentication. The optional client transport posts the original JSON bytes
with the note ID in the `Idempotency-Key` header over HTTPS, with redirects
disabled. A success requires HTTP 200 or 201 and a JSON receipt containing the
same `id`, the SHA-256 digest of those bytes as `sha256`, and a nonempty
`reference`. The reference should identify the verified GitHub record. The
client stores the matching receipt beside the immutable note, excludes it from
the pending list, and can safely retry a missing or mismatched receipt.

For a private GitHub inbox, the smallest deterministic receiver can create
`comments/<id>.json` in the approved repository using a GitHub App installed
only on that repository with Contents write permission. A separately
authenticated player request can carry the note to that receiver. Keep the
GitHub App private key and installation tokens on the receiver. On a retry,
read the existing file, verify byte identity, and return the same reference.
Return a conflict if the saved bytes differ. Issue creation would need its
own durable deduplication and readback. See
[GitHub's Contents API](https://docs.github.com/en/rest/repos/contents#create-or-update-file-contents)
and [installation authentication](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation).

To release live sending, wire the approved receiver and player authentication
to the pending queue, expose queued and delivered states, and enable Android
network access. Verify an authorized test submission by reading back the GitHub
file and comparing its bytes, then build Windows and Android from the same
release commit and check real Windows input and the Fold keyboard in both
orientations.

## Verification

Run `./run-tests.ps1 run_comment_ui_test run_comment_queue_test` from the project
root. These tests use disposable data and drive Godot's input events through
the normal boards. For the HTTP integration test, run the same queue script with
Godot `--headless --path . -s tests/run_comment_queue_test.gd -- --loopback` and
the test runner's isolated APPDATA and LOCALAPPDATA paths. The fake receiver
binds only on localhost. It simulates a lost response after writing, a wrong
digest, and a successful idempotent retry. Headless input and geometry checks
leave native IME, graphics, physical control and installed-build verification
open.
