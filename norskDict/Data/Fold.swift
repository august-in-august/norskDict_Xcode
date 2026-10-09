import Foundation

/// Normalizes Norwegian text into the search key used by `form.fold` in norskdict.sqlite.
/// Must stay byte-for-byte compatible with `fold()` in the data pipeline's `scripts/build_db.py`.
func fold(_ s: String) -> String {
    let keep: Set<Character> = ["æ", "ø", "å"]
    return String(
        s.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .precomposedStringWithCanonicalMapping
            .map { character -> String in
                if keep.contains(character) {
                    return String(character)
                }
                return String(character).folding(options: .diacriticInsensitive, locale: nil)
            }
            .joined()
    )
}

/// Letter-tolerant input variants a user might type instead of the correct Norwegian letter
/// (aa -> å, oe -> ø, ae -> æ), per the product plan's "accent- and letter-tolerant input" requirement.
/// Returns the folded query plus any additional folded variants worth trying, most-likely first.
func foldedQueryVariants(_ raw: String) -> [String] {
    let primary = fold(raw)
    guard !primary.isEmpty else { return [] }

    var variants: [String] = [primary]
    let substitutions: [(String, String)] = [("aa", "å"), ("oe", "ø"), ("ae", "æ")]
    var seen: Set<String> = [primary]

    func addVariant(_ s: String) {
        if seen.insert(s).inserted {
            variants.append(s)
        }
    }

    // Try each digraph -> letter substitution, and combinations of them, since a query
    // might contain more than one (e.g. "oesterraad" -> "østerråd" isn't realistic, but
    // "blaabaer" -> "blåbær" needs both "aa" and "ae" replaced).
    var frontier = [primary]
    for _ in substitutions {
        var next: [String] = []
        for candidate in frontier {
            for (pattern, replacement) in substitutions where candidate.contains(pattern) {
                let substituted = candidate.replacingOccurrences(of: pattern, with: replacement)
                if substituted != candidate {
                    addVariant(substituted)
                    next.append(substituted)
                }
            }
        }
        if next.isEmpty { break }
        frontier = next
    }

    return variants
}
