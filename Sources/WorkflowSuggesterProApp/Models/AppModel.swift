import AppKit
import Foundation
import Observation
import WorkflowSuggesterCore

@MainActor
@Observable
final class AppModel {
    enum GenerationSource: Equatable {
        case onDevice
        case cloud(provider: String)

        var displayName: String {
            switch self {
            case .onDevice: return "On-device"
            case .cloud(let provider): return "Cloud (\(provider))"
            }
        }
    }

    enum ProviderMode: String, CaseIterable, Codable, Identifiable {
        case onDeviceFirst, forceAnthropic, forceOpenAI
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .onDeviceFirst: return "Automatic (on-device first)"
            case .forceAnthropic: return "Anthropic (force cloud)"
            case .forceOpenAI: return "OpenAI (force cloud)"
            }
        }
    }

    // MARK: Data
    var recurringWorkflows: [RecurringWorkflow] = []
    var suggestions: [SuggestionResult] = []
    var generatedScripts: [GeneratedScriptSummary] = []

    // MARK: Status
    var isGenerating = false
    var lastStatusMessage = "Ready. Click Regenerate to scan recent activity."
    var lastGenerationSource: GenerationSource?
    var lastGeneratedAt: Date?
    var lastErrorMessage: String?

    // MARK: Preferences (persisted via AppPreferencesStore)
    var lookbackDays: Int { didSet { persistPreferences() } }
    var minOccurrences: Int { didSet { persistPreferences() } }
    var providerMode: ProviderMode { didSet { persistPreferences() } }

    // MARK: Cloud API keys (Keychain-backed)
    var anthropicAPIKeyDraft = ""
    var openAIAPIKeyDraft = ""
    var isAnthropicKeyStored: Bool
    var isOpenAIKeyStored: Bool

    private static let maxWorkflowsInPrompt = 5
    private static let anthropicKeychainAccount = "anthropic_api_key"
    private static let openAIKeychainAccount = "openai_api_key"

    private let preferencesStore: AppPreferencesStore
    private let keychainStore: any SecretStoring
    private var scriptsDirectoryURL: URL?

    init(
        preferencesStore: AppPreferencesStore = AppPreferencesStore(),
        keychainStore: any SecretStoring = KeychainStore()
    ) {
        self.preferencesStore = preferencesStore
        self.keychainStore = keychainStore
        let prefs = preferencesStore.load()
        lookbackDays = prefs.lookbackDays
        minOccurrences = prefs.minOccurrences
        providerMode = prefs.providerMode
        isAnthropicKeyStored = (try? keychainStore.loadSecret(account: Self.anthropicKeychainAccount)) != nil
        isOpenAIKeyStored = (try? keychainStore.loadSecret(account: Self.openAIKeychainAccount)) != nil

        if let writer = try? AutomationScriptWriter() {
            scriptsDirectoryURL = writer.outputDirectoryURL
            refreshGeneratedScripts()
        }
    }

    func regenerate() {
        guard !isGenerating else { return }
        isGenerating = true
        lastErrorMessage = nil
        lastStatusMessage = "Scanning ActivityWatch history…"

        let lookbackDays = self.lookbackDays
        let minOccurrences = self.minOccurrences
        let providerMode = self.providerMode
        let maxWorkflowsInPrompt = Self.maxWorkflowsInPrompt
        let anthropicKey = try? keychainStore.loadSecret(account: Self.anthropicKeychainAccount)
        let openAIKey = try? keychainStore.loadSecret(account: Self.openAIKeychainAccount)

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let awService = ActivityWatchService()
                let bucketId = try await awService.discoverWindowBucket()
                let since = Date().addingTimeInterval(-Double(lookbackDays) * 86400)
                let windowEvents = try await awService.fetchEvents(bucketId: bucketId, since: since)

                let events: [AWEvent]
                do {
                    let afkBucketId = try await awService.discoverAFKBucket()
                    let afkEvents = try await awService.fetchEvents(bucketId: afkBucketId, since: since)
                    events = AFKFilter().filterToActive(windowEvents: windowEvents, afkEvents: afkEvents)
                } catch {
                    events = windowEvents
                }

                let recurring = RecurrenceDetector().detect(events: events, minOccurrences: minOccurrences)
                await MainActor.run {
                    self.recurringWorkflows = recurring
                    self.lastStatusMessage = recurring.isEmpty
                        ? "No recurring workflows found in the last \(lookbackDays) days."
                        : "Found \(recurring.count) recurring workflow(s). Generating suggestions…"
                }
                guard !recurring.isEmpty else {
                    await MainActor.run { self.isGenerating = false }
                    return
                }

                let promptWorkflows = Array(recurring.prefix(maxWorkflowsInPrompt))
                var env: [String: String] = [:]
                if let anthropicKey { env["ANTHROPIC_API_KEY"] = anthropicKey }
                if let openAIKey { env["OPENAI_API_KEY"] = openAIKey }

                let suggestions: [SuggestionResult]
                let source: GenerationSource
                switch providerMode {
                case .forceAnthropic, .forceOpenAI:
                    let providerName = providerMode == .forceAnthropic ? "anthropic" : "openai"
                    env["WORKFLOWSUGGESTER_PROVIDER"] = providerName
                    await MainActor.run { self.lastStatusMessage = "Generating with cloud provider…" }
                    suggestions = try await CloudSuggestionService(environment: env).generateSuggestions(for: promptWorkflows)
                    source = .cloud(provider: providerName)
                case .onDeviceFirst:
                    do {
                        await MainActor.run {
                            self.lastStatusMessage = "Generating on-device with Apple Intelligence — this can take 30–90 seconds…"
                        }
                        suggestions = try await FoundationModelsSuggestionService().generateSuggestions(for: promptWorkflows)
                        source = .onDevice
                    } catch let error as FoundationModelsSuggestionError {
                        await MainActor.run { self.lastStatusMessage = "On-device unavailable (\(error.description)). Falling back to cloud…" }
                        suggestions = try await CloudSuggestionService(environment: env).generateSuggestions(for: promptWorkflows)
                        source = .cloud(provider: env["WORKFLOWSUGGESTER_PROVIDER"] ?? "auto")
                    }
                }

                let writer = try AutomationScriptWriter()
                let paths = try writer.write(suggestions, timestamp: Date())

                await MainActor.run {
                    self.suggestions = suggestions
                    self.lastGenerationSource = source
                    self.lastGeneratedAt = Date()
                    self.lastStatusMessage = "Wrote \(paths.count) automation script(s)."
                    self.isGenerating = false
                    self.refreshGeneratedScripts()
                }
            } catch {
                await MainActor.run {
                    self.lastErrorMessage = String(describing: error)
                    self.lastStatusMessage = "Generation failed."
                    self.isGenerating = false
                }
            }
        }
    }

    func revealScriptsFolder() {
        guard let scriptsDirectoryURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([scriptsDirectoryURL])
    }

    func reveal(_ script: GeneratedScriptSummary) {
        NSWorkspace.shared.activateFileViewerSelecting([script.url])
    }

    func saveAnthropicKey() {
        guard !anthropicAPIKeyDraft.isEmpty else { return }
        try? keychainStore.saveSecret(anthropicAPIKeyDraft, account: Self.anthropicKeychainAccount)
        isAnthropicKeyStored = true
        anthropicAPIKeyDraft = ""
    }

    func clearAnthropicKey() {
        try? keychainStore.deleteSecret(account: Self.anthropicKeychainAccount)
        isAnthropicKeyStored = false
    }

    func saveOpenAIKey() {
        guard !openAIAPIKeyDraft.isEmpty else { return }
        try? keychainStore.saveSecret(openAIAPIKeyDraft, account: Self.openAIKeychainAccount)
        isOpenAIKeyStored = true
        openAIAPIKeyDraft = ""
    }

    func clearOpenAIKey() {
        try? keychainStore.deleteSecret(account: Self.openAIKeychainAccount)
        isOpenAIKeyStored = false
    }

    private func refreshGeneratedScripts() {
        guard let scriptsDirectoryURL else { generatedScripts = []; return }
        generatedScripts = GeneratedScriptsStore(directory: scriptsDirectoryURL).listScripts()
    }

    private func persistPreferences() {
        preferencesStore.save(AppPreferences(lookbackDays: lookbackDays, minOccurrences: minOccurrences, providerMode: providerMode))
    }
}
