# Guided bedtime breathing

Research checked November 19, 2026, America/New_York.

## Product decision

Press and hold the wind icon throughout a finite guided session. Touch-down
immediately starts the timer and haptics. Keep the finger down through inhaling
and exhaling; the rhythm changes automatically. Lifting the finger pauses the
timer, animation, and haptics. Holding again continues the same phase and time.
There is no separate Start button or per-breath tap mode.
The app opens directly on breathing. Session length and vibration are saved
automatically in Settings, alongside the instructions and research. No reading
or session-configuration choice appears in the nightly flow. Existing readers
move to breathing while their historical entries and vibration choice remain.
The sustained touch is an engagement choice, not a proven therapeutic component.

| Setting | Implementation | Rationale |
| --- | --- | --- |
| Default length | 5 minutes, 30 guided cycles | A manageable starting point informed by brief relaxation studies, not an established optimum for sleep |
| Optional lengths | 10 minutes / 60 cycles; 20 minutes / 120 cycles | Allow a longer comfortable session; the 20-minute duration and six-per-minute rate have direct precedent in a small bedtime study |
| Pace | Inhale 4 seconds; exhale 6 seconds | Six cycles per minute, a commonly studied slow pace; a longer exhale is a design choice with research precedent, not proven superior |
| Breath depth | Gentle and comfortable | Do not encourage repeated maximal inhalations or force a user to keep pace |
| Breath holds | None | Keep the guide simple and avoid requiring breath retention |
| Guidance | Holdable wind icon, expanding/contracting circle, phase text, rising/falling vibration | Keep one finger down through both breathing phases while the rhythm guides the person |
| Completion | Stop after the final full exhale; invite natural breathing and putting the phone down | A finite activity without another automatic session |

Five minutes at this pace equals 30 **guided** cycles. The app does not detect
actual respiration, measure compliance, or infer that somebody fell asleep.
This is an adaptation of research, not a reproduction of a single validated
sleep-treatment protocol.

## What the evidence supports

| Source | Design and relevant findings | Implication |
| --- | --- | --- |
| [Tsai et al., 2015, Psychophysiology](https://doi.org/10.1111/psyp.12333) | Fourteen self-reported insomniacs and 14 good sleepers. A 20-minute bedtime session at 0.1 Hz was associated with improvements in several sleep measures in the insomnia group. | Direct but small-sample precedent for six breaths per minute and the 20-minute option. Does not establish an optimal dose or validate a five-minute sleep claim. |
| [Kuula et al., 2020, Scientific Reports](https://doi.org/10.1038/s41598-020-64218-7) | Pilot with 20 young adults, comparing intervention and control nights. A 30-minute breathing exercise changed some physiological and EEG measures, but had no robust benefit for sleep quality or sleep latency. | Relaxation-related physiological changes cannot be treated as proof of faster sleep onset. |
| [Five-minute slow-breathing study, 2021, Scientific Reports](https://doi.org/10.1038/s41598-021-98736-9) | Pre/post study of 47 younger and older adults. Five minutes of guided breathing gradually moved from 4/4 to 4/6 seconds. State anxiety fell; the study lacked a non-breathing control. | Relevant precedent for a brief guide and the chosen rhythm. It tested anxiety, not bedtime sleep; the app uses a constant 4/6 rhythm rather than the study's gradual transition. |
| [Yilmaz Balban et al., 2023, Cell Reports Medicine](https://pmc.ncbi.nlm.nih.gov/articles/PMC9873947/) | Randomized comparison of daily five-minute breathwork and mindfulness over a month. Exhale-focused cyclic sighing improved positive affect relative to mindfulness; sleep measures did not improve significantly. | Supports investigating brief relaxation practices. Cyclic sighing is a different technique from this app's paced breathing and cannot establish its sleep efficacy. |
| [Breath-ratio comparison trial, 2023](https://pubmed.ncbi.nlm.nih.gov/36871835/) | A 12-week randomized trial with 100 participants found no significant stress-reduction difference between longer-exhale and equal-duration breathing groups. | Do not claim the 4/6 ratio is uniquely effective or better than 5/5 for relaxation or sleep. |
| [Eide et al., 2026, Sleep Medicine Reviews](https://doi.org/10.1016/j.smrv.2026.102284) | Review of nine bedtime slow-breathing studies, 457 participants. Self-reported sleep findings were encouraging; objective measurements were inconclusive. | The overall sleep evidence remains limited and mixed. There is no basis for claiming a universal optimal breath count, exact duration, or proven app-level benefit. |

## Language in the app

Appropriate: “Slow breathing may help you unwind”; “five-minute starting point”;
“six guided breaths a minute.”

Unsupported: “scientifically proven to put you to sleep”; “optimal 30 breaths”;
“4/6 is the best ratio”; “activates the vagus nerve to guarantee sleep”; or any
claimed reduction in sleep latency attributable to this untested app.

The Settings guide links to the sources and distinguishes a convenient default
from demonstrated sleep outcomes. That guide asks for gentle breaths and advises
stopping if light-headed or short of breath. The nightly screen retains only
the immediate hold/release instruction, phase cue, countdown, and finish action.

## Session behavior

- Touch-down on the wind icon immediately begins guidance and the small countdown, with no long-press recognition delay. The icon stays in the same position while held.
- The wind button fills up to 320 points on the opening screen. A brief visual response and soft contact cue acknowledge each hold. The haptic engine is prepared on entry and kept warm between holds; backgrounding and leaving stop it.
- The person keeps holding through every inhalation and exhalation. Releasing pauses; holding again resumes. There is no separate Start, Pause, or Resume button.
- A monotonic clock determines the phase, orb expansion, haptic intensity, countdown, and end boundary. Timer callbacks do not accumulate phase drift.
- Haptics rise during inhalation and fall during exhalation. Enabling them mid-phase uses the current phase's progress and remaining duration.
- Release, app switching, locking the phone, or leaving the activity stop haptics. The app does not promise background or screen-off vibration.
- Releasing preserves the exact elapsed time and partial-cycle position. The small timer and orb freeze while released; holding again continues them. Released time never advances the session, and short holds are not discarded.
- Automatic screen lock is suppressed only while the guide runs. The previous idle-timer setting is restored on pause, completion, and exit.
- Reduced Motion removes the expanding animation; text and haptic guidance remain. VoiceOver receives phase announcements on iOS.
- Done becomes available after the first hold. Completing or exiting an activity is not evidence of sleep.

## Verification

Ten deterministic breathing tests cover start behavior, exact phase
boundaries, synchronized animation, all three durations, completion after the
last exhale, interrupted partial cycles, repeated short holds, frozen animation,
delayed callbacks, duplicate starts, and invalid clock inputs.
Two journal cases cover all saved duration/vibration combinations and older
journals without breathing preferences. Four additional app preference checks
cover migration from reading and legacy vibration storage, relaunch and export,
bedtime edits, failed saves, and data deletion.

Simulator touch-down/up checks confirm automatic phase changes through a
continuous hold, a stable button position, a countdown frozen across released
time, and re-press continuing the same phase. The separate Start button is absent.

The iPhone simulator can verify timing, controls, appearance, and lifecycle
behavior. It cannot demonstrate the feel or reliability of a physical iPhone's
Taptic Engine. Those haptics still require hardware validation.
