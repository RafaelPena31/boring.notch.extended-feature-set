import Defaults
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum SmartReplyAvailability: Equatable {
    case available
    case unavailable(reason: String)
}

enum SmartReplyManager {
    static var availability: SmartReplyAvailability {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else {
            return .unavailable(reason: "Requires macOS 26 or later.")
        }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(reason: describeUnavailable(reason))
        }
        #else
        return .unavailable(reason: "Requires macOS 26 or later.")
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func describeUnavailable(
        _ reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This Mac doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in System Settings."
        case .modelNotReady:
            return "The on-device model is still downloading."
        @unknown default:
            return "Apple Intelligence isn't available right now."
        }
    }
    #endif

    static func suggestReplies(sender: String?, body: String) async -> [String] {
        guard Defaults[.notificationAppleIntelligenceEnabled] else { return [] }

        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *),
              case .available = SystemLanguageModel.default.availability,
              !body.isEmpty
        else { return [] }

        do {
            let session = LanguageModelSession(instructions: """
                Draft very short, casual replies to an incoming message. Match
                its tone and language. Never invent facts, dates or commitments.
                Each suggestion must contain fewer than eight words.
                """)
            let prompt = "From: \(sender ?? "someone")\nMessage: \(body)\nSuggest 3 short replies."
            let result = try await session.respond(
                to: prompt,
                generating: ReplySuggestionSet.self
            )

            var seen: Set<String> = []
            return result.content.replies
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
                .prefix(3)
                .map { $0 }
        } catch {
            return []
        }
        #else
        return []
        #endif
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable
private struct ReplySuggestionSet: Equatable {
    @Guide(description: "2 to 3 short reply suggestions, each under 8 words")
    let replies: [String]
}
#endif
