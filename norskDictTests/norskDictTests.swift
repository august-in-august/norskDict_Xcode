//
//  norskDictTests.swift
//  norskDictTests
//
//  Created by August Yang on 10/9/26.
//

import Testing
@testable import norskDict

struct FoldTests {
    @Test func stripsDiacriticsButKeepsNorwegianLetters() {
        #expect(fold("Blåbær") == "blåbær")
        #expect(fold("Håndverk") == "håndverk")
        #expect(fold("  Gård  ") == "gård")
    }

    @Test func digraphVariantsSubstituteNorwegianLetters() {
        let variants = foldedQueryVariants("blaabaer")
        #expect(variants.contains("blåbær"))
    }

    @Test func plainQueryHasNoSpuriousVariants() {
        #expect(foldedQueryVariants("venn") == ["venn"])
    }
}

@Suite(.serialized)
struct DictionaryDatabaseTests {
    @Test func formLookupFindsLemmaFromInflectedForm() async throws {
        let hits = try await DictionaryDatabase.shared.search("gikk")
        let hit = try #require(hits.first { $0.article.headword == "gå" && $0.article.dict == .bm })
        #expect(hit.matchKind == .exactInflection)
        let hint = try #require(hit.hint)
        #expect(hint.matchedForm == "gikk")
        #expect(Labels.hintPhrase(hint.tags, ui: .en) == "past tense")
    }

    @Test func formLookupFindsLemmaFromPluralDefiniteForm() async throws {
        let hits = try await DictionaryDatabase.shared.search("bøkene")
        #expect(hits.contains { $0.article.headword == "bok" })
    }

    @Test func formLookupFindsNynorskOnlyHeadword() async throws {
        let hits = try await DictionaryDatabase.shared.search("augo")
        // The headword field joins accepted spellings ("auge, auga"), so match by prefix.
        #expect(hits.contains { $0.article.headword.hasPrefix("auge") && $0.article.dict == .nn })
        #expect(!hits.contains { $0.article.dict == .bm })
    }

    @Test func letterTolerantInputFindsAaVariant() async throws {
        // "blaabaer" should fold to "blåbær" and find real headwords with that prefix.
        let hits = try await DictionaryDatabase.shared.search("blaabaer")
        #expect(hits.contains { $0.article.headword.hasPrefix("blåbær") })
    }

    @Test func englishReverseSearchFindsVenn() async throws {
        let hits = try await DictionaryDatabase.shared.reverseEnglish("friend")
        #expect(hits.contains { $0.headword.contains("venn") })
    }

    @Test func chineseReverseSearchFindsVenn() async throws {
        let hits = try await DictionaryDatabase.shared.reverseChinese("朋友")
        #expect(hits.contains { $0.headword.contains("venn") })
    }

    @Test func entryLoadsSensesAndSubsenses() async throws {
        let hits = try await DictionaryDatabase.shared.search("venn")
        let summary = try #require(hits.first { $0.article.headword == "venn" && $0.article.dict == .bm })
        let entry = try #require(await DictionaryDatabase.shared.entry(rowid: summary.article.rowid))
        #expect(entry.senses.count > 1)
        let firstSense = try #require(entry.senses.first)
        #expect(!firstSense.subsenses.isEmpty)
        #expect(!entry.idioms.isEmpty)
    }

    @Test func crossReferenceDefinitionResolvesToOtherHeadword() async throws {
        let hits = try await DictionaryDatabase.shared.search("sette inn")
        let summary = try #require(hits.first { $0.article.dict == .bm })
        let entry = try #require(await DictionaryDatabase.shared.entry(rowid: summary.article.rowid))
        let sense = try #require(entry.senses.first)
        #expect(sense.crossReference != nil)
    }
}

struct SimilarHeadwordsTests {
    @Test func findsEditDistanceMatchForMisspelling() async throws {
        let rowids = await SimilarHeadwords.shared.find(fold("lesse"), excluding: [])
        let articles = try await DictionaryDatabase.shared.articles(rowids: rowids)
        #expect(articles.contains { $0.headword == "lese" })
    }

    @Test func shortQueriesReturnNoMatches() async throws {
        let rowids = await SimilarHeadwords.shared.find("ab", excluding: [])
        #expect(rowids.isEmpty)
    }
}

struct ParadigmTests {
    @Test func mergesRepeatedTagsIntoOneRowWithMultipleForms() {
        let json = """
        [{"lemma":"skrive","tags":["VERB"],"std":"S",
          "forms":[["Inf","skrive"],["Inf","skriva"],["Pres","skriv"],["Past","skreiv"]]}]
        """
        let paradigms = Paradigm.decodeArray(json)
        let paradigm = try! #require(paradigms.first)
        let infRow = try! #require(paradigm.rows.first { $0.tags == ["Inf"] })
        #expect(infRow.forms == ["skrive", "skriva"])
        #expect(paradigm.isStandard)
    }

    @Test func nonStandardParadigmIsFlagged() {
        let json = """
        [{"lemma":"x","tags":["VERB"],"std":"R","forms":[["Inf","x"]]}]
        """
        let paradigm = try! #require(Paradigm.decodeArray(json).first)
        #expect(!paradigm.isStandard)
    }

