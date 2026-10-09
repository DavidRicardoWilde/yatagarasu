//
//  ReadmeCodeHighlighter.swift
//  yatagarasu
//

import Foundation
import MarkdownUI
import SwiftUI

/// Regex-based highlighting for the handful of languages common in READMEs.
struct YatagarasuCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    /// First word of a code fence's info string ("swift title=x" → "swift").
    static func fenceLabel(from language: String?) -> String? {
        guard let language else { return nil }
        let label = language
            .split(whereSeparator: \.isWhitespace)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let label, !label.isEmpty else { return nil }
        return label
    }

    func highlightCode(_ code: String, language: String?) -> Text {
        let trimmedLanguage = Self.fenceLabel(from: language)?.lowercased()
        let rules = highlightRules(for: trimmedLanguage)
        guard !rules.isEmpty else {
            return Text(code)
        }

        let acceptedMatches = acceptedHighlightMatches(in: code, rules: rules)
        guard !acceptedMatches.isEmpty else {
            return Text(code)
        }

        var attributed = AttributedString(code)
        attributed.foregroundColor = ReadmePalette.codePlainText

        for match in acceptedMatches {
            guard
                let stringRange = Range(match.range, in: code),
                let lowerBound = AttributedString.Index(stringRange.lowerBound, within: attributed),
                let upperBound = AttributedString.Index(stringRange.upperBound, within: attributed)
            else {
                continue
            }

            attributed[lowerBound ..< upperBound].foregroundColor = match.color
        }

        return Text(attributed)
    }

    private func acceptedHighlightMatches(
        in code: String,
        rules: [CodeHighlightRule]
    ) -> [CodeHighlightMatch] {
        let fullRange = NSRange(code.startIndex..., in: code)
        var matches: [CodeHighlightMatch] = []

        for rule in rules {
            guard let regex = try? NSRegularExpression(
                pattern: rule.pattern,
                options: rule.options
            ) else {
                continue
            }

            regex.enumerateMatches(in: code, options: [], range: fullRange) { result, _, _ in
                guard let result, result.range.length > 0 else { return }
                matches.append(
                    CodeHighlightMatch(
                        range: result.range,
                        color: rule.color,
                        priority: rule.priority
                    )
                )
            }
        }

        matches.sort {
            if $0.range.location != $1.range.location {
                return $0.range.location < $1.range.location
            }
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            return $0.range.length > $1.range.length
        }

        var accepted: [CodeHighlightMatch] = []
        var lastUpperBound = 0

        for match in matches {
            guard match.range.location >= lastUpperBound else {
                continue
            }
            accepted.append(match)
            lastUpperBound = match.range.location + match.range.length
        }

        return accepted
    }

    private func highlightRules(for language: String?) -> [CodeHighlightRule] {
        var rules: [CodeHighlightRule] = [
            CodeHighlightRule(
                pattern: #"/\*[\s\S]*?\*/|//.*$"#,
                color: ReadmePalette.codeComment,
                priority: 0,
                options: [.anchorsMatchLines]
            ),
            CodeHighlightRule(
                pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#,
                color: ReadmePalette.codeString,
                priority: 1
            ),
            CodeHighlightRule(
                pattern: #"\b\d+(?:\.\d+)?\b"#,
                color: ReadmePalette.codeNumber,
                priority: 4
            ),
        ]

        switch language {
        case "swift":
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:actor|as|async|await|break|case|catch|class|continue|default|defer|do|else|enum|extension|fallthrough|false|for|func|guard|if|import|in|init|let|nil|private|protocol|public|repeat|return|self|static|struct|switch|throw|throws|true|try|var|where|while)\b"#,
                    color: ReadmePalette.codeKeyword,
                    priority: 2
                ),
                at: 0
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"@[A-Za-z_]\w*|\b(?:Int|Double|Float|String|Bool|Date|URL|Data|Color|Text|View|Task|Result)\b"#,
                    color: ReadmePalette.codeType,
                    priority: 3
                ),
                at: 1
            )
        case "bash", "shell", "sh", "zsh":
            rules.insert(
                CodeHighlightRule(
                    pattern: #"(?m)#.*$"#,
                    color: ReadmePalette.codeComment,
                    priority: 0,
                    options: [.anchorsMatchLines]
                ),
                at: 0
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\$(?:\w+|\{[^}]+\})"#,
                    color: ReadmePalette.codeVariable,
                    priority: 2
                ),
                at: 1
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:if|then|else|elif|fi|for|in|do|done|case|esac|while|function|export|sudo|brew|cd|echo|git|curl)\b|--?[A-Za-z0-9][A-Za-z0-9-]*"#,
                    color: ReadmePalette.codeKeyword,
                    priority: 3
                ),
                at: 2
            )
        case "json":
            rules.insert(
                CodeHighlightRule(
                    pattern: #"(?m)"(?:\\.|[^"\\])*"(?=\s*:)"#,
                    color: ReadmePalette.codeKey,
                    priority: 1
                ),
                at: 0
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:true|false|null)\b"#,
                    color: ReadmePalette.codeKeyword,
                    priority: 3
                ),
                at: 2
            )
        case "yaml", "yml":
            rules.insert(
                CodeHighlightRule(
                    pattern: #"(?m)^\s*[A-Za-z0-9_.-]+(?=\s*:)"#,
                    color: ReadmePalette.codeKey,
                    priority: 1,
                    options: [.anchorsMatchLines]
                ),
                at: 0
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"(?m)#.*$"#,
                    color: ReadmePalette.codeComment,
                    priority: 0,
                    options: [.anchorsMatchLines]
                ),
                at: 1
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:true|false|null|yes|no|on|off)\b"#,
                    color: ReadmePalette.codeKeyword,
                    priority: 3
                ),
                at: 2
            )
        case "javascript", "js", "typescript", "ts":
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:async|await|break|case|catch|class|const|continue|default|else|export|extends|false|finally|for|from|function|if|import|in|let|new|null|return|switch|throw|true|try|typeof|var|while|yield)\b"#,
                    color: ReadmePalette.codeKeyword,
                    priority: 2
                ),
                at: 0
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:Promise|Array|Object|String|Number|Boolean|Date|Map|Set)\b"#,
                    color: ReadmePalette.codeType,
                    priority: 3
                ),
                at: 1
            )
        case "python", "py":
            rules.insert(
                CodeHighlightRule(
                    pattern: #"(?m)#.*$"#,
                    color: ReadmePalette.codeComment,
                    priority: 0,
                    options: [.anchorsMatchLines]
                ),
                at: 0
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:and|as|assert|async|await|break|class|continue|def|elif|else|except|False|finally|for|from|if|import|in|is|lambda|None|nonlocal|not|or|pass|raise|return|self|True|try|while|with|yield)\b"#,
                    color: ReadmePalette.codeKeyword,
                    priority: 2
                ),
                at: 1
            )
        default:
            break
        }

        return rules
    }
}

extension CodeSyntaxHighlighter where Self == YatagarasuCodeSyntaxHighlighter {
    static var yatagarasu: Self {
        YatagarasuCodeSyntaxHighlighter()
    }
}

private struct CodeHighlightRule {
    let pattern: String
    let color: Color
    let priority: Int
    let options: NSRegularExpression.Options

    init(
        pattern: String,
        color: Color,
        priority: Int,
        options: NSRegularExpression.Options = []
    ) {
        self.pattern = pattern
        self.color = color
        self.priority = priority
        self.options = options
    }
}

private struct CodeHighlightMatch {
    let range: NSRange
    let color: Color
    let priority: Int
}
