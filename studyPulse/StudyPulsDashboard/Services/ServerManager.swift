import Foundation

// Docker Compose로 MySQL + Node.js 서버를 관리하는 싱글톤
// docker compose up -d → 준비 완료 폴링 → 상태 퍼블리시
@MainActor
class ServerManager: ObservableObject {
    static let shared = ServerManager()

    enum Status: Equatable {
        case idle
        case starting
        case running
        case error(String)
        case stopped

        static func == (lhs: Status, rhs: Status) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.starting, .starting), (.running, .running), (.stopped, .stopped):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }

        var label: String {
            switch self {
            case .idle:            return "대기 중"
            case .starting:        return "서버 시작 중..."
            case .running:         return "서버 실행 중"
            case .error(let msg):  return "오류: \(msg)"
            case .stopped:         return "서버 정지됨"
            }
        }

        var isRunning:  Bool { self == .running }
        var isStarting: Bool { self == .starting }

        var canStart: Bool {
            switch self { case .idle, .stopped, .error: return true; default: return false }
        }
    }

    @Published var status: Status = .idle
    @Published var logs: [String] = []

    // server/ 디렉토리 경로 — docker-compose.yml이 있는 위치
    var serverDirectory: String {
        get { UserDefaults.standard.string(forKey: "server_directory")
                ?? (NSHomeDirectory() + "/Downloads/studyPulse/server") }
        set { UserDefaults.standard.set(newValue, forKey: "server_directory") }
    }

    private init() {}

    // MARK: - Public API

    func startServer() async {
        guard status.canStart else { return }
        status = .starting
        logs = []

        guard let docker = findDocker() else {
            status = .error("Docker를 찾을 수 없습니다.\nDocker Desktop을 설치해주세요.")
            return
        }

        let composeFile = serverDirectory + "/docker-compose.yml"
        guard FileManager.default.fileExists(atPath: composeFile) else {
            status = .error("docker-compose.yml을 찾을 수 없습니다:\n\(serverDirectory)")
            return
        }

        appendLog("docker compose up -d 실행 중...")
        appendLog("서버 디렉토리: \(serverDirectory)")

        let ok = await runCompose(docker: docker, args: ["compose", "up", "-d", "--build"])
        guard ok else {
            status = .error("docker compose up 실패. 로그를 확인해주세요.")
            return
        }

        // 컨테이너가 실제로 응답할 때까지 폴링 (최대 60초)
        appendLog("서버 준비 대기 중...")
        let port = readPortFromEnv() ?? 3000
        let ready = await waitUntilReady(url: "http://localhost:\(port)/health", timeout: 60)
        status = ready ? .running : .error("서버가 시간 내에 응답하지 않습니다.\n로그를 확인해주세요.")
    }

    func stopServer() {
        guard let docker = findDocker() else { status = .stopped; return }
        Task {
            await runCompose(docker: docker, args: ["compose", "stop"])
            status = .stopped
        }
    }

    func restartServer() async {
        guard let docker = findDocker() else { return }
        status = .starting
        appendLog("서버 재시작 중...")
        await runCompose(docker: docker, args: ["compose", "restart"])
        let port = readPortFromEnv() ?? 3000
        let ready = await waitUntilReady(url: "http://localhost:\(port)/health", timeout: 60)
        status = ready ? .running : .error("재시작 후 응답 없음")
    }

    // MARK: - Docker 탐색

    private func findDocker() -> String? {
        let candidates = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker",
            // Docker Desktop (Apple Silicon)
            "/Applications/Docker.app/Contents/Resources/bin/docker",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }
        // which docker 폴백
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["docker"]
        let pipe = Pipe()
        which.standardOutput = pipe
        try? which.run()
        which.waitUntilExit()
        let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (result?.isEmpty == false) ? result : nil
    }

    // MARK: - Compose 실행

    @discardableResult
    private func runCompose(docker: String, args: [String]) async -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: docker)
        p.arguments = args
        p.currentDirectoryURL = URL(fileURLWithPath: serverDirectory)
        p.environment = buildEnvironment()

        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in self?.appendLog(text) }
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in self?.appendLog("[stderr] " + text) }
        }

        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            await MainActor.run { appendLog("실행 오류: \(error.localizedDescription)") }
            return false
        }
    }

    // MARK: - 준비 완료 폴링

    // health 엔드포인트가 200을 반환할 때까지 2초 간격으로 재시도
    private func waitUntilReady(url: String, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await pingHealth(url: url) { return true }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        return false
    }

    private func pingHealth(url: String) async -> Bool {
        guard let url = URL(string: url) else { return false }
        var req = URLRequest(url: url, timeoutInterval: 3)
        req.httpMethod = "GET"
        return (try? await URLSession.shared.data(for: req)) != nil
    }

    // MARK: - 유틸

    private func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        return env
    }

    // .env에서 PORT 읽기 (없으면 nil → 기본값 3000 사용)
    private func readPortFromEnv() -> Int? {
        let envPath = serverDirectory + "/.env"
        guard let contents = try? String(contentsOfFile: envPath, encoding: .utf8) else { return nil }
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("PORT=") else { continue }
            return Int(trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    private func appendLog(_ text: String) {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        logs.append(contentsOf: lines)
        if logs.count > 200 { logs.removeFirst(logs.count - 200) }
    }
}
