from pathlib import Path
import subprocess,hashlib,json
root=Path(__file__).resolve().parents[3]
bundle=root/'build/ChiikawaCompanion.app/Contents/Resources'
def sha(data): return hashlib.sha256(data).hexdigest()
retained=[]
for name in subprocess.check_output(['git','ls-tree','-r','--name-only','2c7c7e6','Sources/ChiikawaCompanion/Resources'],cwd=root,text=True).splitlines():
 old=subprocess.check_output(['git','show','2c7c7e6:'+name],cwd=root)
 assert sha((root/name).read_bytes()) == sha(old),name
 relative=Path(name).relative_to('Sources/ChiikawaCompanion/Resources')
 assert sha((bundle/relative).read_bytes()) == sha(old),str(relative)
 retained.append(name)
atlases=[]
for friend in ['usagi','kurimanju','momonga']:
 for p in (root/'build/roster'/friend).glob('*.png'):
  if not p.stem.endswith(('-24','-12')):continue
  old=root/'Source/Project/build/roster'/friend/p.name
  assert old.exists() and sha(old.read_bytes())==sha(p.read_bytes()),str(p)
  atlases.append(str(p.relative_to(root)))
new={}
for friend in ['rakko','shisa','kani']:
 p=bundle/'Roster'/friend
 files=sorted(f.name for f in p.glob('*.png'))
 assert len(files)==15 and 'attack-12.png' not in files,(friend,files)
 new[friend]=files
result=dict(base='2c7c7e6',existingResourcesIdentical=len(retained),existingExpansionAtlasesIdentical=len(atlases),newAtlases=new)
(root/'Source/NewFriends-v45/Audit/preservation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='newAtlases'}))
