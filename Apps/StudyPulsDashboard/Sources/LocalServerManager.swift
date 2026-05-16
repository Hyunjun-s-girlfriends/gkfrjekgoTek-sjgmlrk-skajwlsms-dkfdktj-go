import Foundation

@MainActor
final class LocalServerManager {
    static let shared = LocalServerManager()

    private var process: Process?
    private var hasTriedLaunch = false

    func ensureRunning() async throws {
        if await isServerHealthy() {
            return
        }

        if !hasTriedLaunch {
            try launchServer()
            hasTriedLaunch = true
        }

        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 250_000_000)
            if await isServerHealthy() {
                return
            }
        }

        throw LocalServerError.serverDidNotStart
    }

    private func isServerHealthy() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:3000/api/dashboard") else {
            return false
        }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                return false
            }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }

    private func launchServer() throws {
        let workspaceURL = try inferWorkspaceURL()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", "src/server.js"]
        process.currentDirectoryURL = workspaceURL

        let logURL = workspaceURL.appending(path: "data/native-server.log")
        try FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: logURL)
        process.standardOutput = logHandle
        process.standardError = logHandle

        try process.run()
        self.process = process
    }

    private func inferWorkspaceURL() throws -> URL {
        if let env = ProcessInfo.processInfo.environment["STUDYPULS_HOME"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }

        let executable = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        let appBundle = executable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workspace = appBundle
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        if FileManager.default.fileExists(atPath: workspace.appending(path: "src/server.js").path) {
            return workspace
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if FileManager.default.fileExists(atPath: cwd.appending(path: "src/server.js").path) {
            return cwd
        }

        throw LocalServerError.workspaceNotFound
    }
}

enum LocalServerError: LocalizedError {
    case workspaceNotFound
    case serverDidNotStart

    var errorDescription: String? {
        switch self {
        case .workspaceNotFound:
            return "StudyPuls 서버 파일을 찾지 못했습니다."
        case .serverDidNotStart:
            return "StudyPuls 로컬 서버를 시작하지 못했습니다."
        }
    }
}
