import SwiftUI

/// The licence attribution screen required by Bokmålsordboka/Nynorskordboka's open licence and
/// Norsk ordbank's CC BY 4.0 terms (see DATABASE.md's "Gotchas" and the product plan's
/// "Data sources and licences" section).
struct SourcesView: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings

    private var strings: Strings { settings.strings }

    private struct Source {
        var title: String
        var body: String
        var licence: String?
    }

    private var sources: [Source] {
        switch settings.uiLanguage {
        case .en:
            [
                Source(
                    title: "Bokmålsordboka",
                    body: "Definitions, examples and fixed expressions for Bokmål. Edited by Språkrådet "
                        + "(the Language Council of Norway) and the University of Bergen.",
                    licence: nil
                ),
                Source(
                    title: "Nynorskordboka",
                    body: "Definitions, examples and fixed expressions for Nynorsk. Edited by Språkrådet "
                        + "and the University of Bergen.",
                    licence: nil
                ),
                Source(
                    title: "Norsk ordbank",
                    body: "Inflection data used to find the base word from any form you type. "
                        + "Språkrådet and the University of Bergen.",
                    licence: "CC BY 4.0"
                ),
                Source(
                    title: "Translations",
                    body: "The English and Chinese translations of definitions and examples were added "
                        + "by machine translation. They are not part of the original dictionaries and may "
                        + "contain errors. Use \"Report error\" on any entry to flag one.",
                    licence: nil
                ),
            ]
        case .zh:
            [
                Source(
                    title: "Bokmålsordboka",
                    body: "书面挪威语的释义、例句和固定表达。由挪威语言委员会（Språkrådet）与卑尔根大学编纂。",
                    licence: nil
                ),
                Source(title: "Nynorskordboka", body: "新挪威语的释义、例句和固定表达。由 Språkrådet 与卑尔根大学编纂。", licence: nil),
                Source(
                    title: "Norsk ordbank",
                    body: "词形变化数据，用于从你输入的任意词形找到原形。Språkrådet 与卑尔根大学。",
                    licence: "CC BY 4.0"
                ),
                Source(
                    title: "翻译",
                    body: "释义和例句的英文与中文翻译由机器翻译生成，不属于原词典内容，可能存在错误。"
                        + "可在任意词条页点击“报告错误”进行反馈。",
                    licence: nil
                ),
            ]
        }
    }

    var body: some View {
        List {
            ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                VStack(alignment: .leading, spacing: 6) {
                    Text(source.title).font(.system(size: 17, weight: .semibold))
                    Text(source.body).font(.system(size: 15)).foregroundStyle(theme.ink2)
                    if let licence = source.licence {
                        Text(licence)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.ink2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(theme.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
                .padding(.vertical, 4)
            }
            if let built = DictionaryDatabase.shared.dataBuildDate() {
                Text("\(strings.version) \(built)").font(.system(size: 12)).foregroundStyle(theme.ink3)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.grp)
        .navigationTitle(strings.sources)
    }
}
