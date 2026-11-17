# Regional Campaign

Start at the Dawn Waystone. Walk down to the waterwheel and along Millrace, or
climb past the forest ruin to Bell Road. Either regional guardian gives access
to Hollow Tower. Reconnect the regional lifts and open the tower service stair
to earn easier routes back through familiar places.

In regular Waystone, select **Campaign** and choose a character. **Resume Campaign**
opens the saved character. Use **Menu → Save and choose mode** to return to the
mode selector. Starting over requires confirming replacement in Campaign setup.
Desktop uses WASD or ground clicks, Space for the displayed context action, C
for Character, and M for Map. On touch, tap or hold the ground to move and use
the context button above the belt. Controls and stairs can also be tapped within
reach. Rest restores health, Energy and the rejuvenation pouch, integrates
carried XP, and sets the respawn point.

## Places and progression

| Region | Places and decisions | Waystone |
| --- | --- | --- |
| Dawn Forest | Existing clearing, Overlook gate, north trail, east ruin, south return and Sheltered Underpass. The underpass relay controls east ascent. The opening skyline previews Millrace and Hollow Tower. The river descent and ridge stairs favor different regions. | Dawn |
| Millrace | River Descent, Willow Ford, Towpath, Wheelhouse, Miller’s Loft, Mill Catwalk, Loading Basin, Basin Waystone, Maintenance Walk, Penstock Vault, Wheelrace Tunnel, Pump Court, Sandbank, Silt Garden, Sluice and Drain Channel. The towpath exposes the player to ranged sightlines. The wheelhouse screens the south bank. The pump court and sandbank approach opposite sides of the sluice. | Basin |
| Bell Road | Ridge Stairs, Windbreak, Lookout Terrace, Bell Market, Pilgrim Cells, Freight Balcony, Carillon Waystone, Bell Foundry, Parapet Walk, Bellkeeper’s Quarters, Foundry Colonnade, Warden Court and Bridge Approach. The terrace overlooks the basin platform. The foundry and parapet offer different cover. | Carillon |
| Hollow Tower | Foundation Landing, Cistern, Foundation Ascent, Sump Store, Upper Gallery, Broken Cloister, Archive Balcony, Lantern Court, Choir Passage, West Ambulatory, Crown Approach, Hollow Crown, Reliquary and Service Stair. The cistern approaches from below and the gallery looks in from above. They converge at the Lantern Court with distinct arrivals. | Lantern |

The region modules use stable place IDs and attachment positions. Each seed
selects one of two Mill Catwalk placements, one of two Foundry Colonnade
placements, and alternate Ford and Parapet residents. Existing forest tree
dressing is seeded. An imported or resumed seed regenerates the same layout.
This first recipe has one authored option per regional slot.

Wheelhouse and gallery scenery use cutaways. Solid machinery, buttresses and
pillars share a footprint with planar collision. Crossing art plays after the
context action. The bridge forms a physical span, and draining reveals the
walkable riverbed.

## Guardians

| Guardian | Tactical question | Victory consequence |
| --- | --- | --- |
| Sluice Keeper | Gate Sweep fixes its aim before impact. Spillway Jet marks a delayed burst. Crossing the sluice can expose a flank and narrow the retreat. Furnace Breath joins the second phase. | Operate the drain wheel and walk to the foundation stairs. |
| Bell Warden | Counterweight Rush commits to a lane. Baiting a wall collision cuts the rush short and grants a longer recovery. A quill fan discourages hanging back. Bell Sweep joins the second phase. | Release the counterweight and walk across the bridge to the upper gallery. |
| Hollow Keeper | Hollow Mark pressures the current patch of floor. The player can spend the recovery crossing into an open lane or attacking. A tracked sweep, then a charge and volley in the later phase, test that positioning. | The victory message and banner mark completion. The player can continue exploring. |

Ordinary enemies use existing catalog kinds and shared movement, damage, posture
and conditions. The guardians adapt shared attack execution with four new
authored tells. Build purchases and learned spells use the existing rules.

Each optional cache can be taken once after its guards are cleared.
Miller’s Loft, Pilgrim Cells and the Reliquary replenish rejuvenation charges.
Silt Garden and Sump Store supply Firebombs. Bellkeeper’s Quarters and Archive
Balcony supply Smoke Vials. Ordinary encounters award catalogued XP and respawn
after rest or death. Guardians award 18, 18 and 24 XP. Either ending approach is
available without an XP gate.

## Connections and saves

| Connection | How it opens | What it changes |
| --- | --- | --- |
| Overlook gate and Dawn return gate | Existing far-side handles | Existing forest return routes. Dawn can secure either. |
| Dawn service lift | Reach the Penstock Vault and Wheelrace Tunnel to find the platform under the forest | Immediate lift beside the old southern forest loop. Dawn or another Waystone can secure it. |
| Freight lift | Commission from either regional platform before either guardian | Bidirectional travel and a different encounter approach. An already seen endpoint reads as a reconnection. A newly seen endpoint is introduced as a discovery. Basin or Carillon can secure it. |
| Tower service stair | Walk the Choir Passage and West Ambulatory to the crown-side handle | Direct retry path from Lantern Court to the crown approach. Lantern can secure it. |
| Drain channel and counterweight bridge | Defeat the guardian, then operate its control | Permanent, walkable forward routes. With both open, take one tower entrance out through the other. |

Reaching any Waystone secures opened shortcuts. Save/reload keeps each
shortcut’s current and secured states. Death closes an unsecured opening.
Guardian victories and operated crossings survive rest, death, and reload.

In regular Waystone, the Campaign owns `user://waystone-regional-campaign.save`.
New, resume, ambient autosave, rest, death, and explicit mode return all use that
slot. Character purchases, learned spells, enemy actions, the seed and discovery
persist in the same save. The Campaign load checks the regional payload before
opening it. The standalone package retains its own identity and app data.

## Reproduce

Run `build-all.ps1` on a clean committed checkout using the regular export presets.
Use a disposable Godot user data directory for every test, including renderer
tests, because interactions can save immediately.

- `tests/regular_campaign_entry_test.gd` exercises the normal scene and routes
  mouse or portrait touch through start, movement, Character, mode return and
  resume. It takes saves written by the preceding regular build and checks
  legacy and archive file hashes. Run it again with `-- relaunch` in the same
  fixture directory to verify a fresh process restores the Campaign.
- `tests/campaign_regions_test.gd` exercises route legs through ordinary move
  requests and checks guardians, rest, deaths, lifts, crossings and alternate
  approaches. `-- cache` exercises the one-time payout. Controlled travel
  uses deliberately cleared encounters.
- `tests/campaign_guardians_test.gd` uses the existing legal-action planner in
  the actual arenas. `-- wall` isolates the Warden's buttress recovery.
- `tests/campaign_live_route.gd` exercises a populated route with public game
  actions. The planner forecasts consequences on a copy.
- `tests/campaign_regions_capture.gd` renders authored scenarios and sightlines
  at 390 × 844 and 1280 × 800.

The first-time target is 3–4 hours with some detours. Human journey duration remains
to be measured.
