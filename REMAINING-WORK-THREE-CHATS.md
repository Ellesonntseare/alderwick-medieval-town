# Remaining work across the three town chats

Status checked 3 November 2026. Estimates are planning ranges for a first usable, tested version, not guaranteed completion times. They include the newly selected Sims-style features, which expand the earlier scope. Shared functionality should be implemented once across all three chats.

| Chat | Remaining work | Estimated active work |
|---|---|---|
| Set up new project | Final visual checks of forest/neighbour-town connections, doors and scale; real microphone/voice play-through | 30–90 minutes |
| Set up new project | Complete needs and behaviour: energy, hygiene, comfort, fun and social contact alongside existing hunger; moods and personalities affecting choices/dialogue | 2–4 hours |
| Set up new project | Deeper friendships, rivalries, adult romance, family bonds, reputation and consequences, using existing trust/events | 2–4 hours |
| Set up new project | Skills, practice/teaching, cooking, ingredients, recipes, growing food and useful gifts/inventory | 3–5 hours |
| Set up new project (2) | Resolve local AI readiness and run real mission conversations from acceptance through pickup/work/return/reward, then save/reload and duplicate-reward checks | 1–2 hours; more if backend diagnosis expands |
| Set up new project (2) | Final editor interaction/save/reload checks with furniture, doors, existing homes and routed crowds; actual-world placement/removal already updated navigation correctly | 45–90 minutes |
| Set up new project (2) | Final animal/castle/family visual checks and updated handoff notes; faulty sheep already replaced with the working model | 15–30 minutes |
| Set up new project (3) | Polish event propagation, family meals/breaks and generated conversations in ordinary play; coordinate expanded household features with first chat | 45–90 minutes |
| Set up new project (3) | Visually inspect rain/mist, shelter seeking, return to work and performance in busy areas | 30–60 minutes |
| Set up new project (3) | Play through the three exploration clues, their journal entries and connected conversations | 30–60 minutes |
| Shared, pending asset | Inspect supplied player-house model; fix scale/entrance/collision as needed; connect furniture, bed, storage, cooking and visitors | 2–6 hours after a usable model is supplied; substantial mesh repairs can take longer |

Approximate remaining work excluding the pending physical house: 12–24 active working hours across the three chats. Allow roughly 2–4 working days for a usable tested version with integration fixes. Parallel chats share one PC and cannot run heavy full-world tests concurrently.

Latest direct update from Set up new project (2): physical pickups, the four-second workbench repair, the visible repaired wagon, survey-chain actions and editor navigation checks have passed. The AI health retry guard was corrected and a real backend warmup test is running. That chat now estimates 45–90 minutes remaining if recovery works, or 2–3 hours if additional backend faults appear; this supersedes its earlier broad estimate above. Its natural generated mission conversation remains unverified until that test completes.

## Verified foundations

- 53 residents, 24 households; controlled night test reached 49 off-duty beds with four guards on night duty.
- Missions, rewards, trust, promises, currency, food trading and saved journal foundations exist. The latest actual generated mission test is blocked by local AI readiness; it is not complete.
- Editor placement/removal updated actual navigation and retained the cast. Full final editor review remains.
- Forest walking passed its corrected test. Neighbour-town model and connecting road exist; final combined visual check remains.
- Text/voice input controls and local recognition passed a recorded-sample fixture, without opening the user's microphone. Real microphone use still needs the player to try it.
- New events/weather/discovery/home foundations passed the full-world behaviour assertions. An initial home-dialog signal error was fixed and its focused initialization/movement/storage test now passes cleanly.
- Farm shelters, rain return-home behaviour and two-person family breaks passed the new world assertions. Rendered weather and generated conversation quality remain play-through checks.
- Player-home menu and storage registration exist; no substitute home was placed. The user's house asset is still pending.

## Integration rules

Use existing household, event, trust, inventory and home modules rather than competing versions. Finish real AI mission verification early because other conversation-dependent features rely on the same service. Run one final combined walkthrough of day/night, weather, work, conversations, missions, editing and saves after the parallel changes settle. Keep the game closed except necessary tests unless the user asks to open it.

Ageing, generations, separate wishes/goals and a festival system are not part of the latest selected update.
