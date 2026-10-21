"""Read-only PNG preservation and chronology checks for the two revised directions."""
from pathlib import Path
from PIL import Image, ImageChops, ImageOps
import hashlib
import json

root = Path(__file__).resolve().parent
checks = 0

def check(condition, message):
    global checks
    if not condition:
        raise AssertionError(message)
    checks += 1

def components(image):
    data = image.getchannel('A').tobytes()
    seen = bytearray(256 * 256)
    sizes = []
    for start, alpha in enumerate(data):
        if alpha <= 127 or seen[start]:
            continue
        queue = [start]
        seen[start] = 1
        for index in queue:
            x, y = index % 256, index // 256
            for xx, yy in ((x - 1,y),(x + 1,y),(x,y - 1),(x,y + 1)):
                if 0 <= xx < 256 and 0 <= yy < 256:
                    n = yy * 256 + xx
                    if not seen[n] and data[n] > 127:
                        seen[n] = 1
                        queue.append(n)
        sizes.append(len(queue))
    return [size for size in sizes if size > 20]

frames = {}
records = []
for direction in ['up-left', 'up-right']:
    old = Image.open(root / 'References' / f'chiikawa-{direction}-24.png').convert('RGBA')
    new = Image.open(root / 'Final/Atlases' / f'chiikawa-{direction}-24.png').convert('RGBA')
    check(new.size == (1536,1024), f'{direction}: same 6x4 cells')
    frames[direction] = []
    changes = []
    for index in range(24):
        x, y = index % 6 * 256, index // 6 * 256
        a, b = old.crop((x,y,x+256,y+256)), new.crop((x,y,x+256,y+256))
        frames[direction].append(b)
        check(a.crop((0,181,256,256)).tobytes() == b.crop((0,181,256,256)).tobytes(), f'{direction} {index+1}: every foot and lower-tail RGBA byte preserved')
        check(a.crop((0,0,256,115)).tobytes() == b.crop((0,0,256,115)).tobytes(), f'{direction} {index+1}: head preserved')
        center = (85,0,171,256) if direction == 'up-left' else (85,0,171,256)
        check(a.crop(center).tobytes() == b.crop(center).tobytes(), f'{direction} {index+1}: central torso preserved')
        diff = ImageChops.difference(a,b)
        box = diff.getbbox(alpha_only=False)
        check(box is not None and box[1] >= 115 and box[3] <= 181, f'{direction} {index+1}: only hand-height pixels change')
        check(len(components(b)) == 1, f'{direction} {index+1}: hands and feet remain connected to the body')
        saved = Image.open(root / 'Final/Frames' / f'{direction}-{index+1:02}.png').convert('RGBA')
        check(saved.tobytes() == b.tobytes(), f'{direction} {index+1}: chronological exported frame matches atlas')
        count = sum(aa != bb for aa,bb in zip(a.getdata(),b.getdata()))
        changes.append({'frame':index + 1,'changedPixels':count,'boundsTopLeft':list(box)})
    check(len({hashlib.sha256(im.tobytes()).hexdigest() for im in frames[direction]}) == 24, f'{direction}: 24 distinct frames')
    records.append({'direction':direction,'frames':changes})
for index in range(24):
    check(ImageOps.mirror(frames['up-left'][index]).tobytes() == frames['up-right'][index].tobytes(), f'{index+1}: right is exact mirror of completed left')
for name in ['hand-comparison-v37.gif','hand-comparison-slow-v37.gif']:
    gif = Image.open(root / 'Final' / name)
    check(gif.n_frames == 24, f'{name}: 24 frames')
    duration = 0
    for index in range(gif.n_frames):
        gif.seek(index)
        duration += gif.info['duration']
    check(duration == (2880 if 'slow' in name else 1360), f'{name}: unchanged cycle timing')
report = {'verified':'2026-10-21','checksPassed':checks,'feetRgbaExactAll48Frames':True,
          'headRgbaExactAll48Frames':True,'centralTorsoRgbaExactAll48Frames':True,
          'rightIsExactMirror':True,'directions':records}
(root / 'asset-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(f'{checks} asset checks passed; all 48 foot regions byte-identical.')
