# Detailed Design

## Status

- Project: `evomap-console`
- Platform: `macos-app`
- Framework: `SwiftUI`
- Phase: `implementation`
- Related plan: `docs/PLAN.md`

## Product assumptions

- Primary users: operators and builders who need a native desktop console for EvoMap workflows
- Core product direction: `evomap-console` should turn this idea into a focused v1 product: A native macOS app to manage EvoMap nodes, skills, services, orders, and knowledge graph APIs.
- The current implementation now covers `Nodes`, `Skills`, `Services`, `Orders`, and `Graph`; `Activity` remains deferred
- The app should feel like a Mac operator tool, not a generic SaaS dashboard

## Design focus for v1

- [x] SwiftUI screen composition and navigation ownership
- [x] device-specific interaction model and lifecycle behavior
- [x] reference-backed information architecture before UI coding begins

## Architecture direction

- [x] screen map, navigation model, and platform-specific interactions
- [x] SwiftUI view composition and state ownership
- [x] data model, persistence, and networking boundaries
- [x] platform integrations, permissions, and lifecycle handling
- [ ] test strategy for views, flows, and integration points

## Reference inputs

- Official macOS references are captured in `docs/UI_REFERENCES.md`
- The layout direction is based on Apple's macOS HIG plus behavior references from TablePlus, Proxyman, and Raycast
- No code template is locked in; these references guide structure and interaction only

## V1 information architecture

### Window model

- `Main window`: the primary console for day-to-day EvoMap management
- `Settings window`: credentials, endpoint overrides, defaults, and experimental toggles
- Secondary windows are deferred until there is a concrete need for separate `Orders` or `Graph` workspaces

### Main navigation model

Use `NavigationSplitView` as the root app container:

1. `Sidebar`
   - `Overview`
   - `Nodes`
   - `Skills`
- `Services`
- `Orders`
- `Graph`
- `Activity` (`Later`)
2. `Content column`
   - list or table of entities for the selected module
3. `Detail column`
   - the focused editor / preview / management surface for the selected entity

This follows Apple's guidance to keep sidebars shallow and move deeper entity navigation into a separate content pane.

### Toolbar model

- Leading:
  - sidebar toggle
  - current section title
- Center:
  - current node/environment picker when relevant
- Trailing:
  - search
  - refresh/sync
  - primary action (`Connect Node`, `Publish Skill`, etc.)
  - inspector toggle
  - settings entry

Critical actions must also exist in the menu bar via SwiftUI commands.

## Screen map for v1

### Overview

- Purpose: lightweight launch surface, not the main workspace
- Contents:
  - auth readiness
  - node health summary
  - skill publish status summary
  - recent activity

### Nodes

- Content pane:
  - table of known nodes
  - columns like node name, claim state, heartbeat, environment, last seen
- Detail pane:
  - node summary
  - connection / claim actions
  - recent events
  - heartbeat and environment details
- Inspector:
  - raw IDs
  - endpoint config
  - auth headers / debug state

### Skills

- Content pane:
  - table of local and remote skills
  - state grouping: draft, changed, published
- Detail pane:
  - rendered `SKILL.md`
  - parsed metadata preview
  - publish / update controls
  - version history
- Inspector:
  - character counts
  - bundled file limits
  - validation warnings
  - raw publish payload preview

## Interaction rules

- Prefer inline detail and inspectors over modal-heavy flows
- Prefer tables and lists for operator data over dashboard cards
- Keep sidebar hierarchy flat
- Keep search scoped to the current module
- Keep settings and secrets out of the main workspace

## Technical direction

- Root container: `NavigationSplitView`
- Module collections: `List` or `Table` depending on data density
- Search: `searchable`
- Inspector surfaces: SwiftUI inspector APIs or an equivalent trailing panel pattern
- Settings: dedicated `Settings` scene
- Menu parity: `SidebarCommands` plus custom command groups

## First implementation slice

Build in this order:

1. app shell and root split view
2. sidebar navigation
3. `Nodes` content table
4. `Node Detail` workspace
5. toolbar and menu commands
6. settings window

Only after this slice feels right should `Skills` ship.

## Decisions to finalize

- [x] App / screen / page structure is clear
- [ ] Shared modules and boundaries are clear
- [ ] State, data flow, and persistence choices are clear
- [ ] External integrations are scoped
- [ ] Testing approach is defined for the first milestone

## Risks and spikes

- Determine which EvoMap node/account actions require browser-backed auth versus `node_secret` alone
- Validate the best inspector implementation for raw JSON payloads and headers
- Decide how local `SKILL.md` drafts map to remote versions without confusing users

## Ready-for-build checklist

- [x] MVP scope is frozen in `docs/PLAN.md`
- [x] Detailed design is specific enough to implement without major ambiguity
- [x] First implementation slice is identified
