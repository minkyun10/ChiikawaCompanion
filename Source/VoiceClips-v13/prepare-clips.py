#!/usr/bin/env python3
"""Rebuild the four spoken excerpts from the original locally supplied reference."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path, help='Original character sample MP3')
parser.add_argument('--write-resources', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parent
catalog = json.loads((root / 'catalog.json').read_text())
for line in catalog['clips']:
    duration = line['sourceEnd'] - line['sourceStart']
    target = root / 'Clips' / line['file']
    target.parent.mkdir(parents=True, exist_ok=True)
    filters = ('highpass=f=65,loudnorm=I=-18:TP=-1.5:LRA=11,'
               f'afade=t=in:d=0.008,afade=t=out:st={duration - 0.035}:d=0.035')
    subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-y', '-ss', str(line['sourceStart']),
                    '-i', str(args.source), '-t', str(duration), '-vn', '-af', filters,
                    '-ar', '44100', '-ac', '1', '-c:a', 'aac', '-b:a', '128k',
                    '-movflags', '+faststart', str(target)], check=True)
    if args.write_resources:
        resources = root.parents[1] / 'Sources/ChiikawaCompanion/Resources/Voice'
        resources.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, resources / line['file'])
if args.write_resources:
    shutil.copy2(root / 'catalog.json', resources / 'hachiware-recordings-v13.json')
