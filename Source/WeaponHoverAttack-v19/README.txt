Hachiware armed hover attack - v19
Date: 2026-10-19
App: 0.12.0 (23)

The user requested an attack while hovering over an armed Hachiware, especially the
expression in their supplied image. The left-hand Chiikawa character is excluded.

Artwork
The built-in image_gen tool produced Generated/attack-original.png using the supplied
attack expression and approved T-pose identity. The exact prompt is Prompts/attack.txt.
All 12 poses retain open shiny eyes, angled eyebrows, nose-bridge effort marks,
pink hatched cheeks and an open mouth with a small pink tongue. Both paws grip one
blue barbed U-shaped sasumata. The attack art includes its own weapon.
The source's RGB under alpha=0 contains a dark gradient. Native compositing correctly
preserves the genuine transparency; no background replacement or chroma key is used.

Registration
PrepareAttackAtlas.swift locates transparent row and per-row column gutters, crops
all 12 drawings chronologically, normalizes hair width and anchors the ground baseline.
Final contains the 6x2 atlas, all 256x256 frames and a registration report.
Iterations retains the rejected equal-column cut log and all crown-anchor images.
The final ground baseline avoids floating above the desktop. Source pixels are retained
without redrawing; the runtime sheet is a registered copy of the generated artwork.

Behavior
Only a carried sasumata changes hover from wave/laugh to the attack.
The 1.2-second loop starts at frame one on each hover and uses a local elapsed clock.
Leaving hover clears the attack on the next 60-Hz update and resumes distance-based gait.
Paused walking, expression-off, drag, incoming notification and explicit daily actions
retain their existing priorities. Ground items and life props never move during attacks.
The generic equipment overlay is omitted for this pose so there is only one weapon.
Existing walking, daily-action, voice and older expression resources remain byte-identical.

Implementation
WeaponAttack.swift caches all frames at launch. CompanionArtwork.swift dispatches the
new action. Desktop.swift chooses it only for active armed hover and resets its clock.
The optional pointer visibility input is for deterministic controller tests; normal use
continues to use the real native window occlusion and pointer geometry.

See validation.json, cli-self-test.txt, self-test.txt, existing-resources-preserved.json,
Review/hachiware-attack-frames-v19.png and Review/hachiware-hover-attack-v19.gif.
