# Publishing Guide

## Recommended First Public Release Flow

1. Run the local audit:

   ```bash
   ./scripts/open_source_audit.sh
   ```

2. Build the app:

   ```bash
   xcodebuild -project EvomapConsole.xcodeproj -scheme EvomapConsole -configuration Debug build
   ```

3. Review the public-facing files:

   - `README.md`
   - `LICENSE`
   - `SECURITY.md`
   - `CONTRIBUTING.md`
   - `CODE_OF_CONDUCT.md`
   - `.github/ISSUE_TEMPLATE/*`

4. Create the initial commit:

   ```bash
   git add .
   git commit -m "Initial open-source release"
   ```

5. Create a GitHub repository. Recommended initial visibility: private until the final scan passes, then switch to public.

6. Push:

   ```bash
   git remote add origin git@github.com:owenshen0907/evomap-console.git
   git push -u origin main
   ```

7. Before making the repository public:

   - confirm no screenshots expose private account data
   - confirm sample node IDs and claim URLs are fake
   - update `.github/ISSUE_TEMPLATE/config.yml` with the real repository/security contact URL
   - Update README badge owner from `owenshen0907` to the GitHub account or organization name
   - decide whether to keep the bundle identifier as `dev.evomapconsole.app`

## Suggested GitHub Repository Settings

- Enable secret scanning if available.
- Require pull request review before merging to `main` after the first public release.
- Use squash merge by default for small external contributions.
- Add topics: `macos`, `swiftui`, `evomap`, `a2a`, `agent-tools`, `knowledge-graph`.

## First Release Tag

Use `v0.1.0` only after the first live-account validation pass. Until then, keep the repository public but describe it as implementation-stage software.
