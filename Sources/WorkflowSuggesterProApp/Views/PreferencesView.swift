import SwiftUI

struct PreferencesView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        Form {
            Section("Activity Scan") {
                Stepper("Lookback: \(appModel.lookbackDays) day(s)", value: $appModel.lookbackDays, in: 1...60)
                Stepper("Minimum occurrences: \(appModel.minOccurrences)", value: $appModel.minOccurrences, in: 2...20)
            }

            Section("Suggestion Provider") {
                Picker("Provider", selection: $appModel.providerMode) {
                    ForEach(AppModel.ProviderMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Text("Automatic tries the on-device model first and falls back to cloud only if it's unavailable. Forcing a cloud provider always skips on-device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Cloud API Keys") {
                apiKeyRow(
                    label: "Anthropic",
                    draft: $appModel.anthropicAPIKeyDraft,
                    isStored: appModel.isAnthropicKeyStored,
                    onSave: appModel.saveAnthropicKey,
                    onClear: appModel.clearAnthropicKey
                )
                apiKeyRow(
                    label: "OpenAI",
                    draft: $appModel.openAIAPIKeyDraft,
                    isStored: appModel.isOpenAIKeyStored,
                    onSave: appModel.saveOpenAIKey,
                    onClear: appModel.clearOpenAIKey
                )
                Text("Keys are stored in the macOS Keychain, not as environment variables — required because apps launched from the Dock don't inherit a Terminal session's exported variables.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 420)
    }

    private func apiKeyRow(
        label: String,
        draft: Binding<String>,
        isStored: Bool,
        onSave: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack {
            SecureField(isStored ? "\(label) key stored" : "\(label) API key", text: draft)
            if isStored {
                Button("Clear", role: .destructive, action: onClear)
            } else {
                Button("Save", action: onSave)
                    .disabled(draft.wrappedValue.isEmpty)
            }
        }
    }
}
