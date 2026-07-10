import Foundation

struct GeneratedScriptsStore {
    let directory: URL

    func listScripts() -> [GeneratedScriptSummary] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls
            .filter { $0.pathExtension == "sh" }
            .map { url in
                let title = Self.title(fromScriptAt: url) ?? url.deletingPathExtension().lastPathComponent
                let createdAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return GeneratedScriptSummary(url: url, title: title, createdAt: createdAt)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// AutomationScriptWriter always writes "#!/bin/sh" as line 1 and "# <title>" as line 2
    /// — parse that rather than the slugified filename, which is lossy.
    private static func title(fromScriptAt url: URL) -> String? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count > 1, lines[1].hasPrefix("# ") else { return nil }
        return String(lines[1].dropFirst(2))
    }
}
