# macOS Xcode Cloud

Anycast Scout GUI uses the same macOS release shape as `pingle-gui`: GitLab
keeps the source repository and Linux release path, while Xcode Cloud owns the
Developer ID macOS archive for `release-macos-v*` tags.

## App Store Connect

- Team: `5ccd33ce-d5ef-4a45-8c46-1121af557dbf`
- Xcode Cloud page:
  `https://appstoreconnect.apple.com/teams/5ccd33ce-d5ef-4a45-8c46-1121af557dbf/apps/6762176612/ci/groups`
- Repository: `pingle_software/tools/anycast-scout/gui`
- Workspace: `macos/Runner.xcworkspace`
- Scheme: `Runner`
- Archive trigger: tags matching `release-macos-v*`

The App Store Connect workflow UI must hold the custom environment variables.
The public workflow API does not expose custom environment variable mutation, so
repository changes can prepare the workflow but cannot fill those values from
Git.

## Required Xcode Cloud Variables

- `ANYCAST_SCOUT_GITLAB_TOKEN`: token allowed to clone
  `pingle_software/tools/anycast-scout/backend`.
- `ANYCAST_SCOUT_NOTARY_PRIVATE_KEY_B64`: base64-encoded App Store Connect
  `.p8` private key for notarization. `ANYCAST_SCOUT_NOTARY_PRIVATE_KEY` with
  the raw key text is also supported.
- `ANYCAST_SCOUT_NOTARY_KEY_ID`: App Store Connect API key ID. Defaults to
  `T26WGR4HML`.
- `ANYCAST_SCOUT_NOTARY_ISSUER_ID`: App Store Connect issuer UUID. Defaults to
  `5ccd33ce-d5ef-4a45-8c46-1121af557dbf`.
- `ANYCAST_SCOUT_NOTARY_KEYCHAIN_PROFILE`: optional notarytool keychain profile
  name for local or pre-provisioned runners. If set, it takes precedence over
  the raw API key variables.
- `ANYCAST_SCOUT_BACKEND_REF`: optional override for the backend commit or tag;
  defaults to `backend.ref`.
- `ANYCAST_SCOUT_RUST_TOOLCHAIN`: optional Rust version; defaults to `1.95`.
- `ANYCAST_SCOUT_NOTARY_WEBHOOK_URL`: optional notarytool webhook callback.
- `ANYCAST_SCOUT_NOTARY_NO_S3_ACCELERATION=1`: optional notarytool compatibility
  flag.

## Build Flow

`macos/ci_scripts/ci_post_clone.sh` prepares Flutter, Rust, CocoaPods, and a
release backend bundle under `.xcode-cloud/backend-bundle`.

The Runner target has a `Bundle Anycast Backend` build phase. During Xcode Cloud
archives it copies that backend bundle into:

- `Anycast Scout by Pingle.app/Contents/Resources/backend/anycast-scout`

`macos/ci_scripts/ci_post_xcodebuild.sh` validates the archived app, notarizes it
when the keychain profile is configured, staples the notarization ticket, and
writes a final `*-developer-id-notarized.zip` artifact.

## Tags

Use:

```bash
tools/release/tag_desktop_release.sh 1.2.3
```

The script creates and pushes:

- `v1.2.3` for the existing GitLab desktop release pipeline.
- `release-macos-v1.2.3` for the Xcode Cloud macOS archive workflow.
