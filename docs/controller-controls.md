# PC controller controls

**Baseline:** 0.3.1, presentation 18. **Status:** implemented; physical play acceptance
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
| Menu | Resume, character/upgrades, view, save and quit, or confirmed abandonment |
| D-pad / left stick in menus | Move focus; A confirms, B backs out |

Take Aim requires an explicitly selected visible enemy. The other characters can
attack and cast freely without target selection. Invisible, dead and other-layer
actors are never valid controller target selections. There is no auto-dodge,
auto-pathfinding, hidden aim correction or controller-specific combat discount.

All run setup character choices, upgrades, equipment comparisons, merchant stock,
discipline choices, maps and survey rating buttons are controller-accessible. Optional
free-text survey notes and exact seed entry still use the keyboard. Controller UI
appears on meaningful gamepad input; a keyboard key, mouse click or touch returns to
the existing controls. Stick drift below the radial 0.24 deadzone does not move or
claim input. RT uses 0.55 press / 0.25 release hysteresis.

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

## Verification — 2026-10-18

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
