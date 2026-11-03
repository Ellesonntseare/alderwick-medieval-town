# Local character voices

Character speech uses a separate local copy of the Kokoro-82M ONNX speech runtime that was already installed for Elleson Studio. The Studio installation and saved projects are unchanged. The town's runtime, model, voice data, cache, and retained notices are under `tools/speech`.

- Kokoro-82M model and voice data: https://huggingface.co/hexgrad/Kokoro-82M
- Kokoro ONNX wrapper: https://github.com/thewh1teagle/kokoro-onnx
- ONNX Runtime: https://github.com/microsoft/onnxruntime
- Phonemizer and eSpeak NG notices, model card, voice information, and source references: `tools/speech/tts-notices/kokoro` and package distribution metadata.
- Python runtime notice: `tools/speech/python/LICENSE.txt`.
- Model file provenance and checksums: `tools/speech/models/SOURCES.json`.

Eight consistent English voice profiles are assigned across residents: George, Daniel, Fable, Lewis, Emma, Alice, Isabella, and Lily. These are model voice profiles, not cloned voices supplied by the user. Dialogue is synthesized locally on the CPU; requests stay on the loopback interface, and generated turns are cached locally. Godot plays the mono speech from the character's position with distance attenuation.
