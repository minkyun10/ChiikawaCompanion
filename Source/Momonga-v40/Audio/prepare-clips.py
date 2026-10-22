"""Short official-source click reactions; original videos/ASR remain local-only."""
from pathlib import Path
import json,hashlib,subprocess
here=Path(__file__).resolve().parent;root=here.parents[2];out=root/'Sources/ChiikawaCompanion/Resources/Voice'
sources={'157':{'url':'https://www.youtube.com/watch?v=d5_Z8cvOHo8','file':'episode-157.mkv'},'25':{'url':'https://www.youtube.com/watch?v=x-OxpDicqKo','file':'episode-25.mkv'}}
clips=[('cute','귀엽겠지?','157',3.0,7.35),('look','날 봐!','157',8.35,9.75),('praise','날 보고 칭찬해라!','157',24.05,25.8),('wait','오래 기다렸지?','25',53.58,56.05)]
catalog={'speaker':'미소','sourceTitle':'애니박스 공식 먼작귀 25화·157화 — 모몽가(하늘다람쥐)','sourceProfile':'https://www.youtube.com/channel/UCBTSkFNWmoOkBeZwANcbiIA','captionPolicy':'Brief app reaction captions based on local ASR timing; not a certified verbatim transcript.','clips':[]}
for slug,text,ep,start,end in clips:
 name=f'momonga-{slug}-v38.m4a';duration=end-start
 subprocess.run(['ffmpeg','-y','-v','error','-ss',str(start),'-t',str(duration),'-i',str(here/'Originals'/sources[ep]['file']),'-vn','-af',f'afade=t=in:st=0:d=0.015,afade=t=out:st={duration-.03}:d=0.03,loudnorm=I=-18:TP=-2:LRA=7','-ar','44100','-ac','1','-c:a','aac','-b:a','128k',str(out/name)],check=True)
 actual=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(out/name)],text=True))
 catalog['clips'].append({'id':'momonga-'+slug,'text':text,'file':name,'duration':actual,'sourceURL':sources[ep]['url'],'sourceStart':start,'sourceEnd':end,'sha256':hashlib.sha256((out/name).read_bytes()).hexdigest()})
for p in [here/'catalog.json',out/'momonga-recordings-v38.json']:p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
provenance={'verified':'2026-10-22','actor':'미소','actorPrimaryProfile':'https://studiomonkey.co.kr/actor_profile?name=%EB%AF%B8%EC%86%8C','actorRoleEvidence':'Primary actor profile lists 먼작귀 - 하늘다람쥐. No unrelated actor demo used.','sources':[],'selectionEvidence':['ReviewFrames/episode-157-contact.png','ReviewFrames/mouth-157-7-11.png','ReviewFrames/mouth-157-23-27.png','ReviewFrames/mouth-25-52-57.png'],'verificationMethod':'Official uploader metadata, scene identity and visible mouth timing, with local ASR as a timing aid. No listening-based phonetic certification claimed.','synthesized':False,'voiceCloned':False,'runtime':'Four bundled local clips played only on click or explicit preview; background soundtrack in original mix may remain.','originals':'Full videos and complete ASR remain local-only in Audio/Originals; only short selected clips and curated provenance are versioned.'}
for ep,src in sources.items():
 j=json.loads((here/'Originals'/f'episode-{ep}.info.json').read_text());assert j['channel_id']=='UCBTSkFNWmoOkBeZwANcbiIA'
 provenance['sources'].append({**src,'episode':ep,'title':j['title'],'channel':j['channel'],'channelURL':j['channel_url'],'sha256':hashlib.sha256((here/'Originals'/src['file']).read_bytes()).hexdigest()})
(here/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
print('Prepared four official-source Momonga click reactions.')
