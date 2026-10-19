Hachiware recorded voice — v13
Date: 2026-10-19
App version: 0.9.0 (17)

The user approved the previously downloaded Son Jeong-min voice sample for their personal companion.
Four short spoken excerpts from that public character sample are used as local click dialogue.
Source title, URL, hash and edit boundaries are in provenance.json and catalog.json.
The source profile credits Son Jeong-min as Hachiware/Gareuma; these excerpts are identified as
public character-demo audio rather than attributed to a specific numbered television episode.

Clips
- sushi: 초밥이다! (0.00–1.12)
- mixed: 엉망진창으로 뒤섞였어. (5.45–8.38)
- tasty: 맛있다! (11.92–13.51)
- story: 그래서 말이야. (13.54–15.16)
Total final audio duration: 7.26 seconds. The source's later singing section is not included.
The complete reference remains in the user's original download location; only these spoken excerpts
are included in the application and this archive.

Preparation
Each excerpt was trimmed with FFmpeg, high-passed at 65 Hz, normalized toward -18 LUFS,
limited toward -1.5 dB true peak, faded at its boundaries, and encoded as mono AAC at 44.1 kHz.
The source spoken section was analyzed locally using MLX Whisper small and large-v3-turbo-q4.
No source audio was uploaded for transcription or synthesis. The local models are not app dependencies.
Short standalone excerpts produce unreliable ASR; clip-transcription-check.json records those failures.
Captions use the longer spoken context. The uncertain water/rice sentence and later sections were omitted.
Iterations preserves the first tasty edit and the first native UI capture.

Behavior
- Recorded dialogue mode is on by default, with click voice enabled at 65% volume.
- Every click displays the selected recording's own text and replaces any previous sound immediately.
- The same recording does not repeat on consecutive clicks.
- The original ten user-provided quotes are preserved as a separate text mode; they have no matching audio.
- Click voice, mode and volume are independent from existing Kakao notification TTS and sender mappings.
- Mute, changing dialogue mode, dragging, going home, hiding the character and incoming alerts stop playback.
- Explicit preview can play while the click-voice switch is off; it does not change that preference.
- Files are bundled in Resources/Voice. Playback works without Downloads or network access.

Validation
The local resource path was repaired after a failing development-bundle check.
The four clips decode, their caption timings match, and peak levels remain below 0 dBFS.
148 CLI checks and 151 packaged checks passed. Playback tests replace only device start, so tests are silent.
The real Mac preview started and its completion delegate reported normal completion.
A native segmented-control rendering issue was replaced with explicit labeled mode buttons.
Artwork hashes confirm all existing PNG resources, walks, house and sleep imagery are unchanged.
Actual Kakao delivery and acoustic loopback recording were not part of this change.
See validation.json for final UI verification and self-test.txt for the packaged results.
