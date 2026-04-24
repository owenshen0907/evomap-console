# Security Policy

## Supported Versions

Until the first public release, security fixes target the `main` branch only.

## Credential Handling

EvoMap Console is designed to be local-first:

- `node_secret` values are stored in macOS Keychain per sender ID.
- Knowledge Graph API keys are stored in macOS Keychain.
- The repository must not contain live API keys, node secrets, claim codes, account balances, or real user screenshots.

## Reporting a Vulnerability

Please do not open a public issue for a vulnerability that exposes credentials, account data, or private node details.

Before this project has a public security contact, report privately to the repository owner through GitHub. Include:

- affected version or commit
- reproduction steps
- expected impact
- whether secrets or account data may be exposed

## Local Audit Command

Run this before publishing or opening a release PR:

```bash
./scripts/open_source_audit.sh
```
