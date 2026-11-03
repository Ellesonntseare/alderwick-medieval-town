# Connected town improvements

Selected scope: spreading town events, family activities, conversations grounded in nearby events, behaviour-changing weather, a player home using the user's future house model, and exploration discoveries.

## Town events and conversations

Mission requests and resolved missions create factual events. The giver knows their own request; residents nearby can witness the event when there is a clear line of sight. News can pass between residents during a real, nearby conversation after its first exchange. Knowledge retains its source and is saved separately for each resident. Actual empty markets also produce a shortage event. This does not remove food artificially to force a story.

The existing generated dialogue receives known events, nearby visible neighbours and their current activities, weather, and relevant evidence carried by the player. It is instructed to distinguish witnessing from hearsay and to avoid reciting schedules. Dialogue still uses the existing local AI and voice services; these additions do not require another account.

## Families

Existing household membership, permanent beds and evening homecoming remain in place. During daylight, eligible relatives can route towards each other for short breaks. Duties, carrying deliveries, existing conversations, sleeping and occupied routines take priority. A family break has two actual participants. When both carry food and somebody is hungry, sharing a packed meal consumes their food and records the event in both personal histories. Family breaks are staggered rather than scheduled for the entire town at once.

## Weather

The upper-left menu offers clear, overcast, rain, mist, and changing weather. Changing weather advances every 75 seconds for previewing. Clear is the initial setting. Weather works with the existing optional day/night cycle and its one-minute preview setting.

Rain uses a modest local particle count and softer lighting. Mist raises distance fog. Eligible outdoor residents search for reachable positions beneath actual collision roofs. Guards keep their posts. Farm animals return to their pasture home positions beneath the new open shelters. Failed shelter routes are retried later rather than teleporting residents through buildings. Clear weather releases shelter routines.

## Discoveries

Press **G** beside evidence to examine it. Three initial discoveries are tied to the delivery, wagon and surveyor stories: a delivery slip, a workshop note, and a masonry sketch. They must be examined nearby with unobstructed visibility. They can reveal an investigation lead, but cannot complete the mission, award its coins, or prove the surveyor is safe. Relevant residents receive evidence context for free-form discussion. Found evidence is saved and appears among journal belongings.

## Player home — selected potter's house and spacious interior

The user selected `mitterkirchen_-_topferwerkstatt_potters_house.glb` as their house and `the_interior_14_is_spacious.glb` as its interior, explicitly requiring an indoor spawn with only the interior visible. Both are now implemented as linked exterior/interior spaces. See `PLAYER-HOME.md` for controls and test evidence. The native fixture passes actual floor landing, stair climbing to the gallery, sofa use, sleeping, getting up and entry/exit. Source inspections are in `review/player-home` and `review/player-home-interior`. No generic replacement room is used.

The **Your home** menu is prepared. No resident family's home can be claimed. `player_home.register_house(model)` accepts an unoccupied enterable house after its scale, entrance, collision and furniture are reviewed. Storage transfers remove items from one inventory before adding them to the other, require proximity and persist to disk. The menu provides store/take controls.

## Files and verification

- `game/town_events.gd`: factual news, individual knowledge and family breaks.
- `game/town_weather.gd`: weather selection, particles, lighting and cover seeking.
- `game/town_discoveries.gd`: nearby examination and mission leads.
- `game/player_home.gd`: house registration and persistent storage.
- `game/living_world_features_review.gd`: integration checks using separate review saves.

Review runs use `--validate-living-world-features` so they do not write normal player progress. Script checks are in `living-world-parse.log`; integration results are in `living-world-features-review.log`. A passing script check alone is not proof that the full integration review passed.

The first full-world integration run completed all behaviour assertions with `failures=[]`. It also exposed an unrelated-to-assertions home-window signal initialization error; that was corrected, and `player-home-review.log` now passes cleanly, including window initialization, movement restoration and storage. Generated conversation quality and rendered rain still need an ordinary play-through; no claim of a complete visual review is made by the headless checks.

Subsequent native weather checks (`weather-visual-review.log`) pass rain emission outdoors, no rain under a physical roof, mist, clear-light restoration and preservation of a held night. Rendered rain and mist were inspected in `town-weather-rain.png` and `town-weather-mist.png`. Weather now changes cloud/fog colour and light without calling the clock's routine transitions. Generated conversation quality still benefits from a normal player walkthrough.

The first full industrial/night regression reached 48 sleeping residents; all six industrial commuters reached their actual family beds. Oren remained beside a public stool because the first grid connection crossed its corner. `village_life.find_route` now checks the physical start connector and searches nearby reachable cells when blocked. The focused real-character reproduction passes (`route-connector-review.log`). The complete-town rerun is recorded in `industrial-world-final-review.log`.

The complete-town rerun passes with `failures=[]`, all 49 off-duty residents asleep and the six commuters in their own family beds. Door routes supply the physical character to the start-connection check while retaining their previous night routing policy. The test uses a controlled held night, not a promise that every long-distance commute fits inside the short one-minute preview night.

The isolated local-generation context review now also passes (`living-context-review.log`). Finn naturally mentions sheltering from rain and distinguishes news Corvin told him from something personally witnessed; he does not invent a completed recovery. This uses separate review history and leaves player conversation history unchanged. A cold-start attempt exceeded the earlier 45-second review wait; the review now allows up to 120 seconds without changing the game service or restarting an active session.
