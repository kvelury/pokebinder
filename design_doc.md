# PokéBinder — Design Doc

The design authority for this project. It describes the app **as it is today**, plus the decisions
that got it here and the reasons they should not be quietly undone.

- This file is tracked in git and travels with the repo. Keep it current — when you change how the
  app works, change this too, in the same commit.
- `handoff.md` is **not** tracked (it is in `.gitignore`). It is scratch: the work order for whoever
  is picking up the next chunk. Nothing durable should live only there.

Last updated for: **Card hover**. Parts 1–6, optional Liquid Glass themes, queued two-way
Notion refresh, the continuous pinch-zoomable grid, and the beside-card type hover card are shipped.

---

## 1. What PokéBinder is

A native macOS app that virtualizes a physical Gen 1 Pokémon card binder.

It opens straight to page 1 of a 19-page binder. You flip pages with the arrows, ⌘←/⌘→, a two-finger
trackpad swipe, or by typing a page number. You search to spotlight a Pokémon and the binder flips
itself to find it. Each pocket shows the Pokémon's name, Pokédex number, and hi-res official artwork;
cards you don't own are greyed out behind a dashed sleeve. Ownership is read from and written back to
a Notion database over MCP.

The origin spec (`~/Downloads/pokemon-binder-app-spec.md`) described a React + Tailwind web app. That
was overridden: this is a native macOS app. **The spec remains the authority on data plumbing and
features only — never on look, feel, or stack.** The visual design is the user's own; §8 records what
is locked.

## 2. Platform & build

### macOS 26 is the floor — a standing rule

**This app targets macOS 26 and nothing older.** Write macOS 26 APIs directly: **no `#available`, no
`@available` fallbacks, no `#if` branches for older systems.**

The reason is testability, not taste. There is no Xcode on this machine (Command Line Tools only) and
no older macOS to run on, so a compatibility branch could never be verified — it would be untested
code posing as a safety net.

Two consequences worth knowing:

- **`Package.swift` must use the string form `platforms: [.macOS("26.0")]`, not `.macOS(.v26)`.**
  `.v26` is `@available(_PackageDescription 6.2)`, so it would force `// swift-tools-version: 6.2` —
  and a tools-version of 6.0+ turns on **Swift 6 language mode by default**, dragging in a
  strict-concurrency migration across `ArtworkStore`'s actor, the `@MainActor` stores, and
  `NotionAuth`'s `NWListener` callbacks. The string overload is not tools-version gated, so
  `// swift-tools-version: 5.9` stays.
- **Liquid Glass is opt-in inside the app.** The saved Classic style preserves the original flat-pill
  chrome. The Liquid Glass style uses macOS 26 APIs directly and follows the functional-layer rules
  in §5; neither style needs a compatibility branch.

| Fact | Value |
|---|---|
| Xcode | **Not installed** — Command Line Tools only. No `.xcodeproj`, no `xcodebuild`. |
| Swift | 6.3.3, `// swift-tools-version: 5.9` |
| macOS SDK | 26.5 |
| Deployment target | macOS 26.0 (`Package.swift`, and `LSMinimumSystemVersion` in `Info.plist`) |
| Bundle | `com.pokebinder.app`, display name **PokéBinder** |

### Building and running

```bash
./build.sh              # → build/PokéBinder.app, ad-hoc signed and verified
./build.sh --install    # also replaces /Applications/PokéBinder.app (opt-in on purpose)
```

SPM produces an ASCII `PokeBinder` binary; `build.sh` copies it into `Contents/MacOS/` under that same
ASCII name, which is what `CFBundleExecutable` must match. **Do not rename the executable to the
accented `PokéBinder` inside the bundle** — `codesign` fails to exclude a non-ASCII main-executable
filename from its resource-sealing rule, seals its pre-signature hash, and leaves the bundle failing
`codesign --verify` (this broke the Stage Manager icon in practice: a bundle that fails signature
verification can be shown as a placeholder by system icon surfaces even though `NSWorkspace` reads the
icon fine). The bundle directory name and `CFBundleDisplayName`/`CFBundleName` stay accented — only
the executable filename is ASCII. The generated `PokeBinder_PokeBinder.bundle` is copied into
`Contents/Resources`; `TypeIconAssets` checks there first and falls back to SwiftPM's `Bundle.module`
location for package builds. `build.sh` quits a running copy by
**bundle id** (`quit app id "com.pokebinder.app"`), which is immune to display-name changes and
LaunchServices name caching.

