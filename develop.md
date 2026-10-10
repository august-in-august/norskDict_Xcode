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

### 2026-10-10 (later) — Visual polish + real inflection tables
- **Theme swatch gap widened** (4pt → 18pt spacing) and the **icon picker's two longest names
  shortened** ("Hei · Hi · 你好" → "Greetings"/"问候语", "Lookup Arrow" → "Lookup"/"查词") plus a
  wider label frame and trailing scroll padding, so the last tile in the row isn't clipped.
- **Sources stats sentence** now spells out "Bokmål"/"Nynorsk" instead of "bm"/"nn" abbreviations.
- **Inflection tables rebuilt to match ordbøkene.no's layout**, verified against its actual
  rendering for "dusje" (verb), "pen" (adjective), "hus" (noun) — screenshots the user provided.
  This replaces the generic label/forms list (kept only as a fallback for parts of speech
  without a dedicated layout — pronouns, determiners, adverbs, etc.):
  - **Noun**: Singular/Plural × Indefinite/Definite 4-cell grid, with the correct indefinite
    article ("et"/"ei"/"en") prefixed onto the singular-indefinite form based on gender.
  - **Adjective**: a Singular(masc/fem, neuter, definite)/Plural grid, plus a separate
    "Comparison" card (comparative, superlative indefinite/definite) shown only when the
    adjective actually inflects for degree.
  - **Verb**: infinitive/present/past/perfect/imperative rows, then a "Past participle"
    sub-section broken out by gender/number/definiteness (a Norwegian past participle inflects
    like an adjective) and a "Present participle" row — matching ordbøkene's own section
    structure exactly (verified against the real `dusje` paradigm JSON).
  - **Root-cause fix enabling all of this**: `Paradigm.mergedStandardRows(from:)` merges forms
    across *every* standard (`std = "S"`) paradigm of a word, not just the first. A word can
    have several standard paradigms differing only in an accepted spelling variant — "hus" has
    two paradigms whose sole difference is `Plur Def`: "husa" vs "husene" — and ordbøkene merges
    these into one cell ("husa, husene"); the old code's `paradigms.first { isStandard }` picked
    only one paradigm and silently dropped the other spelling. Added 2 regression tests for this.
  - 19 unit tests pass (17 + 2 new); all three POS layouts verified pixel-by-pixel against the
    user's ordbøkene.no reference screenshots in the simulator.

### 2026-10-10 (later still) — Verb table correctness + styling, per closer ordbøkene comparison
The user compared the live app against ordbøkene.no more closely (a cleaner reference
screenshot of "dusje" showing grey italic function-word markers and usage hints) and found:
- **Variant form ordering was wrong**: "Past participle" → Definite/Plural showed
  "dusja, dusjete, dusjede" but ordbøkene shows "dusja, dusjede, dusjete". Root cause: merged
  forms were kept in raw JSON-array-arrival order, which isn't alphabetical. **Fix**:
  `Paradigm.mergedStandardRows(from:)` now sorts each tag's forms alphabetically after merging —
  verified this also matches every other previously-checked example ("dusja, dusjet";
  "dusj, dusja, dusje"; "husa, husene"), so it's a general rule, not a one-off. Added a
  regression test (`mergedFormsAreSortedAlphabeticallyNotByJSONOrder`).
- **Function-word markers weren't visually distinguished**: "å dusje", "har dusja" rendered as
  one uniform-styled string. `LabeledRow` (the verb table's row renderer) now takes optional
  `prefix`/`suffix` strings rendered in grey italics via `Text` concatenation, separate from the
  (highlightable) form text — matching ordbøkene's own grey-italic treatment of "å"/"har"/
  "den/det".
- **Imperative forms were missing their "!"**: added `suffix: "!"` to the imperative row.
- **Added "+ noun" usage hints to the past-participle-as-adjective rows** (Masculine/feminine,
  Neuter, Plural get a grey-italic " + noun"/" + 名词" suffix; Definite additionally gets a
  grey-italic "den/det " prefix) — this is new content beyond what was there before, following
  a third reference screenshot the user provided showing ordbøkene annotates these forms with
  how they're used (participle + a following noun, since Norwegian past participles decline
  like adjectives when used attributively).
- 20 unit tests pass (19 + 1 new); re-verified in the simulator against the exact row-by-row
  expectations from the user's screenshots.

