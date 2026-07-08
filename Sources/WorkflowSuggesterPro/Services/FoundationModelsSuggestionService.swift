import Foundation
import FoundationModels

enum FoundationModelsSuggestionError: Error, CustomStringConvertible {
    case unavailable(SystemLanguageModel.Availability.UnavailableReason)

    var description: String {
        switch self {
        case .unavailable(.deviceNotEligible):
            return "This device is not eligible for Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is not enabled in System Settings."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading or preparing."
        @unknown default:
            return "The on-device model is unavailable for an unknown reason."
        }
    }
}

struct FoundationModelsSuggestionService: Sendable {
    func generateSuggestions(for workflows: [RecurringWorkflow]) async throws -> [SuggestionResult] {
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw FoundationModelsSuggestionError.unavailable(reason)
        }

        let session = LanguageModelSession()
        let prompt = """
        Recurring workflows detected on this Mac from the last 14 days of window-activity history:

        \(WorkflowPromptFormatting.summary(for: workflows))

        \(WorkflowPromptFormatting.instruction)
        """
        // includeSchemaInPrompt: false — guided generation constrains output via the
        // Generable schema regardless; spelling it out in the prompt text is pure token
        // cost against the model's 8192-token context window with no accuracy benefit.
        //
        // Uses SuggestionList (a wrapper Generable with an array property), not
        // [SuggestionResult].self directly — measured on real hardware that a top-level
        // array-of-Generable type burns ~7900 tokens of fixed schema/grammar overhead
        // against the 8192-token window, vs. a 286-token actual prompt. The wrapper
        // avoids that overhead.
        let result = try await session.respond(
            to: prompt,
            generating: SuggestionList.self,
            includeSchemaInPrompt: false
        )
        return result.content.suggestions
    }
}