Launch through the **`build-and-run-macos-app` skill**. It quits the running instance first — plain
`open` just foregrounds a stale build, and you will think your change didn't apply.

There is a focused sync check executable, `PokeBinderSyncCheck`, covering interval
resolution, snapshot migration, the durable edit queue, local-wins merging, partial
write failures, and overlapping syncs. Command Line Tools has no XCTest, so this is
an ordinary SwiftPM executable rather than `swift test`:

```bash
swift run PokeBinderSyncCheck
```

App verification is still by running the built `.app`. Do not treat the checks as a
substitute for a connected Notion pass.

### Identifiers that must not change

Each of these keys stored user data; renaming any of them silently discards it.

- `CFBundleIdentifier` = `com.pokebinder.app` — the `UserDefaults` domain is keyed by it.
- The `pokebinder.*` UserDefaults keys in `AppSettings` (appearance, type era, Notion tokens,
  `pokebinder.notionSyncInterval`, `pokebinder.notionSyncCustomMinutes`,
  `pokebinder.gridCardWidth`), and
  `localOwnedDexNumbers` in `CollectionStore`.
- The Application Support paths, which stay ASCII `PokeBinder` despite the display name:
  `PokeBinder/artwork/` and `PokeBinder/ownership.json`.

## 3. Data model & layout derivation

151 Pokémon, 8 pockets per page (4 per side of an open spread), 19 pages.

```swift
page   = (n - 1) / 8 + 1        // 1...19
absPos = (n - 1) % 8 + 1        // 1...8
side   = absPos <= 4 ? .left : .right
slot   = absPos <= 4 ? absPos : absPos - 4
```

Implemented in `Pokedex.swift`, along with the 151 bundled names, `formattedNumber` (zero-padded to
three digits), and `artworkURL(for:)`.

**Page 19 holds only #145–#151 — the last pocket is permanently empty.**
`Pokedex.dexNumber(page:side:slot:)` returns `nil` there and `CardSlotView` draws an empty dashed
sleeve. This is correct behaviour, not an error path. Do not "fix" it.

### What Notion supplies, and what it doesn't

The Notion database (`187a66ca-0d0d-40da-b3aa-64f51adceb65`) has `Name`, `Pokédex #`, `Page`,
`Absolute Position`, `Owned` (`"__YES__"` / `"__NO__"`), plus a per-row `id`.

During planning, Notion's stored `Page` and `Absolute Position` were checked against the formulas
above for all 151 rows: **0 mismatches**. Layout is therefore fully derivable offline, and Notion
supplies **only** the `Owned` bit and the row `id` (used as `page_id` for writeback). That is why the
binder renders completely before any connection exists, and why the join is on **`Pokédex #`, not
name**.

Artwork comes from the PokeAPI sprite CDN — 475×475 PNGs with alpha, public and immutable:
`https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/{n}.png`

## 4. Architecture

