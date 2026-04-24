# UI References

## Goal

Use a reference-backed macOS layout before implementation so `evomap-console` feels like a native operator console instead of a generic dashboard.

## Official Apple references

### 1. Designing for macOS

Reference:
- <https://developer.apple.com/design/human-interface-guidelines/designing-for-macos>

What to borrow:
- Use the Mac's large display to show more content with fewer nested levels.
- Support keyboard shortcuts, menu commands, and personalization.
- Let people resize, hide, and reveal supporting panels instead of forcing one rigid layout.

Implication for this app:
- Prefer a multi-pane desktop layout over stacked pages.
- Design for keyboard-first operators, not touch-first cards.

### 2. Sidebars

Reference:
- <https://developer.apple.com/design/human-interface-guidelines/sidebars>

What to borrow:
- Use the sidebar for broad, flat navigation between peer areas.
- Keep the sidebar hierarchy shallow; if the hierarchy gets deeper than two levels, add a content list between sidebar and detail.
- Let people hide the sidebar when they need more room.

Implication for this app:
- The root sidebar should switch between top-level product areas like `Overview`, `Nodes`, `Skills`, `Services`, `Orders`, and `Graph`.
- Per-area entities should live in a second pane, not inside a deeply nested sidebar.

### 3. Toolbars

Reference:
- <https://developer.apple.com/design/human-interface-guidelines/toolbars>

What to borrow:
- Leading edge: navigation controls and title context.
- Center: common controls.
- Trailing edge: search, inspectors, important persistent actions.
- Keep toolbars deliberate and avoid overcrowding.

Implication for this app:
- Leading: sidebar toggle and current section title.
- Center: node/environment switcher when relevant.
- Trailing: search, refresh/sync, primary action, inspector toggle.

### 4. NavigationSplitView

Reference:
- <https://developer.apple.com/documentation/swiftui/navigationsplitview>
- <https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types>

What to borrow:
- Use `NavigationSplitView` as the root layout for two- or three-column Mac navigation.
- Control column visibility explicitly when the workflow benefits from focus mode.

Implication for this app:
- Use a three-column root: sidebar -> content list/table -> detail workspace.
- Avoid legacy `NavigationView`.

### 5. Table + Search

Reference:
- <https://developer.apple.com/documentation/swiftui/table>
- <https://developer.apple.com/documentation/swiftui/adding-a-search-interface-to-your-app>

What to borrow:
- Use `Table` for sortable, scannable operator data.
- On macOS, `searchable` naturally lands in the trailing toolbar area.

Implication for this app:
- `Nodes`, `Skills`, `Services`, and `Orders` should default to table/list presentation, not oversized dashboard cards.
- Search should filter the current module rather than opening a separate screen.

### 6. Settings and menu commands

Reference:
- <https://developer.apple.com/documentation/swiftui/settings>
- <https://developer.apple.com/documentation/swiftui/building-and-customizing-the-menu-bar-with-swiftui>

What to borrow:
- Use a dedicated `Settings` scene on macOS.
- Mirror critical toolbar actions in the menu bar because toolbars can be customized or hidden.

Implication for this app:
- Keep tokens, API keys, endpoint overrides, and feature flags in a separate Settings window.
- Add `SidebarCommands` and app-specific command groups early.

## Product references

These are behavior references, not visual clones.

### TablePlus

Reference:
- <https://tableplus.com/>

Patterns worth borrowing:
- multi-pane workspace for managing structured resources
- tabs/windows for parallel work
- "open anything" mindset for jumping to entities quickly
- dense but readable data views instead of inflated cards

### Proxyman

Reference:
- <https://proxyman.com/>
- <https://docs.proxyman.com/>

Patterns worth borrowing:
- source list + content list + deep inspector workflow
- strong filtering and debugging posture
- command palette as a productivity multiplier
- right-side detail inspector for raw metadata and advanced controls

### Raycast

Reference:
- <https://www.raycast.com/core-features/quicklinks>

Patterns worth borrowing:
- keyboard-first command invocation
- compact action surfaces over modal-heavy flows
- quick links / quick actions for frequent workflows

## Proposed layout direction for v1

### Window model

- Main window: operator console for daily work
- Settings window: credentials, API endpoints, defaults, experimental flags
- Secondary windows later, only if `Orders` or `Graph` need dedicated workspaces

### Main window structure

Use a three-column layout:

1. Sidebar
   - `Overview`
   - `Nodes`
   - `Skills`
   - `Services` (disabled or marked `Later` in v1)
   - `Orders` (later)
   - `Graph` (later)
   - `Activity` (later)

2. Content column
   - context-aware list or table for the selected module
   - examples:
     - `Nodes`: all known nodes and connection states
     - `Skills`: local drafts, imported skills, remote published versions

3. Detail workspace
   - detailed editor / preview / publish panel for the selected item
   - optional trailing inspector for raw metadata, auth state, headers, JSON payloads

### Visual direction

- Native macOS first, not web-dashboard styling
- Dense information, generous alignment, restrained chrome
- Use SF Symbols and platform materials instead of custom illustration-heavy surfaces
- Prefer inline detail and inspectors over modal overload

### Module-specific layout notes

### Overview

- small set of status surfaces only
- not a card wall
- show node health, auth readiness, recent publish activity, and last sync

### Nodes

- content pane: table with node name, claim state, heartbeat, environment, last seen
- detail pane: selected node summary, credentials state, recent events, and actions
- inspector: raw identifiers, endpoint config, auth/debug information

### Skills

- content pane: table grouped by local draft, remote published, and changed state
- detail pane: rendered `SKILL.md`, publish form, bundled files preview, remote version history
- inspector: parsed frontmatter, character counts, validation warnings, tag/category mapping

### What not to do

- do not start from a generic KPI dashboard with six unrelated cards
- do not bury top-level product areas in nested accordions
- do not make every action a modal sheet
- do not force users to leave the current context to inspect raw payloads

### First implementation slice

Start with:
- app shell
- root sidebar
- `Nodes` table
- `Node Detail` workspace
- toolbar with sidebar toggle, refresh, search, and settings entry

After that:
- add `Skills` list + detail + publish draft flow
