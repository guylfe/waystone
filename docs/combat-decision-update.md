# Combat decision update candidate

Status: implementation candidate, 12 November 2026, based on c4703699b9895cf46069334a15bc5d962f390a80. Current state owns delivery status; combat framework owns mechanics; controller controls owns bindings. This document records the bounded delta and remaining design questions.

Normal gameplay commits one complete ordinary melee cut with its authored recovery. Holding may repeat complete actions after readiness, but never buys a cut at a live combo link. Commit Combo uses the existing touch action, keyboard G or controller LB+left-stick-click to arm (Bow retains LB+A); a visible enemy confirms facing and the whole authored Sword, Knife, Twin Knives or Staff sequence. Repeating selection cancels freely before confirmation. The complete existing phase cost is prepaid (including the existing allowed overdraw); release cannot truncate or debit later cuts. Poise, interruption, geometry, earned ranks, finisher effects and weapon sequence cooldowns remain owned by the original executors. No experimental finisher bonus is added.

Ordinary Bow commits a 0.45 personal-second draw and the existing half-draw release/recovery, with the original interpolated damage, range, projectile speed and posture. Commit Shot commits 0.90 personal seconds and the existing +25% full-shot damage. Ordinary draw cost is prepaid at its original half-draw price; strong cost remains 18 raw Energy. Both retain earned preload and existing soft-target tracking at 2.4 radians per simulation second; live aim/release events cannot improve or shorten the commitment. Tracking stops when visibility/line of sight is lost. Arrows retain physical contact and cover. Bow arts and Take Aim stay separate. This half-draw ordinary value is a provisional implementation tuning choice, not Guy's acceptance of balance.

`RunState.EXECUTION_PLAYBACK_RATE` is 1.25. Streamed execution and precomputed timeline playback accumulate world time at that rate. The per-frame streamed budget scales from four to five ticks, preserving the selected pace at 30 FPS; below 30 FPS the existing bounded catch-up policy can still slow wall-time execution. All actors, projectiles, hazards and world timers run through unchanged 1/120-second ticks and original personal tempos. Menus and deliberation stay frozen. Source simulation tests measure world seconds, not playback wall time. Historical explicit Survey/lab options keep their action grammar and simulation identity; their playback also uses the selected universal rate. No old results establish acceptance of the new normal rules.

Save schema remains 39. New fields are optional action dictionary entries. Generated Expedition still refuses a premature mid-action save; the presentation completes commitments before suspension. Integrated Survey retains its mid-obligation persistence. Ordinary nonintegrated Survey retains its prior ready-on-load policy. Deterministic checkpoints include active automatic-draw/full-combo ownership and full-sequence paid phases; absent flags leave historical comparisons unchanged.

The lead resolved movement on 12 November: normal directional ground taps commit a full fixed stride, initially the existing 34 units, including nearer taps. `committed_move_distance` owns the rule across touch, mouse, keyboard/controller and direct normal movement requests. Explicit historical Survey comparisons retain requested short distances. No idle-time floor or new automatic stop system is added. Held travel still chains the same full steps and accepts direction only for the next commitment. Character Combat and controller help explain full strides; the existing held-movement line/circle now shows the nominal current committed stride rather than the finger's exact destination. Collision may clip that nominal segment.

Measured base Warrior comparison: twenty 4-unit requests take 2.6667 world seconds with the new rule versus 0.3333 in the historical control: 7.5 versus 60 decision boundaries per world second (9.375 versus 75 per nominal playback second at 1.25×). A full stride still travels about 34.667 units because the original 120 Hz tick rounding is unchanged. Twenty short taps now have the same activity commitment as twenty full strides; this does not establish that the remaining stride cadence is comfortable or that travel tedium is solved.

Existing interaction taps do not use a special short-approach movement action. Out-of-range objects refuse; nearby supplies collect/repack in place, and merchant/Waystone/passage interaction radii remain unchanged. Thus there is no new unrestricted short-approach exception. A full step from 120 units away enters the 112-unit pickup range without passing the pickup, and a supply four units away can be collected without movement. No pickup is deliberately overshot to manufacture a time cost. Existing pickup/merchant input and Survey/Expedition lifecycle checks pass.

Wall probes with 0/10/20 units of clearance move 0/8.667/19.500 units respectively, each spending the full existing stride clock (0.1333 world seconds). A 100-unit doorway admits travel; a 50-unit opening blocks crossing, with the body's circular corner approach preserved. Floor-edge movement retains the existing cardinal footprint contract (0.72 × body radius), not a newly invented full-disc rule. These are clipped or blocked committed attempts, with unchanged collision and no extra delay. New fixture assertions were corrected to match these pre-existing geometry contracts; runtime geometry was not widened or tightened.


Enemy `_melee_intent` already weights choices by range and retains the selected intent across approach. No extra random system, hit roll, counter selection or reroll is introduced. The lead resolved this portion after the independent analyst's forced-branch and seeded matrix: retain the existing Duellist weights, timings and damage and add factual qualitative guidance. The presentation now distinguishes parry available/recharging/active/locked by the current commitment, names the committed thrust or cut and shows early/middle/ending recovery. Inspection warns that recovery can expire before player contact and a parry may return; it does not promise a safe full combo. The independent matrix establishes a cautious escape with damage/resource/time/position costs in the tested fixtures, not a universal counter or global success probability. No new randomness or prediction simulator is added.

