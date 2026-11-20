# Sleep App

A native iPhone app for a gentler end to the day.

**Status: development build 0.2.** The app runs in the iPhone simulator and as a
native Mac preview. All 46 core tests and six app preference checks pass. The full app and three Screen Time
extensions pass type checks against the iPhone SDK. Signed device installation,
real app-limit enforcement, and background behavior still need device testing.

## Try the native preview

For iPhone, open SleepApp.xcodeproj, select the **SleepAppPreview** scheme, choose
an iPhone simulator, and Run. This target includes the breathing routine,
reminders, settings, and diary without Family Controls or App Group entitlements.
No developer team is needed for the simulator.

For a connected iPhone, select your Personal Team on the SleepAppPreview target.
The preview target is configured for standard automatic signing; installation
with a Personal Team has not yet been tested on this device.

A locally built Mac preview is written to Artifacts/SleepAppPreview.app.
Generated apps, caches, local signing settings, and diary data are excluded
from source control. Both previews use the actual app screens and local persistence. Mac tabs use
native macOS chrome; iPhone uses the native bottom tab bar.

To rebuild with the Swift command-line tools:

    python3 scripts/build_preview.py

Core use works without a backend, login, API key, or third-party package download.

## Included

- Open directly on breathing and hold the wind icon to begin. No nightly activity choice or configuration screen.
- Optional bedtime plan, wake time, selected nights, and app protection in Settings.
- Session length, vibration, instructions, and research in Settings. Duration and vibration save automatically and survive relaunch; older vibration choices and journal history are preserved.
- Hold the wind icon for guided breathing: 5 minutes by default, with 10- and 20-minute options;
  four seconds in and six seconds out, synchronized animation and haptics, a small timer
  that starts on touch-down and pauses on release, exact progress on the next hold,
  reduced-motion support, and a finish action available from the start. The saved length applies to new sessions. Research and limitations: [breathing notes](docs/BREATHING_RESEARCH.md).
- Finish whenever ready, or let the timer reach its endpoint. The circle and active
  vibration settle for 1.4 seconds before one quiet message appears: "The rest can
  wait. Put your phone down." No tabs, restart prompt, completion pulse, or dashboard
  follows. Normal screen locking resumes. A later visit after the saved wake time
  restores navigation for the morning.
- Morning check-ins for reported sleep-attempt time, restfulness, and external constraints.
- A weekly reflection using real entries, explicit missing data, and no inferred sleep.
- Atomic local persistence, damaged-file preservation, data export, and deletion.
- Optional local wind-down reminders on selected nights, with no sound or badge.
  Permission is requested only when the reminder is switched on.
- Screen Time authorization, selection, weekly schedules, a 20-minute protection
  test, and an override for the rest of the current window.
- Routine preview, app, activity-monitor, shield-configuration, and shield-action targets.
- Required-reason privacy declarations for app and App Group preferences.

No sample sleep outcomes are inserted into a user's journal. An early finish or
timed endpoint records that the routine ended, not evidence that the person slept.

## Optional app limits

See [the blocking findings and device setup](docs/BLOCKING_FINDINGS.md) for the
Opal research, enforcement fixes, verified checks, and remaining signing steps.
Run `python3 scripts/check_blocking_setup.py` to inspect the current setup.

App limits restrict only the apps or websites a person selects. They are an
optional guardrail for unwanted bedtime scrolling. The quiet routine remains
available without them. Simulator builds do not enforce real app limits.

The **SleepApp** scheme retains the Family Controls implementation and embeds
the three extensions. A paid Apple Developer Program team is required to sign
that capability. Personal Team signing cannot provide it. This setup can wait
while we develop and test the routine in SleepAppPreview.

When testing the full protection build, use these steps. Xcode 26.3 is installed
and selected; the deployment target is iOS 17.