```
Sources/PokeBinderSync/          testable sync library (no UI)
├── NotionSyncInterval.swift     Manual / 1 / 3 / 5 / 8 / Custom + due-date helper
├── OwnershipSnapshot.swift      ownership.json + pending edits + lastSyncedAt
├── OwnershipReconciler.swift    local-wins merge
└── OwnershipSyncCoordinator.swift serialized pull + flush

Tests/PokeBinderSyncCheck/       `swift run PokeBinderSyncCheck`

Sources/PokeBinder/
├── PokeBinderApp.swift     @main — WindowGroup, appearance apply, theme environment, window sizing
├── Appearance.swift        app style, glass palette, and Light / Dark / Auto
├── AppSettings.swift       the pokebinder.* UserDefaults keys
├── Pokedex.swift           151 names + the derivation above + artwork URLs
├── Models.swift            BinderSide, ViewMode, BinderSlot, SlotEmphasis
├── Theme.swift             environment palette + adaptive tokens + typography + BinderMetrics
├── ArtworkStore.swift      actor + disk cache + prefetch, and CardArtworkView
├── CollectionStore.swift   OwnershipBackend, LocalOwnershipBackend, CollectionStore
├── BinderState.swift       navigation + search (matching, auto-flip, cycling, emphasis)
├── GridState.swift         live grid cardWidth, log zoom mapping, scroll anchor
├── Notion/
│   ├── NotionAuth.swift             OAuth 2.1, dynamic client registration, PKCE, loopback server
│   ├── NotionMCPClient.swift        Streamable-HTTP MCP: initialize → tools/call, SSE parsing
│   ├── NotionManager.swift          ObservableObject: connect/disconnect, authorized tool calls
│   └── NotionOwnershipBackend.swift queues toggles; CollectionStore flushes on sync
└── Views/
    ├── ContentView.swift        owns app state; toolbar, bottom bar, Settings sheet, sync timer
    ├── WindowConfigurator.swift the only NSWindow bridge — hides the title, clears first responder
    ├── BinderView.swift         the 3D page turn, cover, spread, spine, trackpad catcher
    ├── PageSideView.swift       one page: 2×2 pockets + gutter shadow
    ├── CardSlotView.swift       one pocket: badge, art, name, owned/missing/spotlight
    ├── CardDetailPanel.swift    the centred detail panel + the Owned toggle
    ├── CardZoomOverlay.swift    scrim + the pocket→centre pop
    ├── PagerBar.swift           ◀ · click-to-edit N / 19 · ▶, NotionResyncButton, CollectedCountPill
    ├── PillChrome.swift         shared Classic/glass control and panel surfaces
    ├── GridView.swift           the continuous grid, page sheet, pinch catcher
    ├── GridZoomMeter.swift      the floating zoom control that replaces the pager
    └── SettingsSheet.swift      Collection / Theme / Notion / About sections
```

### Three contracts to preserve

These are what let the app's parts be worked on independently, and they still hold.

1. **`OwnershipBackend`** (`CollectionStore.swift`) — a `@MainActor` protocol of `displayName`,
   `loadOwnership()`, `setOwned(dex:owned:)`. No view knows where ownership lives.
   `CollectionStore.use(_:)` swaps the backend at runtime, which is how connecting Notion takes
   effect without a relaunch. The local backend writes immediately. The Notion backend **queues**
   `setOwned` into `ownership.json`; `CollectionStore.resync()` pulls Notion, overlays queued
   edits (local wins the same Pokédex number), pushes successful writes, and leaves failures
   queued. Overlapping syncs are rejected by `OwnershipSyncCoordinator`.

2. **`BinderState.goTo(page:)`** — *every* page change funnels through it: arrows, the editable
   field, ⌘←/⌘→, trackpad swipe, and search auto-flip. It is a clamp-and-set;
   `BinderView` observes `currentPage` and drives the animation from it. That is what lets a turn in
   flight **retarget** rather than queue when auto-flip fires on every keystroke.

3. **`CardSlotView` is the only thing that draws a card and `CardDetailPanel` /
   `CardZoomOverlay` the only things that present one.** Grid mode supplies a different
   `BinderMetrics` (`BinderMetrics(cardWidth:)` — never `fitting(_:)`) and the same `$selection`
   binding, and nothing else. A future change to the card or the popup lands in grid mode for
   free, with no grid-side edit.

### Caching, and why the app is never blank

Three layers, each defending a different stall:

