# Local dialogue disabled

On 5 November 2026 the user requested removal of the game's AI function and downloaded Llama installation, with character dialogue postponed.

- A shared disabled feature flag prevents dialogue requests, social generation, neural voice startup, health polling and microphone controls on desktop and Android. Saved voice settings or paired addresses cannot enable them.
- The opening screen no longer contains AI startup or polling. Character inspection and market trade controls remain. Jobs, schedules, movement, families and other local simulation systems remain independent of the language model.
- The Android PC connection interface is removed. The phone bridge, chat-server and model-download entry points now exit without starting a server or downloading anything.
- Removed tools/ai/models, runtime, runtime-b10632, both Llama runtime ZIP archives and range-probe.bin to the Windows Recycle Bin. Total file size was 2,419,574,922 bytes. Recycled files remain recoverable and do not free disk capacity until the Recycle Bin is emptied.
- Character histories, story data and unrelated projects were preserved. Speech runtime files were retained but the game cannot start their service.

Validation

- dialogue_disabled_review.gd passed using the actual dialogue, speech and panel scripts without --no-ai or --no-voices flags. Public health/send callbacks could not start services, input and microphone controls were absent, and backend process IDs stayed zero.
- Normal boot validation passed with dialogue disabled and no AI wait.
- No Llama/Alderwick Python services or listeners on ports 34319–34322 were found after the change.
- These changes affect the local game source. Previously exported Android APKs are unchanged.
