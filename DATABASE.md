# norskdict.sqlite — database reference for app developers

Offline dictionary database for the iOS/iPadOS app: Bokmål (`bm`) and Nynorsk (`nn`) articles from
Bokmålsordboka / Nynorskordboka, with English and Simplified Chinese translations and full inflection tables.

- File: `build/norskdict.sqlite` (≈214 MB; ≈78 MB compressed in the App Store download). Not in git — rebuild it with
  `python3 scripts/build_db.py` (≈20 s, needs `chunks/`, `out/all/`, `raw/`).
- Schema version: `meta.schema = '1'`. Built: `meta.built`.
- **Read-only.** Ship it in the app bundle and open it with `readonly = true` (no copy to Documents needed).
  User data (bookmarks, history, settings, toggle states) belongs in a separate writable store, keyed by
  `(dict, id)` — **not** by `rowid`, which can change between builds.
- Plain SQLite + FTS5 (both available in the iOS system SQLite). Recommended access layer: GRDB.swift 7.x.

Counts (build 2026-10-09): 186,912 articles (bm 90,865 / nn 96,047), 265,871 senses, 198,741 examples,
21,135 fixed expressions, 843,725 searchable forms.

---

## Data model at a glance

```
article (one dictionary entry, one per dict)
 ├── sense      idiom = 0          the entry's own numbered senses
 │    └── example                   examples under a sense
 ├── idiom      ord = 1, 2, …       fixed expressions ("faste uttrykk")
 │    └── sense idiom = idiom.ord   senses of that expression
 │         └── example
 ├── paradigm (JSON column)         inflection tables
 └── form (many)                    every string that should find this article in search
```

`article.rowid` is the key all child tables point to (column name `article`).

---

## Tables

### `article`
| column | type | meaning |
|---|---|---|
| `rowid` | INTEGER | internal key used by every other table |
| `dict` | TEXT | `'bm'` or `'nn'` |
| `id` | INTEGER | UiB article id. `(dict, id)` is unique and **stable across builds** — use it for bookmarks/history and for links to `https://ordbokene.no/{dict}/{id}` |
| `headword` | TEXT | lemma as displayed, e.g. `skrive`, `stå på`. Multiple spellings may be joined, e.g. `gård, gard` |
| `hgno` | INTEGER | homograph number. `0` = no homographs; `1, 2, 3 …` distinguish entries with the same headword (`bank` has bm 1–4). Show as a superscript or roman numeral |
| `pos` | TEXT | part of speech + gender, see *Part-of-speech values* below. May be `''` (185 rows) |
| `rank` | INTEGER | frequency order, lower = more common (1 = most common). **Sort search results by this** |
| `gloss_en`, `gloss_zh` | TEXT | short headword translation for result lists, e.g. `write` / `写` |
| `variants` | TEXT | other accepted spellings, `|`-separated, `''` if none (21,559 rows have some) |
| `paradigm` | TEXT | JSON inflection tables, see below. `'[]'` if the word has none (11 rows) |

### `sense`
| column | meaning |
|---|---|
| `article` | → `article.rowid` |
| `idiom` | `0` = the article's own sense; `n > 0` = sense of fixed expression `idiom.ord = n` |
| `ord` | 1-based display order within (article, idiom) |
| `n` | sense number as printed by the dictionary (`'1'`, `'2'`, sometimes `'1a'` style). Display this, sort by `ord` |
| `def` | Norwegian definition. `''` for 62 senses that only have examples — then `en`/`zh` repeat the gloss; show only the examples |
| `en`, `zh` | translation of the definition |

### `example`
| column | meaning |
|---|---|
| `article`, `idiom` | as in `sense` |
| `sense` | → `sense.ord` of the parent sense (same `article` and `idiom`) |
| `ord` | 1-based order |
| `text` | Norwegian example (headword written out in full) |
| `en`, `zh` | translation |

### `idiom`
| column | meaning |
|---|---|
| `article` | → `article.rowid` (the entry the expression is listed under) |
| `ord` | 1-based order; matches `sense.idiom` / `example.idiom` |
| `expr` | the expression, e.g. `stå skrive`, `skrive til` |

Some expressions also exist as their own article (`pos = 'EXPR'`, e.g. `stå på`). Both are findable via `form`.

### `form` — the search index
| column | meaning |
|---|---|
| `fold` | normalised search key (indexed): lowercase, accents removed (`é→e`, `ô→o`), **`æ ø å` kept** |
| `form` | the original string |
| `article` | → `article.rowid` |
| `kind` | `'lemma'` (the headword), `'variant'` (alternative spelling), `'infl'` (inflected form, e.g. `skreiv`, `huset`), `'idiom'` (fixed expression listed in that article) |

The same `fold` can point to many articles (`huset` → bm *hus*, bm *huse*, nn *hus*). One article has many rows.

### `en_fts` + `en_fts_map` — English reverse search
`en_fts` is a contentless FTS5 table (`tokenize='porter unicode61'`, so `houses` matches `house`) over every
English gloss and sense translation. Its `rowid` is mapped to the article by `en_fts_map(id, article)`.