- `ArtworkStore` — an `actor` with a permanent disk cache under `PokeBinder/artwork/`, in-flight
  request dedup, and page prefetch. `BinderState.prefetchNeighbours()` warms the pages either side of
  the current one, so a flip never lands on empty pockets.
- `ArtworkImageCache` — a main-actor `NSCache` of decoded `NSImage`s, so scrolling back to a page
  doesn't re-decode.
- `OwnershipSnapshot` — last-known ownership, Notion row ids, queued local edits, and
  `lastSyncedAt`, written to `ownership.json`. On launch `CollectionStore.load()` paints the
  snapshot (pending edits overlaid) before the network returns. Older files without the new
  fields still load; pending starts empty. A toggle updates the queue immediately and is written
  to Notion on the next sync, not on the click.

While artwork loads, a pocket draws `Color.clear` rather than a spinner — eight spinners on a spread
is noisier than the art simply arriving.

## 5. Design system

### Palettes

Classic remains forest green + brass. Liquid Glass adds Full Glass (neutral content and untinted
glass), Forest & Brass, Navy & Gold, and Burgundy & Dark Gold. Light and dark are first-class for
every palette. Palette tokens recolor the binder and functional accents, never Pokémon artwork.

|  | Light | Dark |
|---|---|---|
| cover | `#2E4A3C` | `#12211B` |
| page | `#FFFFFE` | `#172420` |
| sleeve | `#F0F5F1` | `#1F2E28` |
| rings / accent (brass) | `#A8863C` | `#D0A94F` |

Tokens live on the `Theme` value in `Theme.swift`, which is injected through `EnvironmentValues`.
Each color is still built with `Color.adaptive(light:dark:)`. Because SwiftUI asset-catalog colors
aren't available to an SPM executable, that helper wraps an `NSColor` dynamic provider:

```swift
Color(nsColor: NSColor(name: nil) { appearance in
    let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    return NSColor(hex: isDark ? dark : light)
})
```

The closure runs **at draw time against the current `NSAppearance`**, while changing style or palette
replaces the environment `Theme` value and redraws the complete hierarchy.

### Typography

Per the spec: **mono for numbers** (`Theme.numberFont`), **rounded sans for names**
(`Theme.nameFont`). Both take a size so they can scale with the card.

### Geometry

`BinderMetrics` derives every measurement from a single `cardWidth`, so the whole spread scales as
one object and never distorts. Real cards are 2.5" × 3.5", so `cardAspect = 5/7`.
`BinderMetrics.fitting(_:)` solves for the largest card that fits the window. `CardDetailMetrics`
is the popup's equivalent of `BinderMetrics` — one derived scale, every measurement a multiple of it.

⚠️ `fitting(_:)` restates the padding ratios as literals. Change `pagePadding`, `coverPadding` or
`cardGap` and you must mirror it there. `CardDetailMetrics.referenceSafe` must be re-measured if the
toolbar chrome or `CardZoomOverlay.safePanelRect`'s insets change.

### Chrome — two visual systems

`PillChrome.swift` is the shared surface boundary. Classic renders the original fill, hairline, and
optional floating shadow. Liquid Glass uses native `glassEffect`, interactive pointer response on
actionable controls, and `GlassEffectContainer` for adjacent shapes. Reduce Transparency falls back
to the opaque semantic fill and border. Large transient panels use the same policy through
`panelChrome`.

Chrome is **floating or a bar**, not Classic vs Liquid Glass. Liquid Glass always floats; grid
mode floats in either style, because a continuous grid should not be capped by a bar. Binder +
Classic keeps the opaque unified toolbar and its anti-double-container rules (`.buttonStyle(.plain)`
and `.sharedBackgroundVisibility(.hidden)`). Floating chrome removes the visible top bar, extends
content into the titlebar, and presents Binder/Grid, search, and Settings as three floating clusters.
The standard traffic lights remain and sit over the content. The window background is draggable when
the toolbar background is absent.

