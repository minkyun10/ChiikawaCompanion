Hachiware joined arm roots — v15
Date: 2026-10-19
App version: 0.9.2 (19)

The user approved the joined v14 legs and requested the same visual connection for the arms.
Only the side-walk arm-root contours are opened at the shoulder. The original closed arm
cutout now draws below local y=0, leaving a U-shaped contour that joins the torso.
Clipping happens after the original pivot and rotation transforms. Both arms retain their
swing, hand positions, size below the shoulder and timing. Right walking mirrors the completed
left frames. The approved v14 legs, other walking directions, items and mixed dialogue are unchanged.

Final contains a transparent 6x4 atlas, 24 frames for each direction, chronological sheet,
keyposes and normal/slow GIF previews. Iterations preserves the initial native review.
The editable native rig was revised; no new image-generation model output was required.
Every image produced for this request is retained in this folder or Source/Project.

Reproduce from the repository root
  swift Source/JoinedArms-v15/JoinedArmPreview.swift Source/FourPhaseWalk-v9/rig-parts-bold-v9.png <output-directory>
  python3 Source/JoinedArms-v15/VerifyJoinedArms.py

VerifyJoinedArms.py reads the before/after sheets and checks each changed pixel against the
rotating arm-cap region in arm-local coordinates. It checks every approved leg pixel and
compares the gait, body-bob, swing and transform source against v14. It does not edit artwork.
visual-preservation.json records the exact per-frame change counts and bounds.
The application includes a regression check that every v14 leg pixel survives loading.
See self-test.txt and validation.json for the final packaged verification.
Live KakaoTalk delivery is outside this visual change's validation scope.
