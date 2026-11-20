# Development build 0.2

Prepared November 18, 2026, America/New_York.

Quiet-ending follow-up, November 19: "Done for tonight" is available before the
first hold and throughout the routine. Choosing it or reaching the timer's end
freezes held time, gently contracts and fades the circle, and tapers only an
already-playing haptic pattern to silence over 1.4 seconds. A paused or unstarted
session never generates an ending vibration. The only final content is "The rest
can wait. Put your phone down." There are no tabs, restart links, completion
sounds, rewards, or routes back to a dashboard. The normal idle timer is restored.
Returning from the background retains the ending until the saved wake time;
a later visit restores morning access, including for sessions ended after
midnight. A fresh app launch starts on breathing.

All 46 core cases and six AppModel preference checks pass. New cases cover
finishing before starting, every partial-breath position, paused time, and a
release at the timed endpoint. Early finishes preserve actual held time and do
not invent completed breaths. The updated iPhone preview builds and runs, the
full app and all three extensions pass iPhone SDK type checks, and the native
Mac preview builds. Simulator inspection confirms that an immediate finish
reveals one accessible message, zero interaction targets, and no tab bar, and
records one routine-ending event without a morning check-in. A continuously
held five-minute simulator session reaches the same message automatically;
returning through the Home screen retains it. A six-second hold followed by
release and early finish also reaches that message. Each of the three paths
saves exactly one routine-ending event. The physical
vibration taper and VoiceOver focus still require device validation. The
ending uses opacity without circle movement when Reduce Motion is enabled.

Nightly-flow simplification, November 19: reading and activity selection are
removed from the main experience. The app opens directly on breathing; session
length, vibration, instructions, and research live in Settings. Duration and
vibration save automatically to the journal and survive relaunch, bedtime
edits, and export. Returning readers receive breathing while historical plans,
reading completions, and their earlier vibration choice are retained. Local
data deletion restores the default five-minute session with vibration enabled.
All 42 core cases and six AppModel preference checks pass. The updated iPhone
simulator and native Mac preview build; the full iPhone app and all three
extensions pass SDK type checks.
On a separate iPhone 16e simulator, the breathing screen has no duration,
vibration, activity, or research controls. Settings changes to 20 minutes and
vibration off survive process termination and relaunch; a new session starts
at 20:00. A seven-second hold reaches 19:53 and release pauses it. The guide
opens and closes from Settings. Physical vibration remains a device check.

App-blocking follow-up, November 19: 30 core checks pass; the full app and three
extensions pass iPhone SDK type checks; the complete SleepApp simulator build
succeeds. Source preflight confirms the capability declarations and embedding,
but the four targets still need consistent capable-team signing. Live iPhone
shielding remains unverified. Two AppModel preference failure checks also pass
using the preview service. See [blocking findings](BLOCKING_FINDINGS.md).

Guided-breathing follow-up, November 19: hold the wind icon through automatic
four-second inhales and six-second exhales. Touch-down begins the small timer
and haptics immediately; release freezes exact progress; the next hold
continues the same phase. There is no separate Start button or per-breath tap
mode. Sessions last 5 minutes by default, with 10- and 20-minute options.
All 40 core cases pass, including ten breathing cases. The updated iPhone preview builds
and runs; full iPhone source and extensions pass SDK type checks; the native
Mac preview builds. Simulator checks cover duration selection, automatic phase
changes while continuously held, release/re-press with a frozen countdown,
returning from Home in a paused state, and the research
sheet. Finite completion and delayed callbacks are covered by deterministic
tests. Physical vibration feel, VoiceOver announcements, and Reduced Motion
still need device/accessibility validation.
See [breathing research and behavior](BREATHING_RESEARCH.md).

## Delivered and checked

Wind-button entry, November 19: Breathe is the initial tab for new and returning
users, with no onboarding requirement. The main wind button scales up to 320
points; its touch target stays fixed through the hold/release transition.
The simulator confirms a clean first launch reaches it directly, a continuous
hold advances from inhale to exhale, and release freezes the timer across idle
time. Touch feedback and a prepared haptic engine improve response on press.
Actual vibration feel still needs validation on a supported iPhone.

