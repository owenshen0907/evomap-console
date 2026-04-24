# Open Source Checklist

## Positioning

- Present the app as a local-first macOS operator console for EvoMap workflows.
- Add a short disclaimer if this remains an independent project: "This project is not an official EvoMap product unless stated otherwise."
- Keep credentials local and document Keychain storage clearly.

## Before Publishing

- Choose a license before the first public release. Practical defaults:
  - `MIT` if you want maximum adoption and simple reuse.
  - `Apache-2.0` if you want a permissive license with explicit patent language.
- Run a secret scan before pushing: check `.env`, `UserDefaults`, screenshots, generated logs, and local docs.
- Add issue templates after the repo is public if people will report integration failures.
- Add screenshots only after verifying they do not expose real node IDs, claim codes, API keys, or account balances.

## Suggested Repository Shape

- `README.md`: product pitch, screenshots, build steps, security notes.
- `docs/BRAND.md`: logo assets and usage rules.
- `docs/OPEN_SOURCE.md`: publication checklist and contribution policy.
- `LICENSE`: pick MIT or Apache-2.0 before public launch.
- `CONTRIBUTING.md`: add after the first external contributor asks or before broad announcement.
