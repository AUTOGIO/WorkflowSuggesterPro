import SwiftUI
import WorkflowSuggesterCore

struct DashboardView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statusSection
                recurringWorkflowsSection
                suggestionsSection
                actionsSection
                generatedScriptsSection
            }
            .padding(20)
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("WorkflowSuggester Pro")
                .font(.largeTitle.bold())
            Text("Recurring workflows detected from ActivityWatch, with automation suggestions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusSection: some View {
        GroupBox("Status") {
            VStack(alignment: .leading, spacing: 8) {
                Text(appModel.lastStatusMessage)
                    .font(.body)

                if let source = appModel.lastGenerationSource, let generatedAt = appModel.lastGeneratedAt {
                    HStack(spacing: 8) {
                        sourceBadge(source)
                        Text(generatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = appModel.lastErrorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }

    private func sourceBadge(_ source: GenerationSource) -> some View {
        let displayName: String = switch source {
        case .onDevice: "On-device"
        case .cloud(let provider): "Cloud (\(provider))"
        }
        return Text(displayName)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }

    private var recurringWorkflowsSection: some View {
        GroupBox("Recurring Workflows (\(appModel.recurringWorkflows.count))") {
            if appModel.recurringWorkflows.isEmpty {
                Text("No data yet — click Regenerate below.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(appModel.recurringWorkflows, id: \.self) { workflow in
                        HStack {
                            Text(workflow.app)
                                .fontWeight(.medium)
                            Text("— \"\(workflow.title)\"")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(workflow.occurrences)x")
                                .font(.caption.monospacedDigit())
                            Text("~\(Int(workflow.totalDuration / 60))min")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(4)
            }
        }
    }

    private var suggestionsSection: some View {
        GroupBox("Suggestions (\(appModel.suggestions.count))") {
            if appModel.suggestions.isEmpty {
                Text("No suggestions generated yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(appModel.suggestions, id: \.self) { suggestion in
                        suggestionCard(suggestion)
                    }
                }
                .padding(4)
            }
        }
    }

    private func suggestionCard(_ suggestion: SuggestionResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(suggestion.title)
                    .font(.headline)
                Spacer()
                savingsBadge(suggestion.savings)
            }
            Text(suggestion.rationale)
                .font(.body)
                .foregroundStyle(.secondary)
            DisclosureGroup("Implementation") {
                Text(suggestion.implementation)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func savingsBadge(_ savings: String) -> some View {
        let color: Color = switch savings.lowercased() {
        case "high": .green
        case "low": .gray
        default: .orange
        }
        return Text(savings)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var actionsSection: some View {
        GroupBox("Actions") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Button(appModel.isGenerating ? "Generating…" : "Regenerate") {
                        appModel.regenerate()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appModel.isGenerating)

                    if appModel.isGenerating {
                        Button("Cancel", role: .destructive) {
                            appModel.cancelGeneration()
                        }
                    }
                }

                if appModel.isGenerating {
                    ProgressView("Generating… this can take 30–90 seconds for on-device generation.")
                        .progressViewStyle(.linear)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }

    private var generatedScriptsSection: some View {
        GroupBox("Generated Automation Scripts (\(appModel.generatedScripts.count))") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Scripts are for manual review — WorkflowSuggester Pro never executes them for you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if appModel.generatedScripts.isEmpty {
                    Text("None yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.generatedScripts) { script in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(script.title)
                                    .fontWeight(.medium)
                                Text(script.createdAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Reveal in Finder") {
                                appModel.reveal(script)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }
}
