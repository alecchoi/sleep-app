#!/usr/bin/env python3
"""Type-check the full iPhone code against the SDK without signing or installation."""
from pathlib import Path
import os
import subprocess

root = Path(__file__).resolve().parents[1]
output = root/".build"/"ios-typecheck"
output.mkdir(parents=True,exist_ok=True)
sdk = subprocess.check_output(["xcrun","--sdk","iphoneos","--show-sdk-path"],text=True).strip()
compiler = subprocess.check_output(["xcrun","--find","swiftc"],text=True).strip()
environment = os.environ.copy()
environment["CLANG_MODULE_CACHE_PATH"] = str(output/"module-cache")
base = [compiler,"-disable-sandbox","-swift-version","5","-target","arm64-apple-ios17.0",
        "-sdk",sdk,"-module-cache-path",str(output/"module-cache"),"-parse-as-library"]
subprocess.run([
    *base,"-emit-module","-module-name","SleepCore",
    *map(str,sorted((root/"Sources"/"SleepCore").glob("*.swift"))),
    "-emit-module-path",str(output/"SleepCore.swiftmodule")
],env=environment,cwd=root,check=True)
groups = {
    "SleepApp":[*sorted((root/"App").glob("*.swift")),root/"Native"/"SharedDeviceStore.swift"],
    "ActivityMonitor":[root/"Extensions"/"ActivityMonitor"/"SleepActivityMonitor.swift",root/"Native"/"SharedDeviceStore.swift"],
    "ShieldConfiguration":[root/"Extensions"/"ShieldConfiguration"/"SleepShieldConfiguration.swift"],
    "ShieldAction":[root/"Extensions"/"ShieldAction"/"SleepShieldAction.swift"]
}
for module,paths in groups.items():
    subprocess.run([
        *base,"-typecheck","-module-name",module,"-I",str(output),"-D","DEBUG",
        *map(str,paths)
    ],env=environment,cwd=root,check=True)
    print(f"PASS iPhone SDK type-check: {module}",flush=True)
print("Type-checking passed. Code signing, linking and on-device enforcement remain separate checks.")
