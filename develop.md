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
- **Stack**: Swift 6, SwiftUI, deployment target iOS/iPadOS 18.0. GRDB.swift (already added as
  a Swift package dependency) for read-only access to `norskdict.sqlite`. User data (bookmarks,
  history, view-state) in SwiftData/`@AppStorage` — kept separate from the bundled dictionary DB.
- **Navigation**: TabView (Search/Bookmarks/History/Settings) on iPhone; NavigationSplitView
  sidebar with the same four sections on iPad.
- **Not in git**: `norskdict.sqlite` (214 MB build artifact, rebuilt via the companion
  `norskDict` pipeline repo's `build_db.py`). Xcode still bundles the local copy as an app
  resource; see `.gitignore`.

## Repo layout
```
norskDict/                    Xcode project root (this repo)
├── norskDict/                 app target sources (SwiftUI views, App entry point)
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

## Open decisions (from the product plan, unresolved)
- Final app name (working name "Slå opp")
- Pricing model (free / paid up front / one-time unlock — no subscription needed, no running costs)
- Whether v1 ships English/Chinese reverse search or it moves to 1.1
- Data update cadence (every release vs. quarterly)
- Norwegian as a third UI language

## Progress log
### 2026-10-09
- Initial Xcode project created (`norskDict.xcodeproj`, default SwiftUI template:
  `ContentView.swift`, `Item.swift`, `norskDictApp.swift`).
- GRDB added as a Swift package dependency (`Package.resolved` present).
- Set up git repo hygiene: added `.gitignore` (Xcode user state, `.DS_Store`,
  `norskdict.sqlite`), unstaged the sqlite file, brought in `DATABASE.md`, the development
  plan, and the design handoff bundle as versioned reference docs.
- Wrote this `develop.md` as the project's running development log.
- **Next**: Phase 2 of the plan — app skeleton and search (GRDB read-only connection to the
  bundled DB, search screen with form lookup / prefix / fuzzy / reverse search, input folding).
