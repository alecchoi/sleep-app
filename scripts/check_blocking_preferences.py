#!/usr/bin/env python3
"""Exercise actual AppModel preference persistence and failures with the preview service."""
from pathlib import Path
import os
import subprocess

root = Path(__file__).resolve().parents[1]
output = root / ".build/blocking-preferences"
output.mkdir(parents=True, exist_ok=True)
environment = os.environ.copy()
environment["CLANG_MODULE_CACHE_PATH"] = str(output / "module-cache")
environment["SWIFTPM_MODULECACHE_OVERRIDE"] = str(output / "module-cache")
subprocess.run([
    "swiftc", "-swift-version", "5", "-emit-library", "-emit-module", "-module-name", "SleepCore",
    *map(str, sorted((root / "Sources/SleepCore").glob("*.swift"))),
    "-o", str(output / "libSleepCore.dylib"), "-emit-module-path", str(output / "SleepCore.swiftmodule")
], cwd=root, env=environment, check=True)
binary = output / "BlockingPreferenceChecks"
subprocess.run([
    "swiftc", "-disable-sandbox", "-swift-version", "5", "-parse-as-library", "-D", "DEBUG", "-D", "SLEEPAPP_PREVIEW",
    "-I", str(output), "-L", str(output), "-lSleepCore",
    "-Xlinker", "-rpath", "-Xlinker", "@loader_path",
    *[str(root / path) for path in ["App/AppModel.swift", "App/ProtectionController.swift",
                                   "App/ReminderController.swift", "App/Theme.swift",
                                   "scripts/BlockingPreferenceChecks.swift"]],
    "-o", str(binary)
], cwd=root, env=environment, check=True)
subprocess.run([str(binary), "--data-directory", str(output / "test-data")], cwd=root, check=True)
