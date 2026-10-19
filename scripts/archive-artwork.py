#!/usr/bin/env python3
"""Copy artwork into Source without discarding any previously archived version."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
from datetime import datetime, timezone

IMAGE_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.icns', '.avif',
                    '.heic', '.tiff', '.tif', '.bmp', '.ico', '.pdf'}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def preserve_copy(source, destination, archive, version_path):
    if destination.exists():
        old_hash = digest(destination)
        if old_hash == digest(source):
            return
        old = archive / 'Versions' / old_hash[:16] / version_path
        old.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(destination, old)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--generated-dir', type=Path)
    parser.add_argument('--latest', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    archive = root / 'Source'
    if args.generated_dir:
        for source in sorted(args.generated_dir.rglob('*')):
            if source.is_file() and source.suffix.lower() in IMAGE_EXTENSIONS:
                relative = source.relative_to(args.generated_dir)
                preserve_copy(source, archive / 'GeneratedOriginals' / relative,
                              archive, Path('GeneratedOriginals') / relative)
    for current, directories, names in os.walk(root):
        directories[:] = [d for d in directories if d not in {'.git', '.codex', '.claude', '.cursor'}
                           and not (Path(current) == root and d == 'Source')]
        for name in names:
            source = Path(current) / name
            if source.suffix.lower() not in IMAGE_EXTENSIONS or source.is_symlink():
                continue
            relative = source.relative_to(root)
            preserve_copy(source, archive / 'Project' / relative, archive, relative)

    manifest_path = archive / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    files = []
    for path in sorted(archive.rglob('*')):
        if not path.is_file() or path == manifest_path or path.name == '.DS_Store':
            continue
        relative = path.relative_to(archive)
        original = str(relative.relative_to('Project')) if relative.parts[0] == 'Project' else str(path.relative_to(root))
        files.append({'kind': 'image' if path.suffix.lower() in IMAGE_EXTENSIONS else 'supporting',
                      'source': original, 'archive_path': str(relative),
                      'bytes': path.stat().st_size, 'sha256': digest(path)})
    images = [entry for entry in files if entry['kind'] == 'image']
    manifest.update(updated_at=datetime.now(timezone.utc).isoformat(), latest_applied=args.latest,
                    image_file_count=len(images), unique_image_content_count=len({e['sha256'] for e in images}),
                    supporting_file_count=len(files) - len(images), image_bytes=sum(e['bytes'] for e in images), files=files)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    for entry in files:
        assert digest(archive / entry['archive_path']) == entry['sha256']
    print(f"Archived and verified {len(images)} image files, {len(files) - len(images)} supporting files.")

if __name__ == '__main__':
    main()
