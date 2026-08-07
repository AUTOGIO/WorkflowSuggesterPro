import Foundation

public struct WorkflowPipelineConfig: Sendable {
    public let lookbackDays: Int
    public let minOccurrences: Int
    public let maxWorkflowsInPrompt: Int
    public let forceCloud: Bool
    public let environment: [String: String]

    public init(
        lookbackDays: Int = 14,
        minOccurrences: Int = 4,
        maxWorkflowsInPrompt: Int = 5,
        forceCloud: Bool = false,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.lookbackDays = lookbackDays
        self.minOccurrences = minOccurrences
        self.maxWorkflowsInPrompt = maxWorkflowsInPrompt
        self.forceCloud = forceCloud
        self.environment = environment
    }
}

public enum GenerationSource: Sendable, Equatable {
    case onDevice
    case cloud(provider: String)
}

public struct PipelineResult: Sendable {
    public let recurringWorkflows: [RecurringWorkflow]
    public let suggestions: [SuggestionResult]
    public let writtenScriptURLs: [URL]
    public let source: GenerationSource
}

public struct WorkflowPipeline: Sendable {
    public init() {}

    public func run(
        config: WorkflowPipelineConfig,
        onStatus: @Sendable (String) async -> Void = { _ in }
    ) async throws -> PipelineResult {
        let awService = ActivityWatchService()
        let bucketId = try await awService.discoverWindowBucket()
        let since = Date().addingTimeInterval(-Double(config.lookbackDays) * 86400)
        let windowEvents = try await awService.fetchEvents(bucketId: bucketId, since: since)

        let events: [AWEvent]
        do {
            let afkBucketId = try await awService.discoverAFKBucket()
            let afkEvents = try await awService.fetchEvents(bucketId: afkBucketId, since: since)
            events = AFKFilter().filterToActive(windowEvents: windowEvents, afkEvents: afkEvents)
        } catch {
            await onStatus("AFK bucket unavailable (\(error)); using unfiltered window events.")
            events = windowEvents
        }

        let recurring = RecurrenceDetector().detect(events: events, minOccurrences: config.minOccurrences)
        guard !recurring.isEmpty else {
            return PipelineResult(recurringWorkflows: [], suggestions: [], writtenScriptURLs: [], source: .onDevice)
        }

        let promptWorkflows = Array(recurring.prefix(config.maxWorkflowsInPrompt))

        let suggestions: [SuggestionResult]
        let source: GenerationSource

        if config.forceCloud {
            await onStatus("Using cloud provider…")
            suggestions = try await CloudSuggestionService(environment: config.environment)
                .generateSuggestions(for: promptWorkflows)
            source = .cloud(provider: config.environment["WORKFLOWSUGGESTER_PROVIDER"] ?? "auto")
        } else if #available(macOS 26.0, iOS 26.0, *) {
            do {
                await onStatus("Generating on-device with Apple Intelligence…")
                suggestions = try await FoundationModelsSuggestionService()
                    .generateSuggestions(for: promptWorkflows)
                source = .onDevice
            } catch let error as FoundationModelsSuggestionError {
                await onStatus("On-device unavailable (\(error.description)). Falling back to cloud…")
                suggestions = try await CloudSuggestionService(environment: config.environment)
                    .generateSuggestions(for: promptWorkflows)
                source = .cloud(provider: config.environment["WORKFLOWSUGGESTER_PROVIDER"] ?? "auto")
            }
        } else {
            await onStatus("On-device not available on this OS. Using cloud provider…")
            suggestions = try await CloudSuggestionService(environment: config.environment)
                .generateSuggestions(for: promptWorkflows)
            source = .cloud(provider: config.environment["WORKFLOWSUGGESTER_PROVIDER"] ?? "auto")
        }

        let writer = try AutomationScriptWriter()
        let paths = try writer.write(suggestions, timestamp: Date())

        return PipelineResult(
            recurringWorkflows: recurring,
            suggestions: suggestions,
            writtenScriptURLs: paths,
            source: source
        )
    }
}
