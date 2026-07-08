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
        let result = try await session.respond(to: prompt, generating: [SuggestionResult].self)
        return result.content
    }
}
