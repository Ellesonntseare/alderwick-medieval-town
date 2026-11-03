# Your potter's house and spacious interior

The user selected the Mitterkirchen potter's house for the exterior and `the_interior_14_is_spacious.glb` for the interior. Normal launches start the player inside the selected interior in first person. Other view options remain available. The exterior is hidden during indoor play, and the interior is hidden after leaving.

The selected loft is larger and taller than the thatched shell. Its human proportions are preserved by using a linked interior space instead of compressing it into the shell. Press **E** at the marked entrance/exit to move between them. This is the user's actual selected interior, not a generic replacement room.

## Furniture

- Stand beside a sofa seat and press **E** to sit.
- Walk up the east-side stairs to the upper gallery. The player bed is on the upper floor.
- Stand beside the bed and press **E** to lie down/sleep.
- Press **E** or **Space** to get up. The player's safe position from before using the furniture is restored.
- The house is reserved for the player; NPC family assignment and bed reservation skip it.
- The **Your home** menu stores and withdraws carried belongings while near the registered interior home.

The added bed uses the existing detailed medieval furniture asset. Sofa use anchors match the selected interior's existing furniture. The upper slab has a cutout for the stair flight, tested with the actual player capsule. Source downloads remain unchanged.

## Integration

`town.home_district` exposes `interior`, `exterior`, `spawn`, `porch`, `cooking_anchor`, `seats`, `bed`, `enter_home()` and `leave_home()`. `enter_visitor(person)` accepts up to two residents already within four metres of the exterior entrance, and `exit_visitor(person)` returns them outside; visitor scheduling belongs to the life simulation. The API's presence does not mean visitor scheduling or cooking has been verified here.

Native tests: `player-home-stairs-review.log` passes indoor spawn clearance, floor landing, actual stair ascent, sofa posture/getting up, sleep occupancy/release, exterior hiding and entry/exit. `town-player-home-inside.png` is an actual rendered indoor view. Complete-town checks are recorded separately in `player-home-world-review.log`.

The complete-town review passed with `failures=[]`: all 53 residents remain, the player settles safely on the indoor floor, storage is registered to the selected interior, NPC families do not claim either home space, and the outside arrival point is clear.

The subsequent life-simulation integration review (`character-life-world-review.log`) also passed with `failures=[]`: the supplied home's kitchen completes timed cooking with real ingredients, cooked food reduces player hunger, an invited resident physically reaches the porch before entering, then exits and resumes town life, and sleeping restores the player's energy. Cooking and visit scheduling are implemented by the life-simulation modules and use the home APIs above.

Model credits and embedded licences are preserved in `game/downloaded/player-home/credits.json`: exterior Mario_Wallner, CC BY-NC 4.0; interior dasy444, Sketchfab Standard.
