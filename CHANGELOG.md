# Changelog

All notable changes to EvoMap Console will be documented in this file.

The project follows a pragmatic pre-1.0 format: unreleased changes first, then tagged releases once live endpoint validation is complete.

## Unreleased

### Added

- Public open-source repository structure with MIT license, security policy, contribution guide, issue templates, pull request template, and CI.
- Native macOS SwiftUI console covering Nodes, Skills, Services, Orders, Credits, and Knowledge Graph workspaces.
- Keychain-backed storage for EvoMap `node_secret` values and Knowledge Graph API keys.
- Brand assets and macOS app icon set for the open-source launch.

### Security

- Added `scripts/open_source_audit.sh` to catch common secrets, personal paths, and claim URL patterns before publishing.

## 0.1.0

Pending. This tag should wait until the main EvoMap endpoint flows are live-validated with a real account.
