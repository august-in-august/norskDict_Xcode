# norskDict — development log

Working name: **Slå opp** ("look it up"). An offline Norwegian learner's dictionary for
iPhone/iPad (iOS/iPadOS 18.0+): Bokmål and Nynorsk side by side, any inflected form finds
its headword, every definition/example has English and Simplified Chinese translations.
Fully offline, no account, no server. Target App Store release: Feb 1, 2027.

This file is the running log of what's been done and what's next. Full background lives in:
- `docs/development_plan_v2.docx` — product plan, phases, licensing, risks (source of truth)
- `DATABASE.md` — schema and query reference for `norskdict.sqlite`
- `docs/design/` — Claude Design handoff (`project/SlaOppApp.dc.html` + `support.js`) with
  pixel-level specs for every screen (Search, Entry, Bookmarks, History, Settings, Sources)

## App at a glance
- **Content**: 186,912 articles (bm 90,865 / nn 96,047), ~843,725 searchable forms, senses,
  examples, idioms, inflection paradigms. All bundled in one read-only SQLite file.
- **Stack**: Swift 6, SwiftUI, deployment target iOS/iPadOS 18.0. GRDB.swift for read-only
  access to `norskdict.sqlite`. User data (bookmarks, history) in SwiftData; view preferences
  in `AppSettings` (an `@Observable` class backed by plain `UserDefaults`, not `@AppStorage` —
  see "Decisions made").
- **Navigation**: TabView (Search/Bookmarks/History/Settings), each its own `NavigationStack`,
  on iPhone; a 3-column `NavigationSplitView` (sidebar/content/detail) on iPad. Both share one
  `AppRoute` enum and a `destinationView(for:open:)` renderer — see `Navigation/RootView.swift`.