### 2026-10-10 (even later) — Noun table row-splitting, dict-aware articles, empty grey cell
Another close comparison against ordbøkene.no (searching "drittsekk" and "pen") surfaced two
more issues:
- **Noun cells got cramped/confusing for words with multiple full spelling variants.**
  "drittsekk, dritsekk" has two standard paradigms with *different* `lemma`s ("drittsekk" and
  "dritsekk"), each a complete independent declension — unlike "hus", where both paradigms
  share the same lemma and differ in only one tag. The old flat merge treated both cases the
  same way, producing "en dritsekk, en drittsekk" / "dritsekker, drittsekker" / ... crammed
  into quarter-width cells with nowhere good to wrap. **Fix**: `Paradigm.standardGroups(from:)`
  groups standard paradigms by `lemma` first, merging only within each group; the noun table
  now renders one shared header + one data row *per lemma group* — "hus" still gets one row
  (same lemma, "husa, husene" merged), but "drittsekk, dritsekk" now gets two clean rows, one
  per spelling. Added 2 regression tests (divergent-lemma split, same-lemma merge preserved).
- **The indefinite article hint ("en"/"et"/"ei") was Bokmål-only and unstyled.** Nynorsk uses
  different forms for masculine/neuter ("ein"/"eit" vs Bokmål's "en"/"et"; feminine "ei" is
  shared) — `NounInflectionTable` now takes `dict` and picks the right set. The article prefix
  (and the verb table's "å"/"har"/"den/det" markers, already fixed) now share one helper,
  `joinedFormsText`, so every marker renders in grey italics distinct from the (highlightable)
  word — previously the noun article was just plain-concatenated text.
- **Adjective table had a visible empty grey box.** The sub-header row's 4th cell (a blank
  continuation under "Plural", which only spans 1 column so doesn't need its own sub-header)
  still got the grey `fill` background from `GroupHeaderCell` despite having no text — reading
  as a stray empty rectangle. Fixed: `GroupHeaderCell` skips the fill when its title is empty.
- 22 unit tests pass (20 + 2 new); all three fixes (plus a bonus Nynorsk "eit hus" check)
  verified in the simulator.

### 2026-10-10 (yet later) — Entry section order, Chinese grammar terminology
- **Reordered `EntryColumn`'s sections**: Inflection now comes first (right after the
  headword/POS header), then the numbered senses/meaning, then Fixed expressions, then the
  source line — previously it was meaning → fixed expressions → inflection.
- **Chinese grammar terms for noun/adjective (and the verb table's past-participle "Definite"
  row, which shares the same string)**: "不定形" → "不定态" and "定形" → "限定态" for
  indefinite/definite form labels. Changed both `Strings.indefinite`/`.definite` (used by the
  noun table's Indefinite/Definite headers and the verb table's past-participle Definite row)
  and the adjective table's separate `TableLabel` "definiteForm" entry, so the terminology is
  consistent everywhere it appears, not just the two places explicitly mentioned.
- Build clean, 22 unit tests pass (unaffected by these changes — no test covers UI copy/order
  directly). Visual re-verification in the simulator was skipped this round due to hitting the
  session's rate limit mid-check; both changes are simple, low-risk (a block move + 3 literal
  string replacements) and compiled/tested cleanly, but should get a quick visual glance next
  time the app is run.

### 2026-10-10 (final round) — Grid background-span bug; more ZH terminology
Two more fixes, both from screenshots: the adjective table's "Comparison" header and the main
table's "Singular"/"Plural" header had a visible white gap in the grey band (should be solid).
- **Root cause**: SwiftUI's `Grid` doesn't correctly paint a `.gridCellColumns(n)`-spanning
  cell's background over its leading column — confirmed by removing the span entirely.
  **Fix**: every header cell that used to span multiple columns (`Singular`/`Plural` in both
  the noun and adjective tables, and `Comparison` in the gradbøying table) is now N individual
  non-spanning `GroupHeaderCell`s instead, with the label text only in the first and blank
  (still grey-filled) continuation cells after it. `GroupHeaderCell` gained a `showBackground`
  flag so the *other* kind of blank cell — one with no group membership at all, like the
  adjective table's trailing cell under "Plural", which should stay blank/white — can still
  opt out explicitly. This trades perfectly-centered span labels for guaranteed-correct grey
  bands; given the choice is between a cosmetic nicety and an actual rendering bug, correctness
  won.
- **More Chinese terminology**: adjective table's "Superlative indefinite"/"Superlative
  definite" column headers changed from two-line "最高级\n不定形"/"最高级\n定形" to single-line
  "最高级不定态"/"最高级限定态", per the same 态-not-形 convention adopted earlier.
