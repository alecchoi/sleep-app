# App blocking: findings and fixes

Reviewed November 19, 2026, America/New_York.

**Opal-style app blocking is possible with Apple's public Screen Time APIs.**
Opal's own [help center](https://help.opalapp.com/article/why-do-i-need-to-grant-screen-time-permission)
confirms this is the technology it uses. Sleep App already had the framework
integration; this change fixes enforcement lifecycle bugs and identifies the
remaining signing requirements. Real iPhone blocking has not yet been verified.

## How it works

| Component | Role in Sleep App |
| --- | --- |
| Family Controls | Request the owner's permission using `requestAuthorization(for: .individual)` and present Apple's `FamilyActivityPicker` |
| Managed Settings | Cover selected apps, categories, and websites with a system shield |
| Device Activity | Register selected-night schedules and let the monitor extension update shields while the main app is not running |
| Shield Configuration extension | Supply the Sleep App shield's appearance |
| Shield Action extension | Handle the shield's “Leave this app” button |
| App Group | Share the bedtime plan, private selection tokens, and enforcement intent between the app and monitor |

Individual authorization has been available since iOS 16. Sleep App targets
iOS 17, so an adult can authorize their own phone without a parent or a second
device. A VPN or a backend is not needed for this implementation.

The picker returns opaque tokens. We pass those tokens back to Apple's APIs;
we do not need a list of installed apps, hardcoded Instagram bundle identifiers,
or access to the selected app's contents. Authorization revocation invalidates
the tokens, so the user must select apps again after restoring permission.

## Why the current build cannot block

| Build or account | What it supports |
| --- | --- |
| SleepAppPreview, including a preview installed on iPhone | Routine features; Screen Time authorization and blocking are deliberately compiled out |
| iPhone simulator | UI, compilation, and extension packaging checks; this project disables enforcement in the simulator |
| Free Personal Team | Cannot sign the Family Controls capability needed by the full app |
| Apple Developer Program team | Development provisioning for the full app and extensions, followed by real iPhone testing |
| TestFlight or App Store | Separate Family Controls distribution approval for the app and each Screen Time extension, plus correctly provisioned builds |

Apple lists the Developer Program at **US $99 per membership year**, with
regional pricing and applicable eligibility exceptions. Development access and
distribution approval are separate: the distribution request is not required
just to begin development testing with correctly provisioned development builds.
Approval and account membership cannot be created by editing an entitlements file.

The current project declares the correct Family Controls and App Group
entitlements, extension entry points, and embedded extensions. Its main app has
a target-level team assignment; all three extensions currently inherit an empty
team. Debug and Release therefore both need consistent signing configuration.
The team ID alone does not establish whether membership is active or capable.

## Fixes made

- Explicitly switching protection off now clears nightly intent, test deadlines,
  overrides, monitoring registrations, and the named Managed Settings store.
  Turning it off also works with an invalid plan or unavailable shared storage.
  A failed journal save does not turn blocking back on, including after relaunch.
- Authorization, selection, and storage failures during enablement now enter
  cleanup instead of leaving an older block in place.
- Refresh reconciles shared enforcement with the saved app preference and
  repairs missing or stale weekday registrations.
- A late end callback from an earlier test no longer deletes a newer test's
  deadline. Deadlines use the same whole-second precision as the OS schedule.
- Stopping a test restores any active nightly rule; it does not silently bypass
  that rule. Expiration also restores an existing current-night override.
- Revocation is observed while the app is open. Invalid selection tokens are
  cleared, monitoring is stopped, and shields are removed.
- Saving an empty selection is now valid and turns protection off, rather than
  rejecting the edit and restoring unwanted targets.
- Preview setup explains that installation on iPhone does not add Screen Time
  access. Nightly controls and test actions have accessibility identifiers.

`Sources/SleepCore/ProtectionSession.swift` contains the enforcement transitions
used by shared storage and the monitor. Existing stored preference keys are
retained, so these changes do not require deleting a user's plan or journal.

## Verification

