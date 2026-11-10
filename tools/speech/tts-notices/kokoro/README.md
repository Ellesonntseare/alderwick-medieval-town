# Optional Kokoro offline voices

Kokoro-82M model: Apache-2.0, https://huggingface.co/hexgrad/Kokoro-82M . ONNX runtime wrapper kokoro-onnx0.6.1: MIT, https://github.com/thewh1teagle/kokoro-onnx . Pinned ONNX and style files: model-files-v1.0 release. Local sizes and SHA-256 are in speech/models/kokoro/SOURCES.json.

Phonemizer3.4.0 and eSpeak NG1.52.0: GPL-3.0. eSpeak1.52.0 was queried from the installed DLL. Licenses are retained here and in kokoro-packages distribution metadata. Corresponding sources: https://github.com/espeak-ng/espeak-ng/tree/1.52.0 , https://pypi.org/project/phonemizer/3.4.0/ , https://github.com/thewh1teagle/espeakng-loader . Source archives are retained alongside this notice when downloaded. Preserve notices and source availability for any later distribution.

Generation uses local CPU inference. Narrator/Bright/Gentle/Serious delivery adjusts neural pace and pause timing, and does not add trained emotional acting. Existing Piper voice defaults are unchanged.
