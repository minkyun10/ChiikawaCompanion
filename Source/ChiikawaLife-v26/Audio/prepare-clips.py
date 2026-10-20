#!/usr/bin/env python3
"""Cut four original nonverbal reactions. No synthesis or voice imitation."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

here = Path(__file__).resolve().parent
root = here.parents[2]
source = here / 'Originals/chiikawa-jooeun-sample.webm'
catalog = {
    'speaker': '이주은',
    'sourceTitle': '[성우 이주은] 캐릭터 - 겁많고 소심한 햄스터💗 (치이카와)',
    'sourceProfile': 'https://www.youtube.com/@jooeun_2',
    'sourceURL': 'https://www.youtube.com/watch?v=V0IPf4ENMJs',
    'captionPolicy': 'Bubble punctuation expresses the app reaction; it is not a verbatim transcription.',
    'clips': [
        {'id': 'chiikawa-surprise', 'text': '…!', 'file': 'chiikawa-surprise-v26.m4a', 'sourceStart': 0.38, 'sourceEnd': 1.94},
        {'id': 'chiikawa-cry', 'text': '…', 'file': 'chiikawa-cry-v26.m4a', 'sourceStart': 15.18, 'sourceEnd': 17.50},
        {'id': 'chiikawa-effort', 'text': '…!!', 'file': 'chiikawa-effort-v26.m4a', 'sourceStart': 20.32, 'sourceEnd': 22.24},
        {'id': 'chiikawa-happy', 'text': '…♡', 'file': 'chiikawa-happy-v26.m4a', 'sourceStart': 26.92, 'sourceEnd': 28.70},
    ],
}
clips_dir = here / 'Clips'
clips_dir.mkdir(exist_ok=True)
resources = root / 'Sources/ChiikawaCompanion/Resources/Voice'
assert resources.is_dir(), resources
validation = []
for clip in catalog['clips']:
    length = clip['sourceEnd'] - clip['sourceStart']
    target = clips_dir / clip['file']
    filters = f'highpass=f=65,loudnorm=I=-20:TP=-2:LRA=9,afade=t=in:d=0.012,afade=t=out:st={length-0.04}:d=0.04'
    subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-y', '-ss', str(clip['sourceStart']), '-i', str(source),
                    '-t', str(length), '-vn', '-af', filters, '-ar', '44100', '-ac', '1', '-c:a', 'aac', '-b:a', '128k',
                    '-movflags', '+faststart', str(target)], check=True)
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'quiet', '-show_entries', 'format=duration', '-of', 'json', str(target)]))
    clip['duration'] = float(probe['format']['duration'])
    assert abs(clip['duration'] - length) < 0.08
    stats = subprocess.run(['ffmpeg', '-nostdin', '-v', 'info', '-i', str(target), '-af', 'volumedetect', '-f', 'null', '-'], capture_output=True, text=True, check=True)
    validation.append({'id': clip['id'], 'duration': clip['duration'], 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                       'volume': [s.strip() for s in stats.stderr.splitlines() if 'mean_volume:' in s or 'max_volume:' in s]})
    shutil.copy2(target, resources / clip['file'])
(here / 'catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n')
shutil.copy2(here/'catalog.json', resources/'chiikawa-recordings-v26.json')
(here / 'validation.json').write_text(json.dumps(validation, ensure_ascii=False, indent=2)+'\n')
(here / 'provenance.json').write_text(json.dumps({
    'verified': '2026-10-20', 'speaker': '이주은', 'role': '치이카와', 'sourceURL': catalog['sourceURL'],
    'sourceSHA256': hashlib.sha256(source.read_bytes()).hexdigest(), 'sourceBytes': source.stat().st_size,
    'method': 'Ordinary public YouTube download; no account cookies, credentials or private API keys',
    'use': 'User-authorized personal desktop companion; four short nonverbal excerpts',
    'synthesized': False, 'voice_cloned': False, 'machine_transcript_is_authoritative': False,
    'reaction_names': 'App performance mapping; emotional labels are interpretation, not source transcript',
    'background_audio': 'No source separation performed; any original ambience remains in excerpts',
}, ensure_ascii=False, indent=2)+'\n')
print('Prepared and checked four original Korean Chiikawa reaction clips.')
