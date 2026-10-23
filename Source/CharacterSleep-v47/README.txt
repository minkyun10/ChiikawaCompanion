Character-specific sleeping artwork v47 — 2026-10-23

Built-in image_gen. Prompts/, References/, Generated/ retain the production inputs and every draft.
Final/ contains selected original sleeping illustrations. Review/ contains actual native sprite and shared-house previews.
Before/ retains the replaced six sleep atlases for comparison. Approved walking, attack, item and original Hachiware/Chiikawa sleep artwork stay intact.

Character identity: approved project T-pose/rig references. Hachiware sleep is the bedding and line-quality reference only.
One shared house, same fixed desktop position and entry/sleep/wake behavior. No new items or automatic audio.

Applied: v0.24.0 / build 51. Six 12-frame sleep atlases, 3.6-second breathing loop.
The fixed alpha-union viewport fills each bed using the actual illustration, with margins for the maximum inhale.
Decoded atlas pixels are reused. Large new originals are only loaded by the offline renderer or explicit self-test.

Review/sleep-characters-v47.png — six new sleeping designs rendered by the packaged app.
Review/sleep-breathing-v47.gif — quiet breathing loop.
Review/sleep-individual-homes-v47.png — six separate previews at the actual 360x214 house size.
Review/sleep-shared-homes-v47.png — both shared-house skins with all eight occupants, enlarged and actual size.
Final/Native/*/sleep-12.png — final packaged atlas sheets.

Validation: 855 self-test checks passed, including 45 sleep-source/loop/viewport/1x/Retina checks.
Audit/art-preservation.json: of 223 existing bundle resources, only the six intended sleep atlases changed.
Audit/visual-review.txt: character identity and composition observations.
All six prompts use the built-in image_gen tool with approved project character references; no new web references required.

Eight-companion performance recheck: 10-second active scene, 59.89 Hz app callbacks, 29.12% of one CPU core, 0.167% callbacks over 25 ms. This is not compositor-present FPS and does not establish zero dropped frames.
