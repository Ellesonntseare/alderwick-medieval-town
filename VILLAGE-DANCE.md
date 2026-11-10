# Copper Stag village dance

The open green at (-29, 24), beside the tavern and north of the community garden, has bunting, warm lanterns and six reserved dance positions. The gathering uses existing residents and their fitted JazzDance and RunnerDance animations; it does not create duplicate NPCs. Residents physically route to the green, dance for roughly180–200 seconds, then return to normal routines. Guards, stallkeepers, industrial workers, indoor workers and children are excluded; active conversations and current routines retain priority. Nightfall and the gathering toggle release participants through the existing routine cleanup.

Music: **Medieval: Minstrel Dance**, RandomMind, CC0. Official source: https://opengameart.org/content/medieval-minstrel-dance . The loop is converted to mono32kHz Ogg Vorbis (~529KB), with content/tempo unchanged. Credits and source metadata are recorded in game/audio/festival/CREDITS.md and review/minstrel-source.html.

The AudioStreamPlayer3D pans from the green; an explicit player/focus-distance envelope maintains intended loudness in overhead view. Full near gain inside3m, fades smoothly to silence at32m; quiet default -16dB and a further dialogue duck. It only plays when at least two residents have arrived and are dancing. Gathering and local music have separate settings in the journal, integrated by the UI chat.

Focused test: review/festival-functional.log passed six actual character rigs, looping music, near/far gain, overview listening, dialogue duck, dance completion memory and night cleanup. The rendered full-town test also passed. Six residents reached the green on foot and danced together while the local music played. All 75 residents and 30 industrial workers were present. The test used a 2x clock to shorten observation. See festival-party-final.log and review/village-dance-in-town.png.

