#!/usr/bin/env python3
"""Check the accepted identity and other characters against the preceding release."""
from pathlib import Path
import hashlib,json,subprocess,plistlib
ROOT=Path(__file__).resolve().parents[3]
BASE='456483e'
BUNDLE=ROOT/'build/ChiikawaCompanion.app/Contents'
def digest(b): return hashlib.sha256(b).hexdigest()
def previous(p): return subprocess.check_output(['git','show',f'{BASE}:{p}'],cwd=ROOT)
resources=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'Sources/ChiikawaCompanion/Resources'],cwd=ROOT,text=True).splitlines()
retired={f'usagi-expression-{s}-v38.png' for s in ['laugh','attack','surprised','sleep','neutral']}
retained=[]; archived=[]
for p in resources:
 name=Path(p).name; expected=digest(previous(p)); bundled=BUNDLE/'Resources'/Path(p).relative_to('Sources/ChiikawaCompanion/Resources')
 if name in retired:
  saved=ROOT/'Source/UsagiIdentity-v44/Before'/name
  assert not (ROOT/p).exists() and not bundled.exists(),p
  assert digest(saved.read_bytes())==expected,name
  archived.append(name)
 else:
  assert digest((ROOT/p).read_bytes())==expected,p
  assert digest(bundled.read_bytes())==expected,str(bundled)
  retained.append(p)
unchanged=[];changed=[]
for friend in ['usagi','kurimanju','momonga']:
 for p in sorted((BUNDLE/'Resources/Roster'/friend).glob('*.png')):
  old=digest(previous(f'Source/Project/build/roster/{friend}/{p.name}'));new=digest(p.read_bytes())
  if friend!='usagi' or p.name.endswith('-24.png'):
   assert old==new,str(p);unchanged.append(friend+'/'+p.name)
  else:
   assert old!=new,str(p);changed.append(friend+'/'+p.name)
assert len(unchanged)==38 and len(changed)==8
approved='Source/Usagi-v38/Approval-v2/Generated/usagi-tpose-sheet-for-approval.png'
assert digest((ROOT/approved).read_bytes())==digest(previous(approved))
with (BUNDLE/'Info.plist').open('rb') as f:info=plistlib.load(f)
assert info['CFBundleShortVersionString']=='0.21.0' and info['CFBundleVersion']=='48'
for ref in json.loads((ROOT/'Source/UsagiIdentity-v44/References/Official/sources.json').read_text()):
 assert digest((ROOT/'Source/UsagiIdentity-v44/References/Official'/ref['path']).read_bytes())==ref['sha256']
report={'date':'2026-10-22','baseline':BASE,'app_version':'0.21.0','build':48,
 'approved_tpose_unchanged':True,'retained_resources_identical':len(retained),
 'unchanged_atlases':unchanged,'updated_usagi_actions':changed,'retired_full_body_expressions_archived':archived,
 'official_reference_hashes_verified':True}
Path(__file__).with_name('preservation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(f'PASS: approved T pose, {len(retained)} retained resources and {len(unchanged)} atlases unchanged; {len(changed)} Usagi actions updated; {len(archived)} old expression bodies archived.')
