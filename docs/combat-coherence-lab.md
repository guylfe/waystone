# Local combat coherence lab

20 October 2026. Experimental local branch from `0fb5694fda7f6018b03f4aeed2a3c8533759ec52`. This unnumbered experiment implements Dr. Stone's resolved combat contract. Production remains 0.3.3. Guy's acceptance of feel remains open.

The entry scene is `scenes/combat_coherence_lab.tscn`. `scripts/experiments/combat_lab_catalog.gd` owns variant IDs, payoff, exact seed42 fixtures, profile setup, manifest and supplemental authoritative digest. Normal Sword phases remain authored once in RunState. GameBoard, actor constructors, contact, navigation, incoming hits and Expedition executors remain shared.

| Variant | Local rules |
|---|---|
| A | Existing combat/input rules in the fixed harness |
| B | Frozen normal Sword junctions |
| C | B plus prepaid, one-use Commit |
| G | C, moving only F2 Archer to (1810,1060) |
| E | C, truncating only Briarhook ordinary approach at existing engage distance with LOS |

Normal Sword freezes before the complete 120 Hz tick that would cross the next link. Continue accepts one token; release clears automatic continuation without revoking that token. Holding chooses the same tokens. Recover locks the current exit. Move/Dodge at the junction captures one request and pays recovery first, then revalidates it. A forced replacement discards the request. Readiness stays false throughout the junction and recovery. One combo identity and spent action poise persist across cuts.

Commit is armed while ready, then confirmed on a living visible hostile target in normal melee range. Invalid targeting and insufficient resources preserve world state and arm. Successful targeting prepays actual modified phase costs (base 36 Energy), grants no overdraft and marks subsequent phases paid. Only final-cut base damage gains 10 before normal modifiers/Defense. Full irrevocable remaining time includes all paid cuts and recovery; flinch, posture-break floors and Shield/Polearm reads use the separate current-cut horizon. Existing heavy/protected exceptions and the older ordinary `melee` active-contact exception remain.

Commit survives release and voluntary defensive requests; real hits, posture breaks, sleep, parry and death retain their existing replacement authority. No refund, rearm, chase or automatic resume is added. Neutral input is required afterward. Explicit focus/menu suspension closes normal actions at a legal boundary and serves recovery, or finishes Commit through the normal executor and its consequences. Fresh/retry lab sessions do not load or save normal runs or archive Survey results. The launcher isolates APPDATA/LOCALAPPDATA per variant; this project additionally uses the distinct `WaystoneCombatLab` user directory. Each playable retry writes only an experiment entry manifest there.

Controls: Commit K/LT or button; T/RS selects a visible enemy; Enter/RT confirms armed targeting or continues a junction. Tapping an enemy continues using existing facing. Continue works without a surviving original target. J/LS recovers at a junction. Existing movement and Dodge inputs pay recovery before acting. The touch Defense button selects a direction for the queued Dodge. LB retains its shortcuts. Compare/Retry and Escape suspend; Resume requires neutral input. The native GameBoard handles ordinary Knife, Bow, Staff, spell and ability paths.

Fixtures include F1 tell, F1-D natural approach, separately labelled F1-P flank diagnosis; F2 exact camp seats/cover; F3 cleave, F3-T thrust, F3-N natural selection, F3-P recovery; F3-K/KP protection/recovery; and F0 native generated seed42 Expedition entry. F0 preserves the real first-site record and starts at the ordinary entrance, with no diagnostic teleport. Full and declared 60% HP/35% Energy profiles are selectable. The sweep profile earns Swordsmanship rank one through the level-two upgrade transaction. Scouting copies shift the player 340 west and retain natural perception. Distant F0 actors have unassessed loaded-geometry occupancy until their regions load.

Verification entrypoints:

```powershell
.\run-tests.ps1
.\run-tests.ps1 combat_lab_contract_test combat_lab_input_test -TimeoutSeconds 600
.\run-tests.ps1 combat_lab_policy_trace -TimeoutSeconds 600
.\run-tests.ps1 combat_lab_replay_test -TimeoutSeconds 600
```

The lab digest includes full action and enemy state, tick parity, RNG, resources, conditions and world objects; historical control goldens are unchanged. Tests compare semantic input choices separately from live hold/token flags. The runner now rejects runtime errors in production scripts even when Godot exits zero. A deliberately failing, subsequently removed probe established this detection; its source and logs remain in `.runtime` evidence.

Measured results and exact artifact hashes belong in the accompanying handoff and `.runtime` evidence, not in production balance claims. Headless direct input dispatch at desktop and narrow viewports is synthetic engine evidence. No real renderer, physical touch/controller, Windows export, device install or human play acceptance is implied.
