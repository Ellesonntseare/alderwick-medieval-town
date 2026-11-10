# Movement and route optimization — 4 November 2026

Selected by the user: 1 movement/collisions, 2 static rendering, 4 distant character detail, 5 route planning and crowd searches. This record covers 1 and 5; town_performance work is coordinated separately.

## Changes

- `villager.gd`: flat walking uses the normal collision sweep without a speculative step test. A blocked static wall triggers the upward/forward step probes. Crowd bodies do not trigger stepping. Standing residents recheck static floor support every 0.20–0.26 seconds; displacement and moving platforms bypass this shortcut.
- `street_traffic.gd`: existing per-physics-tick spatial cells also serve local social searches; an unchanged steering direction does not require a second speculative wall sweep.
- `village_life.gd`: potential conversation partners are collected near the resident, retaining friendship priority and a 12 m distance limit. Occupancy checks for meeting places use the same nearby cells.
- `walking_routes.gd`: up to 256 static paths are reused for 3 seconds, separated by start, destination and walking policy. Returned arrays are copied. Dynamic crowd avoidance and personal detours bypass this cache. Paving connectors are cached until navigation is rebuilt; map edits clear all these caches.
- Stuck-path recovery is limited to three searches per physics tick. Residents whose turn is deferred keep collision-based movement and retry next tick. Initial routes and door approaches are not delayed by this budget.

## Verification

- `review/routes-optimized-review.log`: policies, route reuse, immutable cached paths, obstacle detours, editor invalidation and deferred recovery budget passed.
- `review/traffic-optimized-review.log`: opposing pedestrians, matching-model spacing, passing a stationary guard and a two-person doorway queue passed.
- `game/movement-regression-review.log`: 4.499986 m flat walk, three 20 cm steps, solid wall blocking without climbing and 8.999999 m movement with budgeted updates passed. A resident on removed support fell from 2.0001 m to 0.8668 m, confirming cached floor contact is refreshed.
- `game/route-connector-movement-regression.log`: an actual resident can leave a position beside a stool and join a grid path.

These focused fixtures establish behaviour, not full-world FPS. Compare the final 75-resident scene at equal quality, resolution and camera positions before reporting a performance gain. Test the market, industrial workshops, archery range and night homeward movement, including slow-frame percentiles.

## Combined rendered checkpoint

All four selected optimizations are implemented. Fixed decorations use spatial MultiMesh batches preserving materials and visibility ownership; 444 source meshes formed 66 batches in the loaded town. Visible residents beyond 18 m sample animation at 12 Hz (Performance) or 20 Hz (Balanced); nearby residents and active conversations retain full updates. High and Ultra retain full animation updates.

Rendered tests on Intel UHD 630 loaded 75 residents, 30 industrial workers and ten archery trainees. Work/delivery checks, archery (36 shots), and Roslin's actual garden walk passed with no reported activity failures. Material/transform batching and animation timing tests passed separately.

| Scene | Earlier 75-resident run | Optimized run |
| --- | ---: | ---: |
| Industrial overview | 26.45 FPS | 33.60 FPS |
| Market Balanced | 24.41 FPS | 26.85 FPS |
| Market Performance | 29.14 FPS | 34.42 FPS |
| Market overhead Performance | 28.72 FPS | 34.27 FPS |

Market Performance p95 frame time changed from 55.81 to 37.13 ms and average reported physics time from 34.52 to 21.72 ms. These are short runs with active residents, not deterministic matched frames or a stable 60 FPS claim. Source logs: `industrial-75-world.log`, `optimized-75-world.log`, `lag-profile.json`. This checkpoint precedes removal of the two château ruins. The accelerated night home/bed check was still running when this record was written; it is not included in the daytime FPS samples.

## Accelerated simulation correction

The initial accelerated night test exposed an extra time-scale multiplier in resident movement. Movement now scales accumulated updates by the actual physics delta, including the raised-step retry. A focused regression passed at 0.5x and 3x time scale, each with ordinary and budgeted updates: expected 0.75 m / 4.5 m, measured within 0.000005 m. Flat walking, stairs, walls, 10 Hz travel and removed-floor checks remained passing. This correction does not alter the recorded normal-speed daytime FPS samples. The night population check must be rerun; the earlier run did not establish successful sleep for everyone.
