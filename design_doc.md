# PokéBinder — Design Doc

The design authority for this project. It describes the app **as it is today**, plus the decisions
that got it here and the reasons they should not be quietly undone.

- This file is tracked in git and travels with the repo. Keep it current — when you change how the
  app works, change this too, in the same commit.
- `handoff.md` is **not** tracked (it is in `.gitignore`). It is scratch: the work order for whoever
  is picking up the next chunk. Nothing durable should live only there.

Last updated for: **Part 5 — Theme settings**. Parts 1–5 are shipped.

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
- **Targeting macOS 26 is not permission to use Liquid Glass.** `glassEffect` and friends are now
  reachable without a check. The flat-pill chrome (§5) is a deliberate design choice, not a
  compatibility compromise.

| Fact | Value |
|---|---|
| Xcode | **Not installed** — Command Line Tools only. No `.xcodeproj`, no `xcodebuild`. |
| Swift | 6.3.3, `// swift-tools-version: 5.9` |
| macOS SDK | 26.5 |
| Deployment target | macOS 26.0 (`Package.swift`, and `LSMinimumSystemVersion` in `Info.plist`) |
| Bundle | `com.pokebinder.app`, display name **PokéBinder** |

### Building and running

```bash
./build.sh              # → build/PokéBinder.app, ad-hoc signed
./build.sh --install    # also replaces /Applications/PokéBinder.app (opt-in on purpose)
```

SPM produces an ASCII `PokeBinder` binary; `build.sh` renames it to `PokéBinder` on the copy into
`Contents/MacOS/`, which is what `CFBundleExecutable` must match. `build.sh` quits a running copy by
**bundle id** (`quit app id "com.pokebinder.app"`), which is immune to display-name changes and
LaunchServices name caching.

Launch through the **`build-and-run-macos-app` skill**. It quits the running instance first — plain
`open` just foregrounds a stale build, and you will think your change didn't apply.

There is **no test suite**. Verification is by running the app.

### Identifiers that must not change

Each of these keys stored user data; renaming any of them silently discards it.

- `CFBundleIdentifier` = `com.pokebinder.app` — the `UserDefaults` domain is keyed by it.
- The `pokebinder.*` UserDefaults keys in `AppSettings` (appearance, Notion tokens), and
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
Sources/PokeBinder/
├── PokeBinderApp.swift     @main — WindowGroup, appearance apply, 1320×900 default, 1000×780 min, unified toolbar
├── Appearance.swift        Light / Dark / Auto → NSApplication.shared.appearance
├── AppSettings.swift       the pokebinder.* UserDefaults keys
├── Pokedex.swift           151 names + the derivation above + artwork URLs
├── Models.swift            BinderSide, ViewMode, BinderSlot, SlotEmphasis
├── Theme.swift             adaptive color tokens + typography + BinderMetrics
├── ArtworkStore.swift      actor + disk cache + prefetch, and CardArtworkView
├── CollectionStore.swift   OwnershipBackend, LocalOwnershipBackend, CollectionStore
├── BinderState.swift       navigation + search (matching, auto-flip, cycling, emphasis)
├── Notion/
│   ├── NotionAuth.swift             OAuth 2.1, dynamic client registration, PKCE, loopback server
│   ├── NotionMCPClient.swift        Streamable-HTTP MCP: initialize → tools/call, SSE parsing
│   ├── NotionManager.swift          ObservableObject: connect/disconnect, authorized tool calls
│   ├── NotionOwnershipBackend.swift the OwnershipBackend conformance
│   └── OwnershipSnapshot.swift      ~/Library/Application Support/PokeBinder/ownership.json
└── Views/
    ├── ContentView.swift        owns app state; toolbar, bottom bar, Settings sheet
    ├── WindowConfigurator.swift the only NSWindow bridge — hides the title, clears first responder
    ├── BinderView.swift         the 3D page turn, cover, spread, spine, trackpad catcher
    ├── PageSideView.swift       one page: 2×2 pockets + gutter shadow
    ├── CardSlotView.swift       one pocket: badge, art, name, owned/missing/spotlight
    ├── CardDetailPopover.swift  big art + the Owned toggle
    ├── PagerBar.swift           ◀ · click-to-edit N / 19 · ▶, and CollectedCountPill
    ├── PillChrome.swift         the single pill surface
    ├── GridViewStub.swift       "Coming soon"
    └── SettingsSheet.swift      Collection / Theme / Notion / About sections
