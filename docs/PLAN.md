# Project Plan

## Goal

- Project: `evomap-console`
- Type: `personal`
- Platform: `macos-app`
- Framework: `SwiftUI`
- Target users: EvoMap builders and operators who need a native desktop console for frequent management tasks

`evomap-console` should turn this idea into a focused v1 product: A native local-first macOS app to manage EvoMap nodes, skills, services, tracked orders, and paid Knowledge Graph APIs.

## MVP scope draft

- ship one clear end-to-end EvoMap management workflow on macOS
- keep the console local-first and usable without any user-owned backend
- validate the main desktop information architecture before investing in deeper automation and activity tooling

## Core user flows

- register or reconnect an EvoMap node and review its current status
- import a local `SKILL.md`, inspect the publish payload, and publish or update it
- browse, publish, order, accept, and rate marketplace services from the Mac
- query and manage the paid EvoMap Knowledge Graph directly with an API key stored in Keychain

## Workstreams

- foundation: native multi-pane macOS shell, settings, inspector, and local persistence
- product flows: `Overview`, `Nodes`, `Skills`, `Services`, `Orders`, and `Graph`
- data integration: node identity, Keychain storage, skill parsing, marketplace calls, and KG API access
- delivery: build validation, live endpoint verification, and release-readiness basics

## Milestones

1. Scope freeze: confirm local-first operator-console positioning
2. Implementation slice 1: build `Node` management flow
3. Implementation slice 2: build `Skill` import and publish flow
4. Implementation slice 3: build `Services` + `Orders`
5. Implementation slice 4: build paid `Graph` access via official `/kg/*` endpoints
6. Validation: test inferred payloads, polish `Activity`, and prepare launch

## Immediate next actions

- [x] Fill in the exact MVP problem statement
- [x] List the top 3 user flows
- [x] Confirm official EvoMap endpoints needed for `Node`, `Skill`, `Services`, `Orders`, and `KG`
- [x] Lock the sidebar / content / inspector layout before implementation
- [x] Expand `docs/DESIGN.md` before major implementation
- [ ] Live-validate the inferred service rating and KG ingest payloads against a real EvoMap account
- [ ] Add the remaining `Activity` workspace

## Open questions

- Which marketplace payloads still need live validation because the public docs do not show full schemas?
- Should `Activity` stay in the main window or become a dedicated audit/history workspace later?
- Should the console eventually support browser-session account APIs such as API key lifecycle management, or stay strictly local plus official programmatic endpoints?
