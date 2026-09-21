# Firebase configuration

After cloning the repository, place the Firebase app configuration files here:

| File | Installed location |
| --- | --- |
| `google-services.json` (Android) | `android/app/google-services.json` |
| `GoogleService-Info.plist` (iOS) | `ios/Runner/GoogleService-Info.plist` |

Download each platform's own file from Firebase project settings. The Android
JSON cannot be used as the iOS plist. Either file can be supplied independently.
Both source and installed configuration files are ignored by Git.

From the repository root, run with Python 3 (no dependencies required):

```sh
python3 firebase_config/setup.py
```

You can also run `python3 -m firebase_config.setup` from the repository root,
or run the script by its absolute path from any working directory. On Windows,
use `py` instead of `python3` if needed.

The script keeps the originals here, replaces existing destination files, and
skips missing platforms. Repeated runs leave identical files unchanged. Invalid
JSON/plist files or no supplied files produce a nonzero exit status.

This installs the files only. For initial iOS setup, add the installed plist to
the Runner target in Xcode and configure the Google sign-in URL scheme described
in the root README. These Xcode changes can then be committed for other machines.