```

### Two contracts to preserve

These are what let the app's parts be worked on independently, and they still hold.

1. **`OwnershipBackend`** (`CollectionStore.swift`) — a `@MainActor` protocol of `displayName`,
   `loadOwnership()`, `setOwned(dex:owned:)`. No view knows where ownership lives.
   `CollectionStore.use(_:)` swaps the backend at runtime, which is how connecting Notion takes
   effect without a relaunch. `CollectionStore` already does the optimistic flip and the
   revert-on-error, so a backend only has to throw.

2. **`BinderState.goTo(page:)`** — *every* page change funnels through it: arrows, the editable
   field, ⌘←/⌘→, trackpad swipe, and search auto-flip. It is a clamp-and-set;
   `BinderView` observes `currentPage` and drives the animation from it. That is what lets a turn in
   flight **retarget** rather than queue when auto-flip fires on every keystroke.

### Caching, and why the app is never blank

Three layers, each defending a different stall:

- `ArtworkStore` — an `actor` with a permanent disk cache under `PokeBinder/artwork/`, in-flight
  request dedup, and page prefetch. `BinderState.prefetchNeighbours()` warms the pages either side of
  the current one, so a flip never lands on empty pockets.
- `ArtworkImageCache` — a main-actor `NSCache` of decoded `NSImage`s, so scrolling back to a page
  doesn't re-decode.
- `OwnershipSnapshot` — last-known ownership *and* the Notion row ids, written to
  `ownership.json`. On launch `CollectionStore.load()` paints from it before the network returns, and
  because the row ids are cached too, a toggle immediately after launch still reaches the right
  Notion row.

While artwork loads, a pocket draws `Color.clear` rather than a spinner — eight spinners on a spread
is noisier than the art simply arriving.

## 5. Design system

### Palette

Forest green + brass. Light and dark are both first-class.

|  | Light | Dark |
|---|---|---|
| cover | `#2E4A3C` | `#12211B` |
| page | `#FFFFFE` | `#172420` |
| sleeve | `#F0F5F1` | `#1F2E28` |
| rings / accent (brass) | `#A8863C` | `#D0A94F` |

All 17 tokens live on `enum Theme` in `Theme.swift`, each built with
`Color.adaptive(light:dark:)`. Because SwiftUI asset-catalog colors aren't available to an SPM
executable, that helper wraps an `NSColor` dynamic provider:

```swift
Color(nsColor: NSColor(name: nil) { appearance in
    let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    return NSColor(hex: isDark ? dark : light)
})
```

The closure runs **at draw time against the current `NSAppearance`**, which is why the app follows an
appearance change live without a relaunch — and why the appearance toggle in §7 needs no changes to
`Theme.swift` at all.

### Typography

Per the spec: **mono for numbers** (`Theme.numberFont`), **rounded sans for names**
(`Theme.nameFont`). Both take a size so they can scale with the card.

### Geometry

`BinderMetrics` derives every measurement from a single `cardWidth`, so the whole spread scales as
one object and never distorts. Real cards are 2.5" × 3.5", so `cardAspect = 5/7`.
`BinderMetrics.fitting(_:)` solves for the largest card that fits the window.

⚠️ `fitting(_:)` restates the padding ratios as literals. Change `pagePadding`, `coverPadding` or
`cardGap` and you must mirror it there.

### Chrome — flat pills

`PillChrome.swift` is the app's single pill surface: a fill plus a hairline, in a capsule or a
circle. `.pillChrome(in:active:stroked:)` for controls resting on the toolbar;
`.floatingPill(in:)` for the pager and count, which sit over the binder and take a faint shadow.

Three rules that are load-bearing:

