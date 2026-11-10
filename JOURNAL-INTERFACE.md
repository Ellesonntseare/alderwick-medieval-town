# Medieval journal interface

The previous long sidebar is no longer displayed during play. Its existing
controls retain their callbacks and data, and are relocated into the journal,
camera selector and pause/settings screens. The music toggle and in-game
appearance entry are absent from the new playing interface.

- Before entering: choose any of the 22 human character models, enter
  town, adjust startup graphics/voice settings, or quit. Choosing a character
  persists when Enter town is pressed. AI readiness never auto-enters the world.
- Minimap click: opens the Map page in the same parchment journal used by
  My Life, Activities, Challenges and Journal.
- Journal / J: missions, belongings, relationships, promises and households.
- My Life / L: the existing needs, skills, people, cooking and gardening pages,
  including the needs/moods switch.
- Activities / G: actions available at the player's current location. Actions
  that open another page continue in the same book.
- Map / K: existing map pan, zoom, centering and objective tracking, with travel
  destinations on this page. Travel closes the book and restores walking.
- View: compact first-person, third-person and overhead selector. Tab remains.
- Pause / Esc: Return to town, Settings, Design town, Return to title and Quit.
- Settings: World, Audio & Voices, Graphics and Controls. World includes weather
  and day/night pacing; voice settings retain their saved values and callbacks.
  The separate village gathering has its own world/audio switches.
- Home storage remains available through nearby home/furniture interactions.

The journal stops player movement while open but lets the town and timed
activities run, matching the existing life-panel behavior. The pause/settings
screen pauses the world. Closing either restores the prior movement and mouse
state. The editor retains its own existing pause, collision and save lifecycle.

`game/journal_boot_review.gd` rendered the actual startup screen and verified
selectable appearances and no automatic entry. The first rendered world
test (`journal-world-review.log`) passed the five-page integration, sidebar
absence, relocated settings, minimap handler and Escape/restore checks. Its
screenshots are in `review/journal-*.png`. The final expanded rendered test
(`journal-world-final.log`) also passed travel restoring walking, challenge
start returning to play, and entering/leaving the town editor. Its error log
is empty. The passive village-party observation in that run exposed a separate
startup assignment race (six industrial workers retained as stale dance
members); the festival owner is correcting and verifying that separately.

No APK build is part of this interface update. Physical phone interaction and
player preference on the visual design still require review on the device.
