import json, io, re, statistics, itertools

d = json.load(io.open("survey-archive.json", encoding="utf-8"))

# Roles, fixed to the CURRENT catalog so the classification is consistent across
# versions rather than drifting with whatever the game believed at the time.
ROLE = {
    "boar": "frontline", "blade": "frontline", "brute": "frontline", "knight": "frontline",
    "hound": "flanker", "bandit": "flanker", "knife": "flanker", "captain": "flanker", "duellist": "flanker",
    "archer": "ranged", "javelineer": "ranged",
    "hexer": "area", "ice caster": "area", "fire caster": "area",
    "earth caster": "movement_denial",
    "shield": "screen", "polearm": "reach", "ox": "breaker",
    "warden": "boss", "werewolf": "boss", "chanter": "support",
}

# Demand / punish tags. The first block is EXACTLY as declared before this dataset was
# opened -- 10 rooms of evidence. The second block is enemies that were not tagged then
# and had to be added to cover the archive; they are marked so their contribution can be
# discounted.
DECLARED = {
    "archer":       ({"CLOSE"},           {"STAND_STILL"}),
    "javelineer":   ({"CHANGE_DIR"},      {"RUN_STRAIGHT"}),
    "shield":       ({"WAIT"},            {"CLOSE", "COMMIT"}),
    "duellist":     ({"BAIT"},            {"COMMIT"}),
    "polearm":      (set(),               {"COMMIT"}),
    "bandit":       ({"BAIT"},            {"COMMIT"}),
    "fire caster":  ({"VACATE"},          {"STAND_STILL"}),
    "earth caster": ({"CROSS"},           {"CROSS"}),
    "ox":           ({"DODGE"},           {"STAND_STILL"}),
    "boar":         ({"EVADE_LATERAL"},   {"STAND_STILL"}),
    "hound":        ({"EVADE_LATERAL"},   {"STAND_STILL"}),
    "blade":        (set(), set()),
    "knife":        (set(), set()),
}
ADDED = {
    "hexer":        ({"VACATE"},          {"STAND_STILL"}),
    "ice caster":   ({"VACATE"},          {"STAND_STILL"}),
    "brute":        ({"EVADE_LATERAL"},   {"CLOSE"}),
    "knight":       ({"EVADE_LATERAL"},   {"CLOSE"}),
    "warden":       ({"EVADE_LATERAL"},   {"CLOSE"}),
    "werewolf":     ({"DODGE"},           {"STAND_STILL"}),
    "captain":      (set(),               set()),
    "chanter":      ({"CLOSE"},           {"WAIT"}),
}
TAGS = dict(DECLARED); TAGS.update(ADDED)

def norm(name):
    return re.sub(r"\s+", " ", name.strip().lower())

rows = []
for run in d.get("runs", []):
    ver = run.get("game_version", "?")
    for room in run.get("rooms", []):
        r = room.get("ratings") or {}
        if not r.get("fun"): continue
        kinds = [norm(x) for x in room.get("enemy_labels", [])]
        if not kinds: continue
        roles = {ROLE.get(k, "?") for k in kinds}
        # conflict: one enemy demands an answer another punishes
        conflicts = 0
        for a, b in itertools.permutations(range(len(kinds)), 2):
            da, _ = TAGS.get(kinds[a], (set(), set()))
            _, pb = TAGS.get(kinds[b], (set(), set()))
            conflicts += len(da & pb)
        rows.append({
            "version": ver, "kinds": kinds, "n": len(kinds),
            "roles": len(roles), "conflicts": conflicts,
            "ranged": room.get("ranged_pressure_count", 0),
            "cost": room.get("composition_cost", 0),
            "tier": room.get("threat_tier", 0),
            "fun": r.get("fun"), "tac": r.get("tactical_interest"), "want": r.get("want_again"),
        })

print("rated rooms analysed:", len(rows))

def pearson(xs, ys):
    n = len(xs)
    mx, my = statistics.mean(xs), statistics.mean(ys)
    num = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    dx = sum((x - mx) ** 2 for x in xs) ** 0.5
    dy = sum((y - my) ** 2 for y in ys) ** 0.5
    return num / (dx * dy) if dx and dy else 0.0

def report(subset, label):
    if len(subset) < 12:
        print("  %-26s n=%d (too few)" % (label, len(subset))); return
    fun = [r["fun"] for r in subset]
    print("  %-26s n=%3d   roles r=%+.2f   conflicts r=%+.2f   ranged r=%+.2f   cost r=%+.2f   count r=%+.2f" % (
        label, len(subset),
        pearson([r["roles"] for r in subset], fun),
        pearson([r["conflicts"] for r in subset], fun),
        pearson([r["ranged"] for r in subset], fun),
        pearson([r["cost"] for r in subset], fun),
        pearson([r["n"] for r in subset], fun)))

print("\nCorrelation with FUN (Pearson r):")
report(rows, "all versions")
def vkey(v):
    try: return tuple(int(x) for x in v.split("."))
    except Exception: return (0, 0, 0)
report([r for r in rows if vkey(r["version"]) >= (0, 2, 0)], "0.2.0+")
report([r for r in rows if vkey(r["version"]) >= (0, 2, 14)], "0.2.14+")
report([r for r in rows if vkey(r["version"]) >= (0, 2, 27)], "0.2.27+ (post-roles)")

print("\nMean fun by distinct role count (0.2.0+):")
recent = [r for r in rows if vkey(r["version"]) >= (0, 2, 0)]
for k in range(1, 6):
    s = [r["fun"] for r in recent if r["roles"] == k]
    if s: print("   %d roles  n=%3d  fun=%.2f" % (k, len(s), statistics.mean(s)))

print("\nMean fun by conflict count (0.2.0+):")
buckets = {}
for r in recent: buckets.setdefault(min(r["conflicts"], 6), []).append(r["fun"])
for k in sorted(buckets):
    print("   %d conflicts  n=%3d  fun=%.2f" % (k, len(buckets[k]), statistics.mean(buckets[k])))

print("\nDiscriminating cases -- rooms with the SAME distinct role count (0.2.0+):")
for k in [2, 3]:
    s = [r for r in recent if r["roles"] == k]
    if len(s) < 10: continue
    lo = [r["fun"] for r in s if r["conflicts"] == 0]
    hi = [r["fun"] for r in s if r["conflicts"] >= 2]
    if lo and hi:
        print("   %d roles: zero-conflict n=%2d fun=%.2f  |  2+ conflicts n=%2d fun=%.2f  (gap %+.2f)" % (
            k, len(lo), statistics.mean(lo), len(hi), statistics.mean(hi), statistics.mean(hi) - statistics.mean(lo)))
