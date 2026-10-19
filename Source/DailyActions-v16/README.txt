Hachiware daily actions — v16
Date: 2026-10-19
App version: 0.10.0 (20)

The user asked to keep the focus-timer idea on hold and add Hachiware studying,
comic spit-up and eating, ignoring Chiikawa in the supplied references.
The pink tongue sticking out while studying is mandatory.

Artwork
Built-in image_gen created one 12-frame sheet per action using the approved character
and the user's corresponding reference. Generated contains all three originals and
one study-alpha review edit; rejected/intermediate versions are retained.
Prompts contains the exact prompt set. References contains all four supplied files.
The study source stores nonzero RGB under alpha=0; native compositing correctly hides
those RGB values. Runtime crops/registration preserve genuine alpha rather than chroma-keying.
PrepareDailyAtlas.swift detects actual transparent row gutters, crops chronologically,
and registers frames to the same blue-hair width and crown anchor. Final contains
three 6x2 atlases and all 36 individual 256x256 frames. No walking art was regenerated.
Iterations/00-equal-grid retains the initial equal-row registration of the spit-up sheet;
the final preparation uses real transparent separators so paws and props cannot be cut off.

Behavior
- Settings, character right-click and the menu bar expose all three actions and stop.
- Study runs five 1.8-second writing loops, with the pink tongue in every frame.
- Eating runs three 2-second loops: pick up rice, bring it to the mouth, chew, lower chopsticks.
- Comic spit-up runs one 2.4-second sequence only when explicitly selected.
- Actions start from frame one on a local clock, pause travel, and return to the existing
  roaming/idle setting when finished. Hover does not interrupt an explicitly chosen action.
- Clicking, dragging, incoming notifications, going home, hiding the character, or stop
  interrupt the action. Starting another selected action replaces it immediately.
- A sleeping character wakes for a selected action. Ground props keep independent positions.
  Carried items are temporarily omitted from the action drawing without dropping the item.
- No focus timer, automatic vomiting, new voices, or new permissions were introduced.

Reproduce from the repository root
  swift Source/DailyActions-v16/PrepareDailyAtlas.swift Source/DailyActions-v16/Generated/study-clean-alpha.png study <output-directory>
  swift Source/DailyActions-v16/PrepareDailyAtlas.swift Source/DailyActions-v16/Generated/eat-original.png eat <output-directory>
  swift Source/DailyActions-v16/PrepareDailyAtlas.swift Source/DailyActions-v16/Generated/vomit-original.png vomit <output-directory>

Validation
The image sheets and native animation previews were inspected. Tests check all 36 frames,
transparent corners, chronological playback, pink pixels in the study tongue region,
explicit callbacks, interruption, item-coordinate preservation and expiry in the live update.
All seventeen existing resources and the walking renderer/motion source match their previous
committed bytes; see existing-resources-preserved.json. Final packaged checks and UI evidence
are recorded in validation.json and self-test.txt. Live KakaoTalk delivery was not retested.
