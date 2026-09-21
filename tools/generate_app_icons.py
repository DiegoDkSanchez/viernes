"""Regenerate Android/iOS icons with ImageMagick (`magick`)."""

import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/app_icon.png"


def render(destination: Path, size: int) -> None:
    subprocess.run(
        [
            "magick", str(SOURCE), "-background", "#fcf7e7",
            "-alpha", "remove", "-alpha", "off",
            "-resize", f"{size}x{size}", "-strip",
            f"PNG24:{destination}",
        ],
        check=True,
    )


def main() -> None:
    android = ROOT / "android/app/src/main/res"
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                          "xxhdpi": 144, "xxxhdpi": 192}.items():
        render(android / f"mipmap-{density}/ic_launcher.png", size)

    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    catalog = json.loads((ios / "Contents.json").read_text())
    sizes = {
        entry["filename"]: round(float(entry["size"].split("x")[0])
                                 * float(entry["scale"].removesuffix("x")))
        for entry in catalog["images"]
    }
    for filename, size in sizes.items():
        render(ios / filename, size)
    print(f"Generated 5 Android and {len(sizes)} iOS icons.")


if __name__ == "__main__":
    main()
