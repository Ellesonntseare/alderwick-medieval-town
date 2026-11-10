# Walking, running and jumping review — 4 November 2026

The reported foot stretching was reproduced. Copying the runner clips directly
onto a differently proportioned skeleton displaced its independent foot controls.
The largest raw runner displacement in the 22-model diagnostic was 0.727 m.
Fitting clips alone also left smaller gaps between keys on the original rigs,
because foot positions and shin rotations interpolate independently.

## Changes

- `game/motion_library.gd` now fits `RunnerRun` and `RunnerJump` for every target
  skeleton, replacing any pre-existing unfitted copies. Completed resources stay
  shared for matching residents; player resources remain private.
- `game/feet_attachment.gd` anchors each foot to the currently animated ankle
  after interpolation and blending, retaining the foot's rotation.
- Residents and the player install this modifier before floor grounding.
- The player owner removed direct raw runner-clip copying and isolates native
  mutable clips. Standing uses each model's native/fitted `Idle`, with fitted
  `BasicIdle` for Erika, whose other standing clip caused an awkward lean.

## Verified in this chat

- All 22 model styles: `Walk`, `Run`, `RunnerRun`, `RunnerJump`, 61 samples per
  clip, totaling 5,368 corrected pose samples. No ankle attachment or leg-length
  failures. Largest corrected ankle discrepancy: 0.000000189 m; largest relative
  shin-length deviation: 0.00000324.
- Walk → runner run → runner jump → walk transitions, including intermediate
  blend steps, passed for all 22 styles.
- Pre-existing raw runner clips are replaced rather than silently retained.
- Animation resource sharing and private player loop/key mutation checks pass.
- Rendered labeled walk, jump takeoff and mid-jump sheets were inspected for all
  22 styles. No stretched or detached feet were visible. Long robes hide parts
  of the legs; intentional archer arm poses remain.

Evidence:

- `game/locomotion_rig_review.gd`
- `game/locomotion-rig-review.log`
- `game/locomotion-visual-review.log`
- `review/locomotion-rig-results.json`
- `review/locomotion-walk.png`
- `review/locomotion-takeoff.png`
- `review/locomotion-apex.png`
- `game/motion-memory-review.log`

## Actual player checks reported and evidence inspected

All ten selectable skins passed actual player-controller walking, running and
jump animation checks, including a physical jump of approximately 0.87 m and
landing. The player owner also tested standing with the attachment modifier
after animation processing. Evidence: `review/player-upright-review.log`,
`review/basic-idle-review.log`, `review/player-locomotion-final.log`, and
`review/player-gait-and-jump.png`. The full ten-skin rendered sheet was inspected
in this chat as well.

Erika's standing alignment was separately compared against her rest pose.
`BasicIdle` reduces the lateral knee bend of the other standing clip. The normal
walk's lateral knee offset in the sampled alignment check was approximately
1–5 mm, with no knee collapse. An eight-frame front/profile comparison of `Walk`
and `BasicWalking` is available at `review/erika-walk-comparison.png`; diagnostic
data is in `review/erika-stance-results.json`.

These are focused rig, controller and render checks, not a completed ordinary
town walkthrough or Android device test. APK work remains pending the separate
performance and district work coordinated by the other chats. The user later
explicitly cancelled APK work: do not build or update it without new authorization.

## Night movement correction

The user's later report that residents run around at night exposed the forced
6.5 m/s outdoor and 3.5 m/s indoor one-minute-preview overrides. Those overrides
were removed from `villager.gd`: outdoor return uses at most 2 m/s, indoor routes
1.6 m/s. Industrial return uses its ordinary 2 m/s pace. The 30-worker physical
route fixture passed again at ordinary night walking pace, but its held-night
duration is longer than a one-minute day/night cycle. The short preview now
holds dawn while residents settle rather than forcing a sprint or reversing
their routes every minute.

## Whole-town night validation — 5 November 2026

The remaining native-entrance failures were reproduced at the actual recorded
stuck positions. Coplanar floor contacts could exhaust movement slides, and
rounded porch edges reported an upward-sloping normal that the old step test
did not recognize. A clearance-checked floor retry and ordinary porch step
recovery now handle both. Tall-wall blocking, stairs, removed support, budgeted
walking and slow/fast time scaling all pass in `movement_regression_review.gd`.
Four focused actual-building tests entered through the doors and reached beds.

The complete 75-resident town then passed its held-night check:
`game/native-night-whole-town.log` reports `failures=[]`, 71 sleeping off-duty
residents, and all 22 new industrial workers in actual lodge beds. The four night
guards remain on duty. Everyone settled within 330.1 simulated seconds at normal
walking speed. The test accelerates wall-clock execution with time scaling; it
does not speed up residents relative to game time. This is a held-night check,
not proof that a complete walking commute fits in the original one-minute sky
cycle without its dawn hold.

That same world check confirmed both relocated mission anchors are physically
clear and reachable: Ada's crate at the western market and Ansel at the western
gatehouse. Separate frame-time stutter profiling remains in the other chat.
