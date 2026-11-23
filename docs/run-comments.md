# Mid-run comments

This client is based on Waystone 0.3.9. [Current state](current-state.md) owns
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

In the editor, choose **Delivery**, enter the approved HTTPS service origin
and its participant-scoped submission token, then choose **Apply**. The
client accepts the origin or the complete `/v1/feedback` URL. An empty token
keeps the existing credential for the same endpoint. Clear both fields and
apply to disable delivery. That preserves consented pending reports and
existing receipts. Reports can be queued before enrollment.

The endpoint and participant token are stored in the user's app data at
`user://run-comment-delivery.cfg`. Anyone with access to that app data can
read it. The service should issue revocable, submission-only credentials.
All GitHub credentials belong on the service.

The worker sends `POST /v1/feedback` with a JSON body containing `game`
(`waystone`), `reportId` (UUID), `build`, `note`, and `context`. It sends
`Authorization: Bearer <participant token>` and the same UUID as
`Idempotency-Key`. HTTPS redirects are disabled. The request body is derived
from the immutable saved report on every attempt.

The service must deduplicate by game and report UUID, including when a
response is lost after issue creation. A retry for the same report must return
the same issue. A confirmed response is HTTP 200 or 201 with a positive
integer `issueNumber` and an `issueUrl` exactly equal to
`https://github.com/guylfe/waystone/issues/<issueNumber>`. The client records
that receipt beside the note before removing the report from its pending
list. Failed requests or invalid receipts leave the report queued. Retries
start at two seconds and back off to sixty seconds while the game runs.
The worker checks pending reports on launch, enrollment and successful save.

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

Run `python tests/run_comment_delivery_test.py <Godot-console.exe>` to test
capture through the standard game entry, restart and receipt readback across
three processes. The fixture checks that legacy notes remain local, the
report retries with the same UUID and request bytes after failures, one issue
is recorded by the test receiver, and relaunch after confirmation sends no
request. The plaintext fixture runs only on headless debug loopback and sends
no credentials. Live service enrollment and GitHub readback, native keyboard
and controls, and installed-build verification are separate checks.
