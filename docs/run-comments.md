# Mid-run comments

Waystone 0.3.11 uses private suggestion files. [Current state](current-state.md) owns
release and device status.

## Capture and input

Open **Menu → Comment** in Expedition, Campaign, Campaign Lab, Boss Lab, and
ordinary Combat Survey. For an experimental Survey, use **Survey menu → Comment**.
The regular Run menu waits for the current commitment to finish as usual.
**F8** opens the editor immediately, including during a committed action.

Type a suggestion and choose **Send**. The editor explains that the Waystone team
receives your note, build and gameplay context privately. **Save locally**
keeps the note on this device. On Windows, **Esc** closes the editor.
Controller Start opens the appropriate
menu. Use D-pad or left stick and A to open Comment and choose an action.
B goes back. Use a keyboard to compose with a controller. On Android, tap
the editor to open the software keyboard, or use a connected keyboard.

The world freezes when the editor opens. Closing it returns to the previous
view, including a paused Survey or Run menu. Live gameplay resumes any
committed action. A fresh press is required to repeat held gameplay input.
Cancel discards the draft. If a write fails, the editor retains the draft,
opening snapshot and UUID for another attempt.

## Local records

Each successful save creates `user://run-comments/<id>.json` with a stable
UUID and the player's choice to send or save locally. The editor shows
queued, sent and local counts. A receipt arriving during gameplay displays
**Feedback sent**. Local records and receipts are separate from game saves.

New notes allow up to 2,000 UTF-16 units. Supplementary characters such as
many emoji use two units. The versioned JSON holds the note ID, the note,
and the gameplay context captured when the editor opens. Context includes game and build
identity, entry mode, seed, location, simulation tick, the player, and up to eight
closest visible living enemies on the current layer. It records positions,
health, posture, conditions and action timing. Expedition adds the biome index.
The regional Campaign records the area ID and name and terrain layer. Survey
and Boss Lab add room identity and up to eight existing enemy action events.
Up to eight recent game messages are held in memory and start fresh on load.
The capture excludes raw process and device logs, personal filesystem paths,
credentials, and serialized saves.

## Delivery integration

Waystone posts the stored JSON with `game`, `reportId`, `build`, `note` and
`context` to `https://guylfe-game-feedback.netlify.app/v3/feedback`. Each
suggestion uses its own UUID. The client sends no credentials and refuses
redirects. Only HTTP 200 with matching game, UUID and
`playtest-feedback/<uuid>.json` confirms a private file. The client persists
the receipt beside the note. Offline, 202, transient errors and invalid
receipts leave the original bytes and UUID queued for retry. The client
honors Retry-After on 202, 429 and 503 across restarts. A 400 or 409 keeps
the rejected note locally. Previously submitted and acknowledged reports
stay delivered. Old local-only notes stay local, and previously approved
pending notes retain their IDs and original request bodies.

## Maintaining the private inbox

Handle each suggestion in its own file in private intake. After implementing
and verifying the change, delete that suggestion's file from the private
inbox and verify its removal. Keep pending suggestions until verified.
Keep player reports out of the public game repository.

## Verification

Run `./run-tests.ps1 run_comment_ui_test run_comment_queue_test` and
`python tests/run_comment_delivery_test.py <Godot-console.exe>`.
The normal-entry fixture uses disposable data and a loopback receiver to
exercise sending, restart, deferred responses, schema migration and receipts.
