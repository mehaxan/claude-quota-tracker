# ClaudeQuotaMenuBar

A macOS menu bar app for tracking Claude usage quota.

## Installation

Install via Homebrew:

```sh
brew tap mehaxan/claude-quota-tracker
brew trust mehaxan/claude-quota-tracker
brew install --cask claude-quota-menu-bar
```

> **Note:** `ClaudeQuotaMenuBar` is signed ad-hoc only (not notarized by Apple).
> The cask strips the quarantine flag after install so Gatekeeper won't block
> it, but macOS may still show a first-launch warning.

### Manual install

Download the `.dmg` from the [latest release](https://github.com/mehaxan/claude-quota-tracker/releases/latest), open it, and drag `ClaudeQuotaMenuBar.app` into `/Applications`.
