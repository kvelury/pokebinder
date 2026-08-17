# PokeBinder — Design Doc

Single source of truth for this project: the plan and the handoff, copied verbatim.
Part 1 is built; parts 2 and 3 are open.

---

# PART ONE OF TWO — THE PLAN

# PokeBinder — native macOS Pokémon binder

## Context

`~/Downloads/pokemon-binder-app-spec.md` describes a virtual Gen 1 Pokémon card binder backed by a
Notion database, assuming React + Tailwind on the web. The user wants a **native macOS app**
(macOS 14+, Liquid Glass on macOS 26) and is designing the visuals themselves — so the spec is the
authority on *features and data plumbing only*, never on look and feel.

The work is split into **three parts of roughly equal effort**. Part 1 is the foundational PR and is
**complete**. Parts 2 and 3 are written to be picked up by other coding agents, and are deliberately
**independent of each other** — they touch nearly disjoint files and can run in parallel.

Full context for a fresh agent lives in `/Users/kvelury/repos/pokebinder/design_doc.md`
(plan + handoff, verbatim).

---

## The seam that makes parts 2 and 3 parallel

Part 1 established two contracts. Neither part 2 nor part 3 should need to change them:

1. **`OwnershipBackend`** (`CollectionStore.swift`) — a `@MainActor` protocol with
   `loadOwnership() async throws -> [Int: Bool]` and `setOwned(dex:owned:) async throws`.
   Part 1 ships `LocalOwnershipBackend` (UserDefaults). **Part 3 adds a Notion conformance and hands
   it to `CollectionStore.use(_:)` — no view file changes.** No view knows where ownership lives.
2. **`BinderState.goTo(page:)`** — every page change funnels through this single method (arrows,
   editable field, and in part 2 the search auto-flip). **Part 2 hooks the page-turn animation here**,
   and `BinderSpread` is already isolated so two spreads can be rendered at once mid-turn.

---

## Part 1 — Foundation ✅ COMPLETE

The baseline PR: build system, data layer, theme, and a fully usable static binder.

**Delivered:**
- `Package.swift` (SPM, macOS 14 target), `build.sh` (assembles + ad-hoc signs `build/PokeBinder.app`),
  `Resources/Info.plist`, `.gitignore`. No Xcode on this machine, so no `.xcodeproj`.
- `Pokedex.swift` — 151 bundled names (spellings verified against Notion) + the page/side/slot
  derivation, including `dexNumber(page:side:slot:)` returning nil for the empty pocket on page 19.
- `Models.swift` — `BinderSide`, `ViewMode`, `BinderSlot`, `SlotEmphasis`.
- `Theme.swift` — forest/brass in light **and** dark via `NSColor` dynamic providers (SPM has no
  asset catalog), plus `BinderMetrics` which solves the whole spread's geometry from one card width.
- `ArtworkStore.swift` — actor with permanent disk cache + in-flight dedup + page prefetch, a
  main-actor decoded-image cache, and `CardArtworkView`.
- `CollectionStore.swift` — `OwnershipBackend`, `LocalOwnershipBackend`, and the optimistic
  `CollectionStore` (flip locally, persist, revert + report on failure).
- `BinderState.swift` — page navigation, plus the full search behaviour: match computation, auto-flip
  to the first match as you type, `currentMatchIndex` with ⏎/⌘G/⇧⌘G cycling, and `emphasis(for:)`
  distinguishing the current match from other matches.
- `WindowConfigurator.swift` — hides the window title via `NSWindow.titleVisibility`
  (`.hiddenTitleBar` would take the toolbar with it).
- Views — `BinderView`/`BinderSpread`/`SpineView` (cover, rings, gutter shadow), `PageSideView`,
  `CardSlotView` (corner badge + name, owned/missing/spotlight), `CardDetailPopover`, `PagerBar` +
  `CollectedCountPill`, `GridViewStub`, `SettingsSheet` shell, `GlassChrome` (ported `FloatingChrome`),
  `ContentView` (native toolbar, search centred), `PokeBinderApp`.