### Chinese reverse search
There is no Chinese tokenizer; use `LIKE '%…%'` on `article.gloss_zh` (fast) and `sense.zh` (≈60 ms on a Mac).

### `meta`
`key`/`value` pairs: `built`, `schema`, `stats` (JSON counts), `source` (attribution text).

---

## `article.paradigm` JSON

An array — one object per inflection paradigm. A word can have several (alternative inflections, or several lemmas):

```json
[{"lemma": "skrive", "tags": ["VERB"], "std": "S",
  "forms": [["Inf","skrive"], ["Inf","skriva"], ["Pres","skriv"], ["Past","skreiv"],
            ["<PerfPart>","skrive"], ["Adj <PerfPart> Masc/Fem Ind Sing","skriven"], ["Imp","skriv"], …]}]
```

- `std`: `"S"` = standard (normert) form, `"R"` = registered but non-standard. Show `R` paradigms greyed or hide them.
- `forms`: `[tags, word_form]` in dictionary order. **The same tag can appear more than once** — these are
  alternative accepted forms (`Inf: skrive / skriva`); show them together, separated by `/`.
- `tags`: space-separated codes from Norsk ordbank. Map to labels in the app:

| tag(s) | meaning (EN) | 中文 | Norwegian label |
|---|---|---|---|
| `Sing Ind` / `Sing Def` | singular indefinite / definite | 单数不定 / 单数定 | entall ubestemt / bestemt |
| `Plur Ind` / `Plur Def` | plural indefinite / definite | 复数不定 / 复数定 | flertall ubestemt / bestemt |
| `Inf` | infinitive | 不定式 | infinitiv |
| `Pres` | present | 现在时 | presens |
| `Past` | past | 过去时 | preteritum |
| `<PerfPart>` | past participle | 过去分词 | perfektum partisipp |
| `Imp` | imperative | 命令式 | imperativ |
| `Pass` (with `Inf`/`Pres`) | s-passive | 被动式 | s-passiv |
| `<SPass>` | s-form (e.g. deponent verbs) | s-形式 | s-form |
| `Adj <PerfPart> …` | participle used as adjective (+ gender/number) | 分词作形容词 | partisipp som adjektiv |
| `Adj <PresPart>` | present participle | 现在分词 | presens partisipp |
| `Pos` … | adjective positive (+ `Masc/Fem`/`Neuter` `Ind Sing`, `Def Sing`, `Plur`) | 原级 | positiv |
| `Cmp` | comparative | 比较级 | komparativ |
| `Sup Ind` / `Sup Def` | superlative indefinite / definite | 最高级 不定 / 定 | superlativ ubestemt / bestemt |
| `Masc`, `Fem`, `Neuter` | gender | 阳性 / 阴性 / 中性 | hankjønn / hunkjønn / intetkjønn |
| `Nom`, `Acc` | (pronouns) nominative / accusative | 主格 / 宾格 | nominativ / akkusativ |
| `''` (empty) | unlabeled form — show without a label | | |

## Part-of-speech values (`article.pos`)

`NOUN Masc|Fem|Neuter` (gender; `NOUN Masc / NOUN Fem` = either gender allowed; `Uninfl` = not inflected),
`VERB`, `ADJ`, `ADV`, `ADP` (preposition), `EXPR` (expression), `ABBR`, `INTJ`, `PRON`, `DET …`, `SCONJ`, `CCONJ`,
`PFX` (prefix), `COMPPFX` (compound prefix), `SYM`, `NUM`. Map to display labels in the app (e.g. `NOUN Masc` →
"substantiv, hankjønn" / "noun, masculine" / "名词（阳性）").

---

## Queries

### 1. Search box (exact + prefix, Norwegian)
Fold the user's input the same way the build did (Swift version below), then:

```sql
SELECT a.rowid, a.dict, a.id, a.headword, a.hgno, a.pos, a.gloss_en, a.gloss_zh,
       MIN(CASE WHEN f.fold = :q
                THEN CASE f.kind WHEN 'lemma' THEN 0 WHEN 'variant' THEN 1 WHEN 'idiom' THEN 2 ELSE 3 END
                ELSE 4 + (f.kind <> 'lemma') END) AS match_kind
FROM form f JOIN article a ON a.rowid = f.article
WHERE f.fold >= :q AND f.fold < :q || x'EFBFBF'        -- prefix range: uses the index (LIKE would not)
GROUP BY a.rowid
ORDER BY match_kind, a.rank
LIMIT 50;
```

`match_kind`: 0 exact headword, 1 exact variant spelling, 2 exact fixed expression, 3 exact inflected form,
4 headword starting with the query, 5 other form starting with the query. Tested: `hus` → hus (bm, nn), then huse
(because *hus* is also its imperative), then husleie, huske…; `skreiv` → skrive (bm, nn); about 1–3 ms.

