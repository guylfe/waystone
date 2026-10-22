# Isolated menu/input correction

22 October 2026. Runtime accepted at `d797b01`; locally packaged as 0.3.5 /
Android 305 without runtime-code changes. Both independent final reviews and the
lead's bounded native review passed, including its corrected normal-processing
archive supplement. Exact build/destination verification lives in the external
local-delivery receipt. No remote publication or Android installation is implied.

The dated implementation entries below preserve their original evidence limits.
Their earlier open native/independent-review status is superseded by the bounded
acceptance above. Physical controls, Android/foldable behavior, natural play,
Guy's exact reset and subjective feel remain open. The [current-state owner](current-state.md)
records the delivered baseline; unadopted proposals remain separate.

## Contract and ownership

Frozen deliberation requires dependable input handover: releasing a captured
press must reach its owner after the visible context changes. A menu still serves
the established committed-action suspension boundary. Return requires actual
neutral controls and a fresh gameplay press. No combat timing, damage, costs,
fixture, collision, persistence or result calculation changed.

`combat_lab_board.gd` observes releases before context dispatch, retains held
keys/buttons/axes/contacts across Character and native overlays, and cancels
controller captures on its device's disconnect. Inspection remembers the device
even when it consumes the event before the combat adapter. Its B/Escape, Start
and explicit Resume use the same suspension-return operation. Details Back
returns to the menu; Start resumes directly. Opening the menu still closes an
optional Sword sequence or serves the committed obligation through `lab_suspend`.

`controller_input.gd` owns semantic focus memory and context return, including
native setup, feedback/report, distinct archive list/detail, Character subviews,
the drawn custom composer/map and generic pause. Character and Map return to
their invoking Survey item; generic-pause Character returns to that pause item.
The deepest Back operation is selected first. Feedback must still be deliberately
submitted/skipped; Back never fabricates an answer or discards an attempt.

`menu_navigation.gd` supplies geometric neighbors. Up/Down selects setting rows;
Left/Right changes a focused setting in either direction. Rating/tag/custom grids
follow their visible neighbors. Commands activate with A/Enter. There is no
long-form wrap from the last item to the first. D-pad and stick share 0.32s initial
and 0.14s subsequent repeat, with 0.55 engage / 0.40 neutral hysteresis. Keyboard
arrows use OS repeat. Native text fields have an explicit editing state: activate
or click to edit, Escape to return to navigation. Optional desktop text entry
truthfully requires a keyboard; the existing supported mobile keyboard remains.

Survey setting values update in place. Stable field IDs, actual focus entry and
post-layout scroll correction preserve field/seed/roster context through value
changes and resize. Touch rows provide separate Previous/Next controls; the same
value callback owns both directions. Archive records and ratings have explicit
semantic IDs. Archive detail Back returns to its list record; list Back restores
its report/setup invoker. Stored records, report text, provenance and export
callbacks are preserved.

## Menu metrics and Character

`menu_metrics.gd` converts client menu sizes through the actual final viewport
transform. Desktop review targets are 16–18px body text, at least 48px commands,
and a bounded 820px column. Authored titles/hints may be larger. Mobile menus
include reported screen density relative to 160dpi; this is an implementation
choice requiring device review, not verified Android dp/hit-size acceptance.
Projection and simulation geometry remain owned by the existing board/executor.

`character_menu.gd` uses native wrapping controls and scrolling for existing
equipment, attributes, belt repacking, weapon arts, tracks, stage inspection and
upgrade/choice confirmation. It calls the established state transactions and
confirmation rules. Track cards reflow from three to two to one column, retaining
readable type and row height instead of shrinking text to fit a fixed card. An
opaque panel separates text from world annotations. The panel also synchronizes
while the experimental menu is suspended, so closing Character hides its native
surface immediately. Existing equipment-detail placeholder content remains;
the equipment-explanation proposal has not been adopted here.

