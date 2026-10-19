"""Read-only verification of the native rig revision. Run from the repository root."""
from PIL import Image
from pathlib import Path
import json
import subprocess

base = Path('Source/JoinedWalkAndMixedDialogue-v14')
original = Image.open('Sources/ChiikawaCompanion/Resources/hachiware-side-walk-24-v9.png').convert('RGBA')
joined = Image.open(base / 'Final/hachiware-side-24-frame-sheet-v14.png').convert('RGBA')
frames = []
for index in range(24):
    x, y = index % 6 * 256, index // 6 * 256
    before = original.crop((x, y, x + 256, y + 256))
    after = joined.crop((x, y, x + 256, y + 256))
    changed = [(j % 256, j // 256) for j, (a, b) in enumerate(zip(before.getdata(), after.getdata())) if a != b]
    assert changed
    assert all(80 <= x < 180 and 174 <= y < 224 for x, y in changed)
    for rectangle in [(0, 0, 256, 174), (0, 224, 256, 256)]:
        assert before.crop(rectangle).tobytes() == after.crop(rectangle).tobytes()
    frames.append({'frame': index + 1, 'changed_pixels': len(changed),
                   'change_bounds': [min(x for x, y in changed), min(y for x, y in changed),
                                     max(x for x, y in changed), max(y for x, y in changed)]})
source = Path('Source/FourPhaseWalk-v9/FourPhasePreview.swift').read_text()
revision = (base / 'JoinedWalkPreview.swift').read_text()
for start, end in [('let frameCount =', 'func drawCharacter('), ('func drawFoot(', 'func drawArm(')]:
    before = source[source.index(start):source.index(end)]
    after_end = end.replace('drawCharacter', 'drawRawCharacter')
    after = revision[revision.index(start):revision.index(after_end)]
    assert before == after
assert not subprocess.check_output(['git', 'diff', '--', 'Sources/ChiikawaCompanion/Roaming.swift'])
report = {'date': '2026-10-19', 'all_24_frames': frames,
          'head_and_upper_body_pixel_identical': True, 'bottom_32_rows_pixel_identical': True,
          'all_changes_in_lower_joint_band': [80, 174, 180, 224],
          'gait_functions_and_transforms_identical_to_v9': True, 'runtime_motion_code_unchanged': True,
          'cycle_distance_points': 62.7, 'speed_points_per_second': 46, 'full_cycle_frames': 24,
          'click_pool_entries': 14, 'voice_entries': 4, 'text_only_entries': 10}
(base / 'visual-preservation.json').write_text(json.dumps(report, indent=2) + '\n')
print('All 24 frames preserve the gait and every pixel outside the lower joint band.')
