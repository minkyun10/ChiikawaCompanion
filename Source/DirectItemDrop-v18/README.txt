Direct item handoff - v18
Date: 2026-10-19
App: 0.11.1 (22)

Request
Dragging a camera, guitar or sasumata onto Hachiware should equip it immediately.

Behavior
- DesktopItemView emits its drag-release callback only after an actual drag.
  An ordinary click still requests the existing walk-to-item behavior.
- Release uses the actual pointer location against the character's existing body hit area,
  excluding transparent margins. It does not require the item to be near the feet.
- A valid release equips and displays the item immediately, hides its ground window,
  cancels a daily action or pending journey and keeps the character at its current position.
- Replacing equipment drops only the previously carried item beside the character.
  Other ground items and life props retain their independent world coordinates.
- Releasing elsewhere leaves the item where it was dragged.
- Explicit handoff works with walking and automatic pickup disabled; these settings are preserved.
- Notification bubbles and their expiry/reaction retain priority over equipment gestures.
- Hidden, sleeping or disabled characters and disabled/unavailable items reject handoff.
- Ordinary proximity pickup still uses its original distance check and shared inventory transfer.

Implementation
DesktopItems.swift: actual drag-release callback, accessibility label and tooltip.
Desktop.swift: character target validation and immediate equipment/view update.
CompanionItems.swift: shared inventory transfer for proximity pickup and explicit handoff.
ItemDropChecks.swift: real controller callbacks, state transitions, rejected targets,
inventory uniqueness, independent coordinates and notification preservation.

All existing image, animation and voice resources remain byte-identical.
Any UI captures from this request are retained in Review; no artwork was generated or edited.
See self-test.txt, existing-resources-preserved.json and validation.json for verification.
