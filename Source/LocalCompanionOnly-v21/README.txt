Local desktop companion only — v21
Date: 2026-10-20
App: 0.13.0 (25)

The user chose to remove KakaoTalk integration because connection setup was too complex.
Removed the accessibility notification scanner, parser and sender matching, saved sender
mappings, monitoring controls, preview/demo menu, notification-specific TTS and permission
setup instructions. Startup removes old integration preference keys while preserving
walking, recorded-click voice/volume, items, home and daily-action preferences.
The app no longer needs an external account/API connection or accessibility permission.

Clicking Hachiware still selects among four matching recorded lines and ten text quotes.
Click dialogue keeps its existing bubble, interruption rules and reaction priority.
All eight walking directions, joined limb artwork, hover attacks, carried-item pickup
and handoff, independent prop coordinates, home/sleep and study/eating/spit-up remain.
Only the old notification activity name/deadline were renamed for local click dialogue;
the movement and distance-based gait implementation are unchanged.

All 21 existing image/voice resources are byte-identical to the previous commit.
No new artwork was generated or edited. Historical Source records and image archives
are retained as history, even when they describe features removed in this version.

Validation
- CLI self-test: 197 checks passed.
- Packaged app: 202 checks passed (includes bundled-resource checks).
- Deep, strict code signature verification passed.
- Removal scan, preservation report and native settings review are stored here.
- Existing regression checks cover movement, click speech, props, home and daily actions.