Verification evidence lives under `.runtime/evidence/` and `.runtime/test-results/` in the isolated checkout. `decision_commit_test` covers every melee frame and both resource rules, release immunity, full prepayment/overdraw, automatic Bow timing, aim immunity, save policy, discrete selection/cancellation and movement timing. `decision_commit_input_test` routes actual-root touch/key/pad selection and confirmation on a narrow isometric model. Existing manual Bow/held combo tests explicitly identify their historical comparison fixtures. Exact suite/build results and immutable source identity accompany the handoff. Headless font/input tests are not GPU inspection or physical-device play. No publication, destination integration, Fold installation or human acceptance is claimed.

Final engineering receipt: [0.3.7 candidate verification](releases/0.3.7-candidate.md). All new observed regression failures are resolved through sequential reruns; the existing exact Bandit expected failure remains. The fixed-stride implementation below supersedes the receipt's earlier movement-open status; uncertainty, rendered/device and feel acceptance remain open.

Fixed-stride package and regression receipt: [0.3.7 stride candidate](releases/0.3.7-stride-candidate.md).


## Independent-review presentation correction

Baseline: reviewed candidate 8b3c420, packages from 544dd6c. The independent readability report reproduced obsolete ordinary Attack copy, melee messages naming Commit Shot and a threat under the Commit overlay that could not be selected. Independent core/Bow evidence is attributed to the analyst; this correction does not claim those independent scenarios as new engineer tests.

Normal idle Attack now says HOLD: REPEAT, with AUTO SHOT for Bow; active captions distinguish one cut, automatic draw, full combo/shot and recovery. Historical explicit comparisons retain their own input grammar. `_commit_action_name` supplies the actual weapon action name for selection, cancellation, refusal and the control. Invalid melee confirmation gives a truthful visible-target refusal without spending time/resources.

Normal Commit, Attack, controller guidance, XP and log occupy a fixed measured dock outside `board_rect`, the tactical drawing/input viewport. Its 270 client-unit allocation is independent of target, selection, feedback and commitment. The Mage's existing spell drawer is reserved even when closed, preventing primary controls/camera from moving when it opens. Current messages use a fixed three-line log area, XP two lines; normal action selection/refusal/control text fits the measured allocations in the checked cases. Detailed information retains its existing inspection/Character surfaces.

The camera uniformly reframes the same vertical world extent into the remaining tactical area. No enemy position, alive/visibility state, simulation geometry, RNG or target reach is changed to clear a control. Tests preserve the three world positions from the review's old Commit/Attack/guidance surfaces and confirm their actual body taps now start the combo. Useful field height and 48-unit control minima are checked at sampled Windows client sizes. Rendering scale changes with the viewport; sprite/tell comfort still requires the independent corrected GPU recheck. There is no invisible click-through or target-position-driven layout.

Parry cooldown was already simulation/save/determinism state but was missing from the projected presentation dictionary. It is now included in presentation, so the guard cue/readout no longer treats a missing value as a ready parry. The current commitment blocks new parries even when cooldown is ready; active front parry has its own state. Existing actor/weapon rendering is retained, with a draw-dispatch regression verifying that guidance cannot replace the Duellist body. Qualitative recovery progression derives from actual active-end/duration/elapsed values, never a forecast of future choices.

Checks and package provenance for this successor are in its correction receipt. The Windows-headless input/font/layout/draw-dispatch checks are separate from GPU frames, Android execution and human acceptance. The pre-existing Android Joypad `desktop_controls` gate remains outside this correction; successful desktop synthetic pad routes do not establish mobile controller support. Publication/device delivery and corrected independent rendered review remain with Dr. Stone. The queued 3D demo remains gated on actual combat completion and verified rollback.

Independent-review correction receipt and recheck instructions: [0.3.7 readability correction](releases/0.3.7-readability-correction.md).


## Mage drawer coexistence correction

The independent rendered review of 3dc7594 found the landscape spell drawer using
legacy Attack geometry while the final dock moved Attack over Lightning Bolt/locked
Fire. Normal Mage landscape now reserves a drawer column alongside the final dock,
even while closed. Final layout translates the existing panel and every chip hit
rectangle into that column after action allocation. Primary controls and guidance
use the remaining dock width; battlefield dimensions/camera remain stable. Portrait
allocation, combat, spells, refusals, saves and routing precedence are unchanged.

`mage_drawer_routing_test` exercises actual transformed main-root touch at every
visible available/locked chip center, inset corners/edges and right-half regions
that previously intersected Attack, at 390x844, 720x600 and 1280x800. It checks final
coexisting chip/action/battlefield separation, safe bounds, retained chip and primary
sizes, guidance fit, free selection/refusal and stable open/close geometry. The test
is part of the default suite. `mage_drawer_capture.gd` provides the bounded GPU
recheck; engineering headless results do not establish rendered or physical feel
acceptance. See the external Mage drawer handoff for exact source/build receipts.
