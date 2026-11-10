# Character preview checkpoint — 3 November 2026

Latest user instruction: show the new characters here in chat before putting them into the game. The game should remain closed unless requested or briefly required for a test. Both active chats have been told this preference. New adults/outfits/runner appearances remain staged for this visual review.

## Live versus staged

- Live cast: 45 named residents, nine base model appearances. Mina now uses Emlyn. Original source downloads are preserved.
- User explicitly approved six additional adult residents, bringing the adult cast to 51 when integrated. Their proposed profiles are in `STAGED-CHARACTER-STORIES.json` from the other chat.
- Six staged fitted models exist under `game/characters`: `saxon`, `bruce`, `armoured_assassin`, `robed_scholar`, `medieval_woman`, `cult_archer`. They are assets only; no new resident spawns or player-skin catalog entries have been added yet.
- Proposed names/roles: Gareth (western gate guard), Duncan (supply courier), Selene (night guard), Ivor (archivist), Roslin (herbalist), Fenn (range keeper). Names/stories/roles should be promoted together after the visual review.
- Four modular outfit previews are assembled under `source-assets/assembled-outfits`: male/female peasant and male/female ranger. They use supplied character heads, retain original outfit textures, and are currently static preview assemblies. Fit the clothing to the appropriate runtime skeleton before applying it to existing residents. They are wardrobe variants, not four additional residents or duplicate player base cards.
- Runner inspection found TWO unique appearances: `Downloads/runner/Running.fbx` (Boy01), and `runner/skins/Ch31_nonPBR.fbx` (Ch31). `Fast Run.fbx` and `Breakdance Freeze Var 2.fbx` are animation versions of that same Ch31 appearance.
- Two medieval runner preview assemblies are under `source-assets/medieval-runner-previews`: the smaller child in peasant clothing/cloth hood, and the older runner in ranger clothing. Original faces are retained, modern clothing replaced, proportions previewed at approximately 1.34 m and 1.60 m. They still need a runtime rig/animation pass and have not been added to the resident population. Adding both after the six adults would produce 53 residents.
- The existing `medieval_warrior` training display remains unchanged and unanimated as requested; animate it later.

## Pictures delivered for review

- `review/characters/new-residents-1.png`: Gareth, Duncan, Selene.
- `review/characters/new-residents-2.png`: Ivor, Roslin, Fenn.
- `review/characters/four-medieval-outfit-previews.png`: four outfit sets.
- `review/characters/runner-medieval-clothing-preview.png`: two runner appearances with medieval clothes.
- `review/characters/runner-original-models.png` and `runner-source-inspection.json`: evidence of the two unique runner appearances versus repeated animation files.

The adult equipment still needs cleanup: Saxon shield placement and loose arrows/attachments on the archer are visibly unfinished in the previews. The six have eleven baked activity clips on the common 22-bone rig, but require a full Godot pose/locomotion check before being spawned. Do not describe their integration as complete.

Build/review tools: `tools/rig_remaining_residents.py`, `tools/render_new_residents.py`, `tools/prepare_outfit_previews.py`, `tools/inspect_runner_children.py`, `tools/prepare_runner_medieval_previews.py`. Their corresponding logs are in the project root.

## Other world work already implemented, verification incomplete

- Currency, market food purchases, delivery replenishment, job wages, meals, breaks and tavern visits are connected. The market accounting/total-currency checks have passed.
- Music is off on launch; the upper-left menu collapses using its button or H. The purse UI is anchored at the upper right.
- All nine current model types pass idle/walk/run grounding in `grounding-nine-models.log`. Sampled full-town sole errors were approximately -2.0 cm to +2.1 cm. The dog roamed more than 48 m in the controlled run.
- Same-model avoidance, separated work sources/destinations and staggered errands are implemented. `traffic-spacing-review.log` passed with approximately 1.90 m clearance between matching-model walkers.
- Warm windows/door lanterns, an interior-light group, a budget of 12 nearby lights, district paving/signposts, 751 paving meshes batched to 32 groups, and a 45 FPS native cap are implemented. Native visual verification of the complete town update remains pending.
- Fourteen fixed daytime guards and three separate night guards are implemented. Latest `town-life-final-schedule.log` still has failures: 41 of 42 intended sleepers reached beds at night, all three night guards reached posts; morning 13 of 14 day guards returned, only one of three night guards slept. Pending actors included Elowen near the tavern, Eirik/Wolfram at the town-hall aisle, and Rolf at a western doorway. These door/interior conflicts still need real fixes; do not mark the whole town update complete.
- Actual-bed reservations and awareness of visitors already inside the tavern were refactored in `village_life.gd`. Night entry/exit queues and blocked-route replanning were improved in `villager.gd`/`street_traffic.gd`. Remaining failures above occurred after this refactor and need further diagnosis.

## Coordinated other chat

User explicitly authorized coordination with `Set up new project (2)` (thread `01a1a14e-90c5-7cc1-be48-625d2ed9707f`). That chat owns generated local dialogue, speech, player skin swapping, the unique-base skin menu, character stories, and the two newly downloaded chateau districts.

Its reported passing evidence is available in `character-chat-verified.log`, `tools/ai/local-ai-review.log`, `local-generated-voice-review.log`, `player-skins-review.log`, and `player-appearance-menu-review.log`. Preserve `player.gd`, `town_dialogue.gd`, `dialogue_panel.gd`, `player_appearance_menu.gd`, `player_skins.json` and the story data when working on movement. The skin menu shows one card per base model, not all duplicated NPC appearances. New model entries should wait until this visual review and animation preparation are complete.

That chat is adding the two downloaded chateaux through a dedicated module and two root hooks; do not duplicate its map imports or undo its shared-ground changes.
