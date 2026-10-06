# Arena objectives for map editors

Everything a map editor needs to place King of the Hill hills, Domination zones and Capture the
Flag stands. In StrongDMM, search the object tree for `clash_objective`: every objective marker
is under `/obj/effect/landmark/clash_objective/`.

A map does not need any markers. Without them the game places each mode's objectives
automatically (see Automatic placement). Markers let you choose exactly where they go.

## The markers

| Path under `/obj/effect/landmark/clash_objective/` | Name in StrongDMM | Colour | Mode |
|---|---|---|---|
| `koth_primary` | KOTH primary hill | yellow | King of the Hill |
| `koth_secondary` | KOTH secondary hill | white | King of the Hill |
| `koth_tertiary` | KOTH tertiary hill | white | King of the Hill |
| `domination_zone/a`, `/b`, `/c` | Domination zone A, B, C | green | Domination |
| `clash_flag/uscm` | CTF flag stand (USCM) | blue | Capture the Flag |
| `clash_flag/upp` | CTF flag stand (UPP) | red | Capture the Flag |

- Each mode reads only its own markers, so one map can carry all of them at once.
- Place one of each. With duplicates the game takes whichever it finds first.
- Markers belong on the ground map. They are invisible in game.

## Var edits

Select the placed marker, open VarEdit (pencil in the right panel), change the value.
Text values go in double quotes, numbers without.

| Var | On | Values | Default |
|---|---|---|---|
| `radius` | KOTH and Domination markers | 1 to 7 tiles (outside that range it is clamped) | KOTH 3, Domination 2 |
| `rotation` | `koth_primary` only | `"static"`, `"match"`, `"timed"` | `"static"` |
| `rotate_minutes` | `koth_primary` only | 1 to 10 | 3 |

- A zone covers every open tile within `radius` of the marker, as a circle. Walls inside the circle
  are left out. On open ground radius 1 is 5 tiles, 2 is 21, 3 is 37, 4 is 61.
- Each hill can have its own `radius`.
- Flag stands ignore `radius`. A stand always marks the 3 by 3 square around its tile, and the
  capture happens within 1 tile of your own stand.
- Only the primary hill has `rotation` and `rotate_minutes`.

## Where a marker may go

A marker is usable only when:
- its tile is open ground: not a wall, not blocked by an anchored dense object (doors are fine);
- it is outside both bases (any `/area/clash_arena` area with a `clash_faction`). The base lock
  keeps enemies out, so an objective inside a base could never be taken.

Domination also needs the three zones apart: no tile may belong to two zones (centre distance more
than the two radii added together). CTF needs the two stands at least 10 tiles apart.

A marker that breaks a rule is skipped. What happens next depends on the mode (see Fallback).

## King of the Hill

- `koth_primary` is THE hill. Without it the hill is placed automatically and the secondary and
  tertiary markers are ignored.
- `koth_secondary` and `koth_tertiary` are optional. They are only used for rotation. Either one
  alone is enough to rotate.
- The hill always shows as "Hill" on the HUD and map, whichever marker it sits on.

### Hill rotation (`rotation` on `koth_primary`)

| Value | What players get |
|---|---|
| `"static"` | The hill stays on the primary marker all round. |
| `"match"` | Needs more than one match per round (the map json `tdm_matches`, default 3). The hill moves after every match: match 1 primary, match 2 secondary, match 3 tertiary, then back to primary. It moves during the break between matches, so players see the new spot during the countdown. |
| `"timed"` | During a match the hill moves every `rotate_minutes`: primary, secondary, tertiary, primary. Every match starts on the primary hill. |

Order skips any marker that is missing or unusable. With no usable secondary or tertiary marker the
hill stays static whatever `rotation` says, and admins are told why.

