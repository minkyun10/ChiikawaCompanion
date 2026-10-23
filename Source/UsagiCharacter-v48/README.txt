Usagi character fidelity correction v48 — 2026-10-23

User direction: preserve the initial approved round body; shorten ears by approximately 30 percent (keep 70 percent of root-to-tip length). Brave, loyal, kind, fearless eccentric; eyes and sleeping attitude should reflect this, without villain or horror styling.
The initial approved six-view T-pose is the anatomy authority. All references, prompts, drafts and selected images remain here.
Generation: built-in image_gen. Review material is prepared before replacing runtime artwork.

Selected review images (not yet applied to the running app):
  Final/usagi-six-view-v48.png — corrected six-view T-pose, approximately 30% shorter ears.
  Final/usagi-sleep-v48.png — carefree, half-open upward-looking eyes, tongue and tiny drool bead; compact round body, exactly two arms and two feet.

Front T-pose measurement against the initial approved sheet:
  Ear root reference y=165. Original tip y=30; candidate tip y=71.
  Root-to-tip length 135px -> 94px, a 30.37% reduction.
  Below-ear outline bounds: original [202,166,483,450], candidate [202,166,484,450].
  Same body/limb height and only 1px difference in total width at this sheet resolution.
  This measures the front view, not every pixel or every other view.
  Details: Audit/proportion-review.json.

Future production constraints:
  Treat the initial approved round body and these short ears as separate invariants.
  Never resize the whole body to fit an ear-inclusive height; preserve cheek/belly width and trunk height.
  Change facial parts without generating replacement bodies for every expression.
  Keep eyes small, gaze slightly vacant and uninhibited, mouth cheeky and warm. Fearless and kind, not evil or angry.
  Preserve all drafts. The generated rig-sheet drafts retain a brown halo and are not production-ready; they are archived for traceability only.

Runtime code, assets and walking/sleeping behavior are unchanged by this design-review update.
