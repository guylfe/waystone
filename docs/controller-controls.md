# PC controller controls

## Isolated additional Commit Shot — 1 November 2026

The combined phone successor to frozen `e35ffd8` adds an explicit Sharpshooter
Bow selection alongside ordinary Attack and learned art. It is not installed or
device-verified. Guy explicitly requested this additive action; the initial +25%
damage is the lead's tuning choice. Mechanics are owned by the
[character framework](combat-character-framework.md#152a-isolated-additional-commit-shot--1-november-2026).

| Input | Selection and confirmation |
| --- | --- |
| Touch | COMMIT SHOT (at least 48 client/density units), then tap a visible enemy. Tap the selection again to cancel. |
| Keyboard | **G** selects/cancels; **Tab** cycles visible targets; **Enter** confirms. G was unused in both ordinary and lab handlers; K/J/T remain the lab controls. |
| Controller | Hold **LB**, press **A** to select; right-stick click cycles visible enemies; **A** confirms, **B** cancels. The palette entry/help names the bonus. |

Uncommitted selection is free and stationary. Invalid/no target gives a reason
and leaves a deliberate selection available. Ordinary Attack/F replaces it.
Successful confirmation consumes it and requires a fresh select/confirm for another
shot. RT remains ordinary hold/release, RB remains learned art and Y remains Take
Aim. Commit Shot is not an art purchase or a rebinding. During its committed draw,
a fresh touch drag or right-stick aim uses the ordinary limited aim adjustment;
release cannot fire early. Character → Combat describes cost, bonus and mappings.
Selection help uses the same actual Energy-cost owner as Character Combat, or
explicitly says Recovery has no Energy debit. It shows the controls for the input
that selected the action: touch selection/enemy, G/Tab/Enter, or pad RS-click/A/B.
The bounded successor to `fce23f5` changes this formatting without changing rules.

The retained release observer previously cleared captured keyboard ownership before
F's ordinary Bow release handler. A matched main-root probe demonstrates an endless
draw on frozen e35. The observer now delivers that captured release before clearing
its owner. The prepaid action refuses early release through the same API. Frozen
Sword F continuation and physical-neutral/menu protections remain required controls.
This specific Bow defect is not a diagnosis of Guy's unidentified attack-reset report.

Normal-root routed fixtures cover touch, keys and synthetic pad in both projections,
plus menu, synthetic focus/disconnect, ordinary quick/partial/full charging and
release/repress. Energy uses real Expedition entry; Recovery uses real Boss Lab
entry because the generated Expedition intentionally remains Energy-only. Artificial
open geography/inert targets are named fixtures, not naturally earned play. Headless
geometry/input is not native pixels, physical controls, Android or feel acceptance.

The dated sections below retain their original historical status.

**Unpublished 22 October correction:** setting rows use Up/Down to choose and
Left/Right to change values; grids follow visible neighbors; A/Enter activates
and B/Escape returns to the invoker. Captured releases survive Character/menu
handover, while held controls still require physical neutral and a fresh press.
Setup edits preserve semantic focus/scroll. Archive list/detail and Character
subviews have separate return contexts. Character uses responsive native rows;
menu sizes convert through the actual viewport transform. See the
[implementation and evidence ledger](menu-input-correction.md). This is a
candidate contract, with final native rendering and physical comfort still open;
the established released bindings below retain their historical status.

The isolated 21 October primary-key correction also permits keyboard F to
continue a frozen experimental Sword junction, using the same token as Enter
and RT. Its routed regression checks RT 0.55/0.25 press/release hysteresis and
release/repress through cuts 2/3; physical-controller acceptance remains open.
See [the bounded correction](survey-combat-integration.md#isolated-primary-key-correction--21-october-2026).

The accepted 21 October Survey correction reflows shared native menu hints into
whole glyph/word pairs at narrow widths, preserving their labels and sizes. The
archive uses wrapping 48-unit records in one scroll owner; focus scrolling and
A selection must correspond to visible rows. The focused five-size 0/1/6/12-run
renderer/input probe and exact review boundary are owned by
[Survey integration](survey-combat-integration.md#archive-layout-correction--21-october-2026).
Independent R1/R2 review passed; 786 fresh shared-hints checks passed across
setup, feedback, report and retry. Physical controller feel remains unverified.

0.3.4 adds opt-in experimental controls inside the normal **Dev → Survey** entry.
LT arms Commit; right-stick click cycles eligible targets; RT explicitly confirms
or continues; left-stick click recovers at a frozen Sword junction. Start opens
the Survey menu; D-pad/A navigate native choices and ratings, and fresh neutral
input is required on return. All-enemy Details supports touch taps/swipes and
controller paging. Other modes retain the bindings below. See
[Survey integration](survey-combat-integration.md) for ownership and evidence limits.

**Baseline:** 0.3.4, presentation 20 (ordinary bindings retained from 0.3.3). **Status:** implemented; physical play acceptance
remains open. This owns the bindings and verification record, not combat mechanics;
the character framework and RunState remain authoritative for those.

## Xbox-style bindings

| Control | Action |
|---|---|
| Left stick | Move in screen direction; release finishes the current small step |
| Right stick | Full analog ranged direction; no distance tied to magnitude. In placement mode, move the ground marker |
| RT | Attack; hold continues melee sequences, release ends continuation / fires Bow |
| B | Dodge, Block or Endure; movement direction takes priority over aim; hold for Block |
| RB | Equipped weapon art |
| Y | Subclass ability or selected spell; hold for Advance |
| LB (hold) | Reveal direct shortcuts on the existing bars; release restores ordinary labels |
| LB + A / B / X / Y / RB (Mage) | Lightning / Fire / Ice / Earth / Air spell; learned elemental choices keep these fixed positions |
| LB + D-pad left / down / right | Directly use utility slot 1 / 2 / 3, or replace that slot with a pending pickup |
| LB + D-pad up | Adopted discipline: Trapper in movement direction; Sapper opens ground placement |
| X | Rejuvenation pouch |
| A | Context interaction, or one Wait step when no interaction is available |
| D-pad up | Rally / Stealth toggle, or Circle |
| D-pad left / right | Select one of the three utility slots |
| D-pad down | Use selected utility, or replace that slot when a pickup is pending |
| Left-stick click | One deliberate Wait step |
| Right-stick click | Bow/Mage: cycle visible targets, ending with none; manual aiming clears it |
| A / B during ground placement | Commit at marker / cancel without a cast or Dodge |
| View | Map |
| Menu | Resume, character/upgrades, controller guide, view, save and quit, or confirmed abandonment |
| D-pad / left stick in menus | Move focus; A confirms, B backs out |
| LT | Unassigned; Xbox and Share are managed by the system |

Take Aim requires an explicitly selected visible enemy. The other characters can
attack and cast freely without target selection. Invisible, dead and other-layer
actors are never valid controller target selections. There is no auto-dodge,
auto-pathfinding, hidden aim correction or controller-specific combat discount.

Melee weapons (including the Mage's staff), defense, Advance, Vault and Windstep
follow the left-stick movement direction or current facing. Ranged aim cannot
redirect them. Bow/spells use a live right-stick heading, then movement/facing or
the retained ranged heading when stationary. Both axes are sampled together when
retaining that heading, preventing an axis-release event from snapping it sideways.
Only exact-location abilities use a crosshair: placed spells and Sapper. The marker
moves while the simulation stays stopped, holds its position on stick release and
is clamped to authored range. Confirmation uses normal combat legality and cost.
Thrown items also use ranged direction; a melee character sees that guide while
holding LB if a directional item is carried. Self-use items do not inherit ranged aim.

All run setup character choices, upgrades, equipment comparisons, merchant stock,
discipline choices, maps and survey rating buttons are controller-accessible. Optional
free-text survey notes and exact seed entry still use the keyboard. On PC, controller
UI appears immediately on connection, including a controller already present at
startup. Connection itself does not spend time; neutral input is required before
movement or combat. A keyboard key, mouse click or touch returns to the existing
controls until fresh gamepad input or reconnection. Stick drift below the radial
0.24 deadzone does not move or reclaim input. RT uses 0.55 press / 0.25 release hysteresis.

## Illustrated interface

The HUD pairs action names with original Xbox-style SVG images: colored A/B/X/Y,
shaped bumpers/triggers, labeled sticks and click indicators, directional D-pads,
View and Menu. Images do not replace the action text. Descriptions distinguish
hold/release/tap and show actual selected abilities, items, charges and cooldowns.
Locked arts and empty consumable slots remain explained instead of disappearing.
The touch ability/item bars and spell drawer remain in their original positions;
no controller-only replacement rail is used. LB changes slot badges to direct
buttons and temporarily opens the Mage drawer. Normal badges show LB combinations,
with Y on the currently selected spell. Actions whose buttons are reassigned while
LB is held do not advertise their ordinary bindings. Existing quantities, costs and
cooldown displays stay visible. The old selector modal is removed.
Menu → Controller guide gives the complete reference, including unused LT and
system buttons. Shops, equipment dialogs and survey menus share the same images.
Mandatory survey/outcome panels do not advertise B as a way to skip submission.

`controller_glyphs.gd` owns the atlas and reusable menu hints;
`controller_prompts.gd` owns display descriptions/layout. Those presentation modules
read the combat state/catalogs; they do not author combat costs or availability rules.

## Ownership and safety

- `scripts/presentation/controller_input.gd` owns temporary input intent and focus.
  No controller state is copied into combat snapshots or save migrations.
- `game_board.gd` routes native events and frame-boundary intents; combat calls use
  existing RunState entry points. The native dialog relay is required because
  dialogs have a separate Viewport. No world pointer/touch event is synthesized.
- Custom-drawn menus focus actual entries and reuse their activation handlers.
  Native buttons retain their enabled/toggled state and scroll into view on focus.
- New actions cannot cancel commitments. A 0.22-second input buffer preserves fresh
  action presses near a boundary; it expires and is cleared by modal/focus changes.
- Menu/disconnect releases Bow/combo/Block/Advance holds. A current commitment still
  finishes; save/quit is unavailable until it does. Releasing a drawn Bow follows
  the existing release-to-fire rule, not a free cancellation.
- Returning from menus requires neutral input, preventing accidental attacks or
  movement from a stick/trigger held while navigating. Only one gamepad owns input
  at a time; disconnect permits another device to claim it.
- LB stops held movement/attack chaining while shortcuts are displayed. It does
  not cancel a current commitment; shortcut presses while busy are not queued.
  Releasing LB requires neutral controls before ordinary movement resumes.
  Ground placement suppresses movement/attacks; cancellation, disconnect, focus
  loss or a switch to keyboard/touch discards the uncommitted marker.
- Abandonment requires a second confirmation. Save-and-quit preserves the run.
- Existing touch and keyboard controls remain available, including on Android.
  Android does not activate this PC-specific adapter.

## 0.3.1 verification — 2026-10-18 (previous release)

- Full headless suite: **27 passed; one documented expected Bandit failure; no new
  failures**. Golden deterministic combat hashes remain unchanged.
- Focused adapter tests cover all four weapon frames, frozen-time aiming, stick
  deadzone and projection, release-to-stop, defense direction, Bow release, spell
  selection/casting, setup navigation, bounded buffering, modal neutral guards,
  device isolation, disconnect and native toggle activation.
- Real OpenGL renderer: desktop HUD, ability selector, controller menu, character
  focus, separate native dialog and retained portrait touch layout captured and
  inspected. Native dialog confirmation is tested through its Viewport and occurs
  exactly once. The first check exposed a missing cross-Viewport input route; the
  relay repair passes the repeat check.
- The connected hardware is detected as **XInput Controller**, mapped by Godot.
  Detection and injected input tests do not establish physical play feel or prove
  that every hardware button has been exercised by the user.
- Windows and Android exports completed; packaged metadata verifies `0.3.1` and
  Android version code `301`. No new expedition balance acceptance is claimed.
- Fold installation is pending: wireless discovery returned no devices and the
  previous connection address failed. The existing installation was not removed
  or its save data cleared.

## 0.3.2 verification — 2026-10-18

- Focused adapter tests pass, including connection-driven UI, neutral-on-connect,
  no simulation advance on connection, mobile exclusion, guide/back navigation,
  all four characters' action descriptions and all 20 unique glyph regions.
- Two bounded OpenGL inspection passes covered 1280×800 and 960×600 desktop,
  setup, HUD, ability selector, pause/guide, character sheet, native dialog and
  retained 720×1280 touch layout. The final dialog confirmation test passes
  exactly once through the separate Viewport. A connected gamepad is detected.
- Full regression suite: **27 passed; one documented expected Bandit failure; no
  new failures**. Golden deterministic combat hashes remain unchanged.
- Both exports completed. Packaged metadata verifies Windows `0.3.2` and Android
  `0.3.2` / code `302`. The Windows build is launched for physical-controller play.
- Fold remains unavailable in wireless discovery; new physical-device checks and
  physical controller play acceptance are not claimed.

## 0.3.3 verification — 2026-10-18

- Full regression suite: **27 passing files, one documented expected Bandit
  failure, no new failures**; deterministic combat goldens unchanged. The final
  controller, survey UI and structure tests also pass after the final input/UI edits.
- Adapter tests cover all four weapon frames, continuous analog angles in both
  views, magnitude-independent heading, axis-release stability, direct LB casting,
  stable element shortcuts, movement suppression, exact ground placement/range,
  frozen time/Energy, confirm/cancel, disconnect, both disciplines and direct item
  consumption without a duplicate or potion collision.
- Two bounded OpenGL inspection rounds covered desktop/compact bars and the spell
  drawer, ground marker, guide, native dialog and preserved portrait touch layout.
  Truncated guidance and small badges were corrected; the hint strip was moved
  below the resource gauges so it cannot cover Energy/Posture. Native-window A
  activation occurs exactly once. Connected gamepad detected; subjective physical
  stick feel remains for the user to assess.
- Windows and Android exports produced `0.3.3` / Android code `303`. Wireless ADB
  discovery returned no Fold; installation and new Fold play checks remain pending.

## Local combat coherence experiment (20 October 2026)

The isolated, unnumbered candidate implements selectable A/B/C/G/E lab rules and seed42 fixtures. At that historical checkpoint the release baseline was 0.3.3; the current normal Survey integration is described above. See [the lab implementation and verification boundary](combat-coherence-lab.md); automated success does not establish human acceptance of feel.

The local correction keeps K/T/Enter/J and LT/RS click/RT/LS click. Armed target cycling now filters the exact launch eligibility, including range and LOS. The panel labels Recover as LS click, distinguishes queued direction from facing, and explains the neutral gate. This is synthetic-engine and background rendered evidence, with no physical-controller acceptance. See [the lab owner record](combat-coherence-lab.md).
