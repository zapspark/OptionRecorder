import Foundation
import SwiftData
import SwiftUI
import WheelStrategyCore

@main
struct OptionRecoderApp: App {
    private static let modelContainer: ModelContainer = {
        do {
            let schema = Schema([Position.self, OptionTrade.self])
            let storeURL = try sqliteStoreURL()
            let configuration = ModelConfiguration(
                "OptionRecorderStore",
                schema: schema,
                url: storeURL
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData container: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(Self.modelContainer)
    }

    private static func sqliteStoreURL() throws -> URL {
        if let overridePath = ProcessInfo.processInfo.environment["OPTIONRECORDER_STORE_URL"],
           !overridePath.isEmpty {
            let overrideURL = URL(filePath: overridePath)
            try FileManager.default.createDirectory(
                at: overrideURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            return overrideURL
        }

        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        let appDirectory = baseURL.appending(
            path: "OptionRecorder",
            directoryHint: .isDirectory
        )

        try FileManager.default.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true
        )

        let storeURL = appDirectory.appending(
            path: "OptionRecorder.sqlite",
            directoryHint: .notDirectory
        )

        let legacyStoreURL = appDirectory.appending(
            path: "WheelStrategy.sqlite",
            directoryHint: .notDirectory
        )

        if !FileManager.default.fileExists(atPath: storeURL.path()),
           FileManager.default.fileExists(atPath: legacyStoreURL.path()) {
            try copySQLiteStore(from: legacyStoreURL, to: storeURL)
        }

        return storeURL
    }

    private static func copySQLiteStore(from legacyStoreURL: URL, to storeURL: URL) throws {
        try FileManager.default.copyItem(at: legacyStoreURL, to: storeURL)

        for suffix in ["-wal", "-shm"] {
            let legacySidecarURL = URL(filePath: legacyStoreURL.path() + suffix)
            let sidecarURL = URL(filePath: storeURL.path() + suffix)

            if FileManager.default.fileExists(atPath: legacySidecarURL.path()) {
                try FileManager.default.copyItem(at: legacySidecarURL, to: sidecarURL)
            }
        }
    }
}
