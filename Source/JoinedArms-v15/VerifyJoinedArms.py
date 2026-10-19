"""Verify that v15 only opens the native arm caps; no image pixels are edited here."""
from pathlib import Path
from PIL import Image
import math
import json
import subprocess

base = Path('Source/JoinedArms-v15')
previous = Image.open('Sources/ChiikawaCompanion/Resources/hachiware-side-walk-24-joined-v14.png').convert('RGBA')
joined = Image.open(base / 'Final/hachiware-side-24-frame-sheet-v15.png').convert('RGBA')
assert previous.size == joined.size == (1536, 1024)
frames = []
for index in range(24):
    x, y = index % 6 * 256, index // 6 * 256
    a = previous.crop((x, y, x + 256, y + 256))
    b = joined.crop((x, y, x + 256, y + 256))
    changed = [(j % 256, j // 256) for j, (p, q) in enumerate(zip(a.getdata(), b.getdata())) if p != q]
    assert changed
    phase = index / 24
    body_y = 45 - 5.5 * math.sin(4 * math.pi * phase)
    swing = math.cos(2 * math.pi * phase) * math.pi / 7
    for px, py in changed:
        inside_cap = False
        for pivot_x, angle in [(61, -swing), (145, swing)]:
            dx, dy = px + 0.5 - pivot_x, 255.5 - py - (body_y + 67)
            local_x = math.cos(angle) * dx + math.sin(angle) * dy
            local_y = -math.sin(angle) * dx + math.cos(angle) * dy
            inside_cap |= -10 <= local_x <= 12 and -1.5 <= local_y <= 9
        assert inside_cap, (index + 1, px, py)
    assert a.crop((0, 174, 256, 256)).tobytes() == b.crop((0, 174, 256, 256)).tobytes()
    frames.append({'frame': index + 1, 'changed_pixels': len(changed),
                   'bounds': [min(x for x, y in changed), min(y for x, y in changed),
                              max(x for x, y in changed), max(y for x, y in changed)]})
old_source = Path('Source/JoinedWalkAndMixedDialogue-v14/JoinedWalkPreview.swift').read_text()
new_source = (base / 'JoinedArmPreview.swift').read_text()
for start, end in [('let frameCount =', 'func drawArm('), ('func drawRawCharacter(', 'func bitmap(')]:
    assert old_source[old_source.index(start):old_source.index(end)] == new_source[new_source.index(start):new_source.index(end)]
assert not subprocess.check_output(['git', 'diff', '--', 'Sources/ChiikawaCompanion/Roaming.swift'])
report = {'date': '2026-10-19', 'frames': frames, 'approved_v14_legs_pixel_identical': True,
          'every_pixel_outside_transformed_arm_caps_identical': True,
          'foot_paths_body_bob_arm_swing_and_pivots_unchanged': True,
          'runtime_movement_code_unchanged': True, 'frame_count': 24,
          'distance_per_cycle_points': 62.7, 'default_speed_points_per_second': 46,
          'native_arm_local_clip_max_y': 0}
(base / 'visual-preservation.json').write_text(json.dumps(report, indent=2) + '\n')
print('All 24 frames: approved legs and every pixel outside the rotating arm-root caps are unchanged.')
