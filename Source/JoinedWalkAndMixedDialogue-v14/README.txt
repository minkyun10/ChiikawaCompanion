Hachiware joined side walk and mixed click dialogue — v14
Date: 2026-10-19
App version: 0.9.1 (18)

Changes
- Side walking keeps the approved v9 foot assets, position/rotation transforms, 24-frame
  chronology, 12-frame half-cycle offset, body bob, 62.7 pt stride and 46 pt/s travel speed.
- The editable native rig adds short connections behind the body. Only interior contours
  inside the lower leg-root union are cleared. Existing foot-end outlines remain visible.
- Right walking mirrors the same completed left frames. No other direction was replaced.
- The separate white oval paw overlays on equipped camera/guitar/sasumata were removed.
- Clicking selects from one equal-weight list of fourteen entries: four recorded lines and
  the user's original ten quotes. The immediately previous line is excluded on the next click.
- Only the four recorded entries play matching audio; the ten quotes display text.
  Mute, volume, explicit voice preview and notification priority remain available.
  The obsolete voice/text mode preference is removed without changing other settings.

Artwork
Final contains the registered 6x4 transparent sheet, all 48 left/right frames,
24-frame chronological review, keyposes and normal/slow animated previews.
JoinedWalkPreview.swift edits the established native rig instead of regenerating poses.
No new image-generation model output was needed. All intermediate attempts are in Iterations.
Review includes native application renders and final Mac settings verification.

Reproduce from the repository root
  swift Source/JoinedWalkAndMixedDialogue-v14/JoinedWalkPreview.swift Source/FourPhaseWalk-v9/rig-parts-bold-v9.png <output-directory>

Validation
visual-preservation.json records each frame's changed region. All changes lie inside the
lower joint band x=80...179, y=174...223 in each 256x256 cell. Every upper-body/head pixel
and bottom 32 rows remain identical. The gait functions and transforms match v9 byte-for-byte.
The original side atlas is retained for the packaged regression check.
Voice integration checks exercise all fourteen possible selections without speaker playback.
Actual Kakao delivery is outside this change's validation scope.
