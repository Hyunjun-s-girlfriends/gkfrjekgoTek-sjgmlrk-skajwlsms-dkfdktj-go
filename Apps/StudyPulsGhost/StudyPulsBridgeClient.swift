import Foundation

struct HealthPayload: Encodable {
    let heartRate: Int
    let hrv: Int
    let timestamp: String
}

struct StudyPulsBridgeClient {
    func send(payload: HealthPayload, serverURL: URL) async throws {
        var request = URLRequest(url: serverURL.appending(path: "/api/health/hrv-bridge"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
