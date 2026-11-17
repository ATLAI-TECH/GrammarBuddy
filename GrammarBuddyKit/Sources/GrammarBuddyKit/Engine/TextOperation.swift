// TextOperation.swift
// The four operations (design §6.1) and how their prompts are put together (§6.2).
// Prompt texts live in Engine/Prompts/*.txt; the same files are used by qa/model-eval/run.py.

import Foundation

public enum TextOperation: String, CaseIterable, Sendable, Codable {
    case fix, polish, translate, tone

    /// AI operations; translate defaults to the system translator.
    public var usesAI: Bool { self != .translate }
}

public enum Tone: String, CaseIterable, Sendable, Codable {
    case formal, casual, friendly, concise, academic
}

public enum Prompts {
    /// What each tone means in practice (round 7, P7-03: "concise" came back identical to a plain fix).
    static func toneGuide(_ t: Tone) -> String {
        switch t {
        case .concise: return "Concise means clearly shorter: cut filler, repetition and throat-clearing, merge sentences where that helps, and aim for at least a fifth fewer words while keeping every fact."
        case .friendly: return "Friendly means warm and personal: polite requests instead of orders, contractions where natural, a human opening or closing if the text has none."
        case .formal: return "Formal means professional: no slang or contractions, complete sentences, polite and precise wording."
        case .casual: return "Casual means relaxed and conversational: contractions, short sentences, everyday words."
        case .academic: return "Academic means precise and impersonal: exact terms, hedged claims where the text hedges, no colloquialisms."
        }
    }

    static func file(_ name: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Prompts")
                ?? Bundle.module.url(forResource: name, withExtension: "txt"),
              let s = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// System message. The selected text always goes in the user message, never in here (§6.2).
    public static func system(for op: TextOperation, tone: Tone = .formal, target: String = "English",
                              protectedWords: [String] = [], sourceLanguage: String? = nil, polishTranslation: Bool = false) -> String {
        let protected = protectedWords.isEmpty ? ""
            : ", and these words: " + protectedWords.map { "\"\($0)\"" }.joined(separator: ", ")
        let s: String
        switch op {
        case .translate:
            s = file("translate").replacingOccurrences(of: "{TARGET}", with: target)
        case .tone:
            s = file("tone").replacingOccurrences(of: "{TONE}", with: tone.rawValue) + " " + toneGuide(tone) + " " + file("_common")
        case .fix, .polish:
            s = file(op.rawValue) + " " + file("_common")
        }
        var out = s.replacingOccurrences(of: "{PROTECTED}", with: protected)
        // "Translate and polish": for people who draft in their own language and need publishable text in another
        if op == .translate && polishTranslation {
            out = out.replacingOccurrences(of: "Output only the translation.", with:
                "Then polish the translation so that it reads as if a careful native writer of \(target) had written it: natural word choice and sentence flow, the same level of formality. Do not add, drop or change any fact, number, name, term or citation. Output only the final polished translation.")
        }
        // Round 6: polish and tone drifted into English for zh/ja/de/fr/es. Name the language up front.
        if op != .translate, let lang = sourceLanguage, !lang.isEmpty {
            out = "The text is written in \(lang). Your reply must be in \(lang). " + out
        }
        return out
    }
}
