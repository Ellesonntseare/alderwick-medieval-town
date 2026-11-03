"""Short, local microphone transcription. Audio stays in memory."""
import io, os, pathlib, sys, threading, wave
ROOT=pathlib.Path(__file__).resolve().parent
sys.path.append(str(ROOT/'recognition-packages'))
MODEL=None
LOCK=threading.Lock()

def transcribe(data):
    import numpy as np
    with wave.open(io.BytesIO(data),'rb') as wav:
        if wav.getsampwidth()!=2 or wav.getnchannels() not in [1,2]:
            raise ValueError('Expected mono/stereo 16-bit PCM audio')
        rate=wav.getframerate()
        if not 8000<=rate<=96000 or wav.getnframes()>rate*22:
            raise ValueError('Record a message shorter than 20 seconds')
        audio=np.frombuffer(wav.readframes(wav.getnframes()),dtype='<i2').astype(np.float32)/32768.0
        if wav.getnchannels()==2:audio=audio.reshape(-1,2).mean(axis=1)
    if len(audio)<rate*.3 or float(np.sqrt(np.mean(audio*audio)))<.001:
        return {'text':'','heard_speech':False,'offline':True}
    if rate!=16000:
        audio=np.interp(np.arange(round(len(audio)*16000/rate))*rate/16000,np.arange(len(audio)),audio).astype(np.float32)
    global MODEL
    with LOCK:
        if MODEL is None:
            from faster_whisper import WhisperModel
            MODEL=WhisperModel(str(ROOT/'models/whisper-tiny'),device='cpu',compute_type='int8',cpu_threads=2,local_files_only=True)
        segments,_=MODEL.transcribe(audio,language='en',beam_size=4,vad_filter=True,condition_on_previous_text=False,
                                    initial_prompt='Alderwick village. Gareth, Duncan, Selene, Ivor, Roslin, Fenn. Market, gardens, supplies.')
        text=' '.join(segment.text.strip() for segment in segments).strip()[:1000]
    return {'text':text,'heard_speech':bool(text),'offline':True}