Glass is a **functional layer only**: navigation, controls, hover tooltips, sheets, and the card
detail overlay. Binder pages, sleeves, cards, and artwork stay in the content layer. Avoid glass on
glass; controls that already live on a glass panel don't receive a second material.

There is **no window title** in either style.

## 6. Interaction design

**The binder.** A full skeuomorphic binder: a cover surrounding the spread, three rings down the
centre, and a page shadow falling into the gutter.

**Navigation.** Arrows, ⌘←/⌘→, a two-finger trackpad swipe (interactive — the page follows the
finger and either completes or springs back), or typing a page number. All clamp to 1…19.

**The page turn.** A 3D rotation on the ring axis, ~0.28s, with a shadow sweeping the page
underneath. Driven from `currentPage` so it retargets mid-flight. **Reduce Motion downgrades it to an
instant swap** (`@Environment(\.accessibilityReduceMotion)`).

Other app-authored feedback uses a compact motion scale: ~0.08s for pointer and control changes and
~0.12s for search, ownership, and artwork changes. Reduce Motion disables those animations. Intent
delays such as the hover-tooltip pause and trackpad inactivity threshold are not part of the motion
scale.

**Search.** Auto-flip plus spotlight. Typing flips the binder to the first match, rings it in brass,
rings other matches faintly, and dims non-matches; ⏎ / ⌘G / ⇧⌘G cycle with an "n of m" counter. ⌘F
focuses the field.

Two things learned the hard way here:

- A highlight that only styles the *visible* page reads as completely broken — typing a name that
  lives on another page just dimmed all 8 cards. **Anything that emphasises an off-screen item must
  also navigate to it.**
- Clearing the field deliberately does *not* navigate. You should stay on the page you were reading,
  not get thrown back to page 1.
- A bare number is treated as an exact Pokédex entry: typing `25` lands on Pikachu, not on every
  number containing a 2 and a 5.

**The pager.** Three separate surfaces — `◀` · an editable `N / 19` · `▶`. They are flat pills in
Classic and a coordinated glass group in Liquid Glass. The page number is
**click-to-edit**: a plain label at rest, swapping to a focused field only when clicked. It is never
focused at launch. (Left to itself, AppKit hands first responder to the first text field in the
content view's key-view loop and `NSTextField` selects all its text, so the app used to open with `1`
highlighted blue. `WindowConfigurator` also clears the initial first responder.)

**Cards.** A corner badge + name layout: mono number badge top-left, artwork centred in the pocket,
type icons top-right, and the name centred at the base. Cards you don't own are **greyscale behind a
dashed sleeve**, with the number and muted type icons still fully legible — that was the point of
choosing corner metadata over text over the art.

**Ownership.** Clicking a card pops today's **detail panel to the centre of the window, with an
explicit `Owned` toggle**. Never click-to-toggle — too easy to change your collection by accident
while browsing.

**Types.** The detail panel presents `#035 | [type icons]` beneath the Pokémon name. Binder and detail
icons share one component and use the SVG glyphs and colors from
`duiker101/pokemon-type-svg-icons`. Hovering a card (binder or grid) for ~250ms presents a hover card
beside it with that Pokémon's type info at Settings → Types → Hover matchups: Simple shows Strong
against and Weak to, Advanced adds resistances and immunities, and Full adds offensive coverage gaps.
The hover card is placed beside the pocket — the side with more room, falling back to above/below if
neither side fits — and scales on the same `CardDetailMetrics` solve as the click-open panel, in a
narrower frame matching the panel's details column. Per-icon type-name tooltips are suppressed on
cards because the hover card already names every type; they remain on the detail panel identity row
and on matchup chips. The hover card is suppressed entirely while the detail panel is open.

