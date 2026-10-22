"""Local-only ASR timing aid, limited to the episode before the ending theme."""
from pathlib import Path
import json,subprocess
import mlx_whisper
root=Path(__file__).resolve().parent
for ep in ['25','157']:
 original=root/'Originals'/f'episode-{ep}.mkv';wav=original.with_suffix('.wav')
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(original),'-t','60','-vn','-ar','16000','-ac','1',str(wav)],check=True)
 result=mlx_whisper.transcribe(str(wav),path_or_hf_repo='mlx-community/whisper-small-mlx',language='ko',word_timestamps=True,verbose=False)
 (root/'Originals'/f'transcript-{ep}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 print('Saved local timing aid for',ep,flush=True)
