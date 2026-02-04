import Foundation

enum CodeBlockParser {
    struct Segment: Identifiable {
        enum Kind: Equatable {
            case text
            case code(lang: String?, content: String)
        }
        let id = UUID()
        let kind: Kind
        let raw: String
    }

    static func parse(markdown: String) -> [Segment] {
        let pattern = #"(?ms)^```(\w*)\n(.*?)\n```$"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .dotMatchesLineSeparators]) else {
            return [Segment(kind: .text, raw: markdown)]
        }

        let ns = markdown as NSString
        let matches = re.matches(in: markdown, range: NSRange(location: 0, length: ns.length))

        if matches.isEmpty {
            return [Segment(kind: .text, raw: markdown)]
        }

        var segments: [Segment] = []
        var lastCursor = 0

        for match in matches {
            // Append text before the code block
            if match.range.location > lastCursor {
                let range = NSRange(location: lastCursor, length: match.range.location - lastCursor)
                let text = ns.substring(with: range)
                segments.append(Segment(kind: .text, raw: text))
            }

            // Extract code block info
            let lang: String? = {
                guard match.numberOfRanges >= 2, match.range(at: 1).length > 0 else { return nil }
                return ns.substring(with: match.range(at: 1))
            }()

            let content: String = {
                guard match.numberOfRanges >= 3 else { return "" }
                return ns.substring(with: match.range(at: 2))
            }()

            let fullMatch = ns.substring(with: match.range)
            segments.append(Segment(kind: .code(lang: lang, content: content), raw: fullMatch))

            lastCursor = match.range.location + match.range.length
        }

        // Append remaining text
        if lastCursor < ns.length {
            let range = NSRange(location: lastCursor, length: ns.length - lastCursor)
            let text = ns.substring(with: range)
            segments.append(Segment(kind: .text, raw: text))
        }

        return segments
    }
}
