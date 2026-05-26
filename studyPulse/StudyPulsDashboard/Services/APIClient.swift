import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case serverError(String)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "잘못된 URL"
        case .noData:              return "데이터 없음"
        case .serverError(let msg): return msg
        case .decodingError:       return "데이터 파싱 오류"
        }
    }
}

// 서버 API 호출을 위한 싱글톤 HTTP 클라이언트
// baseURL은 ProfileView에서 런타임에 변경 가능 (Wi-Fi 환경별 IP 설정)
class APIClient {
    static let shared = APIClient()

    var baseURL = "http://localhost:3000"

    // UserDefaults에서 직접 읽어 MainActor 격리 문제 회피
    private var token: String? { UserDefaults.standard.string(forKey: "studypulse_jwt") }

    private init() {}

    private func makeRequest(_ path: String, method: String = "GET", body: [String: Any]? = nil) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        return req
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        let req = try makeRequest(path)
        let (data, response) = try await URLSession.shared.data(for: req)
        try checkResponse(response, data: data)
        return try decode(data)
    }

    func post<T: Decodable>(_ path: String, body: [String: Any] = [:]) async throws -> T {
        let req = try makeRequest(path, method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        try checkResponse(response, data: data)
        return try decode(data)
    }

    func put<T: Decodable>(_ path: String, body: [String: Any] = [:]) async throws -> T {
        let req = try makeRequest(path, method: "PUT", body: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        try checkResponse(response, data: data)
        return try decode(data)
    }

    func delete(_ path: String) async throws {
        let req = try makeRequest(path, method: "DELETE")
        let (data, response) = try await URLSession.shared.data(for: req)
        try checkResponse(response, data: data)
    }

    // 4xx/5xx 응답을 에러로 변환, 서버 JSON { "error": "..." } 메시지 추출
    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw APIError.serverError(msg ?? "서버 오류 (\(http.statusCode))")
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let raw = String(data: data.prefix(2000), encoding: .utf8) ?? "(binary)"
            let log = """
            ⚠️ [APIClient] decode 실패 (\(T.self))
               원인: \(error)
               원본 응답: \(raw)
            """
            print(log)
            // 파일에도 기록 (앱 콘솔 접근 어려울 때 확인용)
            let logPath = "/tmp/studypulse_decode_error.log"
            let entry = "[\(Date())] \(log)\n\n"
            if let existing = try? String(contentsOfFile: logPath) {
                try? (existing + entry).write(toFile: logPath, atomically: true, encoding: .utf8)
            } else {
                try? entry.write(toFile: logPath, atomically: true, encoding: .utf8)
            }
            throw APIError.decodingError
        }
    }
}