**Card detail.** Clicking a pocket quickly springs the detail panel from that pocket to the centre
of the window; dismissal reverses the same short transition. A scrim dims the whole content area —
pager bar and count pill included; the top functional controls stay bright. Dismiss with the scrim,
Esc, or the ✕ on the panel. Clicking the panel itself does not dismiss (it would fight the Owned
switch). The insertion transition is part of the click's state-change transaction, so it begins
without waiting for an `onAppear` callback. Reduce Motion replaces the travel and scale with the
quick fade. Pointing at a card without clicking is the hover card above — no scrim, not dismissible,
and never hit-tested so a click still opens this panel. The focused card always shows Full matchup
details, independent of the hover setting.

The overlay is hosted in `ContentView` so it can sit above the pager. That is not enough on its own
for the trackpad. `TrackpadPageTurnCatcher` installs a local `NSEvent` scroll-wheel monitor that
does **not** go through SwiftUI hit testing, so a scrim above it would still let two fingers turn
the page underneath the panel. While a card is up the catcher is suspended and **returns the event
unconsumed** — swallowing it would deaden scrolling app-wide, including in the Settings sheet.

**Grid view.** A continuous 151-card grid on one page sheet (the binder's paper, hairline, and
drop shadow, without the gutter gradient). Pinch-zoom reflows the column count by changing
`cardWidth` (80–260pt, log-mapped) rather than applying a `.scaleEffect`, so each cell is
literally the binder's `CardSlotView` at a different size. A bottom-centre glass meter replaces
the pager; ⌘+/⌘−/⌘0 step and reset. Search spotlight and auto-scroll work as in the binder;
⌘←/⌘→ step 8 cards via the existing `goTo`. Switching modes keeps you on the same cards.
Grid mode always uses floating chrome: no toolbar, content to the top of the window, the three
control clusters pinned over the cards. An 86pt top inset (58pt floating cluster + 28pt gap)
keeps the first row clear at rest; cards pass underneath the pills once you scroll.

## 7. Settings & theming

Settings is a **sheet** presented from the toolbar gear, not a `Settings` scene, so ⌘, is not wired.
It is a `Form(.grouped)` at a fixed size, with a `Done` button in a footer below a divider.

Because a sheet gets its own environment root, `ContentView` re-injects `collection` and `notion`
into it explicitly. **Prefer `@AppStorage` over an `EnvironmentObject` for new preferences** — it
sidesteps that entirely, which is why `databaseId` already works that way.

Preference keys follow `AppSettings`: `static let <name>Key = "pokebinder.<name>"`.

### Sections

- **Collection** — the active backend name and the collected count.
- **Theme** — Classic/Liquid Glass style, the four glass palettes, and appearance (below).
- **Types** — Current or original Gen I assignments. Current is the default; Gen I removes later
  Steel/Fairy changes from the seven affected Pokémon. Hover matchups (Simple / Advanced / Full)
  controls only the hover card's rows; the click-open focused card always shows Full details.
- **Notion** — Connect/Disconnect, live status, workspace name, the database id field, and the
  refresh interval (`Manual`, `1`, `3`, `5`, `8`, or a custom whole-minute value). Automatic
  refresh runs only while the app is open and active; changing the interval restarts the timer.
  Becoming active again catches up if an interval is due. Manual mode schedules nothing. The
  bottom-left resync button is always on the main window (binder and grid, every interval) and
  runs the same pull-and-flush immediately. It is disabled only when Notion is disconnected or a
  sync is already running. The binder renders fully with or without Notion, so this section is
  genuinely optional. A connection persists and reloads on launch.
- **About** — binder size (`19 pages · 151 Pokémon`), artwork source, and type-icon credit.

### Appearance

**Light / Dark / Auto**, defaulting to Auto (follow System Settings). `AppAppearance` in
`Appearance.swift` maps these to an `NSAppearance` — `.aqua`, `.darkAqua`, or `nil` for "inherit from
the system" — and applies it as **`NSApplication.shared.appearance`**.

App-wide rather than per-window on purpose. `.preferredColorScheme` on the main content would leave
out the surfaces that live in **their own windows**: the Settings sheet (where the control itself
is) and the native toolbar/titlebar.

The dynamic-provider mechanism in §5 re-resolves every palette token against the new appearance
automatically.

