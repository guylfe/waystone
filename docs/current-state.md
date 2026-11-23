# Waystone current state

**Released 2026-11-22.** [Regular Waystone 0.3.9](https://github.com/guylfe/waystone/releases/tag/v0.3.9) includes the four-region Campaign, mid-run comment capture, and a startup update check. The exported runtime is `c0db50a967c3096edaabfdcc693b5ad4e25e9666`.
**Windows.** The normal launcher executable was updated and verified by SHA-256 (`55dab6e2ce170cf299f1f880e7f035ac403b2f80d9277d2e9d18c34435c93b02`). Its headless Survey smoke passed with isolated saves.
**Android.** The published signed APK is version 0.3.9, code 309, SHA-256 `027f6007586ec533731d009d79f95d0706ff6f547777ad14e820eeff170b9545`. Installation and execution of this version on the Fold are pending.
**Compatibility:** save schema `39`, Survey format `37`, Survey generator `3`, expedition generator `1`, presentation `20` unchanged.
**Authority:** current source/tests define implementation; this document owns current delivery and verification status. Design Foundations owns intent. Guy decides feel acceptance.

## 0.3.10 delivery — 2026-11-23

The release candidate was exported from `ea208dad9fc914febf651489dff086ced198ae0f` (Android version code 310). Both platform assets are in the [private release draft](https://github.com/guylfe/waystone/releases/tag/untagged-b58c7305d08363af1289). The ordinary Windows launcher now starts that build. Its installed headless Survey smoke passed with isolated save data. A disposable packaged copy using a controlled release feed accepted **Update now**, downloaded the final ZIP, checked it, replaced its executable, and preserved an existing Survey save byte for byte. The signed APK has the same package and signing certificate as 0.3.9. Device installation, Android's confirmation screen, and saved-run readback on the Fold remain pending.

The review and public-send choices in the actual Expedition Comment screen produced [issue #2](https://github.com/guylfe/waystone/issues/2) through the [repository publisher](https://github.com/guylfe/waystone/actions/runs/45223484523). Restarting the game replayed the original report and displayed **Sent as GitHub issue #2**. An additional authenticated replay returned the same issue. A repository readback found one matching report marker. The disposable participant enrollment was revoked after verification.

## 0.3.9 startup updates

The Windows and Android release adds a quiet startup check for a newer
stable GitHub release with an installer archive or APK for the current
platform. See [startup updates](startup-updates.md) for input and evidence.
GitHub's anonymous latest-release response identified 0.3.9 and both uploaded
assets. Their GitHub digests matched the verified local builds. The update
checker from the installed Windows package processed that response for both
platforms, offering 0.3.9 against a simulated 0.3.8 and staying quiet on 0.3.9.

The next-release branch adds **Update now** and **Later** in setup and run
menus. It verifies the official asset, saves the active run, and hands off
to the Windows replacement helper or Android system installer. A disposable
Windows install passed replacement, relaunch, rollback, and save preservation.
The Android export matches the published package and signer. Physical Android
installer confirmation and save readback are pending. See [startup
updates](startup-updates.md) for the release contract and verification commands.

### Mid-run comments

Version 0.3.9 includes **Menu → Comment** and **F8** in all regular
playable modes, including Campaign and the experimental Survey menu. The
editor freezes play and saves the typed note with its opening gameplay state
to a local queue. With a player relay configured, the game submits in
the background and retries after restart or relay failure. The editor shows
queued and delivered counts and a copyable GitHub receipt reference.
[Mid-run comments](run-comments.md) owns the input, record format, verification
and integration contract. The live feedback relay and GitHub destination
are pending.

## Regional Campaign integration — 0.3.8

Regular Waystone's mode selector includes **Campaign** alongside Expedition,
Dev (including Survey), Boss Lab, and the original Campaign Lab. Campaign runs
the four-region Dawn Forest, Millrace, Bell Road and Hollow Tower layout through
the shared combat and controls with its angled 3D terrain. Each supported
starting character is selectable. Return through **Menu → Save and choose mode**.
The last selected run resumes after relaunch. Campaign replacement requires
confirmation.

Campaign writes `user://waystone-regional-campaign.save`. The other modes each
write a mode-specific slot and can resume the last matching pre-upgrade shared
slot when their new slot has yet to be created. Survey archives retain their
existing path and schema. Loading a saved Survey leaves the current report,
archive and report files intact. Starting a new measurement session still
updates the current report through its normal flow.

Android is `com.waystone.prototype / 308` with the regular signing certificate.
The Windows resources passed routed mouse and portrait-touch start, move,
Character, mode return, alternate-mode and fresh-process resume checks.
Desktop-hosted APK resources passed the same Expedition and Survey round trips.
The previous regular build generated disposable save and report fixtures.
Their original file hashes survived the exercised switches. Exact Windows
GPU captures cover the main navigation and regional landmarks at 1280 × 800
and 390 × 844. See [Regional Campaign](campaign-regions.md) for routes,
progression and reproduction.

The headless suite passed 63 of 67 test files. The other four reproduced baseline
results in the Bandit assertion, two HUD density probes and the Survey UI log check.

## Combat commitment update — 0.3.7

Normal melee commits one complete cut; Commit Combo prepays and executes the full
weapon sequence. Bow uses fixed automatic ordinary shots and explicit Commit Shot.
Ground taps commit the full 34-unit stride, including nearby taps. Universal 1.25×
playback preserves the 120 Hz simulation and shared actor clocks. Explicit historical
Survey comparisons retain their grammar. Save schema and normal saves are preserved.

Commit/Attack and guidance occupy a stable dock outside the battlefield. Mage spell
chips share final allocation and stay separate from both actions. Existing Duellist
intent/weights/timing/damage remain; qualitative guidance exposes current parry,
commitment and recovery without promising a safe full combo.

Independent source/rendered reviews accepted the bounded corrections, including the
final Mage review (93 checks, zero failures; 27 PNGs at three sizes). Fresh Windows
installed normal-entry smoke passed startup, Survey, feedback/archive provenance and
save with isolated data. Reviewed packages retain runtime fc0b57b; later documentation
commits require no rebuild. [Delivery identities and evidence](releases/0.3.7-delivery.md)
and [mechanic scope](combat-decision-update.md) record limits and provenance.

The unchanged exact Bandit expected failure and Android `desktop_controls` Joypad gate
remain documented. No new GPU review is claimed by engineering; independent frames
are source-rendered. Fold installation/touch/insets/performance, physical controller
and Guy's combat/animation feel remain unverified for 0.3.7.

## Previous release — November 0.3.6 repairs

The normal Windows executable, source and GitHub main contain the six-finding repair
batch. The installed executable matches the reviewed package and passed an isolated
headless normal-entry startup, Survey, feedback/archive and save check. The existing
Start shortcut still targets `builds/windows/Waystone.exe`. All59 personal-data files,
three launch files and unrelated documentation/audits/prototypes were preserved.

The [0.3.6 delivery record](releases/0.3.6-delivery.md) lists exact runtime/package
identities, evidence and unresolved outcomes. Later documentation-only commits do
not change the embedded runtime source identity or require new packages.

| User outcome | Implemented and tested | Remaining boundary |
| --- | --- | --- |
| Mobile Character | No-scroll overview where readable, visible upgrades, full tap-open detail/actions, touch swipes and spatial navigation; independent model/input/payment passes | Actual Fold rendering/touch and comfort |
| Faster Boar |640 movement/.45 aim lock; independent retreat-threat and alternative-response cases | Guy's encounter/feel acceptance |
| Supply/merchant refusal | Identity, truthful denial, tap arbitration, refresh, payment and persistence repairs; bounded independent passes | Exact historical late-run refusal remains unreproduced |
| Wall/general lag | Measured desktop presentation-copy optimization and parity checks | Sustained Android frame/input/thermal profiling; added floor-check cost prevents a phone-speed claim |
| Map edges | Continuous shot/actor blocking and valid inward tangent departure; independent checks | Physical generated journey confirmation |
| Additional Commit Shot | One prepaid full draw/release/recovery shot with+25% initial damage tuning; ordinary charging/arts retained. Hashing, current drawn feedback, dense target visibility and initial action stability independently pass | GPU/phone rendering and physical feel |

The full release suite at3b7 passed54 files with one exact documented pre-existing
Bandit assertion. The final presentation successor passed all9 affected release
files; no new exception or altered golden was introduced. Exact Windows and Android
resource-pack checks passed6326 assertions each; these are desktop-hosted package
checks, not Android execution. The final independent designer review at e0a255
accepted P1/P2/R3 within source/headless scope. Earlier Character, gameplay and D1
acceptance carries through unchanged owners. Overlapping assertion counts are not
unique player journeys or evidence of subjective quality.

Android306 is staged locally but not phone-installed. The USB device check found no
device. The host visual review was not performed because computer-access consent
was still pending; no screen action or alternate graphical route occurred. Actual
Fold DPI/insets/folding, GPU compositing, sustained phone performance and physical
controls remain unverified. The exact historical attack-reset symptom is also open.

Dr. Stone owns phone installation and remaining device/rendered verification after
access is available, and follow-up on reproduced defects. Guy owns comfort and combat
feel acceptance. Windows/GitHub delivery is complete; this does not close the phone
lag or historical-symptom investigations. Superseded3b7/4e90 packages and all reviewed
ancestors remain preserved.

Owners: [world repairs](phone-world-repair.md), [Character/input](menu-input-correction.md),
[controller/HUD](controller-controls.md), [combat framework](combat-character-framework.md).

## Survey integration (released baseline)

0.3.5 packages the accepted runtime `d797b01f337ee4ca36781687d27e907c41dbb143`
(tree `cf81df775d5f305a60a8f7d24b2d446657c02f3b`) for the normal local game.
It repairs Character/menu release ownership, neutral/repress return, semantic
focus/Back, responsive menu metrics, branch transactions and paid-repack return,
feedback containment, and existing Character decision information. F continues
through the existing token at a frozen Sword junction. Save schema, combat rules
and report format are unchanged. The exact original attack-reset symptom is
unidentified; this bounded F fix does not close that report.

Both independent final reviews passed that immutable runtime. The lead's bounded
Windows/OpenGL review passed 647 checks / 99 GPU records, with a normal-processing
archive supplement passing 240 checks / 12 records. The supplement corrected only
a capture-harness artifact; product source stayed frozen. Headless root/density,
transaction, handover and archive evidence remains separately recorded in the
[correction ledger](menu-input-correction.md). Physical controller/touch, Android
and foldable behavior, natural gameplay and subjective feel remain unverified.

The local delivery uses the existing `builds/windows/Waystone.exe` launch target,
with unchanged shortcut arguments/icon. Exact release-source, embedded build,
package smoke, installed destination, rollback and personal-data preservation
receipts live in the external `local-delivery-20261022` task folder. Subsequent22 October receipts verified GitHub publication and Android305
installation as well; the original local-only receipt retains its historical scope.
The equipment-effects and manual-end wording proposals remain unadopted.

0.3.4 integrates the accepted frozen-Sword/Commit experiment into the normal
**Dev → Survey** entry for generated/custom/exact-roster rooms and all eleven
named presets. Existing behavior remains the initial default; Energy/Recovery is
independent. G/E remain labelled comparisons. The normal completion, ratings,
notes, next, archive and export path retains scenario/source/build provenance.
Save schema 39 preserves experimental obligations and enemy phases; old runs
migrate with no experiment. Feedback/report layouts scroll and reflow at narrow
sizes. The shared readout prioritizes three enemies and exposes all visible facts
through Details, without limiting the actual Survey population.

See [Survey integration](survey-combat-integration.md) for ownership, entry,
controls, exact fixture policy and verification. Independent integration and
focused presentation review have passed. The normal launcher is the delivered
entry; existing audits, prototypes and personal data remain separately owned.
The historical isolated-lab entries below describe earlier evidence; they are
superseded as the player-facing delivery route. Guy's feel acceptance remains open.

The independent `962ee4a` lifecycle review passed 231 checks and its exported
binary probe; presentation review found invisible archive rows and narrow detail
overflow. The isolated repair uses one scroll owner, wrapping 48-unit record rows,
safe-width summaries and reflowing controller hints. Its 0/1/6/12-record five-size
rendered/input matrix and focused regressions are documented in the integration
owner and exact task handoff. Independent R1/R2 review passed the `dbefcb5`
repair; its fresh shared-MenuHints run passed 786 checks with zero failures.
The unchanged lifecycle owners retain the 231-check acceptance. Version remains
0.3.4 / Android 304. Device installation and human feel are not certified by these
checks. Final publication identities and destination verification live in the
external release handoff, so source/build identity stays reproducible.

## What exists now

- Four playable profiles: **Warrior · Vanguard**, **Rogue · Acrobat**, **Rogue · Sharpshooter**, and **Mage · Elementalist**.
- Four working weapon frames in player use: Sword, Knife, Bow, and Staff.
- Native Xbox-style PC controls retain the touch ability/item bars with colored button badges. Held LB reveals direct spell/item/adopted shortcuts. Melee follows movement; ranged actions use analog directional aim; placed actions open a frozen-time marker with confirm/cancel. Connection-driven prompts, focused menus and disconnect/focus safeguards remain. Combat balance and save/generation identities are unchanged. See [controller controls](controller-controls.md) for bindings and verification limits.
- The shared combat kernel includes committed actions, attack capture, Energy and Recovery rule profiles, exhaustion, Dodge, posture, Resolve-derived action poise, conditions, projectile elevation and misdirection, barriers, deterministic save/snapshot support, and survey attribution.
- Fire, Ice, Earth, and Air casters and all eight elemental abilities are implemented. The Elementalist can inherit one spell from each element; Intelligence reduces spell cost through the implemented soft-cap curve without increasing spell damage.
- The Warrior/Vanguard redesign is live: sustained Rally, Battle Flow, Advance, Resolve-derived action poise, Power Through, and Unbreakable. Battle Flow is sequence-based and currently decays after 15 seconds.
- The Combat Survey layer has role-aware recipes, deliberate formations, guaranteed non-melee pressure in ordinary mixed generation, exact-roster experiments, and `Encounter` and `Attrition` profiles. Its generator remains separate from the three-biome Expedition generator.
- Ordinary walking is a chain of short committed steps: a hold repeats them and steering affects the next step. It remains a free tactical defense, but is not steerable within a step. The Ice Caster's old cone complaint predates Frost Lance and Cold Front and is not a standing verdict on current Ice.
- Boss Lab is implemented as a repeatable, isolated evaluation mode. The Werewolf solo redesign is live with Hunting Leap, Double Rake, and Bounding Rake; its pack form remains disabled for comparison. Warden remains provisional. Both legacy bosses are excluded from the new expedition.
- The implemented expedition is a continuous mountain ascent through Briarwild Foothills, the above-ground Cinderworks and Stormglass Summit, with irreversible biome departures, three new solo bosses, one-use restoration, finite healing/economy, equipment and the midpoint adopted-track Exchange. See the implementation ledger for verification limits.
- The 0.3.0 expedition verification covered 100 seeds / 300 maps, legal full-run victories for all four characters and both disciplines. Its APK passed Fold portrait input, frozen time and cold save/resume checks. The 0.3.1 regression suite has 27 passing files plus the documented pre-existing Bandit failure; controller render checks and XInput hardware detection pass. See the controller ledger for build/install status. Physical-controller play feel, Fold inner-display play and sustained combat performance remain unverified.

## Current work order

The approved expedition includes only the necessary actual-commitment timing,
imposed-reaction clock ownership and defensive-response measurement repairs.
Other foundation-audit proposals, including Strength, broader condition rules and
Recovery Rally, remain proposals rather than implied authorization for a rewrite.

The October 17 approval supersedes the Warden-first content gate for this experiment:

1. Play the [0.3.0 expedition prototype](expedition-0.3.0-implementation.md) and collect human journey/boss feedback. Automated feasibility does not establish fun, fairness or readable teaching.
2. Check the Fold's inner display and sustained combat performance; report these separately from the already-passed portrait/suspension smoke tests.
3. Propose narrow tuning or repairs from that evidence before expanding the content programme. Roster counts, rewards and boss statistics remain test values.
4. Revisit Warden, the Werewolf pack comparison, Campaign integration and Recovery versus Energy only as subsequent agreed work; none was implemented by adding the new expedition bosses.

## Document authority and status

| Document | Use now |
|---|---|
| `docs/current-state.md` | Current implementation boundary and next work. Update with every material change. |
| `docs/design-foundations.md` | Standalone description of the game's identity, inspirations, intended experience, and design principles. |
| `docs/development-scope.md` | Production scope, proposed mode scale, future content, and open questions. Current work order remains here. |
| `docs/campaign-design.md` | Detailed Campaign geography, shortcuts, progression, and proposed death/memory policy; unresolved choices are labeled. |
| `docs/narrative-design.md` | Unimplemented story and fragment-power proposals. |
| `docs/design-research.md` | Comparative research, calibration notes, and historical survey evidence. |
| `docs/design-brief.md` | Earlier vertical-slice brief and world/geometry proposals; historical Expedition targets are labeled. |
| `docs/battle-design-bible.md` | Credence-rated enemy, encounter, and boss principles. |
| `docs/combat-character-framework.md` | Shared actor, combat, character, and progression design. Implemented facts must still be checked against source. |
| `docs/controller-controls.md` | Implemented native PC bindings, input-safety contracts and verification ledger. |
| `docs/elemental-casters.md`, `docs/warrior-vanguard-redesign.md` | Implemented programme records plus retained design history. |
| `docs/enemy-encounter-boss-revised-design.md` | Earlier six-update plan: Updates 1–4 shipped; Updates 5–6 deferred by the approved new expedition. |
| `docs/expedition-0.3.0-implementation.md` | Approved three-biome contract, ownership, implementation and verification ledger. |
| `docs/expedition-design-principles.md`, `docs/journey-design-principles.md`, `docs/expedition-encounter-redesign.md` | Enduring pacing principles and historical design rationale; obsolete seven-region/no-Waystone counts are not current requirements. |
| `docs/combat-loop-diagnosis.md`, `docs/attack-capture-design.md`, `docs/attack-capture-implementation.md`, `docs/survey-archive-findings.md` | Historical evidence and shipped design records. Their old baselines are intentional, not current instructions. |
| `docs/code-structure-audit.md` | Architecture record. The accepted first restructuring programme shipped; deeper proposals remain proposals until separately approved. |
| `WAYSTONE_MIGRATION_HANDOFF.md` | Detailed operational history, testing, building, and device handoff. |

## Documentation maintenance contract

Documentation is part of the implementation boundary, not optional cleanup.

1. Every material code change must update the document that owns the changed rule, system, or plan in the **same change**.
2. Every numbered release must update `README.md`, version metadata, this file, and any affected operational baseline in `WAYSTONE_MIGRATION_HANDOFF.md`.
3. When a proposal ships, changes, or is rejected, label its status explicitly. Preserve useful history, but never leave a historical proposal worded as current work.
4. Values duplicated for explanation must name their source owner. The catalogs, schemas, migrations, and current source remain authoritative over prose.
5. New documents must state their baseline, status, and relationship to existing authority. Prefer updating an owner over creating a competing source of truth.
6. Verification reports must distinguish simulation tests, renderer inspection, builds, installation, and play evidence. None substitutes for another.
7. A code task is not complete while its documentation describes the previous behaviour or priority.

## Repository boundary

The live development branch is `main`. `archive/main-pre-0.2` is historical. Do not resume work from removed checkpoint branches or an older synchronized checkout. Inspect the remote and the current version before publishing.

## Local combat coherence experiment (20 October 2026)

The isolated, unnumbered candidate implements selectable A/B/C/G/E lab rules and seed42 fixtures. At that historical checkpoint the release baseline was 0.3.3; the current normal Survey integration is described above. See [the lab implementation and verification boundary](combat-coherence-lab.md); automated success does not establish human acceptance of feel.

The independent review-correction candidate adds truthful pips, a fixed state panel, range-filtered explicit targets, debt/facing/resistance reads and real background OpenGL captures. C remains default. See the lab owner document and accompanying handoff for focused checks and limits; physical input, independent acceptance and Guy's feel remain open.

The follow-up isolated repair from `118060a` adds captured content swipes,
48-unit Previous/Next inspection paging and controller access through Start,
D-pad focus and A next/use. Compare uses labelled 48-unit cycling fields and
an explicit Start fresh reset. Three concise enemy phase/resistance lines share
the upper information slot; the F2 world is 200 units high at 720x480 and about
254 at 390x844. Separated outlined numeric keys use leaders to sampled actor
bodies. Original close/rotation geometry and D3 Resume behavior are retained.
See the lab owner and delivery handoff for GUI-event traces, exact unchanged
natural-contact digests, inspected real-renderer frames and limits. These are
engineering results awaiting independent re-check; physical input, motion
readability and Guy's acceptance remain open. Production and combat rules are
unchanged, with C default and G/E separate comparisons.

The subsequent isolated information-overflow repair from `495ddd` removes
nominal label-height assumptions and duplicate live guidance. Actual font-sized
rows show current obligation/exit, relevant refusal or interruption and all three
enemy facts together within the same 110-unit slot; full wording and observed
event history remain in Details. The 200/250 world floors, original 20/15/14px
type and 48-unit controls are retained. A 292-state five-size/two-projection
matrix passes rendered glyph/row containment with unchanged authoritative states;
the identical test fails on the preserved control. Exact boundary pixels and
input/restoration regression evidence accompany the handoff. This is engineering
verification awaiting focused independent acceptance; physical input and human
feel remain unverified.

Mage drawer source/package receipt: [0.3.7 Mage correction](releases/0.3.7-mage-drawer-correction.md).