- **Process note**: the first verification pass of this fix reported the Comparison table's
  grey gap and old Chinese text as still broken. Grepping the source confirmed the fix *was*
  there — the subagent had tested a stale installed build. A forced fresh reinstall
  (`DeviceInteractionInstallAndRun`) and re-verification confirmed everything was actually
  correct. Recorded in memory: when a verification result looks surprising, check the source
  for the literal reported strings before concluding a fix failed.
- 22 unit tests pass (no regressions); both fixes verified against a confirmed-fresh build.

### 2026-10-10 (and later still) — GitHub repo, report-error destination
- **Pushed to GitHub**: created a private repo `august-in-august/norskDict_Xcode` via `gh repo
  create`, added as `origin`, pushed `main`.
- **"Report error" now opens a GitHub issue instead of a mailto draft.** Tapping it opens
  `https://github.com/august-in-august/norskDict_Xcode/issues/1` directly (the user's chosen
  tracking issue for translation error reports). GitHub's URL-based pre-fill
  (`?title=&body=`) only works for the *new issue* composer, not for adding a comment to an
  existing issue, so the dict/id/headword context the old mailto subject/body carried can't be
  auto-filled here — confirmed with the user this tradeoff is acceptable (no pre-fill; the
  toast now asks the user to name the word/error manually when commenting).
- **Diagnosed (not yet fixed) a scroll-performance issue on the Search results page**: the
  Bokmål/Nynorsk swipeable results nest a `List` inside a `TabView(.page)` style — a known
  SwiftUI combination that's slow because the page-style TabView keeps both pages' `List`s
  (each independently a scroll view) alive and laid out simultaneously, and the horizontal
  (page-swipe) and vertical (list-scroll) gesture recognizers have to disambiguate on every
  touch. This matches the user's exact complaint (lag specifically scrolling the results page,
  not the home/typing screens, which use a single plain `List` with no nested `TabView`).
  **Not fixed yet** — offered to replace the nested-scroll-view structure with a single scroll
  surface + manual swipe handling; awaiting the user's go-ahead.
- 22 unit tests pass; the report-error change verified in the simulator (confirmed it opens the
  exact issue URL, confirmed via a forced-fresh-install re-check after the stale-build lesson
  from the previous session).

### 2026-10-10 (final) — Scroll-lag fix, BM/NN tab legibility
- **Fixed the search-results scroll lag**: replaced the `TabView(.page)` wrapping two `List`s
  with a single `List` (keyed by `model.dictTab`'s `.id()` so scroll position resets per
  dictionary) plus a manual swipe `DragGesture`, the same pattern already used successfully on
  the entry screen's BM/NN swipe. Confirmed scrolling, swiping, and direct pill taps all still
  work correctly on a fresh install.
- **Fixed low-contrast Bokmål/Nynorsk tab selection**: `SegmentedPill` (shared by the entry
  screen, search results, and Settings' Light/Dark/System and Left/Right-handed controls)
  previously signaled selection only via a card-background swap — in the "White" theme's dark
  variant (`bg`/`grp` both pure black, `card` only #1C1C1E) that's a ~2-3% brightness
  difference, nearly invisible. Added a `selectedTint` closure parameter (defaults to `nil`,
  falling back to the existing `theme.ink`/`theme.ink2` behavior for Settings' other uses) and
  wired the two BM/NN call sites (`EntryView`, `SearchView`) to tint the selected segment's
  text with `theme.bm`/`theme.nn`. Also dimmed unselected segments to `theme.ink2` generally
  (benefits every `SegmentedPill` use, not just BM/NN). Verified: selected text now reads
  reddish-orange for Bokmål / blue for Nynorsk in both Light and Dark, clearly distinct from
  the dimmed unselected segment.
- **Re-investigated the reported "white background gap" in the inflection table** (a screenshot
  the user attached alongside this round's feedback, showing "pen"'s Comparison table in the
  White theme's dark variant). Could not reproduce it on a fresh install, in either Light or
  Dark — pixel-sampled the header bands directly and found no anomaly. This is almost certainly
  the same bug already fixed in the previous commit (`dbc0623`, the `Grid` column-span
  background fix); the screenshot was likely taken before that fix reached the user's device.
  No further code change made for this one.
- 22 unit tests pass; all three items verified together on a confirmed-fresh install.
