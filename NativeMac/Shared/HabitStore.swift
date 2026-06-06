import Foundation

final class HabitStore {
    static let shared = HabitStore()

    static let fileName = "app-state.json"
    static let uiTestFileName = "app-state-uitest.json"
    static let appDirectoryName = "KiteNative"
    static let uiTestDirectoryName = "KiteNativeUITests"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> AppState {
        if Self.shouldResetUITestState {
            save(.default)
            return .default
        }
        guard let url = storageURL(),
              let data = try? Data(contentsOf: url),
              let state = try? decoder.decode(AppState.self, from: data)
        else {
            return .default
        }
        return state
    }

    func save(_ state: AppState) {
        guard let url = storageURL() else { return }
        do {
            let data = try encoder.encode(state)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save app state: \(error)")
        }
    }

    private func storageURL() -> URL? {
        let isUITest = Self.usesUITestState
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first

        return appSupport?
            .appendingPathComponent(
                isUITest ? Self.uiTestDirectoryName : Self.appDirectoryName,
                isDirectory: true
            )
            .appendingPathComponent(isUITest ? Self.uiTestFileName : Self.fileName)
    }

    private static var shouldResetUITestState: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest-reset-state")
    }

    private static var usesUITestState: Bool {
        shouldResetUITestState || ProcessInfo.processInfo.arguments.contains("--uitest-use-state")
    }
}
