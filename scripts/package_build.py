#!/usr/bin/env python3
"""Package source and the native preview, excluding caches and local diary data."""
from pathlib import Path
import os
import stat
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
destination = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root/"Artifacts"/"SleepApp_First_Build.zip"
app = root/"Artifacts"/"SleepAppPreview.app"
if not (app/"Contents"/"MacOS"/"SleepPreview").is_file():
    raise SystemExit("Build the preview first: python3 scripts/build_preview.py")
destination.parent.mkdir(parents=True,exist_ok=True)
excluded = {".build",".swiftpm",".git",".preview-data","__pycache__","Artifacts","DerivedData","xcuserdata",".xcodebuildmcp"}
paths = []
for directory, children, files in os.walk(root):
    children[:] = [name for name in children if name not in excluded]
    for name in files:
        path = Path(directory)/name
        if name != ".DS_Store" and path != destination and path.name != "Local.xcconfig":
            paths.append(path)
paths.extend(path for path in app.rglob("*") if path.is_file() and path.name != ".DS_Store")
with zipfile.ZipFile(destination,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=7) as archive:
    for path in sorted(paths):
        archive.write(path,"SleepApp/"+path.relative_to(root).as_posix())
with zipfile.ZipFile(destination) as archive:
    assert archive.testzip() is None
    names = set(archive.namelist())
    for expected in ["SleepApp/README.md","SleepApp/Package.swift",
                     "SleepApp/SleepApp.xcodeproj/project.pbxproj",
                     "SleepApp/Artifacts/SleepAppPreview.app/Contents/MacOS/SleepPreview"]:
        assert expected in names,expected
    mode = archive.getinfo("SleepApp/Artifacts/SleepAppPreview.app/Contents/MacOS/SleepPreview").external_attr >> 16
    assert mode & stat.S_IXUSR, "Preview executable lost its executable permission"
print(f"Packaged {len(paths)} files; {destination.stat().st_size:,} bytes; archive integrity passed")
print(destination)
