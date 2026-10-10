# App Store Connect listing content

Copy-paste source for App Store Connect metadata. Two localizations: English (U.S.) and
Chinese (Simplified). In-app UI only supports English/中文 ([[UILanguage]]), so these are the
only two App Store Connect localizations planned for now — see the ASO note at the bottom
before adding more.

Note: the home-screen app name (`CFBundleDisplayName`) is "Norsk Dictionary" — separate
from the App Store listing name below, which is allowed to be longer/more keyword-rich.

---

## English (U.S.)

**Name** (30 char max)
```
Norsk Dict - Bokmål & Nynorsk
```

**Subtitle** (30 char max)
```
Offline · Inflections · EN/中文
```

**Promotional text** (170 char max, editable anytime without review)
```
Bokmål & Nynorsk in one app, with full inflection tables, EN/中文 translations, native pronunciation, and complete offline access — no internet needed.
```

**Description**
```
Norsk Dict is a complete Norwegian dictionary covering both official written standards — Bokmål and Nynorsk — in one app, with English and Chinese (中文) translations for every definition and example.

FEATURES
• Full coverage of Bokmålsordboka and Nynorskordboka, the official dictionaries edited by Språkrådet (the Language Council of Norway) and the University of Bergen
• Type any word form — including inflected forms like gikk, kapitalene, or peneste — and the app finds the base word automatically, powered by Norsk ordbank's inflection data
• Side-by-side Bokmål and Nynorsk results so you can compare both standards at a glance
• Full inflection tables for nouns, adjectives, and verbs
• English and Chinese translations for definitions and examples, with one-tap "Report error" if a machine translation looks off
• Native pronunciation using on-device speech synthesis
• Bookmarks and search history
• Adjustable text size, light/dark themes, and left- or right-handed navigation layouts
• Fully offline — the entire dictionary lives on your device, no internet connection required

WHO IT'S FOR
Whether you're a newcomer preparing for norskprøven, a student of Bokmål or Nynorsk, or an English or Chinese speaker who wants fast, reliable definitions with inflections included, Norsk Dict gives you everything in one lookup.

Translations marked "machine-translated" are generated automatically and may contain errors — the original Norwegian definitions and examples come directly from Bokmålsordboka, Nynorskordboka, and Norsk ordbank (Språkrådet & University of Bergen; Norsk ordbank under CC BY 4.0).
```

**Keywords** (100 char max)
```
ordbok,norwegian,grammar,verb,słownik,словник,قاموس,từ điển,noun,declension,norge
```

---

## Chinese (Simplified)

**Name**
```
Norsk dict - 挪威语双语词典
```

**Subtitle**
```
离线词典·书面语与新挪威语·变格变位·发音
```

**Promotional text**
```
书面语与新挪威语合一,内置变格变位表、中英双语翻译与真人发音,完全离线使用,无需联网。
```

**Description**
```
Norsk Dict 是一款完整的挪威语词典应用,同时收录两种官方书面语——书面语(Bokmål)与新挪威语(Nynorsk)——并为每条释义和例句提供英文和中文翻译。

主要功能
• 完整收录《书面语词典》(Bokmålsordboka)与《新挪威语词典》(Nynorskordboka),由挪威语言委员会(Språkrådet)与卑尔根大学编纂
• 输入任意词形(例如 gikk、kapitalene、peneste 等变位变格形式),应用会基于 Norsk ordbank 的词形变化数据自动找到词典原形
• 书面语与新挪威语结果并排显示,方便对比两种书面语标准
• 提供名词、形容词、动词的完整变格变位表
• 释义和例句均配有英文与中文翻译,如发现机器翻译有误,可一键"报告错误"
• 内置语音合成朗读发音
• 支持收藏与查询历史
• 可调节字号、浅色/深色主题,支持左手或右手单手导航布局
• 完全离线使用——整部词典已内置于设备中,无需联网

适合人群
无论你是正在准备挪威语测试(norskprøven)的新移民、学习书面语或新挪威语的学生,还是希望获得包含变格变位信息、快速可靠释义的中文或英文母语使用者,Norsk Dict 都能一站式满足你的查词需求。

标注为"机器翻译"的内容为自动生成,可能存在误差;挪威语原文释义与例句均直接来自《书面语词典》《新挪威语词典》和 Norsk ordbank(挪威语言委员会与卑尔根大学编纂,Norsk ordbank 采用 CC BY 4.0 协议)。
```

**Keywords**
```
挪威语,词典,书面语,新挪威语,学挪威语,变格,变位,语法,留学挪威,发音,北欧语言,norsk,ordbok
```

---

## ASO note: multi-language keywords

Apple's keyword field is per-localization and capped at 100 characters — too small to hold
meaningful terms for 6+ languages. Two things to know:

1. A storefront with no dedicated localization falls back to the app's **primary language**
   metadata. So someone browsing the Polish or Ukrainian App Store sees the **English**
   listing by default — which is why the English keyword field above includes a few non-Latin
   "dictionary" terms (Polish, Ukrainian, Arabic, Vietnamese) as a stopgap.
2. The real fix is adding dedicated App Store Connect localizations (metadata only, not an
   in-app language) for high-value markets, each with its own full 100-char keyword field.

Rough list of who's likely actually searching for a Norwegian dictionary (based on Norway's
largest immigrant/refugee-origin populations — adult immigrants need Norwegian for
residency/citizenship, unlike casual hobbyist learners) — not a verified ranking, just a
starting hypothesis: **Poland, Lithuania, Syria, Somalia, Iraq, Eritrea, Afghanistan,
Philippines, Ukraine** (fastest-growing since 2022), **Thailand/Vietnam**.

Recommended next step: ship with just EN + ZH (matches actual in-app UI languages), then
after a few weeks check App Store Connect's search-term report to see which non-English
queries are already finding the app via the English fallback. That tells you empirically
which 1-2 extra localizations (likely Polish, Arabic, or Ukrainian) are worth building,
instead of guessing upfront.
