import Foundation

@MainActor
final class DashboardModel: ObservableObject {
    @Published var dashboard: DashboardResponse?
    @Published var focus: [FocusPoint] = []
    @Published var stress: [StressSample] = []
    @Published var drowsiness: [DrowsinessPoint] = []
    @Published var coach: CoachResponse?
    @Published var ranking: RankingResponse?
    @Published var devices: [DeviceStatus] = []
    @Published var selectedSubjectId = "subject_math"
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let client = StudyPulsAPIClient()

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await LocalServerManager.shared.ensureRunning()

            async let dashboardValue: DashboardResponse = client.get("/api/dashboard")
            async let focusValue: [FocusPoint] = client.get("/api/dashboard/focus")
            async let stressValue: [StressSample] = client.get("/api/dashboard/stress")
            async let drowsinessValue: [DrowsinessPoint] = client.get("/api/dashboard/drowsiness")
            async let coachValue: CoachResponse = client.get("/api/ai/coach")
            async let rankingValue: RankingResponse = client.get("/api/groups/ranking")
            async let deviceValue: DeviceStatusResponse = client.get("/api/devices/status")

            dashboard = try await dashboardValue
            focus = try await focusValue
            stress = try await stressValue
            drowsiness = try await drowsinessValue
            coach = try await coachValue
            ranking = try await rankingValue
            devices = try await deviceValue.devices
            selectedSubjectId = dashboard?.subjects.first?.id ?? selectedSubjectId
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startTimer() async {
        do {
            try await LocalServerManager.shared.ensureRunning()
            let _: StudySession = try await client.post("/api/study/start", body: ["subjectId": selectedSubjectId])
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func endTimer() async {
        do {
            try await LocalServerManager.shared.ensureRunning()
            let _: StudySession = try await client.post("/api/study/end", body: [:])
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connectWatchBridge() async {
        do {
            try await LocalServerManager.shared.ensureRunning()
            let response: DeviceStatusResponse = try await client.post("/api/devices/watch-bridge/connect", body: [:])
            devices = response.devices
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct StudyPulsAPIClient {
    var baseURL = URL(string: "http://127.0.0.1:3000")!

    func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appending(path: path)
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
