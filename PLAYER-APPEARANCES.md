# Player appearance selection

The face menu selects the player's skin. It lists each distinct base model once; residents who share a model do not create repeated entries. The resident cast, jobs, names and stories remain separate.

Open the upper-left menu and choose **Player appearance · choose a face**. Scroll or search the rendered faces, select one to see its name and appearance information, then choose **Use [appearance]**. The player changes appearance and the view switches to third person so the result is visible. The choice is saved locally for the next launch.

The current catalog contains nine existing base models: Townsperson, Craftsperson, Village herbalist, Traveller, Knight, Viking, Mercenary, Hooded ranger, and Emlyn. Additional models under visual review are not automatically added to the playable catalog. Clothing variants can be attached to their base rather than appearing as duplicate people.

The pictures are actual Godot renders from the same models and appearance settings. The original batch of 45 resident portraits remains under `game/portraits`; the player menu uses one representative per base model. It does not show 45 repeated resident cards.

Changing skin preserves the player's camera and controls. Each current skin has the neutral player idle, walking, transferred runner run/jump, sitting, and sleeping clips. Shield equipment uses the same rigid mounting correction as the residents. `player-skins-review.log` checks all nine current models for required clips and actual jump/landing behaviour.

Configuration is in `game/player_skins.json`, the menu is `game/player_appearance_menu.gd`, and the selected appearance is saved to the game's `user://player-appearance.json`. NPC story designs are in `CHARACTER-STORIES.md`; six additional adult profiles awaiting visual review are in `STAGED-CHARACTER-STORIES.json`.
