# Selected improvements, 5 November 2026

The user selected items 1, 2, 4, 5 and 6 from the performance/gameplay audit. The walking-map capture optimization (item 3) is outside this change. Local AI dialogue and neural voice services remain disabled.

## Rendering

Fixed crop boxes now share exact-material, exact-geometry MultiMesh batches in bounded cells. Additional fixed furniture assets use the existing owner-local batching policy. Movable props, doors, roofs, editor objects and independently hidden interior owners remain separate. Collisions remain on original nodes. A rendered Intel UHD 630 crop patch changed from 60 draws to 2 with zero changed pixels. The full crop layout was reduced from 120 instances to four batches. In the full town the new primitive pass combined 130 sources into six batches, and the decoration pass combined 484 sources into 86 batches. These source counts do not all appear in every camera view.

See RENDER-SCENERY-BATCHING.md and the primitive/furniture/native-house fixtures. A proposed wall/floor disk cache was measured and removed because it provided no useful warm saving over the native merge.

## Movement

Pavement connector discovery shares one bounded local traversal instead of repeated A* calls. Industrial runtime replans enter a fair queue retaining the latest requested destination, with at most two searches per physics tick and a soft 1.2 ms batch threshold. Crowd recovery uses a shared soft budget and spaces repeated escape probes while preserving physical checks and door ownership. A single individual search cannot be interrupted by the soft budget. Initial setup routes remain immediate. Focused workload, nearest-point equivalence, traffic, door queue and stool-corner checks passed. The full-town headless night regression passed after correcting a narrow lodge-junction handoff: all 71 off-duty residents reached actual beds, including all 22 new workers, with 30/30 industrial-home handoffs and zero pending residents at 330.1 simulated seconds. Four night guards remain on duty. A final night-return waypoint now accepts 0.85 m arrival, while every intermediate/daytime waypoint remains 0.4 m. The physical home/door/bed route still runs normally. A recorded-position regression reproduces the old deadlock and verifies the correction. Log: review/night-homes-movement-after-junction.log.

## Startup

City navigation caching now applies to desktop and Android. Actual static collision geometry and transforms, the navigation source, region and saved layout participate in invalidation. Cache coordinates and values are validated completely before replacing a live grid, and writes replace a completed temporary file.

Fitted character motions are cached as compressed plain transform-key arrays, grouped per rig to avoid opening and writing a separate file for each clip. Source motion content, source rest transforms, target rest signature, track path and fitting recipe determine cache identity. Cached data is restricted to finite bone position/rotation/scale tracks. No script, scene or method-track objects are deserialized. Real Walk interpolation equivalence and invalid source/rig/path/method/nonfinite checks passed.

The final rendered repeat launch reached readiness in 26.038 seconds, with 1,047 motion cache hits and zero misses. City walking navigation restored in 0.532 seconds. The earlier rendered run before prepared-motion caching took 71.071 seconds, including 6.669 seconds of uncached navigation. This is a short repeat-launch comparison on the current PC, not a device-independent loading guarantee. First preparation and changed geometry/motions require rebuilding. A temporary 113.777-second experimental startup included the rejected wall cache and per-clip motion-cache I/O and is explicitly excluded from final timing evidence.

## Missions with dialogue postponed

All three existing stories have resident-panel actions for accepting requests, checking leads and returning items. Actions require the current nearby resident and expected active mission step, reject stale clicks and missing items, consume handed-in items once and retain existing mission rewards. Findings are persisted as journal notes instead of generated speech. The existing map objectives continue to follow actual resident positions. The full rendered world exercised Ada's acceptance and Corvin's clue through their real panel buttons with chat input hidden. Separate tests cover the surveyor contact chain, remote action rejection, hand-in requirements, one completion and saved notes.

## Repeatable orders and visible activity

Archery, delivery, timber and furniture-repair contracts repeat after a 60-second active-play cooldown. Successive orders rotate through three difficulty/reward variants and requesters. Delivery destinations rotate through the square market, western market and castle provisions, actually adding 4, 6 or 8 food portions to the correct market. Archery requires 3, 4 or 5 new hits, and timber orders require 3, 4 or 5 newly gathered pieces. Completed orders pay once per round, improve the requester's trust and award a relevant player skill benefit. Completion counts/cooldowns persist, old one-time saves migrate, and the wallet's paid-reward records reconcile interrupted saves. Failed attempts can be retried; cancelling a carried delivery releases its crate safely.

Quiet paired social exchanges can now use the downloaded HeadShakeNo body-language animation. It only runs during an actual paired meeting and preserves existing work/guard exclusions. Repeated physical work reuses at most three result meshes per station rather than accumulating one mesh for every future cut or repair. A 100-action fixture retained exactly three result meshes and the original station.

## Final rendered measurement

Performance preset, 1280 x 800, AI disabled, all 75 residents and 30 industrial workers retained, 15-second fixed-camera samples after warmup. Industrial buildings and workplace props finished loading before that district was measured.

| View | Average FPS | p95 frame | Longest frame |
| --- | ---: | ---: | ---: |
| Square, third person | 45.37 | 32.946 ms | 61.687 ms |
| Archery, overhead | 52.12 | 32.514 ms | 45.050 ms |
| Industrial, overhead | 42.95 | 32.135 ms | 41.916 ms |

These are variable live-world samples. They do not establish higher whole-game FPS than every earlier sample or stable 60 FPS. The exact crop comparison proves the rendering reduction, and route fixtures prove workload distribution. Remaining pauses still need work. The trace includes first-use indoor route work up to about 11 ms, as well as the remaining overall physics/render cost.

Artifacts: review/optimized-final-performance.log, review/current-no-ai-performance.json, review/optimized-square.png, review/optimized-archery.png, review/optimized-industrial.png and review/offline-mission-in-town.png. No new APK, Git commit or upload was produced. Test windows were closed.

## Final checks

The final no-AI fixture again confirmed zero backend process IDs, hidden chat/microphone controls and no service startup. All dedicated cache, offline-mission, repeated-order and repeated-work visual checks passed. The actual rendered mission-panel/world-destination checks and the final full-town night check completed with no failures. No Godot test process was left running.