- **Not in git**: `norskdict.sqlite` (214 MB build artifact, rebuilt via the companion
  `norskDict` pipeline repo's `build_db.py`). Xcode still bundles the local copy as an app
  resource; see `.gitignore`.
- **Status**: all v1 screens from the design are built and wired to the real database —
  Search (home/typing/results), Entry, Bookmarks, History, Settings, Sources. 17 unit tests,
  all passing. Verified interactively on iPhone and iPad simulators. Not yet done: performance
  profiling on older devices, accessibility audit, TestFlight.

## Repo layout
```
norskDict/                    Xcode project root (this repo)
├── norskDict/                 app target sources
│   ├── Data/                    DictionaryDatabase (GRDB), Fold, SimilarHeadwords, Models, Labels
│   ├── Navigation/               AppTab, AppRoute, RootView (the adaptive shell)
│   ├── Search/, Entry/, Bookmarks/, History/, Settings/, Speech/   one folder per screen/feature
│   ├── Theme/                    Theme (5 palettes × light/dark), Strings (EN/ZH copy)
│   ├── User/                     Bookmark, HistoryEntry (SwiftData models)
│   └── UI/                       small shared components (DictBadge, SegmentedPill, chips)
├── norskDictTests/              Swift Testing unit tests (data layer, fold, labels, paradigms)
├── norskDict.xcodeproj/
├── docs/
│   ├── development_plan_v2.docx
│   └── design/                 Claude Design handoff bundle (read project/SlaOppApp.dc.html first)
├── DATABASE.md
├── norskdict.sqlite            (gitignored — present locally, bundled into the app target)
└── develop.md                  this file
```

## Decisions made
- `norskdict.sqlite` is excluded from git (matches the note in `DATABASE.md`); it's a
  reproducible build artifact, and at 214 MB it would blow past GitHub's 100 MB file limit
  without git-lfs. The Xcode project still references the local file as a bundled resource.
- Reference docs (`DATABASE.md`, the development plan, and the full design handoff) are
  copied into this repo under version control so implementation work has everything in one
  place and history tracks how the spec evolves.
- **Settings is `@Observable` backed by plain `UserDefaults`, not `@AppStorage`.** Wrapping
  `@AppStorage` properties behind `@ObservationIgnored` computed properties looks tempting but
  silently breaks SwiftUI invalidation: `@Observable` only tracks reads of its own instrumented
  stored properties, and `@ObservationIgnored` opts the backing storage out of that. `AppSettings`
  uses plain stored `var`s with `didSet { UserDefaults.standard.set(...) }` instead.
- **The in-app UI language (EN/中文) is a hand-written `Strings` struct, not String Catalogs.**
  String Catalogs follow the system locale; the product plan requires an in-app toggle
  independent of the device language, which String Catalogs can't do without bundle hacks.
- **Reverse-translation search (English/Chinese) always runs in parallel with the Norwegian
  form lookup, never as a fallback gated on "no Norwegian hits."** A query can legitimately
  prefix-match an unrelated inflected form (e.g. "friend" prefix-matches "friende", an
  inflection of the verb "fri") while still being a word the user meant to look up in English —
  found via simulator testing, see the progress log below.
- **Inflection table is one generic label/forms list, not the design mock's noun-2×2/verb-4-col
  special cases.** The mock's `table()` helper only covered the two word classes its demo data
  used; real articles span many more (adjectives, pronouns, prepositions...), so a generic
  vertical table (one row per paradigm row, tag label + forms) is used for every part of speech.
- **Every idiom (fixed expression) renders through the same `SenseRowView` as regular senses**,
  not the design mock's flattened single def/en/zh — real idiom entries can have up to 9 senses
  and their own examples (verified against the data), unlike the mock's simplified demo idioms.
- **History is recorded by `EntryView` whenever an entry is opened** (from search, bookmarks,
  history itself, or a cross-reference), keyed by `(dict, uibId)` — never `rowid`, which isn't
  stable across database rebuilds (per `DATABASE.md`'s "Gotchas").
- **Known limitation**: the Bokmål/Nynorsk "counterpart" lookup for the entry screen's
  side-by-side columns matches on exact `headword` string. Articles whose headword differs
  slightly between dictionaries (e.g. bm "venn" vs nn "ven, venn") won't find each other. Low
  priority — most headword pairs match exactly — but worth a smarter match (e.g. comparing each
  comma-separated spelling) if it comes up in testing.

## Open decisions (from the product plan, unresolved)
- Final app name (working name "Slå opp")
- Pricing model (free / paid up front / one-time unlock — no subscription needed, no running costs)
- Data update cadence (every release vs. quarterly)
- Norwegian as a third UI language

(English/Chinese reverse search was an open decision in the plan — v1 now ships it, running in
parallel with Norwegian form lookup; see "Decisions made" above.)

## Progress log
### 2026-10-09
- Initial Xcode project created (`norskDict.xcodeproj`, default SwiftUI template:
  `ContentView.swift`, `Item.swift`, `norskDictApp.swift`).
- GRDB added as a Swift package dependency (`Package.resolved` present).
- Set up git repo hygiene: added `.gitignore` (Xcode user state, `.DS_Store`,
  `norskdict.sqlite`), unstaged the sqlite file, brought in `DATABASE.md`, the development
  plan, and the design handoff bundle as versioned reference docs.
- Wrote this `develop.md` as the project's running development log.
- Built the full v1 UI shell end to end (plan phases 2–5 in one pass), verified interactively
  in the iOS simulator after every screen:
  - **Data layer**: `DictionaryDatabase` (lazy read-only GRDB connection), `fold()` +
    letter-tolerant variants (aa→å, oe→ø, ae→æ), `SimilarHeadwords` (bounded-Levenshtein fuzzy
    match over ~190k lemma folds), `Models`/`Labels` (POS and inflection-tag → EN/中文 display
    labels). All SQL verified directly against `norskdict.sqlite` via the `sqlite3` CLI before
    wiring into Swift.
  - **Foundation**: `AppSettings`, `Theme` (5 palettes × light/dark), `Strings` (EN/中文 copy),
    `Bookmark`/`HistoryEntry` SwiftData models, `RootView` (adaptive TabView/NavigationSplitView
    shell, `AppRoute`-based navigation shared between both).
  - **Search**: home (recent + tip), live typing results (Bokmål/Nynorsk/Similar-headwords
    groups), submitted results (segmented BM/NN pill + swipeable pages + page dots).
  - **Entry**: senses with nested sub-senses and examples, fixed expressions and inflection as
    collapsible sections (state remembered across entries via `AppSettings`), generic inflection
    table with the searched form highlighted, tappable cross-references, EN/中文 toggles with a
    machine-translated notice + mailto report action, pronunciation (nb-NO), bookmarking.
    iPhone: segmented/swipeable BM↔NN. iPad: side-by-side columns.
  - **Bookmarks/History/Settings/Sources**: swipe-to-remove bookmarks, day-grouped history with
    clear confirmation, theme/appearance/translation-defaults/UI-language/text-size settings,
    licence attribution screen.
  - **Tests**: added a `norskDictTests` Swift Testing target (17 tests: fold/variants, form
    lookup incl. Nynorsk-only and letter-tolerant input, English/Chinese reverse search, entry
    sense/subsense/cross-reference loading, similar-headwords, paradigm tag-merging, labels).
    All passing.
  - **Bugs found and fixed during simulator verification** (via a device-interaction subagent
    driving the real app, not just unit tests): (1) English reverse search for "friend" never
    ran because a prefix match on the unrelated inflected form "friende" made the
    emptiness-gated fallback condition false — fixed by always running reverse search in
    parallel; (2) the BM/NN tab could get stuck on the wrong dictionary after a fast
    search-then-submit because `submit()` read `groups` before the in-flight async search had
    resolved — fixed by keeping `dictTab` in sync reactively as results land, not decided at
    submit time; (3) Settings/Bookmarks/History screens didn't visually update when the user
    picked a different color theme, because the Settings `Form` had no `.background(theme.grp)`
    and the Bookmarks/History empty-state `VStack`s hugged their text's width instead of filling
    the screen (so `.background(theme.bg)` only painted a narrow band) — both fixed.
- **Next**: plan phases 6–7 — performance testing on iPhone XS-class hardware (50ms/keystroke,
  5ms form lookup targets from the plan), accessibility pass (Dynamic Type, VoiceOver labels,
  contrast per theme), TestFlight beta, App Store listing/screenshots/privacy label.

### 2026-10-09 (later) — App icon picker
- Merged the 9-icon set from `../NorskDict app development/AppIcons/` (Claude Design handoff:
  Å Tile/Speech å "Simple", Moose/Happy Book/Greetings "Cute", Theme Split/Card Stack/Flag
  Lens/Lookup Arrow "Modern" — each with light/dark/tinted appearances) into
  `Assets.xcassets`: 9 `.appiconset`s + 9 `IconPreview-*.imageset`s (180pt previews for the
  in-app picker, since alternate app icons can't be loaded with `Image(_:)`).
  - Adapted the handoff's `AppIconOption.swift`/`AppIconPicker.swift` to this codebase's
    conventions: `@Observable AppIconManager` instead of `ObservableObject`/`@Published`;
    bilingual `displayName(ui:)`/`Style.label(ui:)` instead of English-only strings, matching
    `ThemePalette.displayName(ui:)`; `theme.tint`/`theme.ink` instead of `.accentColor`/
    `.primary`. Added `AppIconSection()` to `SettingsView.swift` right after the theme-color
    picker.
  - Verified in the simulator: all 9 tiles render real previews grouped correctly into
    Simple(2)/Cute(3)/Modern(4), primary icon shows selected by default.
  - **Resolved 2026-10-10**: the agent couldn't set `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS`
    via Xcode's build-setting UI (not listed as a standard searchable setting in this Xcode
    version) or via the MCP build-setting tool (rejected as an unknown key) or by editing
    `project.pbxproj` directly (blocked — Xcode was open, and direct pbxproj edits with Xcode
    open risk crashing/corrupting it). The user added it manually as a **user-defined build
    setting**, name `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS`, value `YES` — confirmed
    working on a physical device (icon switching shows iOS's native "You have changed the icon"
    confirmation, as expected).

### 2026-10-10 — Settings UI adjustments
- **Icon picker simplified**: removed the Simple/Cute/Modern style grouping (`AppIconOption.Style`
  deleted — it was unused once the grouping UI was dropped). `AppIconSection` is now a single
  horizontally-scrolling row of all 9 icons, each just a preview tile + name, no category headers.
- **4 new theme palettes**: Blush, Slate, Lavender, Butter (joining White/Paper/Grey/Sage/Mist —
  9 total), following the same light/dark bg-grp-card pattern as the original 5. The theme swatch
  row in Settings now scrolls horizontally instead of a fixed `HStack` (9 swatches no longer fit
  on screen at once).
- **Left/right-hand navigation layout**: new `NavigationHand` setting (`.left`/`.right`) in
  `AppSettings`, surfaced as a segmented control in a new Settings section between Appearance and
  App Icon. `.left` (default, preserves the original unchanged tab order — Search
  first/leading) keeps Search closest to a left thumb's reach; `.right` reverses the order
  (`AppTab.ordered(for:)`) so Search ends up last/trailing, closer to a right thumb. Applied to
  both the iPhone `TabView` and the iPad sidebar `List`.
- **Content stats moved from Settings → About to the Sources screen**: removed the flat
  "Articles: 186,912" row from Settings; added `DictionaryDatabase.contentStats()` (reads
  `meta.stats` JSON + a `GROUP BY dict` query for the bm/nn split) and a new `ContentStats`
  model. Sources now shows a full breakdown — "186,912 articles (bm 90,865 / nn 96,047),
  265,871 senses, 198,741 examples, 21,135 fixed expressions, 843,725 searchable forms." —
  above the existing build-date/version line.
- All 17 unit tests still pass; all 4 changes verified together in the simulator (theme scroll
  + selection, hand-order reversal on the live tab bar, single-row icon picker, Sources stats
  line with live DB counts).
