"""Prepare four short public actor-demo reactions for click-only local playback."""
from pathlib import Path
import hashlib,json,subprocess

here=Path(__file__).resolve().parent
root=here.parents[2]
source=here/'kwon-daye-character-sample.mp3'
out=root/'Sources/ChiikawaCompanion/Resources/Voice'
source_url='https://www.dropbox.com/scl/fi/cbjg31uhssooksnrhjdwq/_7..mp3?rlkey=dqi1gjnrcbhnz6cmvqnj6bgc6&dl=1'
catalog={
    'speaker':'권다예',
    'sourceTitle':'권다예_7. [캐릭터 남아] 광기, 시끄러운, 마이웨이, 사차원 — 공개 성우 샘플',
    'sourceProfile':'https://honeyrainsound.tistory.com/6',
    'sourceURL':source_url,
    'captionPolicy':'Symbols describe app reactions; they are not literal transcripts. The provider identifies the actor and performance style, not an anime episode.',
    'clips':[],
}
for slug,caption,start,end in [('trill','…♪',0.02,1.00),('shout','…!!',1.02,2.80),('curious','…?',9.25,10.65),('cheer','…!',14.65,16.15)]:
    name=f'usagi-{slug}-v38.m4a';duration=end-start
    subprocess.run(['ffmpeg','-y','-v','error','-ss',str(start),'-t',str(duration),'-i',str(source),'-vn',
        '-af',f'afade=t=in:st=0:d=0.015,afade=t=out:st={duration-0.03}:d=0.03,loudnorm=I=-18:TP=-2:LRA=7',
        '-ar','44100','-ac','1','-c:a','aac','-b:a','128k',str(out/name)],check=True)
    actual=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(out/name)],text=True))
    catalog['clips'].append({'id':'usagi-'+slug,'text':caption,'file':name,'duration':actual,'sourceStart':start,'sourceEnd':end,
                             'sha256':hashlib.sha256((out/name).read_bytes()).hexdigest()})
for target in [out/'usagi-recordings-v38.json',here/'catalog.json']:
    target.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
(here/'provenance.json').write_text(json.dumps({
    'verified':'2026-10-22','provider':'HoneyrainSound, public actor sample page','page':catalog['sourceProfile'],
    'source_url':source_url,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
    'actor':'권다예','source_label':catalog['sourceTitle'],
    'role_source':'https://www.wikitree.co.kr/articles/1146571',
    'role_boundary':'The interview identifies Kwon Da-ye as Usagi. The audio provider labels a character demo rather than a named episode; this is credited as her public demo, not an authenticated episode extract.',
    'machine_transcript_is_authoritative':False,'synthesized':False,'voice_cloned':False,
    'runtime':'Bundled local excerpts; playback only from click or explicit preview.'
},ensure_ascii=False,indent=2)+'\n')
print('Prepared four real actor-demo excerpts; no synthesis or voice imitation.')
