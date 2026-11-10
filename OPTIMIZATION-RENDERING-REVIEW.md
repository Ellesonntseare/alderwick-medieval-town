# Fixed decorations and distant animation

The Performance/Balanced presets now sample distant visible residents' animation
at 12/20 Hz, while nearby residents and conversations retain full animation.
Their movement, collisions, chores, deliveries and home routing continue to use
the existing simulation. High and Ultra retain full visible animation. Hidden
characters continue their schedules without evaluating invisible animation.

Fixed repeat props use shared MultiMesh draws in 16 m cells. Batches retain
their owner transform and visibility, original material and shadow policy.
Doors, roofs, carried equipment, future trade items and individually editable
props keep their own objects. House surface merging covers architecture;
furniture retains its separate visibility owner. The map captures static
MultiMesh geometry in its own rendering world too.

Focused validation:

- `performance-detail-review.log`: quality settings save/load, free overhead
  focus, frustum checks, actual AnimationPlayer time advancing in the distant
  manual mode, and full animation restored for a conversation.
- `static-decoration-render.log`: seven sources become three bounded draws;
  materials/transforms remain correct; moving/hiding a house affects its batch;
  door and editor objects are excluded. Use an actual renderer for this fixture:
  Godot's headless dummy renderer does not provide MultiMesh transform readback.
- `game/garden-route-review.log`: Roslin physically walks from her actual
  practice lane across the existing town to the community garden and completes
  gardening. The old 60 m chore radius incorrectly rejected that 60.5 m trip.
- `game/night-pacing-review.log`: short sky preview does not reverse homeward
  walkers at dawn. Departure begins at dusk; night holds for settlement and
  eight seconds of rest, bounded to 300 extra seconds if a route remains blocked.
  Guards on the night watch are excluded. Disabling the cycle restores daylight.

The first rendered 75-resident combined run passed daytime activity checks:
30 industrial workers, local deliveries, ten archery pupils with 36 shots, and
completed gardening. It grouped 444 repeat mesh sources into 66 batches.

Short samples on the existing PC with both château ruins still present:

| View | FPS | 95th percentile frame ms | Mean physics ms | Mean draws |
| --- | ---: | ---: | ---: | ---: |
| Industrial overhead | 33.60 | 50.70 | 41.86 | 1172.8 |
| Market, Balanced | 26.85 | 46.49 | 35.53 | 1671.5 |
| Market, Performance | 34.42 | 37.13 | 21.72 | 1290.2 |
| Market overhead, Performance | 34.27 | 46.34 | 25.20 | 1083.8 |

The prior same 75-person script sampled the industrial view at 26.45 FPS and
the market Performance view at 29.14 FPS. These are short samples with moving
crowds, not a fixed deterministic graphics benchmark or a stable 60 FPS claim.
The working set sampled around 3.1 GiB, with roughly 3.4 GiB private memory:
the 2–3 GB target is not consistently achieved yet. Original texture images are
retained; 3D texture imports use compression and a 512 px cap to reduce memory.

The corrected post-removal actual night test (`corrected-night-homes.log`)
confirms all 22 new workers physically reached their reserved lodge beds after
fixing a gate bottleneck. Total sleepers were 51 of 71 off-duty residents;
20 existing residents remain blocked on native entrances or home routes.
The later native-entrance repair passes the full town test in
`game/native-night-whole-town.log`: failures=[], 71 of 71 off-duty residents
sleeping, including all 22 new crew, at 330.1 simulated seconds. Four guards
remain on night watch. Accelerated-test movement is verified at both 0.5x and
3x time scale, at ordinary and budgeted updates.

After the two ruins were removed, a first fresh industrial sample was invalid:
the background model load had not completed, leaving workers on an empty yard.
The harness now explicitly waits for the industrial visual before warming up
and taking a sample. The corrected `loaded-district-performance.log` records
`INDUSTRIAL_VISUALS_LOADED` and `INDUSTRIAL_SAMPLE_READY visible=true` first.
Its actual factory scene sampled 38.12 FPS, p95 40.388 ms, max 192.43 ms,
mean physics 22.546 ms and mean draws 990.48. The screenshot is
`industrial_30_overhead-optimized.png`. Other short samples in that run were
43.54 FPS at archery, 27.23 at Balanced market, 37.38 at Performance market,
and 44.13 at Performance market overhead. These remain variable short samples,
including a visible 192 ms industrial stutter; they do not establish stable 60.

Final visual inspection found that the workbench batches needed origins near
their own cells for distance visibility. That culling correction is now saved.
The final `industrial-visible-review.log` explicitly verifies factories loaded,
30 workers, 28 instanced bench/crate mesh sources and nine nearby batches, with
no failures. `industrial-30-workers-final.png` visibly shows the factory yard,
workers and work stations together. The camera is locked during this test.
After a five-second warmup, its ten-second sample measured 32.15 FPS,
p95 49.159 ms, max 847.129 ms, mean physics 28.303 ms, and mean draws 1117.88.
`industrial-visible-performance.json` is the final industrial measurement;
it supersedes the 38.12 FPS result before the prop visibility correction.
The sampled working set shortly before the end was 3,250,987,008 bytes
(about 3.03 GiB); private memory was 3,700,899,840 bytes (about 3.45 GiB).
The memory and smoothness targets still need further work.
