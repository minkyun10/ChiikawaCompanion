Hachiware proximity actions — v17
Date: 2026-10-19
App version: 0.11.0 (21)

The user requested studying near a desk, comic spit-up near a furball, and eating near rice.
Three native desktop life props use the existing accessory palette and rounded outlines.
No animation frames were regenerated. Existing v16 study/eat/spit-up art, tongue detail,
approved v15 side walk and other directions stay unchanged.

Behavior
- All three props are enabled by default. Proximity reactions have their own switch.
- The character's foot contact within 34 pt triggers the corresponding action.
- Dropping the character nearby also triggers it; dragging a prop does not trigger until release.
- Clicking a prop or its settings visit button walks to it first. An explicit visit takes
  priority over automatic carried-item pickups and auto-rest; entering the house still works
  when explicitly requested. A pending carried-item request is not interrupted by incidental props.
- On interaction, the character aligns to the prop's fixed contact anchor. No prop coordinate moves.
- The desk/rice floor drawing is temporarily hidden because its approved pose already includes
  that prop. It returns at exactly the same coordinates when the action ends. Furball remains behind.
- Study is 9 seconds, eating 6 seconds, and comic spit-up one 2.4-second sequence.
- Staying nearby never loops the action. Automatic rearming requires leaving an 84-pt radius
  and a 30-second cooldown (45 seconds for furball). Explicit clicks can request another visit.
- Character dragging, calling/resetting, notifications and visibility changes never scatter props.
  Individual prop dragging changes only that prop. Display-layout changes clamp to valid screens.
- Prop visibility and proximity preferences persist. Positions/latches/cooldowns are runtime-only.
- Settings, character right-click and the menu bar retain immediate manual action selection.

Implementation
ActivitySpots.swift contains the independent world model, native artwork and desktop windows.
Desktop.swift arbitrates visits, proximity, actions, carried items and the home routine.
ActivitySpotChecks.swift verifies mappings, exact entry/exit rules, cooldown, dragging exclusion,
explicit visits, real controller start/expiry, no stationary repeats and coordinate preservation.
The four exported prop/mapping PNGs in Review are previews of the native artwork rather than
new image-generation outputs. All images from this request are archived here or in Source/Project.

Validation
See cli-self-test.txt, self-test.txt, existing-resources-preserved.json and validation.json.
Live KakaoTalk delivery is outside this change's scope.
