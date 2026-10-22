#!/usr/bin/env python3
"""Verify the exclusivity correction against the preceding accepted release."""
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess

ROOT = Path(__file__).resolve().parents[3]
BASE = 'f4fd4434c654dc7dac817d4a08d6dd97d5bea4d9'
BUNDLE = ROOT / 'build/ChiikawaCompanion.app/Contents'
FRIENDS = ('usagi', 'kurimanju', 'momonga')
RETIRED = ('guitar-12.png', 'vomit-12.png', 'study-12.png', 'eat-12.png', 'camera-12.png')


def previous(path):
    return subprocess.check_output(['git', 'show', f'{BASE}:{path}'], cwd=ROOT)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    atlas_checks = []
    archived_checks = []
    for friend in FRIENDS:
        runtime = BUNDLE / 'Resources/Roster' / friend
        atlases = sorted(runtime.glob('*.png'))
        assert len(atlases) == (16 if friend == 'usagi' else 15), (friend, len(atlases))
        for atlas in atlases:
            baseline = f'Source/Project/build/roster/{friend}/{atlas.name}'
            expected = digest(previous(baseline))
            assert digest(atlas.read_bytes()) == expected, str(atlas)
            atlas_checks.append({'friend': friend, 'atlas': atlas.name, 'sha256': expected})
        for name in RETIRED + (() if friend == 'usagi' else ('attack-12.png',)):
            assert not (runtime / name).exists(), (friend, name)
            assert not (ROOT / 'build/roster' / friend / name).exists(), (friend, name)
            archived = Path(f'Source/Momonga-v40/Final/PackagedNative/{friend}/{name}')
            expected = digest(previous(archived))
            assert digest((ROOT / archived).read_bytes()) == expected, str(archived)
            archived_checks.append({'path': str(archived), 'sha256': expected})

    resources = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', BASE,
        'Sources/ChiikawaCompanion/Resources'], cwd=ROOT, text=True).splitlines()
    removed_resources = {f'{friend}-expression-attack-v38.png' for friend in ('kurimanju', 'momonga')}
    retained_resources = []
    for resource in resources:
        expected = digest(previous(resource))
        bundled_resource = BUNDLE / 'Resources' / Path(resource).relative_to('Sources/ChiikawaCompanion/Resources')
        if Path(resource).name in removed_resources:
            assert not (ROOT / resource).exists(), resource
            assert not bundled_resource.exists(), resource
            archived = Path('Source/Project') / resource
            assert digest((ROOT / archived).read_bytes()) == expected, str(archived)
            archived_checks.append({'path': str(archived), 'sha256': expected})
        else:
            assert digest((ROOT / resource).read_bytes()) == expected, resource
            assert digest(bundled_resource.read_bytes()) == expected, resource
            retained_resources.append(resource)

    with (BUNDLE / 'Info.plist').open('rb') as source:
        info = plistlib.load(source)
    assert info['CFBundleShortVersionString'] == '0.20.4' and info['CFBundleVersion'] == '47'
    report = {'date': '2026-10-22', 'app_version': '0.20.4', 'build': 47,
        'baseline_commit': BASE, 'retained_atlases_identical': len(atlas_checks),
        'source_resources_identical': len(retained_resources), 'retired_artwork_archived': archived_checks,
        'retired_atlases_in_runtime': 0, 'atlas_checks': atlas_checks}
    output = Path(__file__).with_name('preservation.json')
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f'PASS: {len(atlas_checks)} retained atlases and {len(retained_resources)} resources unchanged; '
          f'{len(archived_checks)} retired artwork files preserved in Source and excluded from runtime.')


if __name__ == '__main__':
    main()
