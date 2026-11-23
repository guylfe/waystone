# Mid-run comments

This client is part of the Waystone 0.3.10 release candidate. [Current state](current-state.md) owns
release and device status.

## Capture and input

Open **Menu → Comment** in Expedition, Campaign, Campaign Lab, Boss Lab, and
ordinary Combat Survey. For an experimental Survey, use **Survey menu → Comment**.
The regular Run menu waits for the current commitment to finish as usual.
**F8** opens the editor immediately, including during a committed action.

Type a multiline comment and choose **Review comment**. The review explains
that the note, build and gameplay context will appear in a public GitHub issue.
**Send publicly** saves the report and queues it for delivery. **Save locally**
keeps the note on this device. **Back** returns to the draft.

On Windows, **Ctrl+Enter** opens review and **Esc** returns to the draft or
closes the editor from the draft. Controller Start opens the appropriate
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
UUID and the player's choice about public submission. The editor shows
separate queued, sent and local counts. After confirmation it shows **Sent
as GitHub issue #N** in the editor, including after restart. A receipt that
arrives during play shows the same status in a toast. **Delivery** shows a
copyable receipt URL. Notes and receipts remain on disk when a run is
abandoned. The game stores them separately from run saves and Survey reports.

Existing schema 1 notes and receipts remain readable on disk. They stay out
of public delivery. The earlier relay enrollment remains stored for
compatibility. Public feedback uses its own enrollment.

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

In the editor, choose **Delivery**, enter your Waystone playtester code,
and choose **Apply**. First enrollment uses
`https://guylfe-game-feedback.netlify.app/v1/feedback`. For an override,
enter the approved HTTPS origin or the complete `/v1/feedback` URL and its
own code. To keep the code for the current address, leave the masked field
blank. To replace the code, enter the new code and apply. To turn delivery
off, clear both fields and apply. Pending reports and receipts are retained.
Reports can be queued before enrollment.

The participant code is masked during entry and never echoed in the settings
form or included in feedback. The code and endpoint are stored in the user's
app data at `user://run-comment-delivery.cfg`, which is readable by anyone
with access to that data. Use revocable, submission-only credentials. All
GitHub credentials belong on the service.

The worker sends `POST /v1/feedback` with `game` (`waystone`), `reportId`
(UUID), `build`, `note`, and `context`. It sends the code as a bearer token
and the same UUID as `Idempotency-Key`. HTTPS redirects are disabled. The
top-level build is the game version, limited to 96 characters. The original
build and source identifiers remain in the gameplay context. The public
context is capped at 8,192 UTF-8 bytes of JSON within the service's 16,384-byte
request limit. When necessary it drops the oldest messages, then the oldest enemy actions, then the farthest enemies.
The local record keeps the opening context.

New (schema 3) public reports store their exact request body alongside the
note and consent. Existing schema 2 reports retain their original request
encoding and replay unchanged with their original UUID. Some older reports
may exceed the service's current limits.

The service deduplicates by game and report UUID, including when a response
is lost after issue creation. A retry returns the same issue. Waystone
confirms delivery only for HTTP 200 or 201 with a positive integer
`issueNumber` and an `issueUrl` exactly equal to
`https://github.com/guylfe/waystone/issues/<issueNumber>`. The client records
the receipt beside the note before removing the report from its pending list.

HTTP 202 keeps the report queued while the service processes it. For 202,
429 and 503, Waystone waits until at least the advertised `Retry-After`
deadline, including after restart. The fallback backoff starts at two
seconds and grows to sixty seconds. HTTP 401 or 403 pauses delivery across
restart until the enrollment changes. HTTP 400 or 409 stops retries for that
report and keeps the local note. Other eligible reports continue. Delivery
shows the next step for either rejection. A report already accepted under an
earlier code can conflict after replacing that code. The playtest organizer
can look up the original report before a player resends it.

For future games using the same service, give the player a public-disclosure
step, persist the report UUID and consent together, restrict accepted receipts
to that game's repository, and surface the issue number during play and after
restart. Use the same deduplication and receipt checks for each first build.

## Verification

Run `./run-tests.ps1 run_comment_ui_test run_comment_queue_test` from the
project root. The tests drive keyboard, synthetic touch and controller events
through the normal boards using disposable data. To exercise the transport in
the queue test, run Godot with
`--headless --path . -s tests/run_comment_queue_test.gd -- --loopback`
and isolate `APPDATA` and `LOCALAPPDATA` under `.runtime`. That receiver
tests a lost response after the first write and a mismatched issue number
before the successful retry.

Run `python tests/run_comment_delivery_test.py <Godot-console.exe>` to exercise
code-only enrollment, credential replacement and clearing, deferred retries
and receipt readback through the standard game entry across fresh processes.
The fixture verifies byte-identical schema 2 replay, persisted 401, 400 and
409 stops, and deduplication through a delayed receipt. The plaintext
fixture runs only on headless debug loopback and sends no credentials.
Live enrollment and GitHub readback, native keyboard and controls, and
installed-build verification are separate checks.
