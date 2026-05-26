import SwiftUI

@main
struct StudyPulsDashboardApp: App {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var server = ServerManager.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                if auth.isLoggedIn {
                    ContentView()
                        .environmentObject(auth)
                        .environmentObject(server)
                } else {
                    LoginView()
                        .environmentObject(auth)
                }

                // 서버 시작 중일 때 오버레이
                if server.status == .starting {
                    ServerStartingOverlay()
                }
            }
            .task {
                // 앱 시작 시 서버 자동 실행
                await server.startServer()
            }
            .onChange(of: server.status) { status in
                // 서버가 실행되면 저장된 URL 적용
                if status == .running {
                    if let url = UserDefaults.standard.string(forKey: "server_url") {
                        APIClient.shared.baseURL = url
                    }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("서버 재시작") {
                    Task { await server.restartServer() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(server.status == .starting)
            }
        }
    }
}

// 서버 시작 대기 화면
struct ServerStartingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("서버 시작 중...")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Node.js 서버를 초기화하고 있습니다")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}
