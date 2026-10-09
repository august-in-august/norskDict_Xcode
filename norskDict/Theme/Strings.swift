import Foundation

/// UI copy in English and Simplified Chinese, selected by the in-app interface language
/// setting (independent of the system locale). Ported from the `T` table in the design spec.
struct Strings {
    var appTitle: String
    var search: String
    var bookmarks: String
    var history: String
    var settings: String
    var placeholder: String
    var cancel: String
    var recent: String
    var clear: String
    var tip: String
    var similar: String
    var similarSubtitle: String
    var noResults: String
    var swipeHint: String
    var fixed: String
    var infl: String
    var machineTranslated: String
    var report: String
    var reported: String
    var see: String
    var singular: String
    var plural: String
    var indefinite: String
    var definite: String
    var infinitive: String
    var present: String
    var past: String
    var perfect: String
    var appearance: String
    var theme: String
    var light: String
    var dark: String
    var system: String
    var appIcon: String
    var navigationHand: String
    var leftHanded: String
    var rightHanded: String
    var translationsHeader: String
    var translationsFooter: String
    var englishName: String
    var chineseName: String
    var interfaceLanguage: String
    var textSize: String
    var sampleTranslation: String
    var about: String
    var sources: String
    var articles: String
    var senses: String
    var examples: String
    var searchableForms: String
    var version: String
    var clearHistoryTitle: String
    var clearHistoryMessage: String
    var today: String
    var yesterday: String
    var remove: String
    var bookmarksHint: String
    var bookmarksEmpty: String
    var historyEmpty: String
    var selectWord: String
    var noEntriesIn: String
    var bokmaalFull: String
    var nynorskFull: String
    var bokmaal: String
    var nynorsk: String

    func offline(articleCount: Int) -> String {
        let formatted = Self.groupedNumberFormatter.string(from: NSNumber(value: articleCount)) ?? "\(articleCount)"
        return offlineTemplate.replacingOccurrences(of: "%@", with: formatted)
    }

    private var offlineTemplate: String

    private static let groupedNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }()

    static func `for`(_ language: UILanguage) -> Strings {
        switch language {
        case .en:
            Strings(
                appTitle: "Slå opp", search: "Search", bookmarks: "Bookmarks", history: "History",
                settings: "Settings", placeholder: "Any form of a word", cancel: "Cancel", recent: "Recent",
                clear: "Clear",
                tip: "Type any form of a word: “gikk” finds gå, “bøkene” finds bok, “augo” finds auge.",
                similar: "Similar headwords", similarSubtitle: "Lignende oppslagsord",
                noResults: "No matches. Check the spelling or try the base form.",
                swipeHint: "Swipe to switch dictionary", fixed: "Fixed expressions", infl: "Inflection",
                machineTranslated: "Machine-translated", report: "Report error",
                reported: "Report saved. It will be sent next time you’re online.",
                see: "see", singular: "Singular", plural: "Plural", indefinite: "Indefinite", definite: "Definite",
                infinitive: "Infinitive", present: "Present", past: "Past", perfect: "Perfect",
                appearance: "Appearance", theme: "Theme", light: "Light", dark: "Dark", system: "System",
                appIcon: "App Icon",
                navigationHand: "Navigation Layout", leftHanded: "Left-handed", rightHanded: "Right-handed",
                translationsHeader: "Show translations by default",
                translationsFooter: "Translations appear under each definition and example. "
                    + "You can also switch them on any entry.",
                englishName: "English", chineseName: "中文 Chinese", interfaceLanguage: "Interface language",
                textSize: "Text size", sampleTranslation: "a good friend of mine", about: "About",
                sources: "Sources", articles: "articles", senses: "senses", examples: "examples",
                searchableForms: "searchable forms", version: "Version",
                clearHistoryTitle: "Clear history?",
                clearHistoryMessage: "All recent lookups will be removed from this device.",
                today: "Today", yesterday: "Yesterday", remove: "Remove",
                bookmarksHint: "Swipe left on a word to remove it.", bookmarksEmpty: "No bookmarks yet",
                historyEmpty: "No history", selectWord: "Search for a word to see its entry",
                noEntriesIn: "No entries in ", bokmaalFull: "Bokmålsordboka", nynorskFull: "Nynorskordboka",
                bokmaal: "Bokmål", nynorsk: "Nynorsk", offlineTemplate: "Offline · %@ articles"
            )
        case .zh:
            Strings(
                appTitle: "Slå opp 查词", search: "查词", bookmarks: "收藏", history: "历史", settings: "设置",
                placeholder: "输入单词的任意形式", cancel: "取消", recent: "最近搜索", clear: "清除",
                tip: "可以输入任意词形：输入 gikk 可查到 gå，输入 bøkene 可查到 bok，输入 augo 可查到 auge。",
                similar: "相近词条", similarSubtitle: "Lignende oppslagsord",
                noResults: "没有找到结果。请检查拼写，或尝试输入原形。", swipeHint: "左右轻扫切换词典",
                fixed: "固定表达", infl: "词形变化", machineTranslated: "机器翻译", report: "报告错误",
                reported: "报告已保存，将在联网后发送。", see: "参见", singular: "单数", plural: "复数",
                indefinite: "不定态", definite: "限定态", infinitive: "不定式", present: "现在时", past: "过去时",
                perfect: "完成时", appearance: "外观", theme: "主题", light: "浅色", dark: "深色",
                system: "跟随系统", appIcon: "应用图标",
                navigationHand: "导航布局", leftHanded: "左手", rightHanded: "右手",
                translationsHeader: "默认显示翻译",
                translationsFooter: "翻译显示在每条释义和例句下方。也可以在任意词条页中切换。",
                englishName: "English 英语", chineseName: "中文", interfaceLanguage: "界面语言",
                textSize: "字体大小", sampleTranslation: "我的一个好朋友", about: "关于", sources: "数据来源",
                articles: "词条", senses: "释义", examples: "例句", searchableForms: "可搜索词形",
                version: "版本", clearHistoryTitle: "清除历史记录？",
                clearHistoryMessage: "此设备上的所有查询记录都将被删除。", today: "今天", yesterday: "昨天",
                remove: "移除", bookmarksHint: "向左轻扫单词即可移除。", bookmarksEmpty: "还没有收藏",
                historyEmpty: "没有历史记录", selectWord: "搜索单词以查看词条", noEntriesIn: "没有词条：",
                bokmaalFull: "Bokmålsordboka 书面语词典", nynorskFull: "Nynorskordboka 新挪威语词典",
                bokmaal: "Bokmål", nynorsk: "Nynorsk", offlineTemplate: "离线可用 · %@ 个词条"
            )
        }
    }
}