1. **One pill per control. Never a container around a group.** The Binder/Grid pair is two icon pills
   where only the active one is filled — not a segmented track. (This rule is about the *toolbar*. A
   segmented picker inside a Settings `Form` is fine and is what §7 uses.)
2. **Keep `.buttonStyle(.plain)` on every toolbar control.** It is the only thing stopping macOS 26
   drawing its own 36pt container beneath our pill — a pill inside a capsule.
3. **`.buttonStyle(.plain)` does not apply to a `TextField`.** The search field is the one control
   that still got a container, so its `ToolbarItem` carries
   `.sharedBackgroundVisibility(.hidden)` instead. Its pill is also drawn `stroked: false` — with the
   container gone, the fill alone carries the shape and a hairline on top read as a second border.

`.toolbarBackground(Theme.chrome, for: .windowToolbar)` makes the bar opaque; without it the titlebar
stays translucent and the desktop bleeds through the top edge.

There is **no window title**. `WindowConfigurator` sets `titleVisibility = .hidden`;
`.windowStyle(.hiddenTitleBar)` would take the toolbar with it, and with it the traffic lights'
placement in a unified titlebar. A visible title also pushes the centred search field off centre.

## 6. Interaction design

**The binder.** A full skeuomorphic binder: a cover surrounding the spread, three rings down the
centre, and a page shadow falling into the gutter.

**Navigation.** Arrows, ⌘←/⌘→, a two-finger trackpad swipe (interactive — the page follows the
finger and either completes or springs back), or typing a page number. All clamp to 1…19.

**The page turn.** A 3D rotation on the ring axis, ~0.45s, with a shadow sweeping the page
underneath. Driven from `currentPage` so it retargets mid-flight. **Reduce Motion downgrades it to an
instant swap** (`@Environment(\.accessibilityReduceMotion)`).

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

**The pager.** Three separate pills — `◀` · an editable `N / 19` · `▶`. The page number is
**click-to-edit**: a plain label at rest, swapping to a focused field only when clicked. It is never
focused at launch. (Left to itself, AppKit hands first responder to the first text field in the
content view's key-view loop and `NSTextField` selects all its text, so the app used to open with `1`
highlighted blue. `WindowConfigurator` also clears the initial first responder.)

**Cards.** A corner badge + name layout: mono number badge top-left, artwork centred in the pocket,
name centred at the base. Cards you don't own are **greyscale behind a dashed sleeve**, with the
number still fully legible — that was the point of choosing a corner badge over text over the art.

**Ownership.** Clicking a card opens a **detail popover with an explicit `Owned` toggle**. Never
click-to-toggle — too easy to change your collection by accident while browsing.

**Grid view.** The Binder/Grid segment is live and switchable, and Grid lands on a "Coming soon"
empty state.

## 7. Settings & theming

Settings is a **sheet** presented from the toolbar gear, not a `Settings` scene, so ⌘, is not wired.
It is a `Form(.grouped)` at a fixed size, with a `Done` button in a footer below a divider.

Because a sheet gets its own environment root, `ContentView` re-injects `collection` and `notion`
into it explicitly. **Prefer `@AppStorage` over an `EnvironmentObject` for new preferences** — it
sidesteps that entirely, which is why `databaseId` already works that way.

Preference keys follow `AppSettings`: `static let <name>Key = "pokebinder.<name>"`.

### Sections

- **Collection** — the active backend name and the collected count.
- **Theme** — appearance (below).
- **Notion** — Connect/Disconnect, live status, workspace name, and the database id field. The binder
  renders fully with or without Notion, so this section is genuinely optional. A connection persists
  and reloads on launch.
- **About** — binder size (`19 pages · 151 Pokémon`) and the artwork source.

### Appearance

**Light / Dark / Auto**, defaulting to Auto (follow System Settings). `AppAppearance` in
`Appearance.swift` maps these to an `NSAppearance` — `.aqua`, `.darkAqua`, or `nil` for "inherit from
the system" — and applies it as **`NSApplication.shared.appearance`**.