**Working end-to-end:** opens to page 1; arrows and the editable field navigate all 19 pages; search
flips the binder to the first match, rings it in brass, rings other matches faintly, dims non-matches,
and ⏎/⌘G cycle through matches with an "n of m" counter; clicking a card opens the detail popover
whose Owned toggle persists locally; Grid segment lands on the Coming Soon container; light/dark
both render; toolbar and pager use Liquid Glass on macOS 26.

**Toolbar is deliberately bare** (user's call): plain text tabs with a brass underline for the active
view, a background-less search field, a plain gear, and no window title. macOS 26 already draws a
glass capsule around each toolbar item, so any container of ours inside one reads as an oval nested
in an oval — do not reintroduce `.pickerStyle(.segmented)` or a capsule behind the search field.

**Two traps already hit and fixed:**
- A `@MainActor` type cannot be constructed in a *default argument* (evaluated nonisolated) — build
  it in the initializer body instead.
- Search that only styles the current page reads as completely broken. Any feature that highlights
  something off-screen must also navigate to it.

---

## Part 2 — Motion & gestures

**Nothing in this part touches Notion or ownership.** Files: `BinderView.swift`, `BinderState.swift`,
`ContentView.swift`.

> Scope note: search auto-flip, ⏎/⌘G match cycling and ⌘F were pulled forward into part 1 — without
> the auto-flip, search appeared broken (typing a name not on the current page just dimmed every
> card). Trackpad swipe navigation moved here to keep the three parts balanced.

1. **3D page turn on the ring axis.** `BinderSpread(page:metrics:selectedDex:)` already renders one
   complete spread. Keep the outgoing and incoming spread in the hierarchy during the transition and
   drive `rotation3DEffect(.degrees(θ), axis: (0,1,0), anchor: .leading /* or .trailing */, perspective: 0.6)`
   from 0 → ±180 over ~0.45s, with a shadow whose opacity tracks |θ|. Direction comes from the sign
   of the page delta in `goTo(page:)`. Watch z-ordering: the turning page must pass *over* the page
   it is uncovering and *under* the cover.
2. **Interruptibility.** Search auto-flip can fire on every keystroke, so a turn already in flight
   must retarget rather than queue — hold the animation on `currentPage` rather than a one-shot task.
3. **Reduce Motion.** `@Environment(\.accessibilityReduceMotion)` → instant swap, no rotation.
4. **Trackpad swipe.** Two-finger horizontal swipe turns the page, per the spec's "prev/next arrows
   or swipe". Ideally interactive — the page follows the finger and completes or springs back.
5. **Keyboard.** ⌘← / ⌘→ for previous/next page, respecting the 1…19 clamp.

**Verify:** flipping in both directions animates around the rings and settles; typing quickly into
search retargets mid-turn without stacking animations; Reduce Motion makes turns instant; swipe and
⌘←/⌘→ both clamp at pages 1 and 19.

---

## Part 3 — Notion MCP integration

**Nothing in this part touches binder rendering or animation.** Files: new
`Sources/PokeBinder/Notion/`, `SettingsSheet.swift`, and one line in `ContentView.swift`.

1. **Port from Dosa, near-verbatim** (see design_doc for why these are trustworthy):
   - `~/repos/dosa/Sources/Dosa/Notion/NotionAuth.swift` → OAuth 2.1 + PKCE + RFC 7591 dynamic client
     registration + `LoopbackHTTPServer` on ports 53682–53685. Rename `client_name` to PokeBinder and
     repoint the `AppSettings.notion*Key` constants at this app's own keys.
   - `~/repos/dosa/Sources/Dosa/Notion/NotionMCPClient.swift` → Streamable HTTP MCP client.
2. **`NotionManager.swift`** for *this* schema: `fetchAll()` issuing one
   `notion-query-data-sources` call, and `setOwned` issuing `notion-update-page`. Keep each row's
   `id` keyed by Pokédex number — that id is the `page_id` for writeback. Join on `Pokédex #`, never
   on name.
3. **`NotionOwnershipBackend: OwnershipBackend`** wrapping the manager. This is the only integration
   point: `await collection.use(notionBackend)`.
4. **Snapshot cache** to `~/Library/Application Support/PokeBinder/ownership.json`, so ownership
   paints correctly and instantly on launch before the network returns.
5. **`SettingsSheet`** — replace the disabled button with a real Connect/Disconnect, live status, and
   the workspace name. The database-id field is already wired to `@AppStorage("notionDatabaseId")`.
6. **`ContentView.task`** — if a stored token exists, install the Notion backend on launch.

**Verify:** Connect → browser consent → returns connected; binder repaints to **33 owned / 118
grayscale-dashed** (that is the live count, confirmed during planning); relaunch stays connected and
paints ownership immediately; flipping the popover toggle changes the row in Notion; a forced failure
reverts the local flip and surfaces the error.

---

## Build and run

```bash
./build.sh                 # → build/PokeBinder.app, ad-hoc signed
```
Launch via the **`build-and-run-macos-app`** skill — it quits any running instance first, which
`open` alone will not do (you would silently keep testing a stale build).

## Not in scope

Multi-generation binders, duplicate tracking, condition/grading, sharing, the real Grid view, an app icon.


---

# PART TWO OF TWO — THE HANDOFF

# Handoff — PokeBinder, a native macOS Pokémon binder

**Status: Part 1 (foundation) is built and running. Parts 2 and 3 are open.**
The work is split into three roughly equal parts. Parts 2 and 3 touch nearly disjoint files and can
be done in either order, or in parallel, by different agents.

---

## 1. What this is

A native macOS app that virtualizes a physical Gen 1 Pokémon card binder. It opens straight to
page 1 of a 19-page binder, you flip pages with arrows or by typing a page number, you search to
spotlight a Pokémon, and each card shows its name, Pokédex number, and hi-res official artwork.
Ownership comes from a Notion database over MCP.

The starting point was `~/Downloads/pokemon-binder-app-spec.md`, which specifies a **React + Tailwind
web app**. That was overridden: the user wants a **native macOS app (macOS 14+, Liquid Glass on
macOS 26)**. Treat the spec as the authority on *data plumbing and features only* — not on look,
feel, or stack. The user is designing the visuals themselves; every visual decision in §4 was chosen
by them from visualized options, so **do not change any of them without asking.**

## 2. Environment constraints (checked, not assumed)

| Fact | Value | Consequence |
|---|---|---|
| Xcode | **Not installed** — Command Line Tools only | **No `.xcodeproj`, no `xcodebuild`.** SPM + a hand-assembled `.app` |
| Swift | 6.3.3 | fine |
| macOS SDK | 26.5 | Liquid Glass APIs compile |
| This Mac | macOS 26.6.1 | the Liquid Glass path is testable locally; the 14/15 fallback is not, without forcing the `#else` |
| Deployment target | macOS 14.0 | `Package.swift` → `platforms: [.macOS(.v14)]` |

The repo is **not a git repository** yet.

## 3. Verified facts about the data

Confirmed live via Notion MCP during planning — not assumptions:

- Database `187a66ca-0d0d-40da-b3aa-64f51adceb65` returns **151 rows, 33 currently owned**.
- Schema matches the spec: `Name`, `Pokédex #`, `Page`, `Absolute Position`, `Owned`
  (`"__YES__"` / `"__NO__"`), plus a per-row `id` used as `page_id` for writeback.
- **Notion's stored `Page` and `Absolute Position` agree with the spec's formula for all 151 rows
  (0 mismatches).** So layout is fully derivable offline; Notion supplies **only** the `Owned` bit
  and the row `id`. This is why the binder renders before any connection exists.
- Exact name spellings, already bundled in `Pokedex.swift`: `Nidoran♀` (#29), `Nidoran♂` (#32),
  `Farfetch'd` (#83, straight apostrophe), `Mr. Mime` (#122).
- Artwork CDN returns 200 for #1/#25/#150/#151:
  `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/{n}.png`
  — 475×475 PNG with alpha, public, immutable.

### Layout derivation (implemented in `Pokedex.swift`)

```swift
page   = (n - 1) / 8 + 1        // 1...19
absPos = (n - 1) % 8 + 1        // 1...8
side   = absPos <= 4 ? .left : .right
slot   = absPos <= 4 ? absPos : absPos - 4
```

**⚠️ Page 19 holds only #145–#151 — the last pocket is permanently empty.**
`Pokedex.dexNumber(page:side:slot:)` returns nil there and `CardSlotView` draws an empty sleeve.
Do not "fix" this into an error path.

## 4. Design decisions — locked with the user

Every row was picked by the user from visualized alternatives. **Do not undo without asking.**

| Area | Decision |
|---|---|
| Binder chrome | **Full skeuomorphic binder** — cover surrounding the spread, 3 rings down the center, page shadow into the gutter |
| Liquid Glass | **Chrome only** — toolbar, pager bar, Settings. Pages and sleeves stay opaque |
| Card slot | **Corner badge + name** — mono number badge top-left, art centered, name centered at the base |
| Appearance | **Adaptive light/dark** following System Settings |
| Page turn | **3D page turn on the ring axis**, ~0.45s, shadow sweeping the page underneath *(part 2)* |
| Search | **Auto-flip + spotlight**; ⏎/⌘G cycles matches *(auto-flip and cycling are part 2)* |
| Pager | **Three separate glass capsules** — `◀` · editable `N / 19` · `▶` |
| Toolbar | Native toolbar, **search centered**; Binder\|Grid leading; ⚙ trailing; collected count in the bottom bar |
| Missing card | **Grayscale + dashed sleeve**, number still legible |
| Card click | **Detail popover** with an explicit `Owned` toggle — never click-to-toggle |
| Cover + accent | **Forest green + brass** (below) |
| Grid view | Segment **live and switchable**, lands on a "Coming soon" empty state |

### Palette (in `Theme.swift`)

|  | Light | Dark |
|---|---|---|
| cover | `#2E4A3C` | `#12211B` |
| page | `#FFFFFE` | `#172420` |
| sleeve | `#F0F5F1` | `#1F2E28` |
| rings / accent | `#A8863C` | `#D0A94F` |

Typography per the spec: mono for numbers, rounded sans for names.

### Behaviors agreed alongside

- The binder renders **with or without Notion**; Settings is genuinely optional.
- Connection persists and loads on app start.
- **Reduce Motion** downgrades the page turn to an instant swap.

---

## 5. The two contracts that keep parts 2 and 3 independent

**Do not change these.** They are why the remaining work parallelizes.

1. **`OwnershipBackend`** (`CollectionStore.swift`) — `@MainActor` protocol:
   ```swift
   var displayName: String { get }
   func loadOwnership() async throws -> [Int: Bool]
   func setOwned(dex: Int, owned: Bool) async throws
   ```
   Part 1 ships `LocalOwnershipBackend` (UserDefaults). **Part 3 writes a Notion conformance and
   calls `CollectionStore.use(_:)`. No view file changes.** `CollectionStore` already does the
   optimistic flip + revert-on-error, so part 3 only has to throw.

2. **`BinderState.goTo(page:)`** — every page change funnels through it (arrows, editable field, and
   in part 2 the search auto-flip). **Part 2 hooks the animation here.** `BinderSpread` is already a
   standalone view so two spreads can be on screen at once mid-turn.

---

## 6. Part 1 — foundation ✅ COMPLETE

```
pokebinder/
├── build.sh                    ✅ swift build -c release → build/PokeBinder.app, ad-hoc signed
├── Package.swift               ✅ SPM, macOS 14 target
├── Resources/Info.plist        ✅ com.pokebinder.app
└── Sources/PokeBinder/
    ├── PokeBinderApp.swift     ✅ @main, 1320×900 default, 1000×780 min
    ├── Pokedex.swift           ✅ 151 names + derivation + artwork URL
    ├── Models.swift            ✅ BinderSide, ViewMode, BinderSlot, SlotEmphasis
    ├── Theme.swift             ✅ adaptive colors + BinderMetrics geometry solver
    ├── ArtworkStore.swift      ✅ actor + disk cache + prefetch + CardArtworkView
    ├── CollectionStore.swift   ✅ OwnershipBackend, LocalOwnershipBackend, CollectionStore
    ├── BinderState.swift       ✅ navigation + full search (auto-flip, cycling, emphasis)
    └── Views/
        ├── ContentView.swift        ✅ bare toolbar, search centered, bottom bar
        ├── WindowConfigurator.swift ✅ hides the window title, keeps the toolbar
        ├── BinderView.swift         ✅ BinderView + BinderSpread + SpineView
        ├── PageSideView.swift       ✅ 2x2 side + gutter shadow
        ├── CardSlotView.swift       ✅ badge/art/name, owned/missing/spotlight, popover
        ├── CardDetailPopover.swift  ✅ big art + Owned toggle
        ├── PagerBar.swift           ✅ three glass capsules + CollectedCountPill
        ├── GridViewStub.swift       ✅ Coming soon container
        ├── SettingsSheet.swift      ✅ shell; Notion section disabled pending part 3
        └── GlassChrome.swift        ✅ ported FloatingChrome
```

Working end to end: opens to page 1; arrows and the editable field navigate all 19 pages (clamped,
invalid input reverts); search flips the binder to the first match, rings it in brass, rings other
matches faintly, dims non-matches, and ⏎/⌘G/⇧⌘G cycle with an "n of m" counter; clicking a card opens
the popover and the Owned toggle persists locally; Grid lands on the stub; light and dark both render;
toolbar and pager use Liquid Glass on macOS 26.

### Toolbar is deliberately bare — do not "restore" it

The user explicitly rejected nested containers. macOS 26 already draws a glass capsule around **every
toolbar item**, so anything with its own background inside one reads as an oval within an oval. So:
plain text tabs with a brass underline for the active view, a search field with **no** background,
a plain gear, and **no window title** (`WindowConfigurator` sets `titleVisibility = .hidden`;
`.windowStyle(.hiddenTitleBar)` would remove the toolbar too).
**Do not reintroduce `.pickerStyle(.segmented)` or a `Capsule` behind the search field.**

**Two traps already hit:**
- A `@MainActor` type cannot be constructed in a *default argument* (evaluated in a nonisolated
  context). Build it in the initializer body.
- A highlight that only styles the visible page reads as broken. Anything that emphasises an
  off-screen item must also navigate to it.

## 7. Part 2 — motion & gestures (OPEN)

Touches `BinderView.swift`, `BinderState.swift`, `ContentView.swift`. **No Notion, no ownership.**

> **Scope note:** search auto-flip, ⏎/⌘G cycling and ⌘F were pulled forward into part 1. Search that
> only highlighted the *current* page read as completely broken — typing a name that lived on another
> page just dimmed all 8 cards. Trackpad swipe moved here to keep the parts balanced.

1. **3D page turn.** Render outgoing + incoming `BinderSpread` together and drive
   `rotation3DEffect(.degrees(θ), axis: (0,1,0), anchor: .leading /* or .trailing */, perspective: 0.6)`
   0 → ±180 over ~0.45s, shadow opacity tracking |θ|. Direction from the sign of the page delta.
   Mind z-ordering: the turning page passes *over* what it uncovers and *under* the cover.
2. **Interruptibility.** Auto-flip fires on every keystroke, so a turn in flight must retarget rather
   than queue. Drive the animation from `currentPage` rather than a one-shot task.
3. **Reduce Motion** → instant swap via `@Environment(\.accessibilityReduceMotion)`.
4. **Trackpad swipe.** Two-finger horizontal swipe to turn pages, per the spec's "arrows or swipe".
   Interactive (page follows the finger, completes or springs back) is the goal.
5. **Keyboard.** ⌘← / ⌘→ page, clamped to 1…19.

**Verify:** turns animate around the rings in both directions; typing fast into search retargets
mid-turn without stacking animations; Reduce Motion makes turns instant; swipe and ⌘←/⌘→ clamp at
pages 1 and 19.

## 8. Part 3 — Notion MCP integration (OPEN)

Touches a new `Sources/PokeBinder/Notion/`, `SettingsSheet.swift`, and one line of `ContentView.swift`.
**No binder rendering or animation.**

1. **Port from Dosa near-verbatim** — these are working, production code, don't reinvent them:
   - `~/repos/dosa/Sources/Dosa/Notion/NotionAuth.swift` (382 lines) — OAuth 2.1 against
     `https://mcp.notion.com/mcp` with RFC 7591 dynamic client registration (**no embedded secret**),
     PKCE/S256, `.well-known` discovery with fallbacks, token refresh, and `LoopbackHTTPServer`
     (an `NWListener` on ports 53682–53685) catching the browser redirect.
   - `~/repos/dosa/Sources/Dosa/Notion/NotionMCPClient.swift` (206 lines) — Streamable-HTTP MCP:
     `initialize` → `notifications/initialized` → `tools/call`, `Mcp-Session-Id`, retry-once on
     400/404 session expiry, SSE parsing that picks the response matching the request id.
   - `~/repos/dosa/Sources/Dosa/Notion/NotionManager.swift` — the `ObservableObject` shape and
     `callToolAuthorized(_:_:)` retry-after-refresh pattern.

   Rename `client_name`/`clientInfo` to PokeBinder and repoint the `notion*Key` constants.

2. **`NotionManager.swift`** for this schema:
   ```json
   {"data": {
     "data_source_urls": ["collection://187a66ca-0d0d-40da-b3aa-64f51adceb65"],
     "query": "SELECT * FROM \"collection://187a66ca-0d0d-40da-b3aa-64f51adceb65\" ORDER BY \"Pokédex #\" ASC"
   }}
   ```
   Join on `Pokédex #` (**not** name). Keep each row's `id` keyed by dex number. Write with
   `notion-update-page`:
   ```json
   {"command": "update_properties", "page_id": "<row id>", "properties": {"Owned": "__YES__"}}
   ```
3. **`NotionOwnershipBackend: OwnershipBackend`** — the only integration point.
   `await collection.use(notionBackend)`.
4. **Snapshot cache** to `~/Library/Application Support/PokeBinder/ownership.json` so ownership paints
   instantly on launch before the network returns.
5. **`SettingsSheet`** — replace the disabled button with real Connect/Disconnect, live status, and
   workspace name. The database-id field is already bound to `@AppStorage("notionDatabaseId")`.
6. **`ContentView.task`** — install the Notion backend on launch when a token exists.

**Verify:** Connect → consent → connected; binder repaints to **33 owned / 118 grayscale-dashed**;
relaunch stays connected and paints immediately; the popover toggle changes the Notion row; a forced
failure reverts the local flip and surfaces the error.

## 9. Liquid Glass rules (from Dosa's hard-won comments)

```swift
#if canImport(FoundationModels)   // compile-time macOS 26 SDK probe
if #available(macOS 26.0, *) {    // runtime check
    content.glassEffect(.regular, in: shape)
} else { material(content) }
#else
material(content)
#endif
```

1. **Never apply `floatingChrome` to a toolbar item** — macOS 26 gives toolbar items their own glass;
   ours on top is glass-on-glass.
2. **Never put `if #available` inside a `.toolbar { }` closure.**
   `ToolbarContentBuilder.buildLimitedAvailability` is macOS 14.5+ and we target 14.0, so it resolves
   to the *obsoleted* overload ("may crash on earlier versions"). Put the branch in a `ViewBuilder`
   outside the closure.
3. **Never `.interactive()`** on glass that contains its own controls — only on glass that *is* one
   button.

## 10. Build and run

```bash
./build.sh          # → build/PokeBinder.app, ad-hoc signed
```
Launch via the **`build-and-run-macos-app` skill**. It quits any running instance first; `open` alone
just foregrounds a stale build and you will think your change didn't apply. Don't pass `--install`
unless asked.

## 11. Not in scope

Multi-generation binders, duplicate tracking, condition/grading, sharing, the real Grid view, an app
icon (a `Scripts/make_icon.swift` can follow Dosa's pattern later).
