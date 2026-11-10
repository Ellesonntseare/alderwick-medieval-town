# New character animations — 5 November 2026

`Jazz Dancing.fbx` and `Shaking Head No.fbx` are complete, stable FBX 7700 files.
Their source downloads remain unchanged, with project copies in
`source-assets/social-animation-review/`. The reproducible conversion is
`tools/retarget_runner_actions.py --social`, run through the existing Blender CLI.

The resulting `game/characters/social_actions.glb` is 148,160 bytes and contains:

| Runtime name | Duration | Playback |
| --- | --- | --- |
| JazzDance | 2.333 seconds | Loop |
| HeadShakeNo | 1.8 seconds | Once |

Both clips use the shared rest-aware fitting in `game/motion_library.gd` and are
available on all 22 resident model types and all ten selectable player skins.
Existing model weights, equipment mounts and ordinary walking/carrying behavior
were not changed.

The first diagnostic caught floating during the dance. The glTF/Godot import
optimizes away constant root position tracks, or reduces them to two keys, while
the dance has many changing leg poses. For these two clips only, ground fitting
now creates the root position track when needed and samples it at all animated
pose times before calculating the floor offset. This preserves limb lengths and
keeps the feet attached while grounding the pose.

## Validation

The focused `game/social_animation_review.gd` checked both clips on 22 models and
the actual player setup for all ten selectable skins: 64 clip checks and 3,904
sampled poses. All checks passed, including finite poses, visible motion,
loop/one-shot policy, foot attachment, upper-arm/forearm lengths, thigh/shin
lengths, and grounded ankles.

- Maximum ankle attachment discrepancy: 0.000000135 m.
- Maximum relative upper-arm length error: 0.000000643.
- Maximum relative forearm length error: 0.000000636.
- Maximum grounding discrepancy: 2.73 mm, on Erika's dance; most models were
  below 1 mm. This is an ankle/rest-floor diagnostic, not a full foot-sole contact
  walkthrough on uneven terrain.
- Both labeled 22-model montage sheets were rendered and visually inspected.
  No floating or detached limbs were visible. A raised dancing arm can lift an
  attached shield in front of a face; a festival should temporarily hide held
  equipment and restore it afterward rather than alter the equipment mount.

Evidence:

- `game/social-animation-rigs-final.log`
- `game/social-animation-visuals.log`
- `review/social-animation-rig-results.json`
- `review/social-animation-summary.json`
- `review/social-JazzDance.png`
- `review/social-HeadShakeNo.png`

Town action selection is owned by the other chats. Festival integration may use
`JazzDance` with `RunnerDance` as a fallback now that the clip review has passed.
The clip being available does not imply every resident should dance or shake
their head continuously.

## Six follow-up clips

The following six FBXs are now fitted in `game/characters/remaining_actions.glb`:

- Carrying Turn
- Carrying (`CarryingIdle`, a holding pose)
- Shove Reaction
- Drunk Walk Backwards
- Singing
- Praying

The rendered check passed 264 clip checks and 16,104 sampled poses across 22
resident models and the current catalog of 22 selectable skins. The prayer clip
uses knee and boot support as the character kneels. The six clips are available
as one-shot actions. Evidence is in `game/remaining-animation-review.log` and
`review/remaining-animation-rig-results.json`.