Split results into two lists by `dict` for the Bokmål / Nynorsk tabs. When `match_kind = 3`, show a hint such as
"*skreiv* → past tense of **skrive**": look up the matching row in `form` and its tag in `paradigm`.

Swift fold function (must match `fold()` in `scripts/build_db.py`):

```swift
func fold(_ s: String) -> String {
    let keep: Set<Character> = ["æ", "ø", "å"]
    return String(s.trimmingCharacters(in: .whitespaces).lowercased().precomposedStringWithCanonicalMapping
        .map { keep.contains($0) ? String($0)
               : String($0).folding(options: .diacriticInsensitive, locale: nil) }
        .joined())
}
```

### 2. Entry screen (one article)
```sql
SELECT * FROM article WHERE rowid = :id;
SELECT idiom, ord, n, def, en, zh FROM sense   WHERE article = :id ORDER BY idiom, ord;
SELECT idiom, sense, ord, text, en, zh FROM example WHERE article = :id ORDER BY idiom, sense, ord;
SELECT ord, expr FROM idiom WHERE article = :id ORDER BY ord;
```
Group in code: senses with `idiom = 0` are the main list; for each `idiom` row, its senses are those with
`sense.idiom = idiom.ord`; examples attach by `(idiom, sense)`.

Same headword in the other dictionary (for swiping between BM and NN):
```sql
SELECT rowid FROM article WHERE dict = :otherDict AND headword = :headword ORDER BY hgno;
```

### 3. English reverse search
```sql
SELECT a.rowid, a.dict, a.headword, a.gloss_en, a.gloss_zh
FROM en_fts JOIN en_fts_map m ON m.id = en_fts.rowid JOIN article a ON a.rowid = m.article
WHERE en_fts MATCH :fts                       -- :fts = each word of the input wrapped in double quotes: "write" "off"
GROUP BY a.rowid
ORDER BY (lower(a.gloss_en) = lower(:w) OR lower(a.gloss_en) LIKE lower(:w) || '%') DESC,   -- :w = raw input
         a.rank
LIMIT 50;
```
Quoting the words avoids FTS5 syntax errors on `-`, `:`, `*` etc. Tested: `house` → hus, huse, …;
`write` → skrive, avskrive, …

### 4. Chinese reverse search
```sql
SELECT a.rowid, a.dict, a.headword, a.gloss_en, a.gloss_zh
FROM article a WHERE a.gloss_zh LIKE '%' || :q || '%'
ORDER BY (a.gloss_zh = :q) DESC, a.rank LIMIT 50;
-- fallback when that is empty: same with JOIN sense s ON s.article = a.rowid WHERE s.zh LIKE …, GROUP BY a.rowid
```

### GRDB example
```swift
import GRDB

let dbQueue: DatabaseQueue = {
    var config = Configuration(); config.readonly = true
    let path = Bundle.main.path(forResource: "norskdict", ofType: "sqlite")!
    return try! DatabaseQueue(path: path, configuration: config)
}()

struct ArticleRow: FetchableRecord, Decodable, Identifiable {
    var rowid: Int64          // internal key for child-table queries
    var dict: String          // "bm" / "nn"
    var uibId: Int64          // stable id for bookmarks:  SELECT id AS uibId …
    var headword: String
    var hgno: Int
    var pos: String
    var gloss_en: String
    var gloss_zh: String
    var id: Int64 { rowid }
}

let hits = try dbQueue.read { db in
    try ArticleRow.fetchAll(db, sql: """
        SELECT a.rowid, a.dict, a.id AS uibId, a.headword, a.hgno, a.pos, a.gloss_en, a.gloss_zh
        FROM form f JOIN article a ON a.rowid = f.article
        WHERE f.fold = ? GROUP BY a.rowid ORDER BY a.rank LIMIT 50
        """, arguments: [fold("gikk")])
}
```
(Prefer explicit column lists over `SELECT *` so the `paradigm` JSON is only loaded on the entry screen.)

---

## Gotchas
- `rowid` is not stable between builds → store `(dict, id)` in user data.
- Translations are machine-generated (LLM). Show the Norwegian original by default (per the app design) and
  label EN/中文 as translations.
- `sense.n` is a display label, not always numeric; never parse it as an integer.
- Definitions and translations may contain cross-references like `Se: forhøre` / `参见：forhøre`; these refer to
  other headwords and can be turned into links by looking up the word in `form`.
- "Similar headwords" (ordbøkene's *Lignende oppslagsord*) are not in the data; compute them in the app if wanted
  (e.g. same prefix, or small edit distance on `form.fold` where `kind = 'lemma'`).
- Attribution required by the licence (show in Settings → About): content from Bokmålsordboka and
  Nynorskordboka, © Språkrådet and the University of Bergen, open licence (https://ordbokene.no/eng/about/open-data);
  inflection data from Norsk ordbank (CC BY 4.0). English/Chinese translations added by the app author; UiB and
  Språkrådet are not responsible for them.
