# Fixed scenery batching, 5 November 2026

This change reduces repeated scenery draws without simplifying its geometry,
changing texture resolution, or removing people. AI and voice settings,
movement, schedules, missions and worker counts are untouched.

`game/static_primitive_batches.gd` groups matching opaque box geometry placed
directly under the original Town into local 16 m cells. The crop rows are the
main repeated source: their 120 independently allocated box meshes and
materials become four MultiMesh batches. Each batch retains the original mesh
and active material. Every stored material/mesh setting is compared using its
binary representation, so different colours, UVs, textures and small numeric
differences cannot accidentally share a representative material.

The helper does not recurse into buildings, doors, editor roots, characters,
gardens or other scripts. Scripted, grouped, marked, transparent, overlaid,
custom-bounds and independently visibility-linked sources are excluded.
Original nodes and static collision children remain alive. Batch bounds and
origins stay local. Quality presets use the original source-size visibility
policy plus a conservative offset for the furthest instance, and Ultra restores
the original shadow/range settings. Batches follow the town's visibility and
transform. The map's existing MultiMesh capture path supports them.

The existing decoration whitelist now includes Table_Large, Table_Plate, Mug,
Stool, Bookcase_2 and Chandelier. Existing owner restrictions remain in force:
interior batches stay under their own room, doors/roofs/editor props stay
independent, and movable or trade-marked objects are excluded.

## Validation

- `game/primitive-batches-headless.log` passed the crop layout, exact material
  differences, collision retention, repeated-build safety, quality policies,
  local bounds, owner movement/visibility and dynamic-source exclusions.
- `game/primitive-batches-render.log` passed on the Intel UHD Graphics 630
  OpenGL renderer. A view of one crop patch measured 60 draws before and two
  after. `review/primitive-crops-before.png` and `primitive-crops-after.png`
  have zero changed pixels. Actual MultiMesh transform readback also passed.
- `game/decoration-batches-render.log` passed the original seven-source fixture
  (three batches) and the additional furniture-owner fixture. Moving/hiding a
  room still moves/hides its batch. Doors, roofs and editor objects stayed
  separate. The synthetic furniture fixture shares one test cube across six
  asset labels; it is an ownership/exclusion check, not a real-asset draw count.
- `game/furniture-batches-headless.log` passed with the actual six downloaded
  furniture assets: 12 mesh copies, 22 source surface draws becoming 11 batched
  surface draws, all 12 furniture collision shapes retained, seat marker intact.
- `game/rendering-quality-review.log` passed the existing four-preset graphics
  and distant-animation regression checks.

The crop screenshots are focused geometry checks. They do not establish an
overall FPS gain or memory saving in the full town. The coordinating chat owns
the combined full-world before/after measurement. Both bounded rendered test
windows exited successfully, and no Godot process remained when the renderer
was handed back. No APK, upload, commit or normal game launch was performed.

## Edited implementation

- `game/static_primitive_batches.gd` (new)
- `game/town_performance.gd` (build/apply the new fixed scenery batches)
- `game/static_decoration_batches.gd` (additional static furniture types)
- `game/static_primitive_batches_review.gd` (new focused and rendered fixture)
- `game/static_furniture_batches_review.gd` (new actual-asset fixture)
- `game/static_decoration_batches_review.gd` (expanded ownership fixture)

## House geometry cache evaluation

A separate startup-only experiment tested reuse of already merged walls and
floors. It used bounded plain surface arrays, a schema and content key based on
the source surface arrays and source-to-house transforms, checksummed payloads,
typed channel/index/finite-value validation and current runtime material binding.
It rejected stale edits, wrong schemas, corrupt or truncated files and malformed
geometry, and rebuilt through the ordinary merge on a miss.

The experiment did not justify adding a launch cache for this geometry. In the
focused six-house fixture (actual Floor_WoodDark and Wall_Plaster_Straight assets,
288 source surfaces becoming 12 merged surfaces), rebuilding measured 14.994 ms.
After adding per-pass reuse of validated arrays, a warm disk-cache pass measured
14.661 ms, a difference too small to establish a useful saving. Preparing the cold
cache measured 227.29 ms. The earlier version without per-pass array reuse took
41.018 ms warm. These short headless measurements took place while the other
chat was doing integrated checks; they are cost/benefit probes, not an isolated
hardware benchmark or whole-game loading measurement.

The native merge works on geometry already loaded for the buildings. Hashing,
reading, validating and decoding another representation added work around a
small native SurfaceTool operation. The experimental launch hookup and unneeded
cache prototype were removed. `town_performance.gd` retains its existing
SurfaceTool append/commit implementation for walls and floors. No geometry cache
is shipped or required by this change.

The retained `game/native_house_merge_review.gd` checks the actual native path.
`game/native-house-merge-review.log` passed two rebuilds at 16.113 and 15.272 ms,
each producing all 12 expected batches. Current materials, independently visible
doors and roofs, and ownership when the house moves/hides all passed.
The experiment's measurement record is `game/house-surface-startup-review.log`.
The coordinating chat was notified that any startup measurement that loaded the
temporary prototype must be discarded and repeated with the final source.