| Check | Result |
| --- | --- |
| Core regression runner | 30 cases, zero failures, including five new enforcement lifecycle cases |
| App preference failure checks | Two cases pass against the actual AppModel with the preview service: failed journal save and stale enabled preference |
| iPhone SDK type checks | Main app and all three extensions pass |
| Full SleepApp simulator build | Succeeded; includes embedded ActivityMonitor, ShieldConfiguration, and ShieldAction extensions |
| Source signing preflight | Entitlement declarations, shared storage keys, extension entry points, and embedding pass; team assignment needs setup in Debug and Release |
| Signed iPhone installation and live shields | Not verified |
| Family Controls distribution approval | Not verified; no request was submitted during this work |

The simulator app uses the unsupported-enforcement path. Its successful build
does not prove the physical-device controller or OS enforcement at runtime.
The iPhone controller is additionally checked against the actual iPhone SDK.
An unsigned device link attempted through the shell could not finish because
the execution environment denied SwiftPM access to its manifest cache.

## Complete device setup

1. Use an active Apple Developer Program team. In Xcode choose **SleepApp**,
   rather than SleepAppPreview, and select the same team for SleepApp,
   ActivityMonitor, ShieldConfiguration, and ShieldAction, in both configurations.
2. Use unique app and extension identifiers and register the same App Group on
   all four. `Config/Local.xcconfig.example` provides the local configuration
   template. A team selected directly on a target overrides the xcconfig value;
   update those target assignments as well.
3. Enable Family Controls and App Groups on the four identifiers and use updated
   provisioning profiles. Build and install the full app on an iPhone.
4. Run `python3 scripts/check_blocking_setup.py`. To inspect actual signatures
   and embedded profiles, also run it with `--app /path/to/SleepApp.app` using a
   signed physical-device build. Source declarations alone do not prove access.

   Regression checks can also be repeated with `python3 scripts/check_core.py`
   and `python3 scripts/check_blocking_preferences.py`. The preference runner
   uses only its own temporary journal and does not request Screen Time access.
5. In Sleep App, open app protection, allow Screen Time, select one distraction,
   save, and run the 20-minute test. Open the selected app and confirm its shield.
6. Verify manual stop with nightly protection off; off during a running test;
   test expiration; restarting a test; clearing the selection; permission
   revocation and reselection; and access to unselected essential apps.
7. Verify an overnight schedule, wake-time removal, selected weekdays, current-
   night override, app termination/relaunch, and time-zone changes on the phone.
8. Before TestFlight/App Store distribution, request Family Controls distribution
   access for all four bundle identifiers and verify the approved profiles.

## Limits to keep in the product promises

- We can shield selected whole apps and supported websites. These APIs do not
  provide a way to disable only Instagram Reels while leaving Instagram DMs open.
- Individual authorization is voluntary. Apple does not automatically apply
  parental app-deletion protection to individual authorization. We should not
  promise that a user can never bypass or remove this app.
- Device Activity callbacks are system-managed. Apple says they can occur when
  the device is used, rather than at an exact wall-clock instant. The monitor
  therefore reconciles current intent and time on callbacks; precise overnight
  behavior still needs device testing.
- Apple's minimum Device Activity monitoring interval is 15 minutes. The test
  remains 20 minutes; sub-15-minute automatic sessions need a separately designed
  and validated approach.

## Primary sources

- [Opal: why Screen Time permission is required](https://help.opalapp.com/article/why-do-i-need-to-grant-screen-time-permission)
- [Apple: individual authorization and shared named settings stores](https://developer.apple.com/videos/play/wwdc2022/110336/)
- [Apple: configuring Family Controls and development access](https://developer.apple.com/documentation/xcode/configuring-family-controls)
- [Apple: requesting distribution access for app and extensions](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
- [Apple: supported capabilities by membership](https://developer.apple.com/help/account/reference/supported-capabilities-ios)
- [Apple: membership enrollment and pricing](https://developer.apple.com/programs/enroll/)
- [Apple: selection tokens and revocation](https://developer.apple.com/documentation/familycontrols/familyactivityselection)
- [Apple: shield settings](https://developer.apple.com/documentation/managedsettings/shieldsettings)
- [Apple: callback timing and time zones](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule/nextinterval)
- [Apple: minimum monitoring interval](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort)
