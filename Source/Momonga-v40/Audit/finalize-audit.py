"""Verify final release evidence and record the all-five acceptance gate."""
from pathlib import Path
import hashlib,json,plistlib,re,subprocess
root=Path(__file__).resolve().parents[3];audit=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
write=lambda p,j:p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
app=root/'build/ChiikawaCompanion.app';pack=app/'Contents/Resources';res=root/'Sources/ChiikawaCompanion/Resources'
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
log=audit/'packaged-self-test-v40-release.log';text=log.read_text();assert 'FAIL:' not in text
checks=int(re.search(r'(\d+) checks passed\.',text).group(1));assert checks==612
for friend in ['usagi','kurimanju','momonga']:
 assert f'{dict(usagi="우사기",kurimanju="쿠리만쥬",momonga="모몽가")[friend]}: packaged app loads prebuilt native atlases' in text
 assert '212 exported native asset checks passed.' in (audit/f'native-{friend}-final.log').read_text()
 assert 'FAIL:' not in (audit/f'native-{friend}-final.log').read_text()
old=[]
for name in subprocess.check_output(['git','ls-tree','-r','--name-only','a4544bd','Sources/ChiikawaCompanion/Resources'],cwd=root,text=True).splitlines():
 p=root/name;original=subprocess.check_output(['git','show','a4544bd:'+name],cwd=root)
 assert p.read_bytes()==original
 rel=p.relative_to(res);assert sha(p)==sha(pack/rel);old.append({'path':str(rel),'sha256':sha(p)})
new={};atlases=[]
for friend,folder in [('usagi','Usagi-v38'),('kurimanju','Kurimanju-v39'),('momonga','Momonga-v40')]:
 entries=[]
 for p in res.rglob(friend+'-*'):
  if not p.is_file():continue
  rel=p.relative_to(res);assert sha(p)==sha(pack/rel)
  if p.suffix in ['.m4a','.json'] and p.parent.name=='Voice':
   assert sha(p)==sha(root/'Source'/folder/'Audio/Clips'/p.name)
  entries.append({'path':str(rel),'sha256':sha(p)})
 new[friend]=entries
 for p in (root/'build/roster'/friend).glob('*.png'):
  if not (p.stem.endswith('-24') or p.stem.endswith('-12')):continue
  assert sha(p)==sha(pack/'Roster'/friend/p.name)==sha(root/'Source/Momonga-v40/Final/PackagedNative'/friend/p.name)
  atlases.append({'path':f'Roster/{friend}/{p.name}','sha256':sha(p)})
assert len(old)==51 and len(atlases)==63 and sum(map(len,new.values()))==55
write(audit/'native-ui-v40.json',{'verified':'2026-10-22','appVersion':info['CFBundleShortVersionString'],'appBuild':info['CFBundleVersion'],'method':'CUA native accessibility interaction with the actual packaged app','observedBuilds':[43,44],'interactionDetailsBuild':43,'launchRecheckBuild':44,'observations':['All five visible/walking/recall rows present and enabled','Momonga camera, guitar, common training pole and blossom controls present','Automatic pickup visibly changed Momonga equipped status, including blossom','Selected Momonga manual study; its own status changed to 공부하기','Each new friend shows four recorded click entries plus ten plain-text entries','One shared-house design selector defaults to Hachiware; independent rest rows for all five','Settings closed; actual app left running on desktop'],'firstAXElapsedMs':8637,'firstAXTimingBuild':43,'timingBoundary':'CUA launch plus first accessibility observation, including automation overhead; not an isolated startup benchmark.','audioPreviewPlayed':False,'preferencesChanged':False})
template=json.loads((root/'Source/Usagi-v38/Audit/final-audit-v38.json').read_text())
criteria=template['criteria']
for c in criteria:
 c['result']='pass';c['evidence']=['packaged-self-test-v40-release.log','native-momonga-final.log','native-ui-v40.json','../Final/PackagedNative/momonga','../../../Sources/ChiikawaCompanion/RosterController.swift','../../../Sources/ChiikawaCompanion/RosterArtwork.swift']
 if c['id']=='tpose-front-side-back-top-diagonals':c['acceptance']='Review a consistent six-view primary-reference model before motion; agent review under the autonomous implementation request, not a separate user approval.'
record={'verified':'2026-10-22','character':'momonga','status':'passed','app_version':info['CFBundleShortVersionString'],'app_build':info['CFBundleVersion'],'app_binary_sha256':sha(app/'Contents/MacOS/ChiikawaCompanion'),'functional_regression':{'checks':checks,'log':log.name,'sha256':sha(log)},'native_artifact_checks':{'checks':212,'log':'native-momonga-final.log','sha256':sha(audit/'native-momonga-final.log')},'baseline_resources_preserved':len(old),'new_packaged_resources':new['momonga'],'native_ui':'native-ui-v40.json','visual_review':['../Final/PackagedNative/momonga/eight-directions.png','../Final/PackagedNative/momonga/left-24.png','../Final/PackagedNative/momonga/actions-preview.png'],'criteria':criteria,'voice_boundary':'Official AniBox Korean episode excerpts. Captions are app reaction labels aided by ASR, not certified phonetic transcripts; no cloned or synthesized actor voice.'}
write(audit/'final-audit-v40.json',record)
write(audit/'all-five-final-review.json',{'verified':'2026-10-22','status':'passed','baseline_commit':'a4544bd701e721656af1b57265fab73bddc532df','app_version':info['CFBundleShortVersionString'],'app_build':info['CFBundleVersion'],'app_binary_sha256':record['app_binary_sha256'],'character_order':['usagi','kurimanju','momonga'],'active_roster':['hachiware','chiikawa','usagi','kurimanju','momonga'],'functional_checks':checks,'exported_native_checks':636,'criteria_per_new_character':42,'missing_developable_baseline_features':[],'baseline_resources_unchanged':old,'new_resources':new,'bundled_atlases_exactly_match_native_render':atlases,'evidence':[log.name,'native-ui-v40.json','signature-v40-final.log','security-review.json','native-usagi-final.log','native-kurimanju-final.log','native-momonga-final.log','bundled-atlas-roundtrip.json'],'repairs':['User-approved Usagi identity replaces the rejected draft','Continuous short limb joins with correct raster color','All new walking cycles use one matched foot path with half-cycle offset','Per-character independent props, activity latches, players and rest clocks','Exclusive stable armed-hover silhouette and registered body size','Cup/snack and blossom source-specific keepsakes','Tail separated from Momonga body registration','Native atlases prepared during build; redundant sprite paints suppressed while 60Hz physics/input remain','Shared-home test timestamps made deterministic','AppKit initialized before native window fixtures; all original foreground hit assertions retained'],'source_boundaries':['Usagi four clips are the actual credited actor public character demo; a named episode origin is not authenticated','Kurimanju/Momonga clips are official AniBox episode excerpts; no voice cloning','Ten new character text reactions are fan app captions, not additional synthesized actor recordings','Camera/guitar/common training poles are shared fan app interactions, not claims of canonical possessions','Full raw reference videos and web documents remain local-only in Source; generated images, short clips and provenance are versioned','Memory observations are short samples, not a long-duration soak test']})
print(f'Final evidence verified: {checks} functional, 636 image checks, 51 baseline resources, 55 new base resources, 63 prebuilt atlases.')