App-wide rather than per-window on purpose. `.preferredColorScheme` on the main content would leave
out the surfaces that live in **their own windows**: the Settings sheet (where the control itself
is), the `CardDetailPopover`, and the native toolbar/titlebar.

Nothing in `Theme.swift` participates. The dynamic-provider mechanism in §5 re-resolves all 17 tokens
against the new appearance automatically.

### Adding more palettes later

Planned, not built. What it would actually cost:

- **The call sites are not the problem.** All 59 color references across the Views are the plain
  `Theme.<token>` static-member syntax, in 9 files. Converting `static let` → a computed `static var`
  reading a current-palette value touches **only `Theme.swift`**; no view changes. (Discipline here
  is good: no view builds a color from a hex or an asset name.)
- **Observability is the problem.** `static let` on an `enum` is resolved once and is not observable,
  so a palette swap needs either an environment-driven palette value or a view-identity bump to force
  a redraw. The light/dark axis needs none of this — it rides the `NSAppearance` mechanism instead.
- **A palette is not 17 free colors.** Three ordered luminance ramps have to stay coherent or the
  binder's gradients go flat: `coverHighlight → cover → coverDeep`, `brassBright → brass →
  brassDeep`, and the `controlFill` / `controlFillActive` / `controlStroke` trio.
- **Some shading is deliberately not themed.** The hardcoded `.white.opacity(…)` / `.black.opacity(…)`
  overlays in `BinderView`, `PageSideView`, `CardSlotView` and `PillChrome` are physicality shading,
  not palette. A very light or very dark palette would need them revisited.
- **One known gap:** the connected status dot in `SettingsSheet` is a hardcoded `Color.green` — the
  only semantic color in the app that isn't a `Theme` token.

## 8. Decision log

Every row was chosen by the user, most from visualized alternatives. **Do not undo any of them
without asking.**

| Decision | Why |
|---|---|
| **Full skeuomorphic binder** — cover, 3 rings, gutter shadow | The app is a *binder*, not a grid of cards. The physicality is the product. |
| **Flat pills, not Liquid Glass** | Glass gave every small control its own depth and specular edge; with a pager, a count, a search field and two tabs on screen the chrome competed with the binder. Flat pills read as one system and let the binder be the only thing with weight. Superseded the original "chrome uses Liquid Glass" rule. |
| **One pill per control; no container around a group** | Nested containers were explicitly rejected. Also why `.pickerStyle(.segmented)` is out *in the toolbar*. |
| **No window title** | It sits between the view tabs and the search field and pushes the search off centre. |
| **Corner badge + name card layout** | Keeps the Pokédex number legible even when the card is missing and desaturated. |
| **Card art centred in the pocket** | Square artwork in a 5:7 pocket was top-aligned, dumping all its slack below and reading as sitting too high. |
| **Search pill: no outline at all** | It had two — ours, and macOS 26's own toolbar-item container 3pt outside it. The doubled edge was the complaint. |
| **Missing cards: greyscale + dashed sleeve** | Reads as "empty pocket" at a glance while keeping the number readable. |
| **Detail popover with an explicit toggle** | Never click-to-toggle; browsing shouldn't mutate the collection. |
| **Three separate pager pills, click-to-edit number** | The gap gives the field's focus ring room; arrows want to be round. Click-to-edit stops the app opening with the number selected. |
| **Adaptive light/dark, now with a Light/Dark/Auto override** | Auto stays the default — the app follows System Settings unless told otherwise. |
| **Forest green + brass** | The cover and hardware palette. |
| **App name `PokéBinder`**, with the accent | Matches the official Pokémon spelling. Bundle display strings only; there is still no window title. |
| **macOS 26 only** | See §2 — a fallback for 14/15 could never be tested here. |
| **Grid segment live, landing on "Coming soon"** | Better than a disabled control that gives no feedback. |
| **Notion is optional** | The binder is fully usable offline; Notion adds ownership sync, it isn't a prerequisite. |

## 9. Not in scope

Multi-generation binders, duplicate tracking, condition/grading, sharing, the real Grid view, and an
app icon (a `Scripts/make_icon.swift` could follow Dosa's pattern later).
