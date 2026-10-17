# PC controller controls

**Baseline:** 0.3.2, presentation 19. **Status:** implemented; physical play acceptance
remains open. This owns the bindings and verification record, not combat mechanics;
the character framework and RunState remain authoritative for those.

## Xbox-style bindings

| Control | Action |
|---|---|
| Left stick | Move in screen direction; release finishes the current small step |
| Right stick | Aim; deflection also selects ground-target distance; no time cost |
| RT | Attack; hold continues melee sequences, release ends continuation / fires Bow |
| B | Dodge, Block or Endure; movement direction takes priority over aim; hold for Block |
| RB | Equipped weapon art |
| Y | Selected subclass ability, spell or adopted discipline; hold for Advance |
| LB | Open ability selector; A selects the ability for Y without using it |
| X | Rejuvenation pouch |
| A | Context interaction, or one Wait step when no interaction is available |
| D-pad up | Rally / Stealth toggle, or Circle |
| D-pad left / right | Select one of the three utility slots |
| D-pad down | Use selected utility, or replace that slot when a pickup is pending |
| Left-stick click | One deliberate Wait step |
| Right-stick click | Cycle visible targets, ending with no target; manual aiming clears it |
| View | Map |
| Menu | Resume, character/upgrades, controller guide, view, save and quit, or confirmed abandonment |
| D-pad / left stick in menus | Move focus; A confirms, B backs out |
| LT | Unassigned; Xbox and Share are managed by the system |

Take Aim requires an explicitly selected visible enemy. The other characters can
attack and cast freely without target selection. Invisible, dead and other-layer
actors are never valid controller target selections. There is no auto-dodge,
auto-pathfinding, hidden aim correction or controller-specific combat discount.

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
