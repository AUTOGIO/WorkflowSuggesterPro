import AppKit
import Foundation
import Observation
import WorkflowSuggesterCore

@MainActor
@Observable
final class AppModel {
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
    private var generationTask: Task<Void, Never>?

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

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        lastStatusMessage = "Generation cancelled."
    }

    func regenerate() {
        guard !isGenerating else { return }
        isGenerating = true
        lastErrorMessage = nil
        lastStatusMessage = "Scanning ActivityWatch history…"

        let providerMode = self.providerMode
        let anthropicKey = try? keychainStore.loadSecret(account: Self.anthropicKeychainAccount)
        let openAIKey = try? keychainStore.loadSecret(account: Self.openAIKeychainAccount)

        var env: [String: String] = [:]
        if let anthropicKey { env["ANTHROPIC_API_KEY"] = anthropicKey }
        if let openAIKey { env["OPENAI_API_KEY"] = openAIKey }

        let forceCloud: Bool
        switch providerMode {
        case .forceAnthropic:
            env["WORKFLOWSUGGESTER_PROVIDER"] = "anthropic"
            forceCloud = true
        case .forceOpenAI:
            env["WORKFLOWSUGGESTER_PROVIDER"] = "openai"
            forceCloud = true
        case .onDeviceFirst:
            forceCloud = false
        }

        let config = WorkflowPipelineConfig(
            lookbackDays: self.lookbackDays,
            minOccurrences: self.minOccurrences,
            maxWorkflowsInPrompt: Self.maxWorkflowsInPrompt,
            forceCloud: forceCloud,
            environment: env
        )

        generationTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let result = try await WorkflowPipeline().run(config: config) { status in
                    await MainActor.run { self.lastStatusMessage = status }
                }

                await MainActor.run {
                    self.recurringWorkflows = result.recurringWorkflows
                    if result.recurringWorkflows.isEmpty {
                        self.lastStatusMessage = "No recurring workflows found in the last \(config.lookbackDays) days."
                    } else {
                        self.suggestions = result.suggestions
                        self.lastGenerationSource = result.source
                        self.lastGeneratedAt = Date()
                        self.lastStatusMessage = "Wrote \(result.writtenScriptURLs.count) automation script(s)."
                        self.refreshGeneratedScripts()
                    }
                    self.isGenerating = false
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