Expanded inspection is a separate bounded modal with an opaque backdrop. Its
commands take precedence over covered action-grid hit regions; blank modal space
cannot activate the HUD underneath. World enemy keys/leaders are suppressed
behind modals, and hidden zero-sized toolbar rectangles do not draw glyph text.

## Verification and limits

### Feedback width and Character information parity after independent review

The successor to `bce46bb` repairs a second width-domain error: feedback controls
were client-scaled, but their rating/tag columns were chosen from logical world
width. Under the real project root transform, a modeled 390×844 client still
looked logically wide and expanded the panel beyond the viewport. Reflow now
budgets the requested MenuMetrics area minus actual panel padding and a reserved
vertical scrollbar, in the same units as control minima. Question labels stack
when necessary; rating grids and tags choose fitting columns. Body type and
48-unit command minima remain intact. Reflow runs on creation and transform/area
changes without rebuilding answers, tags, notes or controls. A post-layout scroll
correction preserves the existing pointer-focused control as well as controller
focus, without switching input devices or assigning a new focus target.

Cold narrow entry also reproduced a double-scaled computed minimum in End Survey
confirmation. It now uses bounded wrapping/scrolling content and a fitting
button grid, retaining the same confirmation/cancel callbacks and wording. This
is a related containment correction, not the unadopted manual-end wording change.

Character again displays its state-supplied level-up context and spendable XP.
Waystone secured100/carried147/cost6 displays spendable secured100, separately
labelled carried147 and projected remaining94. Other contexts use their existing
carried balance. The existing native transaction, account debits and autosave
remain unchanged. Equipped/locked art, completed versus available/future stage
status, stage-detail availability, weapon sequence/form and the empty adopted
track explanation are restored in wrapping content. Sword/Knife/Twin Knives/Bow
reuse the retained authored form strings; Staff uses the existing authored
AttackGeometry technique label instead of the old generic Sword fallback.
All known-art controls remain subject to the existing swap prohibition.

The parity checklist compares the pre-migration Character header, retained
combat summary, track cards, stage inspection and confirmation with current state
data. Equipment names/placeholders, attributes, healing/belt counts, chosen stage
labels, rank and purchase callbacks remain; no equipment-effects proposal was
adopted. Exact checklist evidence and before/after labels belong in the external
handoff.

Three default headless regressions supplement the prior transaction/input tests:

- `feedback_root_layout_test.gd` uses the actual project root stretch, routed
  pointer/controller inputs and real delayed feedback. It covers wide→720×480→
  390×844 and the other documented transforms, all answers/questions/tags/notes/
  commands/hints, safe/clipping bounds, exact focus identity, scroll context,
  retained and submitted values, and cold narrow entry. It does not replace the
  normal root with a same-size direct SubViewport. Input journeys run with normal
  board processing; rectangle inventories temporarily pause board dispatch so
  controller auto-scroll does not fight inspection scrolling. Native child layout
  continues, and each hints-on/off inventory asserts actual hints visibility.
- `menu_density_layout_test.gd` begins with actual delayed feedback, then pauses
  the isolated board for explicit unit/density geometry models using the same
  layout code, plus a safe-area inset. A fresh labelled Boss Lab fixture checks
  its separate authored questions. These are geometry models, not observed
  platform DPI, mobile play or native frames. Normal runtime units still come
  only from the actual viewport and platform density; explicit-unit helpers add
  no player setting or saved state.
- `character_information_test.gd` uses labelled synthetic XP/art/form fixtures,
  generated native text, routed branch purchase and state-account assertions in
  Waystone, Survey and Expedition contexts. It checks projected balance, art
  eligibility/identity, completed/future detail and authored forms. These are not
  naturally earned progression.

The 390px root is a virtual narrow/phone layout boundary below the configured
native Windows minimum. The 720×480/default/wide models retain the actual project
stretch too. None of these headless checks certify GPU pixels or native-window
input; final rendered review remains open through the lead-arranged surface.

### Character transaction correction after combined review