    @Test func mergesFormsAcrossMultipleStandardParadigms() {
        // "hus" has two standard paradigms whose only difference is Plur Def: "husa" vs
        // "husene". ordbøkene.no displays both merged into one cell, not as separate tables.
        let json = """
        [{"lemma":"hus","tags":["NOUN","Neuter"],"std":"S",
          "forms":[["Sing Ind","hus"],["Sing Def","huset"],["Plur Ind","hus"],["Plur Def","husa"]]},
         {"lemma":"hus","tags":["NOUN","Neuter"],"std":"S",
          "forms":[["Sing Ind","hus"],["Sing Def","huset"],["Plur Ind","hus"],["Plur Def","husene"]]}]
        """
        let merged = Paradigm.mergedStandardRows(from: Paradigm.decodeArray(json))
        #expect(merged.forms("Plur Def") == ["husa", "husene"])
        #expect(merged.forms("Sing Def") == ["huset"])
    }

    @Test func mergeIgnoresNonStandardParadigms() {
        let json = """
        [{"lemma":"x","tags":["VERB"],"std":"S","forms":[["Inf","x"]]},
         {"lemma":"x","tags":["VERB"],"std":"R","forms":[["Inf","y"]]}]
        """
        let merged = Paradigm.mergedStandardRows(from: Paradigm.decodeArray(json))
        #expect(merged.forms("Inf") == ["x"])
    }

    @Test func mergedFormsAreSortedAlphabeticallyNotByJSONOrder() {
        // Real "dusje" data: 3 standard bm paradigms whose "Adj <PerfPart> Def Sing" values
        // appear in raw JSON order dusja, dusjete, dusjede — but ordbøkene.no (and this table)
        // show them alphabetically sorted: dusja, dusjede, dusjete.
        let json = """
        [{"lemma":"dusje","tags":["VERB"],"std":"S","forms":[["Adj <PerfPart> Def Sing","dusja"]]},
         {"lemma":"dusje","tags":["VERB"],"std":"S","forms":[["Adj <PerfPart> Def Sing","dusjete"]]},
         {"lemma":"dusje","tags":["VERB"],"std":"S","forms":[["Adj <PerfPart> Def Sing","dusjede"]]}]
        """
        let merged = Paradigm.mergedStandardRows(from: Paradigm.decodeArray(json))
        #expect(merged.forms("Adj <PerfPart> Def Sing") == ["dusja", "dusjede", "dusjete"])
    }

    @Test func standardGroupsSeparatesFullyDivergentLemmas() {
        // Real "drittsekk, dritsekk" data: two standard paradigms with different lemmas
        // ("drittsekk" vs "dritsekk"), each a complete independent declension. ordbøkene.no
        // shows these as two separate rows, not merged per-cell into "en dritsekk, en
        // drittsekk" / "dritsekker, drittsekker" (which doesn't fit a quarter-width column and
        // loses which spelling pairs with which).
        let json = """
        [{"lemma":"drittsekk","tags":["NOUN","Masc"],"std":"S",
          "forms":[["Sing Ind","drittsekk"],["Sing Def","drittsekken"],
                    ["Plur Ind","drittsekker"],["Plur Def","drittsekkene"]]},
         {"lemma":"dritsekk","tags":["NOUN","Masc"],"std":"S",
          "forms":[["Sing Ind","dritsekk"],["Sing Def","dritsekken"],
                    ["Plur Ind","dritsekker"],["Plur Def","dritsekkene"]]}]
        """
        let groups = Paradigm.standardGroups(from: Paradigm.decodeArray(json))
        #expect(groups.count == 2)
        #expect(groups[0].lemma == "drittsekk")
        #expect(groups[0].rows.forms("Sing Ind") == ["drittsekk"])
        #expect(groups[1].lemma == "dritsekk")
        #expect(groups[1].rows.forms("Sing Ind") == ["dritsekk"])
    }

    @Test func standardGroupsMergesSameLemmaParadigms() {
        // Real "hus" data: two standard paradigms, both lemma "hus", differing only in
        // Plur Def ("husa" vs "husene") — should stay one group with both forms merged.
        let json = """
        [{"lemma":"hus","tags":["NOUN","Neuter"],"std":"S",
          "forms":[["Sing Ind","hus"],["Plur Def","husa"]]},
         {"lemma":"hus","tags":["NOUN","Neuter"],"std":"S",
          "forms":[["Sing Ind","hus"],["Plur Def","husene"]]}]
        """
        let groups = Paradigm.standardGroups(from: Paradigm.decodeArray(json))
        #expect(groups.count == 1)
        #expect(groups[0].rows.forms("Plur Def") == ["husa", "husene"])
    }
}

struct LabelsTests {
    @Test func partOfSpeechMapsGenderedNoun() {
        #expect(Labels.partOfSpeech("NOUN Masc", ui: .en) == "noun, masculine")
        #expect(Labels.partOfSpeech("NOUN Masc", ui: .zh) == "名词, 阳性")
    }

    @Test func inflectionTagMapsPluralDefinite() {
        #expect(Labels.inflectionTag(["Plur", "Def"], ui: .en) == "plural definite")
    }
}
