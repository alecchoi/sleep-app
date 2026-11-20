#!/usr/bin/env python3
"""Build an Apple Silicon/host Mac preview from the actual shared SwiftUI code."""
from pathlib import Path
import os
import plistlib
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
environment = os.environ.copy()
environment["CLANG_MODULE_CACHE_PATH"] = "/tmp/sleepapp-clang-cache"
environment["SWIFTPM_MODULECACHE_OVERRIDE"] = "/tmp/sleepapp-swift-cache"
command = ["swift", "build", "--disable-sandbox", "--cache-path", ".build/cache",
           "--config-path", ".build/config", "--security-path", ".build/security",
           "--scratch-path", ".build"]
subprocess.run([*command, "--product", "SleepPreview"], cwd=root, env=environment, check=True)
binary_path = Path(subprocess.check_output([*command, "--show-bin-path"], cwd=root, env=environment, text=True).strip())
bundle = root / "Artifacts" / "SleepAppPreview.app" / "Contents"
(bundle/"MacOS").mkdir(parents=True, exist_ok=True)
(bundle/"Resources").mkdir(exist_ok=True)
shutil.copy2(binary_path/"SleepPreview", bundle/"MacOS"/"SleepPreview")
icon = root/"App"/"Assets.xcassets"/"AppIcon.appiconset"/"AppIcon.png"
if icon.exists():
    shutil.copy2(icon, bundle/"Resources"/"AppIcon.png")
(bundle/"Info.plist").write_bytes(plistlib.dumps({
    "CFBundleName":"Sleep App Preview", "CFBundleDisplayName":"Sleep App Preview",
    "CFBundleIdentifier":"com.sleepapp.local-preview", "CFBundleExecutable":"SleepPreview",
    "CFBundlePackageType":"APPL", "CFBundleShortVersionString":"0.2.0", "CFBundleVersion":"2",
    "LSMinimumSystemVersion":"14.0", "NSHighResolutionCapable":True,
    "CFBundleIconFile":"AppIcon.png"
}))
subprocess.run(["codesign","--force","--deep","--sign","-",str(bundle.parent)], check=True)
print(f"\nBuilt {bundle.parent}")
