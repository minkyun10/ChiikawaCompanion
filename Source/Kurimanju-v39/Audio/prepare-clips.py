"""Cut four visually timed Kurimanju exhalations from official AniBox uploads."""
from pathlib import Path
import hashlib,json,subprocess
here=Path(__file__).resolve().parent
root=here.parents[2];out=root/'Sources/ChiikawaCompanion/Resources/Voice'
sources={'35':{'url':'https://www.youtube.com/watch?v=5dTRQblIt-Q','file':'episode-35.mkv'},
         '180':{'url':'https://www.youtube.com/watch?v=0RZqg7KMlfo','file':'episode-180.mkv'}}
catalog={'speaker':'원종준','sourceTitle':'애니박스 공식 먼작귀 35화·180화 — 쿠리만쥬의 짧은 반응',
         'sourceProfile':'https://www.youtube.com/@AniBox','clips':[],
         'captionPolicy':'Brief reaction captions, not a claimed word-for-word transcript of nonverbal exhalations.'}
for slug,text,ep,start,end in [('refresh','하아~','35',11.0,12.35),('satisfied','크하~','35',25.1,26.95),
                             ('relax','…♪','35',57.05,58.8),('oyster','…!','180',12.35,13.95)]:
 source=here/'Originals'/sources[ep]['file'];name=f'kurimanju-{slug}-v38.m4a';duration=end-start
 subprocess.run(['ffmpeg','-y','-v','error','-ss',str(start),'-t',str(duration),'-i',str(source),'-vn',
  '-af',f'afade=t=in:st=0:d=0.015,afade=t=out:st={duration-.03}:d=0.03,loudnorm=I=-18:TP=-2:LRA=7',
  '-ar','44100','-ac','1','-c:a','aac','-b:a','128k',str(out/name)],check=True)
 actual=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(out/name)],text=True))
 catalog['clips'].append({'id':'kurimanju-'+slug,'text':text,'file':name,'duration':actual,'sourceURL':sources[ep]['url'],
  'sourceStart':start,'sourceEnd':end,'sha256':hashlib.sha256((out/name).read_bytes()).hexdigest()})
for path in [here/'catalog.json',out/'kurimanju-recordings-v38.json']:
 path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
provenance={'verified':'2026-10-22','sources':[{**value,'episode':key,'sha256':hashlib.sha256((here/'Originals'/value['file']).read_bytes()).hexdigest()} for key,value in sources.items()],
 'selection_evidence':['ReviewFrames/mouth-35-9-15.png','ReviewFrames/mouth-35-22-28.png','ReviewFrames/mouth-35-54-60.png','ReviewFrames/mouth-180-7-13.png','ReviewFrames/waveform-timing.png'],
 'verification_method':'Official uploader/title metadata, visible Kurimanju mouth/exhalation timing and non-silent source signal. Automated speech transcription is not reliable for nonverbal sounds; no claim of a listening-based phonetic transcript.',
 'synthesized':False,'voice_cloned':False,'ending_theme_included_in_runtime_clips':False,
 'runtime':'Four short bundled local reactions; click or explicit preview only.',
 'original_archives':'Full public source videos remain local reference inputs in Source; Git stores short runtime excerpts, source links and timing evidence.'}
(here/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
print('Prepared four short official-source Kurimanju reactions.')