### Theme persistence and observability

`pokebinder.appStyle` and `pokebinder.glassPalette` are independent saved settings. `PokeBinderApp`
reads both with `@AppStorage`, constructs a `Theme`, and injects it into the complete hierarchy.
Settings writes the same keys, so the main window, sheet, binder, overlays, and tooltips update live.
Appearance remains independent and app-wide through `NSApplication.shared.appearance`.

A palette is not a bag of independent colors. The cover, accent, and control luminance ramps must
remain ordered so gradients, text contrast, and reduced-transparency fallbacks stay legible.
Hardcoded black/white overlays inside the binder remain physicality shading rather than palette.

## 8. Decision log

Every row was chosen by the user, most from visualized alternatives. **Do not undo any of them
without asking.**

| Decision | Why |
|---|---|
| **Full skeuomorphic binder** — cover, 3 rings, gutter shadow | The app is a *binder*, not a grid of cards. The physicality is the product. |
| **Classic and Liquid Glass are user-selectable** | Classic preserves the deliberate flat-pill design. Liquid Glass is an optional macOS 26 functional layer with floating top controls, coordinated groups, and accessibility fallbacks. |
| **No nested material surfaces** | Adjacent glass controls share a `GlassEffectContainer`; a control already living on a glass panel doesn't add another glass layer. |
| **No window title** | It sits between the view tabs and the search field and pushes the search off centre. |
| **Corner badge + name card layout** | Keeps the Pokédex number legible even when the card is missing and desaturated. |
| **Card art centred in the pocket** | Square artwork in a 5:7 pocket was top-aligned, dumping all its slack below and reading as sitting too high. |
| **Search pill: no outline at all** | It had two — ours, and macOS 26's own toolbar-item container 3pt outside it. The doubled edge was the complaint. |
| **Missing cards: greyscale + dashed sleeve** | Reads as "empty pocket" at a glance while keeping the number readable. |
| **Card pops to the centre over a scrim, explicit toggle** | Never click-to-toggle; browsing shouldn't mutate the collection. |
| **Three separate pager pills, click-to-edit number** | The gap gives the field's focus ring room; arrows want to be round. Click-to-edit stops the app opening with the number selected. |
| **Adaptive light/dark, now with a Light/Dark/Auto override** | Auto stays the default — the app follows System Settings unless told otherwise. |
| **Four Liquid Glass palettes** | Full Glass is untinted; Forest/Brass, Navy/Gold, and Burgundy/Dark Gold provide coordinated content and accent ramps. |
| **App name `PokéBinder`**, with the accent | Matches the official Pokémon spelling. Bundle display strings only; there is still no window title. |
| **macOS 26 only** | See §2 — a fallback for 14/15 could never be tested here. |
| **Grid reflows on zoom rather than scaling** | A transform never becomes an overview and resamples text; relayout keeps the card identical to the binder's at every level. |
| **One continuous page sheet behind the grid** | `theme.sleeve` was designed against paper; on the window background the pocket edge collapses in light mode. |
| **The zoom meter replaces the pager in grid mode** | A continuous grid has no pages to turn, and two centre controls would crowd the bar. |
| **Grid mode hides the toolbar and floats the controls** | A continuous grid should not be capped by a permanent slab. The 86pt top inset keeps the first row clear at rest — the only moment the pills are fully exposed — and cards pass under them once you scroll. |
| **Grid draws no empty 152nd pocket** | That pocket is a binder artifact, not a Pokédex one. |
| **Notion is optional** | The binder is fully usable offline; Notion adds ownership sync, it isn't a prerequisite. |
| **Queued Notion writes, local pending wins** | Toggles stay instant in the UI. Remote I/O waits for the next interval or the always-visible resync. A queued app edit beats a conflicting Notion value for that Pokédex number. |

## 9. Not in scope

Multi-generation binders, duplicate tracking, condition/grading, sharing, and an
app icon (a `Scripts/make_icon.swift` could follow Dosa's pattern later).
