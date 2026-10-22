"""Record baseline evidence without treating the new characters as implemented."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
SRC = ROOT / "Sources/ChiikawaCompanion"

# Acceptance criteria describe the requested end state. Baseline evidence is
# deliberately separate from per-character pass/fail and visual approval.
ROWS = [
    ("official-reference-provenance", "Keep user references and primary-source provenance with generated assets; do not present fan additions as canonical.", [("RecordedVoice.swift", "let sourceProfile")], [], ["Source/VoiceClips-v13/provenance.json"]),
    ("tpose-front-side-back-top-diagonals", "Approve a consistent six-view identity sheet before making character motion.", [], [], ["Source/FourPhaseWalk-v9/References/approved-tpose-turnaround.png"]),
    ("8-directions-24frame-walk", "Render all eight directions in chronological 24-frame left/right cycles for the new characters.", [("HachiwareSprites.swift", "var frameCount"), ("HachiwareSprites.swift", "static func forVelocity")], ["all 24 joined side frames retain", "both upward diagonals use", "both downward diagonals use"], []),
    ("matched-left-right-foot-cycle", "Use one matched step trajectory with a half-cycle offset for the opposite foot.", [("HachiwareSprites.swift", "loadRegisteredAtlas(named: Self.assetNames[4]")], ["both steps follow the same body-height cycle half a cycle apart"], []),
    ("attached-arm-leg-contours", "Keep short arms and feet visually connected to the body without changing their reviewed motion.", [("HachiwareSprites.swift", "hachiware-side-walk-24-joined-v15")], ["joining the limbs preserves", "opening the shoulder contours preserves"], []),
    ("body-size-and-foot-registration", "Retain walking body scale, crown position and foot ground level when actions and attacks begin.", [("AttackRegistration.swift", "func destination")], ["attack body", "sole", "feet"], []),
    ("distance-driven-gait", "Advance walking phase by actual displayed path length, preserving phase during pauses and drags.", [("Roaming.swift", "static let distancePerCycle"), ("Desktop.swift", "actor.gait.recordMovement")], ["same displacement produces", "diagonal gait uses actual path length", "stationary and rounded-away movement"], []),
    ("continuous-roaming-without-teleport", "Continue full-desktop walking without snapping to nearby activities or restarting after display observations.", [("Roaming.swift", "private(set) var precisePosition"), ("Desktop.swift", "func triggerNearbyActivity")], ["automatic encounters never jump", "walk the last 28 points", "screen"], []),
    ("hover-reaction-and-next-tick-release", "React only while hovered and release to the user's walking state within the next sub-100ms update.", [("Roaming.swift", "static func resolve")], ["short and long hovers release", "leaving hover respects"], []),
    ("native-foreground-occlusion", "Show above desktop icons but below app windows, and reject hover through foreground windows.", [("Roaming.swift", "static var character"), ("CharacterPointer.swift", "static func canReach(_ actor")], ["character stays below normal app windows", "foreground", "WindowServer"], []),
    ("armed-exclusive-attack-and-stable-hit-area", "Armed hover uses only attack animation with one uninterrupted clock; all visible weapon/body pixels remain interactive.", [("CharacterPointer.swift", "func pointerIsHovering"), ("CompanionItems.swift", "static func hover")], ["six seconds on the extended weapon", "stable hover silhouette covers", "armed hover covers rendered walking outlines"], []),
    ("click-dialogue-random-no-repeat", "Choose uniformly from the character's click entries without immediate repeats and show the matching text.", [("RecordedVoice.swift", "static let all: [ClickDialogue]"), ("Desktop.swift", "func presentClickDialogue")], ["all fourteen lines share", "all fourteen selections show"], []),
    ("click-only-voice-local-playback", "Play authentic available clips only on click or explicit preview; no sound during autonomous motion or hover.", [("Desktop.swift", "func handleCharacterClick"), ("RecordedVoice.swift", "func play(_ line")], ["four real spoken excerpts", "armed pointer regression never plays", "packaged app plays its own bundled recordings"], []),
    ("voice-mute-volume-preview-stop", "Provide mute, volume, preview and stop; replace rapid clicks without overlap and handle missing clips honestly.", [("RecordedVoice.swift", "func setVolume"), ("Desktop.swift", "func previewCharacterVoice"), ("Desktop.swift", "func stopCharacterVoice")], ["rapid clicks replace", "turning off click voice stops", "audio gain clamps"], []),
    ("character-drag-clamp-and-route-reset", "Clamp dragging to a usable desktop and resume from the real released position with the old route cleared.", [("Desktop.swift", "override func mouseDragged"), ("Desktop.swift", "actor?.motion.retarget()")], ["desktop positions clamp", "rounded windows finish journeys"], []),
    ("independent-visible-walking-recall", "Allow independent visibility, walking and recall for each character without changing other characters.", [("Model.swift", "func isVisible"), ("Model.swift", "func isWalking"), ("DesktopChiikawa.swift", "func callFriend")], ["independent", "recall"], []),
    ("settings-persistence-migration", "Persist each character's controls, migrate old preferences and introduce new characters without resetting saved choices.", [("Model.swift", "init(defaults:"), ("Model.swift", "var visibleFriends")], ["later launches preserve", "migration", "persist"], []),
    ("independent-ground-prop-coordinates", "Store ground item positions independently of character movement, recall and actions.", [("CompanionItems.swift", "private(set) var ground"), ("Desktop.swift", "Ground props own screen coordinates")], ["ground", "character drag"], []),
    ("prop-click-to-seek", "Click a ground item to request a real walking journey even when automatic pickup is disabled.", [("Desktop.swift", "func seekItem"), ("CompanionItems.swift", "func target(from")], ["clicking a prop requests a journey"], []),
    ("proximity-pickup-and-cooldowns", "Pick up touched/nearby items reliably, exclude dragged items and apply drop/swap cooldowns.", [("CompanionItems.swift", "func nearbyTarget"), ("CompanionItems.swift", "func pickUp")], ["nearby", "dropped item is not immediately", "while the user is dragging"], []),
    ("direct-drag-drop-equip-owner-check", "Dropping an enabled owned item on its visible character equips immediately without waiting for auto pickup.", [("Desktop.swift", "func receiveDroppedItem")], ["handed", "drop", "disabled item"], []),
    ("equipment-swap-drop-hide", "Swap or drop equipment without duplication, and remove disabled equipment from ground and hands.", [("CompanionItems.swift", "mutating func equip"), ("CompanionItems.swift", "mutating func drop")], ["swapping equipment drops", "turning off a carried prop", "scattering preserves"], []),
    ("camera-action", "Carry and use a camera with an independent temporary performance that yields back to walking.", [("CompanionItems.swift", "case .camera: return .camera")], ["equipment actions", "camera"], []),
    ("guitar-action", "Carry and play a guitar with an independent temporary performance that yields back to walking.", [("CompanionItems.swift", "case .guitar: return .guitar")], ["short equipment actions finish"], []),
    ("weapon-action", "Carry the chosen character weapon and provide reviewed expressive attack frames on hover.", [("CompanionItems.swift", "case .sasumata: return .sasumata"), ("WeaponAttack.swift", "final class WeaponAttackSprites")], ["weapon hover loads twelve", "dedicated attack"], []),
    ("desk-study-with-tongue", "Walk to a desk and study, preserving the requested tongue detail throughout the loop.", [("ActivitySpots.swift", "var action:"), ("DailyActions.swift", "hachiware-study-v16")], ["all twelve study frames retain", "study, eating and comic spit-up"], []),
    ("food-eat", "Walk to a food bowl and eat, with the corresponding ground bowl hidden only during its own action.", [("ActivitySpots.swift", "case desk, furball, rice"), ("Desktop.swift", "func playDailyAction")], ["eating", "source"], []),
    ("furball-spit-up", "Provide the Hachiware-style non-graphic furball action and finish it once, except where the user explicitly excludes it.", [("DailyActions.swift", "hachiware-vomit-v16"), ("CompanionItems.swift", "var duration:")], ["spit-up runs only once", "spit-up finishes in the live update"], []),
    ("independent-activity-prop-drag", "Move desk, furball and bowl as independent screen objects without moving the character or unrelated props.", [("ActivitySpots.swift", "mutating func move"), ("ActivitySpots.swift", "override func mouseDragged")], ["activity", "drag"], []),
    ("activity-approach-arrival-exit-latch", "Approach within 34pt, walk to 2pt arrival, and require exit/cooldown before another automatic trigger.", [("ActivitySpots.swift", "static let triggerRadius"), ("ActivitySpots.swift", "static let arrivalRadius"), ("ActivitySpots.swift", "static let exitRadius"), ("ActivitySpots.swift", "mutating func consume")], ["arrival", "cooldown", "latch"], []),
    ("manual-actions-and-stop", "Offer direct action controls and immediate stop; clicks, dragging and hiding cancel the correct action.", [("Desktop.swift", "func playDailyAction"), ("Desktop.swift", "func stopDailyAction")], ["manual stop releases", "settings action callback", "character menu callback"], []),
    ("context-menu-and-settings-and-status-menu", "Expose per-character controls in settings, character context menus and the status menu.", [("Settings.swift", "struct SettingsView"), ("Desktop.swift", "override func rightMouseDown"), ("main.swift", "func setupMenu")], [], []),
    ("shared-single-fixed-house", "Keep exactly one house at the existing Hachiware position with default Hachiware style, regardless of roster size.", [("Desktop.swift", "let home = DesktopHome()"), ("CaveHome.swift", "static let size = NSSize(width: 360"), ("CaveHome.swift", "visible.minY + 12")], ["single", "fixed", "house"], []),
    ("walk-home-and-drop-equipment", "Walk to the common entrance, drop carried equipment and enter without moving ground props.", [("Desktop.swift", "func goHome"), ("Desktop.swift", "func enterHomeIfReached")], ["homeward", "enter", "drops"], []),
    ("sleep-entry-breathing-wake", "Show entry, breathing sleep and return to walking; keep independent per-character rest clocks.", [("CaveHome.swift", "static let entryDuration"), ("CaveHome.swift", "static func breathingScale"), ("Desktop.swift", "func wakeFromHome")], ["entry animation finishes", "sleeping", "wakes"], []),
    ("automatic-rest-toggle", "Allow independent automatic rest controls with the baseline 90s return and 20s sleep defaults.", [("CaveHome.swift", "static let sleepDuration"), ("CaveHome.swift", "static let returnInterval"), ("Model.swift", "var automaticRest")], ["automatic", "rest"], []),
    ("house-skin-independent-membership", "Changing the house skin must not change its position, identity, sleeping occupants or rest clocks.", [("SharedHome.swift", "var homeOccupants"), ("CaveHome.swift", "enum HomeStyle")], ["design", "occupants", "skin"], []),
    ("hide-cancels-own-actions-and-audio", "Hiding one character cancels its actions, overlays, bubbles and audio while leaving other characters intact.", [("Desktop.swift", "guard enabled else"), ("Desktop.swift", "actor.panel.orderOut(nil); actor.dismissBubble(); stopCharacterVoice()")], ["hiding", "hidden", "voice"], []),
    ("cross-character-state-isolation", "Keep items, activity latches, voice players, selected actions and home routines independent for all five characters.", [("Desktop.swift", "var homeRoutines"), ("Desktop.swift", "let chiikawaVoice"), ("Desktop.swift", "var itemWorld")], ["independent", "unrelated", "other character"], []),
    ("no-runtime-history-or-secret-collection", "Runtime stores only preferences and bounded in-memory state; no notification monitoring, message history, generated cache or remote playback.", [("Model.swift", "let defaults: UserDefaults"), ("RecordedVoice.swift", "AVAudioPlayer(contentsOf: url)"), ("Desktop.swift", "timer = Timer")], ["launch removes retired sender mappings", "network access"], []),
    ("native-launch-and-resource-verification", "Compile and sign the actual app, decode its own packaged assets, and run native window/input regressions.", [("main.swift", "func applicationDidFinishLaunching")], ["packaged", "WindowServer"], []),
    ("middle-and-final-audit-with-fix-loop", "For each character, review intermediate art/behavior, repair feasible omissions, then rerun the full acceptance and cross-character audit.", [], [], ["Source/Usagi-v38/Audit/baseline-features.json", "Source/Usagi-v38/Approval-v2/approval.json"]),
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

checks = {}
for path in [SRC / "SelfTest.swift", *sorted(SRC.glob("*Checks.swift"))]:
    checks[path.relative_to(ROOT).as_posix()] = path.read_text().splitlines()

features = []
for key, acceptance, anchors, patterns, artifacts in ROWS:
    definitions = []
    for filename, anchor in anchors:
        path = SRC / filename
        hits = [(n, line.strip()) for n, line in enumerate(path.read_text().splitlines(), 1) if anchor in line]
        if not hits:
            raise SystemExit(f"Missing baseline anchor: {filename}: {anchor}")
        definitions.append({"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path), "anchor": anchor,
                            "matches": [{"line": n, "text": line} for n, line in hits]})
    relevant = []
    for filename, lines in checks.items():
        for n, line in enumerate(lines, 1):
            if any(pattern.casefold() in line.casefold() for pattern in patterns):
                relevant.append({"path": filename, "line": n, "text": line.strip()})
    files = []
    for filename in artifacts:
        path = ROOT / filename
        if not path.is_file():
            raise SystemExit(f"Missing baseline artifact: {filename}")
        files.append({"path": filename, "sha256": sha(path)})
    features.append({"id": key, "acceptance": acceptance, "implementation_definitions": definitions,
                     "related_existing_check_lines": relevant, "artifacts": files,
                     "new_character_result": "pending", "visual_review_required": key in {
                         "tpose-front-side-back-top-diagonals", "matched-left-right-foot-cycle",
                         "attached-arm-leg-contours", "body-size-and-foot-registration", "weapon-action",
                         "desk-study-with-tongue", "sleep-entry-breathing-wake"}})

expected = json.loads((HERE / "baseline-features.json").read_text())
assert set(f["id"] for f in features) == set(f["id"] for f in expected["features"])
log = HERE / "baseline-self-test.log"
test_lines = log.read_text().splitlines() if log.exists() else []
passes = [line for line in test_lines if line.startswith("PASS:")]
failures = [line for line in test_lines if "FAIL:" in line]
report = {
    "verified": "2026-10-22", "baseline_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    "scope": "Existing Hachiware baseline, shared two-character behavior and acceptance definitions; no new character implementation passes are claimed.",
    "gate": "Usagi T-pose identity awaits explicit user confirmation; motion production, integration and later character production remain on hold.",
    "baseline_differences": [
        "Hachiware side walking is 24 frames; front, back and both diagonal source poses are 12 frames. Greeting has six frames. Directions with paired facings are mirrored.",
        "The new-character target remains 24 frames for every walking direction; passing the existing Hachiware tests does not prove that target.",
        "Hachiware has four real voice clips plus ten text-only quotes. Additional authentic character recordings are an external asset dependency, not solved by generic TTS or unrelated speech.",
        "Hachiware waking uses the existing house exit; Chiikawa additionally has explicit waking frames. New character sleep/wake art needs separate visual review.",
        "Usagi's taller ears require canvas, clamps, hit testing and attack registration to be reviewed together; square Hachiware metrics alone cannot verify them.",
    ],
    "existing_packaged_test_log": {"path": "Source/Usagi-v38/Audit/baseline-self-test.log", "pass_lines": len(passes), "failures": failures,
                                    "terminal_summary": [line for line in test_lines if "checks passed" in line.lower() or "all " in line.lower()][-3:]},
    "coverage_limit": "Related check lines are an index for review, not proof that each entire acceptance criterion or every visual property is tested. New-character assertions and five-character runtime review are still required.",
    "features": features,
}
(HERE / "hachiware-baseline-evidence.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"feature_count": len(features), "existing_pass_lines": len(passes), "failures": failures}))
