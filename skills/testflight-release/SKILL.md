---
name: testflight-release
description: Use when you need to build the iOS PlynKeyboard archive and upload it to TestFlight from this repo, especially for repeatable release pushes through Xcode automatic signing.
---

# TestFlight Release

Use this skill to produce a real iOS release archive for this repository's `PlynKeyboard` app and upload it to TestFlight using the Xcode account already configured on the Mac.

## When To Use It

- The user asks to push or upload the iOS app to TestFlight.
- The task is specific to this repo's `ios/PlynKeyboard.xcworkspace` workspace and `PlynKeyboard` scheme.
- You need a repeatable archive-and-upload flow instead of recreating the `xcodebuild` commands manually.

## Preconditions

- Run from the repo root.
- Xcode must already have a developer account that can sign for team `ZCY45NFH6D`.
- The next uploaded build number must be higher than the last uploaded build for the same marketing version.
- The upload flow depends on Xcode automatic signing and App Store Connect access already working on this machine.

## Workflow

1. Pick a fresh build number.

   A UTC timestamp is the safest default because it is naturally increasing, for example `20260406213045`.

2. Update `CURRENT_PROJECT_VERSION` in the Xcode project.

   Use `scripts/set_ios_build_number.sh <build-number>`.

3. Archive and upload.

   Use `scripts/upload_ios_testflight.sh --build-number <build-number>`.

4. Check the terminal output.

   Success looks like `Uploaded package is processing` followed by `Upload succeeded`.

5. If Apple rejects the upload because the build number was already used, bump it again and rerun.

## Commands

```bash
skills/testflight-release/scripts/set_ios_build_number.sh 20260406213045
skills/testflight-release/scripts/upload_ios_testflight.sh --build-number 20260406213045
```

The upload script also supports:

- `--dry-run` to print the commands without executing them
- `--skip-build-number-update` if the project file was already updated
- `--archive-path <path>` to control where the `.xcarchive` is created
- `--export-path <path>` to control the upload/export working directory

## Files This Skill Touches

- `ios/PlynKeyboard.xcodeproj/project.pbxproj`
- temporary files in `/tmp`

## Notes

- This repo's proven upload path uses `xcodebuild -exportArchive` with `destination = upload` and `method = app-store-connect`.
- The archive step may show `Apple Development` signing, while the upload/export step can re-sign with a store distribution certificate managed by Xcode/App Store Connect.
- This skill does not use `altool` by default because the verified repo workflow succeeded through `xcodebuild` upload directly.

## Troubleshooting

See `references/testflight-troubleshooting.md` for the failure modes already observed and the fixes that worked.