1. Set a unique APP_BUNDLE_ID, your DEVELOPMENT_TEAM, and an APP_GROUP_IDENTIFIER
   in Config/Local.xcconfig. This override is ignored by source control. Example:

       APP_BUNDLE_ID = com.yourcompany.SleepApp
       APP_GROUP_IDENTIFIER = group.com.yourcompany.SleepApp
       DEVELOPMENT_TEAM = YOURTEAMID

2. Register the app and three extension identifiers to the same team.
3. Enable Family Controls and the **same App Group** for all four targets.
4. Build on a connected iPhone. Authorize Screen Time, select distractions, and
   explicitly enable nightly protection.
5. Test a selected app's shield, essential access, end-of-window removal, and
   override recovery before using the app as an overnight blocker.
6. Request Family Controls distribution access for the app and applicable
   extensions before TestFlight/App Store distribution. No request has been submitted.

The shield's action leaves the selected app. Rich activity and override controls
remain inside Sleep App.

## Verification

Run the core cases using the standalone host runner:

    python3 scripts/check_core.py

Exercise blocking preference save failures and inspect signing setup:

    python3 scripts/check_blocking_preferences.py
    python3 scripts/check_blocking_setup.py

The setup check reports configuration gaps; it does not grant capabilities or
prove that an account is enrolled. Its optional `--app` argument reads the actual
entitlements and provisioning profiles of a signed iPhone build.

With full Xcode and XCTest available:

    swift test
    xcodebuild -project SleepApp.xcodeproj -scheme SleepAppPreview \
      -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
      CODE_SIGNING_ALLOWED=NO build

The SleepAppPreview scheme has been built and launched on the iPhone 17 Pro
simulator with iOS 26.3. To type-check the full native iPhone code without signing:

    python3 scripts/check_ios_types.py

Type-checking does not link or install the full device app. Simulator compilation
also does not establish physical-device Screen Time reliability.

To regenerate the checked-in Xcode project deterministically:

    python3 scripts/generate_project.py

## Code map

| Location | Responsibility |
| --- | --- |
| Sources/SleepCore | Calendar logic, reminders, protection decisions, journal model, persistence, original content |
| App | SwiftUI screens, observable state, saved breathing preferences, local reminders, native protection controller |
| Native | App Group settings and shield reconciliation shared with the monitor |
| Extensions | Native monitoring, shield appearance, and shield actions |
| Tests/SleepCoreTests | The same 46 cases used by XCTest and the command-line runner |
| Design | Editable Figma composition and its metadata |
| docs | Build evidence, product decisions, and remaining release gates |

Days name the day wind-down **starts**. For example, Monday 11:45 PM wind-down for
a 12:15 AM bedtime belongs to Monday's selected night. Schedules use local time.
Later plan changes do not rewrite the bedtime target for an earlier night.

## Design

[First editable Tonight screen](https://www.figma.com/design/GHtxtKhVYQiFi6HP5EP2xD?node-id=6-98)

Figma uses Inter by Alec's choice because Figma reported SF Pro as missing.
The app retains native system typography. Figma reference icons use Lucide
vectors; the app uses SF Symbols. Both use the same dark navy/lavender palette,
card hierarchy, and pinned primary action. The Figma screen is a static editable
reference, while the native preview is interactive.

## Next milestone

Test a complete routine on iPhone: save preferences once, receive an optional reminder, finish
breathing, and complete a morning check-in. Continue accessibility and
small-screen checks. Validate optional app-limit enforcement separately when a
capable developer team is available. See docs/BUILD_STATUS.md for remaining checks.

## Primary platform references

- [Family Controls distribution entitlement](https://developer.apple.com/documentation/FamilyControls/requesting-the-family-controls-entitlement)
- [Device Activity schedules](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule)
- [Device Activity callback timing and time zones](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule/nextinterval)
- [Managed Settings](https://developer.apple.com/documentation/managedsettings)
- [Local notification scheduling](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [Monitor extension identifier](https://developer.apple.com/forums/thread/819904)
- [Required-reason privacy declarations](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
