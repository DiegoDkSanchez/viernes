#!/usr/bin/env python3
"""Copy local Firebase app configuration into the native Flutter projects."""

import json
from pathlib import Path
import plistlib
import shutil
import sys


def main() -> int:
    config_dir = Path(__file__).resolve().parent
    project_dir = config_dir.parent
    configs = (
        ("google-services.json", "android/app", json.loads),
        ("GoogleService-Info.plist", "ios/Runner", plistlib.loads),
    )
    pending = []

    # Validate every supplied file before replacing any installed configuration.
    for filename, target, parse in configs:
        source = config_dir / filename
        if not source.exists():
            print(f"Skipped {filename}: not present in firebase_config/.")
            continue
        destination = project_dir / target / filename
        try:
            if not isinstance(parse(source.read_bytes()), dict):
                raise ValueError("configuration must contain an object/dictionary")
            if not destination.parent.is_dir():
                raise ValueError(f"missing project directory: {target}")
        except (OSError, ValueError, plistlib.InvalidFileException) as error:
            print(f"Cannot install {filename}: {error}", file=sys.stderr)
            return 1
        pending.append((source, destination))

    if not pending:
        print("Add google-services.json and/or GoogleService-Info.plist to "
              "firebase_config/, then run this script again.", file=sys.stderr)
        return 1

    for source, destination in pending:
        try:
            if destination.exists() and source.read_bytes() == destination.read_bytes():
                print(f"Already up to date: {destination.relative_to(project_dir)}")
                continue
            shutil.copyfile(source, destination)
        except OSError as error:
            print(f"Cannot copy {source.name}: {error}", file=sys.stderr)
            return 1
        print(f"Installed {destination.relative_to(project_dir)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
