Cave home and sleeping — v11
Date: 2026-10-19
App: 0.8.0 (15)

User request: remove the bag; place Hachiware's cave home at the lower center above the Dock,
behind ordinary app windows; show a sleeping motion when Hachiware enters.

Artwork
- Built-in image_gen generated both transparent raster assets using the supplied references.
- References/cave-reference.png: cave silhouette, grass, vine and storage box.
- References/sleep-reference.jpeg: sideways sleeping face, blanket and woven mat.
- Prompts/cave.txt and Prompts/sleep.txt: full generation prompts.
- Final/hachiware-cave-v11.png and Final/hachiware-sleep-v11.png: original generated pixels.
- Runtime loads those same PNGs, registers their alpha bounds and composes the sleeping sprite in the cave.
- Review/hachiware-cave-home-v11.png: composed preview.
- Review/hachiware-home-sleep-v11.gif: native renderer entry, breathing and rising z animation.
- All generation originals, existing images and older image versions remain archived in Source.
  Historical bag images remain as records; the app no longer offers, equips or renders a bag.

Behavior
- Home is centered on its retained display's usable area, 12 points above the Dock-safe edge.
- Home, props and the character keep independent global coordinates.
- House click or the settings button requests an actual walking journey. Arrival radius is 24 points.
- A deliberate character drag into the entrance can start sleep without enabling autonomous walking.
- Entry takes 0.85 seconds, then the blanket sprite breathes on a 3.6-second cycle.
- Clicking the sleeping home, selecting a prop or receiving an enabled alert wakes Hachiware.
- Sleep also ends after 20 seconds. Automatic rest can request a return after 90 seconds of elapsed time
  while walking is enabled; it can be disabled independently in settings.
- Only a carried prop is placed beside the home. Other ground props never shift on entry or wake.
- Wake has a ten-second automatic-entry cooldown, overridden by a deliberate new house click or drag.
- Existing 24-frame side walking and other directional artwork are unchanged; see walk-preservation.json.

Validation
- CLI self-test: 131 checks passed; packaged app: 133 checks passed.
- Packaged code signature verified with --deep --strict.
- Home geometry, click-through corners, desktop layer, arrival/entry/sleep/wake transitions,
  cooldown, explicit drag, alert wake, settings migration, prop independence and walk retention tested.
- Notification parsing uses synthetic fixtures. A live KakaoTalk delivery was not tested in this change.
- UI validation notes are recorded separately in validation.json.
