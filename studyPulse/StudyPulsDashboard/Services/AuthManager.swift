import Foundation
import AppKit

// Google OAuth 인증 흐름 및 JWT 토큰 관리
// 로그인 플로우: 로컬 HTTP 서버 → 브라우저에서 Google 로그인 → 127.0.0.1 콜백 → id_token → 서버 JWT
// 데스크톱 앱 OAuth 표준 방식 (RFC 8252) — http://127.0.0.1:{랜덤포트} 리디렉션은 등록 불필요
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isLoggedIn = false
    @Published var loginError: String?

    private let tokenKey = "studypulse_jwt"

    var token: String? { UserDefaults.standard.string(forKey: tokenKey) }

    private init() {
        if let token, !token.isEmpty {
            Task { await loadCurrentUser() }
        }
    }

    // MARK: - Google OAuth
    func loginWithGoogle() async {
        loginError = nil

        let clientId = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String ?? ""
        guard !clientId.isEmpty else {
            loginError = "Google Client ID가 설정되지 않았습니다."
            return
        }

        // 랜덤 포트로 로컬 서버 (데스크톱 앱 OAuth 표준 — http://127.0.0.1 등록 불필요)
        let port = UInt16.random(in: 52000...62000)
        let redirectURI = "http://127.0.0.1:\(port)"

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id",     value: clientId),
            .init(name: "redirect_uri",  value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope",         value: "openid email profile"),
            .init(name: "access_type",   value: "offline"),
            .init(name: "prompt",        value: "select_account"),
        ]

        guard let authURL = comps.url else { return }

        do {
            // 기본 브라우저에서 Google 로그인 창 열기
            NSWorkspace.shared.open(authURL)

            // 로컬 서버에서 OAuth 콜백 대기 (최대 120초)
            let code = try await listenForCallback(port: port, timeout: 120)

            // authorization code → id_token 교환
            let idToken = try await exchangeCodeForIdToken(
                code: code, clientId: clientId, redirectURI: redirectURI
            )

            // id_token → 서버 JWT 발급
            let response: AuthResponse = try await APIClient.shared.post(
                "/api/auth/google", body: ["idToken": idToken]
            )
            UserDefaults.standard.set(response.token, forKey: tokenKey)
            currentUser = response.user
            isLoggedIn = true

        } catch {
            loginError = "Google 로그인 실패: \(error.localizedDescription)"
        }
    }

    // MARK: - 로컬 HTTP 서버 (POSIX 소켓)
    // Google이 http://127.0.0.1:{port}/?code=xxx 로 리디렉션하면 코드 추출
    private func listenForCallback(port: UInt16, timeout: TimeInterval) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let sfd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
                guard sfd >= 0 else {
                    cont.resume(throwing: APIError.serverError("소켓 생성 실패")); return
                }

                var yes: Int32 = 1
                setsockopt(sfd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))

                // 타임아웃
                var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
                setsockopt(sfd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout.size(ofValue: tv)))

                var addr = sockaddr_in()
                addr.sin_len    = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port   = port.bigEndian
                addr.sin_addr   = in_addr(s_addr: INADDR_ANY)

                let bound = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.bind(sfd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                guard bound == 0 else {
                    close(sfd)
                    cont.resume(throwing: APIError.serverError("포트 바인딩 실패 (\(port))")); return
                }

                Darwin.listen(sfd, 1)
                let cfd = Darwin.accept(sfd, nil, nil)
                guard cfd >= 0 else {
                    close(sfd)
                    cont.resume(throwing: APIError.serverError("로그인 시간 초과 (120초)")); return
                }

                var buf = [UInt8](repeating: 0, count: 8192)
                let n = Darwin.recv(cfd, &buf, buf.count - 1, 0)
                let req = n > 0 ? String(bytes: buf.prefix(n), encoding: .utf8) ?? "" : ""

                // "GET /?code=xxx&... HTTP/1.1" 에서 code 파싱
                let path = req.components(separatedBy: " ").dropFirst().first ?? "/"
                let params = URLComponents(string: "http://x" + path)?.queryItems

                let code  = params?.first(where: { $0.name == "code"  })?.value
                let error = params?.first(where: { $0.name == "error" })?.value

                // 브라우저에 완료 화면 표시
                let isSuccess = code != nil
                let html = """
                    <!DOCTYPE html><html><head><meta charset="UTF-8">
                    <style>*{margin:0;padding:0;box-sizing:border-box}
                    body{font-family:-apple-system,sans-serif;display:flex;align-items:center;
                    justify-content:center;min-height:100vh;background:#0d0d0f;color:#f0f0f3}
                    .card{text-align:center;padding:48px 64px;border-radius:20px;
                    background:#1a1a1f;border:1px solid rgba(255,255,255,.08)}
                    .icon{font-size:64px;margin-bottom:16px}
                    h2{font-size:22px;font-weight:700;margin-bottom:8px}
                    p{color:#8e8e99;font-size:14px}</style></head>
                    <body><div class="card">
                    <div class="icon">\(isSuccess ? "✅" : "❌")</div>
                    <h2>\(isSuccess ? "로그인 완료!" : "로그인 취소됨")</h2>
                    <p>\(isSuccess ? "StudyPulse 앱으로 돌아가세요" : (error ?? "알 수 없는 오류"))</p>
                    </div></body></html>
                    """
                let resp = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n\(html)"
                send(cfd, resp, resp.utf8.count, 0)
                close(cfd)
                close(sfd)

                if let code {
                    cont.resume(returning: code)
                } else {
                    cont.resume(throwing: APIError.serverError(error == "access_denied" ? "로그인이 취소되었습니다" : "인증 코드 없음"))
                }
            }
        }
    }

    // MARK: - Authorization Code → ID Token 교환
    private func exchangeCodeForIdToken(code: String, clientId: String, redirectURI: String) async throws -> String {
        let clientSecret = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_SECRET") as? String ?? ""
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = [
            "code=\(code)",
            "client_id=\(clientId)",
            "client_secret=\(clientSecret)",
            "redirect_uri=\(redirectURI)",
            "grant_type=authorization_code",
        ].joined(separator: "&").data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.serverError("토큰 응답 파싱 실패")
        }
        if let desc = json["error_description"] as? String {
            throw APIError.serverError("Google: \(desc)")
        }
        guard let idToken = json["id_token"] as? String else {
            throw APIError.serverError("id_token 없음")
        }
        return idToken
    }

    // MARK: - 사용자 정보 로드 / 로그아웃
    func loadCurrentUser() async {
        guard token != nil else { return }
        do {
            let user: User = try await APIClient.shared.get("/api/auth/me")
            currentUser = user
            isLoggedIn = true
        } catch {
            logout()
        }
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        currentUser = nil
        isLoggedIn = false
    }
}
