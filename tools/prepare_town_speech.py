"""Copy the installed offline voice runtime into this project's own folder."""
import pathlib, shutil

SOURCE=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Elleson-Studio\desktop-runtime\speech')
DEST=pathlib.Path(__file__).parent/'speech'
DEST.mkdir(exist_ok=True)
for folder in ['python','native','kokoro-packages','tts-notices']:
    shutil.copytree(SOURCE/folder,DEST/folder,dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
packages=DEST/'python-packages'
packages.mkdir(exist_ok=True)
for path in (SOURCE/'python-packages').iterdir():
    if path.name.lower().startswith(('numpy','onnxruntime','flatbuffers','packaging','protobuf','google','sympy','mpmath','coloredlogs','humanfriendly')):
        if path.is_dir():shutil.copytree(path,packages/path.name,dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
        else:shutil.copy2(path,packages/path.name)
models=DEST/'models'
models.mkdir(exist_ok=True)
for name in ['kokoro-v1.0.onnx','voices-v1.0.bin','SOURCES.json']:
    shutil.copy2(SOURCE/'models/kokoro'/name,models/name)
print('TOWN_NEURAL_SPEECH_RUNTIME_READY',flush=True)
