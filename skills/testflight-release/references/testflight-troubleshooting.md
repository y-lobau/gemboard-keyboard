# TestFlight Troubleshooting

## Verified Repo Settings

- Workspace: `ios/PlynKeyboard.xcworkspace`
- Scheme: `PlynKeyboard`
- Team ID: `ZCY45NFH6D`
- Bundle ID: `com.holas.plynkeyboard`
- Keyboard extension bundle ID: `com.holas.plynkeyboard.keyboard`

## Known Good Upload Flow

The proven upload path for this repo is:

1. `xcodebuild archive ... -allowProvisioningUpdates`
2. `xcodebuild -exportArchive ...` with export options:
   - `destination = upload`
   - `method = app-store-connect`
   - `signingStyle = automatic`
   - `teamID = ZCY45NFH6D`

## Common Failures

### The bundle version must be higher than the previously uploaded version

Meaning:

- `CURRENT_PROJECT_VERSION` is too low for the current marketing version.

Fix:

- Pick a higher integer build number.
- Update it with `scripts/set_ios_build_number.sh <build-number>`.
- Retry the archive and upload.

### altool asks for JWT or username/app-password authentication

Meaning:

- `altool` is not inheriting the Xcode account session for this repo.

Fix:

- Prefer the `xcodebuild -exportArchive` upload flow from this skill instead of `altool`.

### Archive signs with Apple Development

Meaning:

- The local archive may use a development identity during the archive phase.

Fix:

- This is acceptable if the export/upload step successfully re-signs with a store distribution certificate.
- Check the export summary or upload output instead of assuming the archive identity is the final store identity.

### Upload does not start because provisioning cannot be updated

Meaning:

- Xcode does not have a usable Apple account or enough team permissions on this Mac.

Fix:

- Open Xcode and confirm the developer account for team `ZCY45NFH6D` is signed in and can manage automatic signing.
