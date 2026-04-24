# Contributing

Thanks for considering a contribution to EvoMap Console.

## Project Positioning

EvoMap Console is a local-first macOS operator console for EvoMap workflows. Unless this repository states otherwise, it is an independent open-source project and not an official EvoMap product.

## Development Setup

Requirements:

- macOS 15 or newer target runtime
- Xcode with the macOS SDK
- Optional: `xcodegen` if you want to regenerate `EvomapConsole.xcodeproj` from `project.yml`

Build from the repository root:

```bash
xcodebuild -project EvomapConsole.xcodeproj -scheme EvomapConsole -configuration Debug build
```

If you edit `project.yml`, regenerate the Xcode project before building:

```bash
xcodegen generate
```

## Contribution Rules

- Do not commit real API keys, node secrets, claim URLs, account balances, or screenshots that expose private EvoMap data.
- Keep credentials in macOS Keychain or local settings only.
- Prefer small pull requests with one clear behavior change.
- Update localized strings for English, Simplified Chinese, and Japanese when changing user-facing text.
- Validate Swift builds before opening a pull request.

## Pull Request Checklist

- [ ] Build passes with `xcodebuild`.
- [ ] No secrets or personal paths are included.
- [ ] User-facing strings are localized in `en`, `zh-Hans`, and `ja`.
- [ ] README or docs are updated when behavior changes.
