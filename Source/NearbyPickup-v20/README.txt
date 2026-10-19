Pass-by item pickup - v20
Date: 2026-10-19
App: 0.12.1 (24)

The user reported that the character usually walked past items without reacting.
Investigation found a 30-point foot-anchor circle, a 24-second global pickup lockout,
and checking only the currently pursued item before movement.

Changes
- Pickup reach uses the rounded body centered at origin+(66,74), radii (50,62),
  including a six-point reach margin. The prop uses its real 64x64 drawing bounds
  at ground anchor+(-32,-1). It requires rectangle/ellipse contact, not distant attraction.
- Nearby candidates include all eligible, non-dragged ground items, independent of
  the previous pursuit target. Both before- and after-movement checks handle encounters.
- The 24-second next-pursuit delay stays in place so the character can keep wandering.
  Pass-by pickups use their own three-second minimum interval instead.
- Dropped old items keep their twelve-second protection. A manual drop also has a
  one-second nearby delay. Explicit clicks/handoffs can still intentionally equip sooner.
- Automatic-off, explicitly selected journeys, home/life-prop visits, hover, drag,
  notifications, selected daily actions and sleeping retain their priorities.
- Only the previously carried item is dropped when swapping; other world coordinates stay fixed.
- Desk/rice/furball proximity rules are unchanged by this carried-item fix.
- All existing image/voice assets and walking renderer/motion source are unchanged.

Verification
NearbyPickupChecks.swift covers drawn-body contact beyond the old foot radius,
distant rejection, independent cooldowns, automatic-off, dragged exclusion, replacement,
per-item cooldowns, explicit route priority, live controller pass-by during pursuit delay,
coordinate preservation and same-tick contact after real movement.
The existing direct-drop check now asserts that the upper-body handoff is within visual
reach while it remains unequipped during dragging; the older foot-radius exclusion
expectation was intentionally superseded by this change.

See cli-self-test.txt, self-test.txt, validation.json and existing-resources-preserved.json.
No new artwork was generated or edited for this request.
