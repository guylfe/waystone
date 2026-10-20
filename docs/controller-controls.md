# PC controller controls

**Baseline:** 0.3.3, presentation 20. **Status:** implemented; physical play acceptance
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

The isolated, unnumbered candidate implements selectable A/B/C/G/E lab rules and seed42 fixtures. Production remains 0.3.3. See [the lab implementation and verification boundary](combat-coherence-lab.md); automated success does not establish human acceptance of feel.

The local correction keeps K/T/Enter/J and LT/RS click/RT/LS click. Armed target cycling now filters the exact launch eligibility, including range and LOS. The panel labels Recover as LS click, distinguishes queued direction from facing, and explains the neutral gate. This is synthetic-engine and background rendered evidence, with no physical-controller acceptance. See [the lab owner record](combat-coherence-lab.md).