| Work | Evidence |
| --- | --- |
| Toolchain | Xcode 26.3 installed and selected; iPhoneOS 26.2 SDK and iOS 26.3 simulator runtime available |
| iPhone preview | SleepAppPreview built, installed, and launched on iPhone 17 Pro simulator with iOS 26.3 |
| Routine target | No Family Controls or App Group entitlements; no embedded extensions; automatic signing configured |
| Full iPhone source | SleepApp and all three extensions pass type checks against the iPhoneOS SDK |
| Native Mac preview | SleepPreview compiled and packaged as Artifacts/SleepAppPreview.app, locally ad-hoc signed |
| Core regression checks | 25 XCTest cases passed with zero failures |
| Xcode project | Five targets; shared schemes for SleepApp and SleepAppPreview; configuration and plist checks pass |
| Optional reminder | Simulator permission prompt exercised; selected-night schedule enabled; editing wind-down from 10:30 to 10:45 PM updates its status |
| Reminder behavior | Local calendar notifications, no sound or badge, permission requested only on explicit opt-in |
| Existing data | A journal without the new reminder field decodes with reminders off; current settings round-trip |
| Onboarding | All three steps completed in the Mac preview; iPhone welcome screen visually checked |
| Tonight | Native iPhone bottom tabs and pinned action visible; original Mac card-composition issue corrected |
| Activities | Reading and breathing opened in the Mac preview; breathing also opened and exited in the iPhone preview |
| Morning state | Empty journal and missing-data messaging inspected; no sample outcomes inserted |
| App limits | Preview states that its routine works without restricting other apps |
| Design reference | Editable Figma Tonight screen, editable text, reusable controls, bound tokens |

The iPhone SDK check is a compiler type check, not a linked or signed physical
device build. The simulator does not demonstrate Screen Time enforcement or
actual notification delivery while the device is asleep. No screenshots are
included as source artifacts or uploaded as deliverables.

## Core cases

Overnight boundaries; after-midnight weekday ownership; next selected night;
daytime schedules; spring daylight saving; fall daylight saving; a missing
daylight-saving clock time; time-zone changes; invalid schedules; positive
bedtime delay; missing check-ins; historical planned bedtime; no retroactive
plans; check-in validation; storage roundtrip/deletion; corrupt-file preservation;
unsupported protection; authorization/selection/registration requirements;
active-night protection; current-night overrides; no override leakage into a
future night; bounded test protection; reminder weekday ownership across midnight;
invalid reminder plans; backward-compatible journal decoding.

The spring-forward check exposed a calendar edge case. Clock resolution uses
Calendar.nextDate with the next-time-preserving policy documented for Device
Activity. Reminder triggers contain weekday and local clock components without
a fixed time zone.

## Next routine milestone

- [x] Continue development with the simulator and a routine-only iPhone target.
- [x] Add optional, quiet wind-down reminders and retain older local journals.
- [ ] Install SleepAppPreview on a connected iPhone using Personal Team signing.
- [ ] Verify actual reminder delivery, notification denial, permission revocation, Focus behavior, and travel time-zone changes.
- [ ] Complete a routine through a real next-morning check-in without synthetic sleep outcomes.
- [ ] Check Dynamic Type, VoiceOver, reduced motion, small screens, and landscape on iPhone.
- [ ] Check narration, audio interruptions, and screen-off playback on iPhone.
- [ ] Exercise storage-error recovery, export, deletion, OS backups, file protection, and the privacy report.
- [ ] Observe the routine and setup with 8–10 adult users.

Reminders are optional and default off. They do not depend on Family Controls,
App Groups, a backend, or a paid developer team. Device testing remains useful
for the routine, but optional app-limit testing does not hold up routine work.

## Separate optional app-limit validation

- [x] Keep the full SleepApp target and its three native extensions.
- [x] Type-check the full implementation with the iPhone SDK.
- [ ] Configure a capable developer team, unique identifiers, and a matching App Group.
- [ ] Build and install the complete signed app and extensions on an iPhone.
- [ ] Exercise individual Screen Time authorization granted, denied, revoked, and restored.
- [ ] Demonstrate selected app and supported website shields on a physical device.
- [ ] Confirm calls, alarms, transport, and essential accessibility tools remain accessible.
- [ ] Test selected weekdays, cutoff and wake boundaries, midnight, daylight saving, and time-zone changes.
- [ ] Test app termination, restart, offline use, and late monitor callbacks.
- [ ] Test schedule edits while active, failed registration, and end-of-window removal.
- [ ] Verify the 20-minute test ends correctly and can be stopped manually.
- [ ] Verify the current-night override persists and the next scheduled night protects again.
- [ ] Verify corrupt data suspends app protection and preserves the original file.
- [ ] Obtain Family Controls distribution approval for applicable targets before TestFlight or App Store distribution.

Device Activity callbacks are system-managed and can depend on device use; exact
wall-clock behavior has not been established by compiler or simulator checks.
Short timed breaks are excluded. This build does not measure target-app opening
attempts, sleep onset, sleep stages, or minutes saved. Clinical effectiveness and
release readiness remain unvalidated.

## Product validation

Run an opt-in closed beta after the routine is usable and device checks pass.
Finalize consent, comparator, missing-data handling, and progression criteria for
the planned pilot. Compare value against guided free Screen Time setup before
pricing or acquisition work.

## Deferred

Android blocking, calm video, a broad content library, subscriptions, cloud sync,
wearable integrations, social features, and clinical efficacy claims.

GitHub destination: the private [alecchoi/sleep-app](https://github.com/alecchoi/sleep-app)
repository. No recruiting messages, entitlement requests, TestFlight uploads,
or App Store submissions were sent.
