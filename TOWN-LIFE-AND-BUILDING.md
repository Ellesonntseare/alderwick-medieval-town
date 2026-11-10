# Stories, households, animals and town design

## Playing

- **J** opens the journal: requests, the next lead, carried items, remembered actions and households. It does not pause the residents.
- **F** opens a nearby resident's free-text conversation. Offer help in your own words, or use the optional **Offer to help** action in the conversation panel. Questions still use the local AI; there are no preset dialogue replies.
- **E** collects the current mission's nearby labelled item. For the wagon fittings, hold **E** at the carpenter's workbench for four seconds. Work uses the player's work animation.
- Returning an item requires an actual recovered item and a return message to the right resident. Merely claiming to have completed a task cannot award it. Coins are paid once per completed contract.
- Ada's market favour can be exchanged at her open stall for two meals, through the journal.
- **B**, or **Design town**, opens the editor. Drag catalogue items into the world. Drag placed objects or original modular houses to move them. Use **R** to rotate, the scale control for placed objects, and **Delete** for unoccupied objects you placed. **Ctrl+Z/Ctrl+Y** undo and redo. Buildings have doors and furniture; placed beds and stools expose the normal use interactions.
- In the editor, **WASD/arrows** pan and the mouse wheel zooms. Half-metre snapping is optional. Set the floor-height control when furnishing a raised floor, and hide roofs to see the room. Exit with **B** or **Save & return to town**.

The editor freezes simulation while retaining physical collision for placement checks. It saves `user://town-layout.json`, without rewriting downloaded models. When editing finishes, it samples the world again, rebuilds road/pavement routing and restores the existing cast. Original resident homes can be moved, with their indoor residents and anchors following; occupied family buildings cannot be deleted. The current editor catalogue covers modular houses, furniture, outdoor props and path sections. Large scanned map landmarks remain fixed.

## Three connected missions

1. **The misplaced delivery:** Ada → Corvin's delivery slip → the labelled crate beside the western market → return to Ada. Pays 12 coins, increases trust, restores 12 market portions, and grants a market favour.
2. **A wagon before the fair:** Oren → Bram → collect fittings → use the carpenter's workbench → return to Oren. Pays 18 coins, increases trust and reveals the repaired wagon in the workyard.
3. **The overdue surveyor:** Greta → Rowan → Nils → speak with Ansel beside the western gatehouse → report to Greta. Pays 15 coins, increases trust and grants the survey map.

`story_missions.json` holds facts and objectives rather than canned conversation lines. `mission_cast.json` supplies the visiting surveyor's background alongside the 53 permanent residents. Ansel surveys the masonry and has a camp bed for the night. Edda works inside Feira Castle; Sven works inside Castle XIX and produces visible stools and wages. Public boards display actual completed-mission news.

Relationships record accepted help, kept or withdrawn promises, purchases and witnessed insults. A listener can object to an insult about a friend without the absent friend magically knowing it. Positive trade effects are bounded. Progress, belongings and relationship events use `user://town-adventures.json`; reward identifiers are also saved by the economy to prevent duplicate coin payments. Completed wagon restoration is reapplied on loading.

## Families and animals

`households.json` assigns all 53 permanent residents to 24 authored households. Homes are matched to workplaces while respecting existing indoor workers, castle assignments and separate beds. Families with three members use bunks within existing bed footprints. Evening routes share a rendezvous and wait briefly for slower relatives; night-watch members retain their different shifts. Doors use the existing queues and night closing rules.

The night check held darkness long enough for long commutes: all 49 off-duty residents reached their assigned beds, with four night guards working. This is not a claim that every long commute finishes within the night portion of the one-minute preview.

There are 13 ground animals. Farm stock stays inside bounded northern pastures, with sheep grouping, walking/resting cycles and a return to shelter at night or during rain. The small dog remains mobile. Three bird flocks and two individual flying birds use varied sky routes, heights and phases.

The problematic noncommercial sheep download is preserved for reference but is **not spawned**. Its replacement uses the existing proven sheep walk rig, at 0.82 metres. A cow, horse and the other downloaded sheep are used with their prepared walking rigs. Bird flight uses the original valid skeletal/morph animation. See `NEW-WILDLIFE-CREDITS.md` for the source metadata and preparation pipeline.

## Verification records

- `adventures-unit-review.log`: discovery/acceptance, actual item requirements, remote pickup rejection, unrelated conversation, broken promises, bounded trade trust, save/reload and idempotent coin rewards.
- `living-town-review-third.log`: all 53 households/individual beds, 49 night sleepers, four watch exceptions, gathered families, road/pavement/open movement, all farm stock in pastures and sky movement.
- `builder-native-review.log`: actual GUI drag/drop, overlap rejection, undo/redo, saved layout, usable bed and furnished cottage. Later catalogue additions have a separate final fixture log.
- `adventure-builder-world-review.log`: actual workbench interaction, visible repair, survey progression, complete-town navigation add/remove and resident preservation; its initial AI readiness failure is historical and must not be cited as a successful generated-dialogue test.
- `adventure-builder-world-final.log`: the complete real local AI offer, clue, physical pickup, return, 12-coin purse increase, 12-portion stall refill and saved trust passed with no failures. Actual workbench repair, survey chain and full-world editor navigation add/remove also passed in this run.
- `town-boot-review.log`: the lightweight startup scene reached the actual local AI in 15 seconds, before loading the full town. The optional **Enter town now** button allows exploring while conversation loading continues.

The original chat owns voices, movement and the new forest/neighbouring town; chat 3 owns events, weather, discoveries and the player-home framework. The supplied house model is still required before placing that home. Additional needs/skills/cooking features selected in the original chat are separate work.
