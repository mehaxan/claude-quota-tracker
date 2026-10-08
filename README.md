# BedrockMeter

[![CI](https://github.com/mehaxan/claude-quota-tracker/actions/workflows/ci.yml/badge.svg)](https://github.com/mehaxan/claude-quota-tracker/actions/workflows/ci.yml)

A macOS menu bar app that tracks Claude usage quota against an AWS Bedrock
`credential-process` backend. Formerly named ClaudeQuotaMenuBar; this repo
kept its original name (`claude-quota-tracker`) but the app and its Homebrew
cask are now BedrockMeter.

## Installation

Install via Homebrew:

```sh
brew tap mehaxan/claude-quota-tracker
brew trust mehaxan/claude-quota-tracker
brew install --cask bedrock-meter
```

> **Note:** `BedrockMeter` is signed ad-hoc only (not notarized by Apple).
> The cask strips the quarantine flag after install so Gatekeeper won't block
> it, but macOS may still show a first-launch warning.

### Manual install

Download the `.dmg` from the [latest release](https://github.com/mehaxan/claude-quota-tracker/releases/latest), open it, and drag `BedrockMeter.app` into `/Applications`.

## Configuration

Open **Settings…** from the menu bar icon to set:

- **credential-process path** — defaults to `~/claude-code-with-bedrock/credential-process`
- **AWS profile** — defaults to `oec-prod-us-east-1`
- **Refresh interval** — how often quota is checked, in minutes. Defaults to 15, minimum 1.

These can also be set via environment variables (`CLAUDE_QUOTA_BINARY`,
`CLAUDE_QUOTA_PROFILE`, `CLAUDE_QUOTA_REFRESH_INTERVAL` in seconds), which take
precedence over the Settings window.

## Updating

BedrockMeter checks the GitHub releases page for a newer version shortly
after launch and once a day after that. If an update is available, or if you
pick **Check for Updates…** from the menu bar icon yourself, it offers to
download and install it in place, then relaunch.

## Development

```sh
swift build          # build
swift test           # run unit tests
./scripts/build-dmg.sh  # build dist/BedrockMeter.app and dist/BedrockMeter.dmg
./scripts/build-icon.sh # regenerate Resources/AppIcon.icns after an icon design change
```

### Releasing

Pushing to `main` with a bumped `CFBundleShortVersionString` in
`Resources/Info.plist` triggers `.github/workflows/release.yml`, which tags
the commit, builds and publishes the `.dmg` as a GitHub release, and updates
the `bedrock-meter` cask in the
[homebrew-claude-quota-tracker](https://github.com/mehaxan/homebrew-claude-quota-tracker)
tap. Merges that don't change the version are a no-op.

The tap-update step needs a repository secret `HOMEBREW_TAP_TOKEN` — a
personal access token with write access to that tap repo, since the default
`GITHUB_TOKEN` can't push to a different repository.
