"""Loopback-only, cached neural speech for Alderwick; no network model calls."""
import argparse, ctypes, hashlib, io, json, os, pathlib, sys, threading, time, wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
sys.path.insert(0,str(ROOT/'python-packages'))
sys.path.insert(0,str(ROOT/'kokoro-packages'))
os.environ['HF_HUB_OFFLINE']='1'
os.environ['ORT_LOG_SEVERITY_LEVEL']='3'
DLLS=[]
if os.name=='nt':
    for folder in [ROOT/'native',ROOT/'python-packages/onnxruntime/capi']:
        if folder.exists():DLLS.append(os.add_dll_directory(str(folder)))
    if (ROOT/'native/MSVCP140.dll').exists():ctypes.WinDLL(str(ROOT/'native/MSVCP140.dll'))
ENGINE=None
LOCK=threading.Lock()
CACHE=ROOT/'cache'
CACHE.mkdir(exist_ok=True)
CLIENTS=set()
LAST_REQUEST=time.monotonic()
PROFILES=json.loads((ROOT.parent.parent/'game/voice_profiles.json').read_text(encoding='utf-8'))['profiles']
ENGLISH_VOICES={'bm_george','bm_daniel','bm_fable','bm_lewis','bf_emma','bf_alice','bf_isabella','bf_lily','am_michael','am_fenrir','am_puck','af_heart','af_bella','af_nicole','af_sky'}

def engine():
    global ENGINE
    if ENGINE is None:
        import onnxruntime as ort
        from kokoro_onnx import Kokoro
        options=ort.SessionOptions()
        options.intra_op_num_threads=2
        options.inter_op_num_threads=1
        options.log_severity_level=3
        session=ort.InferenceSession(str(ROOT/'models/kokoro-v1.0.onnx'),sess_options=options,providers=['CPUExecutionProvider'])
        ENGINE=Kokoro.from_session(session,str(ROOT/'models/voices-v1.0.bin'))
    return ENGINE

def synthesize(text,voice='bm_george',speed=1.0,character=None):
    import numpy as np
    text=' '.join(str(text).split())
    if not text or len(text)>650:raise ValueError('Speech turns must contain 1 to 650 characters')
    settings=PROFILES.get(character,{})
    voice=settings.get('voice',voice)
    secondary=settings.get('secondary',voice)
    blend=float(settings.get('mix',0))
    speed=float(settings.get('speed',speed))
    if voice not in ENGLISH_VOICES or secondary not in ENGLISH_VOICES:raise ValueError('Unknown voice')
    speed=max(.88,min(1.12,float(speed)))
    key=hashlib.sha256(json.dumps([text,voice,secondary,blend,round(speed,2)]).encode()).hexdigest()
    path=CACHE/(key+'.wav')
    with LOCK:
        if path.exists():return path.read_bytes()
        tts=engine()
        style=tts.voices[voice]*(1-blend)+tts.voices[secondary]*blend
        audio,rate=tts.create(text,voice=style,speed=speed,lang='en-gb' if voice.startswith('b') else 'en-us',sentence_pause=.21,clause_pause=.08)
        if len(audio)<100 or not np.isfinite(audio).all():raise ValueError('No usable speech')
        peak=float(np.max(np.abs(audio)))
        if peak>.92:audio=audio*(.92/peak)
        pcm=(np.clip(audio,-1,1)*32767).astype('<i2').tobytes()
        output=io.BytesIO()
        with wave.open(output,'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(rate)
            wav.writeframes(pcm)
        data=output.getvalue()
        path.write_bytes(data)
        return data

def alive(pid):
    if not pid:return False
    if os.name=='nt':
        kernel=ctypes.windll.kernel32
        kernel.OpenProcess.restype=ctypes.c_void_p
        kernel.WaitForSingleObject.argtypes=[ctypes.c_void_p,ctypes.c_ulong]
        kernel.CloseHandle.argtypes=[ctypes.c_void_p]
        handle=kernel.OpenProcess(0x100000,False,pid)
        if not handle:return False
        result=kernel.WaitForSingleObject(handle,0)
        kernel.CloseHandle(handle)
        return result==258
    return pathlib.Path('/proc',str(pid)).exists()

class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args):pass
    def send(self,status,data,kind='application/json'):
        self.send_response(status)
        self.send_header('Content-Type',kind)
        self.send_header('Content-Length',str(len(data)))
        self.end_headers()
        try:self.wfile.write(data)
        except (BrokenPipeError,ConnectionResetError):pass
    def do_GET(self):
        global LAST_REQUEST
        LAST_REQUEST=time.monotonic()
        if self.path.startswith('/health'):
            try:
                from urllib.parse import urlparse,parse_qs
                pid=int(parse_qs(urlparse(self.path).query).get('pid',['0'])[0])
                if pid:CLIENTS.add(pid)
            except (ValueError,TypeError):pass
            self.send(200,json.dumps({'ready':True,'engine':'Kokoro','offline':True,'recognition_ready':(ROOT/'models/whisper-tiny/model.bin').exists(),'voice_profiles':len(PROFILES),'features':['character_voices','transcribe']}).encode())
        else:self.send(404,b'{}')
    def do_POST(self):
        global LAST_REQUEST
        LAST_REQUEST=time.monotonic()
        origin=self.headers.get('Origin','')
        if origin and not origin.startswith('http://127.0.0.1:'):
            self.send(403,b'{}');return
        if self.path not in ['/speak','/transcribe']:self.send(404,b'{}');return
        try:
            size=int(self.headers.get('Content-Length','0'))
            if self.path=='/transcribe':
                if not 44<=size<=4500000:raise ValueError('Invalid audio size')
                from recognition import transcribe
                result=transcribe(self.rfile.read(size))
                self.send(200,json.dumps(result).encode());return
            if size<1 or size>8192:raise ValueError('Invalid request size')
            request=json.loads(self.rfile.read(size))
            pid=int(request.get('pid',0))
            if pid:CLIENTS.add(pid)
            audio=synthesize(request['text'],request.get('voice','bm_george'),request.get('speed',1.0),request.get('character'))
            self.send(200,audio,'audio/wav')
        except Exception as error:self.send(400,json.dumps({'error':str(error)}).encode())

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--port',type=int,default=34319)
    parser.add_argument('--sample',action='store_true')
    args=parser.parse_args()
    if args.sample:
        for voice,text in [('bm_george','The fresh vegetables have reached the market. I am returning to the farm for another crate.'),('bf_emma','I am keeping watch at the western gate. The merchants can pass while I check the road.')]:
            data=synthesize(text,voice)
            (ROOT/(voice+'-sample.wav')).write_bytes(data)
            print('NEURAL_VOICE_SAMPLE_OK',voice,len(data),flush=True)
        return
    server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
    def monitor():
        while True:
            time.sleep(10)
            if time.monotonic()-LAST_REQUEST>90 and not any(alive(pid) for pid in list(CLIENTS)):
                server.shutdown();return
    threading.Thread(target=monitor,daemon=True).start()
    # Serve microphone/health requests immediately. The first speech request
    # loads Kokoro under its synthesis lock rather than blocking every input
    # control behind a cold neural-model startup.
    print('ALDERWICK_NEURAL_SPEECH_READY lazy_tts=true',flush=True)
    server.serve_forever()

if __name__=='__main__':
    try:main()
    except Exception:
        import traceback
        with (ROOT/'runtime-error.log').open('a',encoding='utf-8') as log:traceback.print_exc(file=log)
        raise
