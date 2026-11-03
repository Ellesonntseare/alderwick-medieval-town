# Talking with residents

Use **F** beside an awake resident. The dialogue panel offers **Type a message**
or **Use microphone**. Both send messages to the same local character AI and
display the reply as text. Character voices can be switched off independently
of typing or microphone input.

## Microphone

Choose the microphone device, press **Start speaking**, then press again to
finish. **Ctrl+Space** does the same while microphone mode is selected.
Recording has a visible indicator and level meter and stops after 20 seconds.
The microphone is inactive until recording starts. Closing the conversation or
switching to typing cancels any unsent recording.

**Send when I finish speaking** is selected by default. Turn it off to review
and edit recognised words before pressing Send. Silence does not send a blank
message. Speech recognition is local English recognition using the bundled
Whisper tiny model; names and noisy speech may need correction. Audio is held
in memory for transcription, not saved as a microphone recording.

## Overheard and joined conversations

Residents in an actual nearby conversation use their assigned voices. Quiet
speech comes from their position, fades with distance and becomes inaudible
past the configured range. Sleeping residents and solitary NPCs do not speak
socially. Nearby conversations can be disabled separately from direct voices.

Approach a pair and use **Join [names] [F]**. Their actual previous lines remain
in the panel. Both residents stay present. Use the participant selector to
address a particular person, or begin your message with their name. Otherwise,
the two alternate replies. Type or use your microphone. Leaving releases both
residents to continue their activities.

## Voice settings

The collapsible menu contains **Character voices**, **Hear nearby conversations**
and **Voice volume**. Default ambient output is deliberately quiet. The default
gain is 70%; direct conversations are slightly clearer than overheard speech.
Settings are saved locally.

`game/voice_profiles.json` assigns stable profiles to all 53 residents and
Ansel. Profiles combine existing neural voice styles with pace and small pitch
differences; these are designed character voices rather than 54 separately
trained actors. The two younger characters have distinct youthful profiles.

NPC output stops while the player records to avoid recording the character's
reply through speakers. Headphones can improve recognition in a noisy room.

## Verified behaviour

- Actual local synthesis with distinct Duncan, Roslin and Ollie samples.
- Recorded speech correctly recognised; silence rejected.
- Native recording bus to transcription to editable message, without opening
  the real microphone during automated tests.
- Joined character AI generated replies with the prior discussion as context.
- Native audio capture confirmed quiet distance attenuation at 2, 8, 18 and
  30 metres; the last sample was silent.
- Text/microphone controls fit 1280×800 and 1280×720 windows.

The physical microphone and its Windows device settings still need the player's
first spoken interaction. Tests use an injected recording so they do not capture
unrequested room audio.

Implementation follows Godot's [microphone stream](https://docs.godotengine.org/en/stable/classes/class_audiostreammicrophone.html)
and capture-bus APIs. Runtime packages and licences are retained under
`tools/speech`, with model provenance in `models/whisper-tiny/SOURCES.json` and
existing Kokoro notices under `tts-notices`.
