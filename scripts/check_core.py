#!/usr/bin/env python3
"""Run the project's actual core test cases without requiring the XCTest SDK."""
from pathlib import Path
import os
import subprocess

root = Path(__file__).resolve().parents[1]
output = root / ".build" / "core-checks"
output.mkdir(parents=True, exist_ok=True)
environment = os.environ.copy()
environment["CLANG_MODULE_CACHE_PATH"] = str(output / "clang-cache")
environment["SWIFTPM_MODULECACHE_OVERRIDE"] = str(output / "swift-cache")

subprocess.run([
    "swiftc", "-swift-version", "5", "-emit-library", "-emit-module",
    "-enable-testing", "-module-name", "SleepCore",
    *map(str, sorted((root / "Sources" / "SleepCore").glob("*.swift"))),
    "-o", str(output / "libSleepCore.dylib"),
    "-emit-module-path", str(output / "SleepCore.swiftmodule")
], cwd=root, env=environment, check=True)
subprocess.run([
    "swiftc", "-swift-version", "5", "-parse-as-library",
    "-I", str(output), "-L", str(output), "-lSleepCore",
    "-Xlinker", "-rpath", "-Xlinker", "@loader_path",
    str(root / "scripts" / "CoreCheckRunner.swift"),
    *map(str, sorted((root / "Tests" / "SleepCoreTests").glob("*.swift"))),
    "-o", str(output / "SleepCoreChecks")
], cwd=root, env=environment, check=True)
subprocess.run([str(output / "SleepCoreChecks")], cwd=root, check=True)