The native branch selector originally stored a bare branch ID, while
`RunState.choose_upgrade` and the original drawn selector require
`track_id|branch_id`. The isolated successor to `03336ab` restores that encoded
transaction value, retaining the existing semantic button IDs. Confirmation
continues to use the existing eligibility, XP, rank, branch-effect and critical
autosave owners; no progression or save format rules change.

Two neighboring return defects were reproduced during that transaction audit.
Character Back could restore pause before the native panel's visibility updated,
letting native entries reach the drawn pause renderer, which expects labels.
The native-panel lookup now also checks the actual Character-open state. A paid
belt repack now consumes its pause/Survey return context when it closes Character,
so a later independent Character opening cannot return to a stale invoker. The
same state request still owns the slot swap and 0.32-second committed action.
Weapon-art swapping remains disabled by the existing state policy.

`tests/character_transaction_test.gd` enters the normal main scene's Character
screen through routed controller input. Labelled synthetic progression fixtures
exercise both initial Sword branches and both initial Steadfast branches in
Expedition, ordinary Survey and Campaign Waystone contexts. Each compares all
progression fields with the established state transaction and reloads the native
confirmation's autosave. It covers selection/cancel, one debit/rank/history entry,
completed-stage inspection, fresh A and duplicate rejection, ordinary Evasion,
insufficient XP, level gates and a stale confirmation. Replenished-XP reloads
separately diagnose the duplicate consumer guard at these initial-stage gates.
Synthetic legacy-art and belt fixtures cover disabled swap eligibility, two-slot
selection/cancel, paid repack timing against the state owner, frozen completion
and return context in Expedition and experimental Survey. These fixtures are not
naturally earned play, physical controller input or exhaustive progression play.
The paired unchanged-control/successor logs, exact test hash and counts belong in
the external transaction-repair handoff.

`tests/menu_journey_test.gd` uses the normal main scene and viewport-routed inputs
with normal frame processing. It configures B/C, named and ordinary Survey, both
resource rules; traverses Character/stage/detail/Back, Map, safe Resume, held
trigger/stick/key/touch return, delayed feedback, spatial ratings and archive
list/detail/report return. It checks focus against clipping ancestors after
resize and exact archive bytes. Focus loss and disconnect include explicit owner
diagnostics, not OS hardware claims. No test assigns a neutral flag or a focus
index to make those journeys succeed. It is included in the default test runner.

The earlier pause-input regression retains repeated F, Enter, RT hysteresis,
touch/pointer, optional exits and legitimate menu-entry sequence endings. Its
Resume click now targets the visible full-menu command after native layout.
The legacy direct-index controller unit test explicitly clears semantic focus
for its bounded diagnostic; it is not sequential-navigation acceptance. The
existing archive 0/1/6/12 × five-size × hints matrix remains available. Expanded
Details may fit without scrolling; its test now distinguishes fitting content
from overflowing content instead of requiring unnecessary scroll.

The external handoff retains an identical common handover probe against the
immutable keyboard-only control and this successor, initial failed instruments,
focused test logs, source preservation hashes, and native-render limitations.
An initial real-native setup capture calibrated the client/logical transform and
revealed transparent Character presentation. Its later Character/feedback labels
did not all represent reached views; those are failed audit instrumentation,
not accepted layouts. A second mounted background attempt had a harness parse
error; its child was subsequently reported foreground despite the inactive,
minimized wrapper. That rendering route was stopped, and only the identified
isolated child was closed through background UIA and verified gone.

No final native rendering is claimed after the opacity/layout/focus corrections.
Headless geometry, source checks and routed synthetic input do not certify GPU
pixels, physical controller/touch comfort, native-window input, Android keyboard,
device density/orientation/performance, or Guy's acceptance of feel. Final native
feedback at all sizes and the changed archive/Character presentation still need
independent rendered review in a background-safe environment. The exact user
attack-reset sequence remains unresolved; retaining the F correction does not
establish that it fixes his report. The manual-end outcome-wording proposal also
remains unimplemented.
