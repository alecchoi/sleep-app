#!/usr/bin/env python3
"""Check Screen Time project wiring and, optionally, a signed iPhone app.

This reads local files only; it never changes signing or requests capabilities.
"""
import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {
    "SleepApp": None,
    "ActivityMonitor": "com.apple.deviceactivity.monitor-extension",
    "ShieldConfiguration": "com.apple.ManagedSettingsUI.shield-configuration-service",
    "ShieldAction": "com.apple.ManagedSettings.shield-action-service",
}
FAMILY = "com.apple.developer.family-controls"
GROUPS = "com.apple.security.application-groups"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, help="Signed physical-device SleepApp.app to inspect")
    args = parser.parse_args()
    failures = []

    def check(condition, description):
        print(f"{'PASS' if condition else 'NEEDS SETUP'} {description}")
        if not condition:
            failures.append(description)

    def plist(path):
        return plistlib.loads(path.read_bytes())

    settings = {}

    def read_config(path):
        if not path.exists():
            return
        for line in path.read_text().splitlines():
            include = re.match(r'#include\??\s+"([^"]+)"', line)
            assignment = re.match(r"(\w+)\s*=\s*(.*?)\s*(?://.*)?$", line)
            if include:
                read_config(path.parent / include[1])
            elif assignment:
                settings[assignment[1]] = assignment[2].strip()

    read_config(ROOT / "Config/Project.xcconfig")
    project = json.loads(subprocess.check_output([
        "plutil", "-convert", "json", "-o", "-", str(ROOT / "SleepApp.xcodeproj/project.pbxproj")
    ]))
    objects = project["objects"]
    targets = {obj["name"]: obj for obj in objects.values() if obj.get("isa") == "PBXNativeTarget"}
    teams = {"Debug": [], "Release": []}
    for name, point in TARGETS.items():
        target = targets[name]
        for config_id in objects[target["buildConfigurationList"]]["buildConfigurations"]:
            config = objects[config_id]
            build = config["buildSettings"]
            entitlements = plist(ROOT / build["CODE_SIGN_ENTITLEMENTS"])
            info = plist(ROOT / build["INFOPLIST_FILE"])
            check(entitlements.get(FAMILY) is True and entitlements.get(GROUPS) == ["$(APP_GROUP_IDENTIFIER)"],
                  f"{name} {config['name']}: Family Controls and shared App Group declared")
            check(info.get("SleepAppGroupIdentifier") == "$(APP_GROUP_IDENTIFIER)",
                  f"{name} {config['name']}: shared storage identifier matches")
            if point:
                check(info.get("NSExtension", {}).get("NSExtensionPointIdentifier") == point,
                      f"{name} {config['name']}: extension entry point")
            teams[config["name"]].append(build.get("DEVELOPMENT_TEAM", settings.get("DEVELOPMENT_TEAM", "")))

    embedded = set()
    for phase_id in targets["SleepApp"]["buildPhases"]:
        phase = objects[phase_id]
        if phase["isa"] == "PBXCopyFilesBuildPhase" and int(phase.get("dstSubfolderSpec", 0)) == 13:
            for file_id in phase["files"]:
                embedded.add(objects[objects[file_id]["fileRef"]]["path"])
    check(embedded == {name + ".appex" for name in TARGETS if name != "SleepApp"},
          "Full app embeds all three Screen Time extensions")
    for mode, values in teams.items():
        check(all(values) and len(set(values)) == 1 and values[0] != "YOUR_PAID_TEAM_ID",
              f"{mode}: same development team assigned to all four targets")

    if args.app:
        bundles = [args.app] + [args.app / "PlugIns" / (name + ".appex") for name in TARGETS if name != "SleepApp"]
        group_sets, signed_teams = [], []
        for bundle in bundles:
            try:
                signed = plistlib.loads(subprocess.check_output(
                    ["codesign", "-d", "--entitlements", ":-", str(bundle)], stderr=subprocess.PIPE))
                profile = plistlib.loads(subprocess.check_output(
                    ["security", "cms", "-D", "-i", str(bundle / "embedded.mobileprovision")], stderr=subprocess.PIPE))
                allowed = profile.get("Entitlements", {})
                groups = signed.get(GROUPS, [])
                check(signed.get(FAMILY) is True and allowed.get(FAMILY) is True,
                      f"{bundle.name}: signed entitlement and provisioning profile permit Family Controls")
                check(bool(groups) and set(groups).issubset(set(allowed.get(GROUPS, []))),
                      f"{bundle.name}: provisioning profile permits the signed App Group")
                group_sets.append(set(groups))
                signed_teams.append(signed.get("com.apple.developer.team-identifier"))
            except (OSError, ValueError, subprocess.CalledProcessError):
                check(False, f"{bundle.name}: readable iPhone signature and provisioning profile required")
        check(len(group_sets) == 4 and all(group_sets[0] == groups for groups in group_sets),
              "Signed app and all extensions share the same App Group")
        check(len(signed_teams) == 4 and all(signed_teams) and len(set(signed_teams)) == 1,
              "Signed app and all extensions belong to the same developer team")
    else:
        print("NOT VERIFIED: paid membership, signed provisioning profiles, or on-device enforcement.")
        print("Inspect a signed build with --app /path/to/SleepApp.app before device testing.")

    print(f"\n{len(failures)} setup issue(s). Source declarations alone do not grant Apple capabilities.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
