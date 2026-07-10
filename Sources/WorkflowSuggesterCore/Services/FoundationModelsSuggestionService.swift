import Foundation
import FoundationModels

public enum FoundationModelsSuggestionError: Error, CustomStringConvertible {
    case unavailable(SystemLanguageModel.Availability.UnavailableReason)

    public var description: String {
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

public struct FoundationModelsSuggestionService: Sendable {
    public init() {}

    public func generateSuggestions(for workflows: [RecurringWorkflow]) async throws -> [SuggestionResult] {
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw FoundationModelsSuggestionError.unavailable(reason)
        }

        // Free-text generation + manual JSON parsing (via CloudJSONExtraction), not
        // @Generable/guided generation. Real runs on this on-device model went through
        // three failure modes with schema-constrained generation: a top-level array type
        // burning ~7900 tokens of fixed schema overhead; an empty GeneratedContent when
        // schema-in-prompt was disabled to dodge that; and a renewed overflow (8193/8192)
        // even after wrapping in a single Generable and shrinking the prompt hard. The
        // common thread was fixed schema/grammar overhead swamping this model's 8192-token
        // context regardless of tuning. Free-text sidesteps schema entirely — it's the
        // same approach already proven reliable for the cloud providers.
        //
        // One bounded retry: a real run produced free text that wasn't valid JSON (the
        // small on-device model doesn't follow strict-formatting instructions as reliably
        // as cloud models). Retrying once with an added, stricter reminder is the standard
        // mitigation — capped at 2 attempts total, not an unbounded loop.
        var lastError: Error = LLMProviderError.invalidResponse("on-device generation produced no attempts")
        for attempt in 1...2 {
            let session = LanguageModelSession()
            let prompt = attempt == 1
                ? WorkflowPromptFormatting.jsonPrompt(for: workflows)
                : WorkflowPromptFormatting.jsonPrompt(for: workflows) + "\n\n" + WorkflowPromptFormatting.strictJSONReminder
            do {
                let result = try await session.respond(to: prompt)
                return try CloudJSONExtraction.parseSuggestions(from: result.content)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}