What players see on a timed move:
- The HUD objective line counts down all match: "Hill USCM, moves in 2:10".
- 30 seconds before the move: an announcement to both teams ("The hill moves in 30 seconds. Follow
  the flashing tiles or the H on your radar."), and the next spot's tiles flash white with
  "NEXT HILL" and a countdown above them. The radar shows it as a hollow H.
- On the move: the old hill disappears, the new one appears, "The hill has moved." Points scored so
  far are kept. The new hill starts open.
- Bots move to the new hill.

## Domination

- Place all three: `domination_zone/a`, `/b` and `/c`.
- If any of the three is missing or unusable, all three zones are placed automatically. Marked and
  automatic zones are never mixed, since that could stack two zones on top of each other.

## Capture the Flag

- Place both `clash_flag/uscm` and `clash_flag/upp`, outside the bases and at least 10 tiles apart.
- If either is missing or unusable, or they are too close, both stands are placed automatically.
- A flag away from its stand, carried or dropped, shows on everyone's radar at any range.

## Painted zones

- Paint the zone's tiles with an objective zone area: `/area/clash_arena/<map>/battlefield/zone_1`
  to `zone_6` (`<map>` is `tdm_deathmatch2000`, `tdm_jungle` or `tdm_kutjevo`). In StrongDMM they show
  as yellow, green, purple, blue, red and dark yellow. In game they read "Objective Zone 1" and so on.
- Put the usual marker (`koth_primary`, `domination_zone/a` ...) on a tile inside that area. The zone
  is then exactly the area's tiles and the marker's `radius` is ignored. The label sits on the marker.
- Each zone needs its own area number. A KOTH hill and a Domination zone may share one area.
- A marker outside any zone area keeps the round `radius` zone.
- Walls inside a zone count: once destroyed, standing there captures.
- Kutjevo maps: `/area/clash_arena/tdm_kutjevo/battlefield` replaces the Kutjevo exterior areas
  (no ceiling, same as the other maps' battlefields).

## TDM bot rally

- `/obj/effect/landmark/clash_bot_rally/uscm` (blue X) and `/upp` (red X): bots of that side walk to
  the rally and hold within 6 tiles of it instead of holding their spawner.
- With several rallies for one side, each new bot picks the one with the fewest bots.
- Only used in modes without objectives (TDM). In KOTH, Domination and CTF bots go to the objectives.
- Without a rally for its side a bot holds around its own spawner.

## Fallback

| Situation | Result |
|---|---|
| No markers for the mode | Automatic placement |
| KOTH: primary missing or unusable | Automatic hill, no rotation |
| KOTH: secondary or tertiary unusable | That spot is skipped, the rest still rotate |
| KOTH: rotation set, no usable secondary or tertiary | Static hill on the primary marker |
| KOTH: `rotation` misspelled | Static hill on the primary marker |
| KOTH: `"match"` on a one match round | Static hill on the primary marker |
| Domination: any of A, B, C missing, unusable or overlapping another | All three automatic |
| CTF: a stand missing, unusable, or the two under 10 tiles apart | Both automatic |
| Automatic placement also fails | No objectives, matches end as draws on time, admins warned |

At round start admins get one chat line per mode saying where its objectives came from, and for
every skipped marker, why. Example: "HVH: Domination: Zones were placed automatically because
domination marker B is inside a base."

## Automatic placement

Used when a mode has no usable markers. It works from the two base areas.
- KOTH: the hill sits on open ground nearest the midpoint between the two base centres (the map
  centre if the map has no base areas).
- Domination: B at that midpoint, A and C to either side of it, across the line between the bases
  (up to 20 tiles out), on ground reachable from B.
- CTF: each stand about 4 tiles outside its own base, on the line from the base to the middle.
  Without both base areas CTF cannot place stands at all.

## Radar

Every arena player's radar shows the objectives as small lettered squares, pinned to the radar's edge
when they are further than 7 tiles, so the radar works as a compass.
- H for the hill, A, B, C for Domination zones, F for flag stands.
- Grey: open. Blue: held by your team (or your flag). Red: held by the enemy (or their flag).
- Hollow: the next hill during the 30 second warning, and a flag away from its stand.

## Testing a map in game

- The round start admin line tells you whether your markers were used.
- HvH Control > Jump to an objective: ghosts you to each objective.
- HvH Control > Re-place objectives: re-reads the markers (useful after moving one with admin tools).
  On KOTH it puts the hill back on the primary marker; a timed rotation restarts its clock.
- KOTH with a secondary or tertiary hill: HvH Control > Move the hill now, and Set hill rotation
  (static, after every match, or timed with minutes). The rotation set here lasts the rest of the
  round and survives Re-place objectives.

## StrongDMM notes

- After the code adds or renames a marker type, close StrongDMM and reopen the `.dme` before saving
  any map. StrongDMM drops types it does not know when it saves.
- Score limits and match counts are not markers: they stay in the map json (`maps/<name>.json`):
  `tdm_koth_point_limit` (default 120), `tdm_domination_point_limit` (default 300),
  `tdm_capture_limit` (default 3), `tdm_matches` (default 3).
- The mode list a map can be voted for is the json `gamemodes` list. Only list modes the map can
  support.
