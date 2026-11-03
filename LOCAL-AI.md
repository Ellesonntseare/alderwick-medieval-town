# Local character conversations

The town uses a local Qwen2.5-3B-Instruct model through llama.cpp. Character replies are generated from freely typed messages, the character's individual background, recent game events, and previous conversations. The text is then spoken by the local Kokoro voice runtime. Neither inference system needs an account or sends conversation text to an external provider.

Open a conversation with F near a resident, or click a resident in overhead view. The right-side panel keeps the character visible and displays a scrolling history. Enter sends a message; Shift+Enter adds a line. Esc or the close button leaves the conversation. There are no canned topic buttons. If the AI is loading or a request fails, the panel shows its status and preserves the message for retry rather than substituting a saved answer.

Each resident has an individual conversation history under `tools/ai/state/player`. Reopening a conversation restores the transcript. The model sees recent turns and a bounded selection of earlier things the player actually said. This is useful conversation memory, not a guarantee of perfect recall of an unlimited history. Review conversations use a separate folder and do not become the player's history.

The 45 character backgrounds and relationships are in `game/character_stories.json`, with a readable version in `CHARACTER-STORIES.md`. They are narrative context, not prewritten dialogue. Current game facts take precedence over an older occupation in a background. Story arcs describe possible future missions; talking does not itself transfer items, change a schedule, award currency, or complete a quest.

Nearby resident conversations also request generated turns. Only one background exchange requests inference at a time, and new background requests yield while the player is chatting. Speech comes from the speaker's position and fades with distance. This PC runs inference on the CPU, so uncached replies can take time; text and voice status should be evaluated alongside game performance.

The game automatically starts the local bridge at `127.0.0.1:34320`, which starts the model server at `127.0.0.1:34321`. Both are bound to loopback. The bridge tracks game processes and shuts down its model child after the game has closed and the idle timeout has elapsed. `--no-ai` disables automatic chat startup for isolated world tests.

Model and runtime provenance:

- Model: Qwen/Qwen2.5-3B-Instruct-GGUF, revision `7dabda4d13d513e3e842b20f0d435c732f172cbe`, file `qwen2.5-3b-instruct-q4_k_m.gguf`, 2,104,932,768 bytes. Expected SHA-256: `626b4a6678b86442240e33df819e00132d3ba7dddfe1cdc4fbb18e0a9615c62d`.
- Runtime: official llama.cpp Windows CPU build `b10632`, archive SHA-256 `9c19f33f2bfcf5259607940d60e0c0e3eb6e5858a2729243b4bd2301cb4ea248`.
- The model's Qwen Research License and model card are retained under `tools/ai/notices`. This model is for this local prototype; commercial distribution requires reviewing that license or replacing the model with one licensed for the intended release.
- llama.cpp's MIT license and the archive's LLVM OpenMP notice are retained with the runtime. A compatible Microsoft C++ runtime DLL is copied beside the model executable from the existing local speech runtime, avoiding changes to Windows system DLLs.
- Voice runtime credits remain in `VOICE-CREDITS.md`.

Relevant checks: `script-parse-chat.log`, `grounding-review-current.log`, `character-chat-preview.log`, and `tools/ai/local-ai-review.log`. Review logs are evidence only when their completion markers report success; a loading marker does not mean an AI reply was generated.

Completed checks: `tools/ai/local-ai-review.log` reports zero failures for generated replies, recall of the freely supplied name Moss, net-repair work and dislike of turnips, saved history, separation from another resident's private history, and a generated neighbour exchange. The native `character-chat-verified.log` reports zero failures for actual chat, reopening its history, recalling Cedar's details, local neural speech playback, and panel visibility. `local-generated-voice-review.log` independently measures non-zero Godot audio from an actual generated reply. The full model's SHA-256 was verified against the publisher's stored object hash.

The first uncached test reply took 20.94 seconds; its follow-up took 5.45 seconds. These are observations from this PC, not a fixed response-time guarantee. Loading the model from disk and running the full town at the same time can take longer.
