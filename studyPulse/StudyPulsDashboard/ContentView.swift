import SwiftUI

// MARK: - Design Tokens
extension Color {
    // 앱 전체 팔레트 — 자연 / 집중 테마
    static let spGreen   = Color(hex: "#2B7A4B")   // 숲 초록 (Apple green보다 깊고 자연스러운)
    static let spGreenLt = Color(hex: "#E8F5EE")   // 연한 초록 (배경 강조)
    static let spBG      = Color(red: 0.972, green: 0.968, blue: 0.960) // 따뜻한 아이보리 #F8F7F5
    static let spCard    = Color(red: 1.0, green: 0.998, blue: 0.995)   // 따뜻한 흰색
    static let spBorder  = Color(red: 0.878, green: 0.867, blue: 0.851) // 따뜻한 테두리
    static let spInk     = Color(red: 0.118, green: 0.133, blue: 0.157) // 딥 네이비 잉크
    static let spMuted   = Color(red: 0.44, green: 0.44, blue: 0.46)    // 보조 텍스트
}

extension View {
    func spCard(padding: CGFloat = 20) -> some View {
        self.padding(padding)
            .background(Color.spCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color(hex: "#1A1A2E").opacity(0.06), radius: 6, x: 0, y: 1)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.spBorder.opacity(0.6), lineWidth: 0.5))
    }
}

// MARK: - ContentView
struct ContentView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var server: ServerManager
    @State private var selectedTab = 0
    @State private var showProfile = false

    var body: some View {
        VStack(spacing: 0) {
            SPNavBar(
                selectedTab: $selectedTab,
                user: auth.currentUser,
                onProfileTap: { showProfile = true }
            )

            ZStack {
                Color.spBG.ignoresSafeArea()
                switch selectedTab {
                case 0: MainView()
                case 1: GroupView()
                case 2: RankingView()
                case 3: AnalyticsView()
                case 4: AIView()
                default: MainView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 620)
        .preferredColorScheme(.light)          // 라이트 모드 고정
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .environmentObject(auth)
                .preferredColorScheme(.light)
                .frame(width: 680, height: 640)
        }
    }
}

// MARK: - Top Navigation Bar
struct SPNavBar: View {
    @Binding var selectedTab: Int
    let user: User?
    let onProfileTap: () -> Void

    private let tabs: [(icon: String, title: String)] = [
        ("square.grid.2x2", "대시보드"),
        ("person.2", "그룹"),
        ("chart.bar", "랭킹"),
        ("clock", "공부시간"),
        ("bubble.left.and.bubble.right", "AI"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            // ── 로고 ─────────────────────────────────────────────────────
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.spGreen)
                        .frame(width: 26, height: 26)
                    Text("🌿")
                        .font(.system(size: 13))
                }
                VStack(alignment: .leading, spacing: -3) {
                    Text("Study")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.spMuted)
                    Text("Pulse")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.spInk)
                }
            }
            .padding(.leading, 22)

            Spacer()

            // ── 탭 ───────────────────────────────────────────────────────
            HStack(spacing: 2) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { i, tab in
                    SPTabButton(icon: tab.icon, title: tab.title, isSelected: selectedTab == i) {
                        selectedTab = i
                    }
                }
            }

            Spacer()

            // ── 오른쪽 ───────────────────────────────────────────────────
            HStack(spacing: 10) {
                // 연속 접속 뱃지
                if let user, user.streakDays > 0 {
                    HStack(spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 11))
                        Text("\(user.streakDays)일")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#C05621"))
                    }
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color(hex: "#FFF3E8"), in: Capsule())
                    .overlay(Capsule().stroke(Color(hex: "#F6AD55").opacity(0.4), lineWidth: 1))
                }

                // 프로필 아바타
                Button(action: onProfileTap) {
                    ZStack {
                        Circle()
                            .fill(Color.spGreenLt)
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Color.spGreen.opacity(0.25), lineWidth: 1.5))
                        if let user {
                            Text(String(user.name.prefix(1)))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.spGreen)
                        } else {
                            Image(systemName: "person")
                                .font(.system(size: 13))
                                .foregroundColor(Color.spGreen)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("프로필")
            }
            .padding(.trailing, 22)
        }
        .frame(height: 52)
        .background(Color.spCard)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.spBorder.opacity(0.7))
                .frame(height: 1)
        }
    }
}

// MARK: - Tab Button
struct SPTabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? Color.spGreen : Color.spMuted)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                isSelected ? Color.spGreenLt : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Server Status (hidden from top bar – used by ServerManager)
struct NavigationItem: View {
    let icon: String; let title: String; let tag: Int
    var body: some View { Label(title, systemImage: icon).tag(tag) }
}

struct ServerStatusBar: View {
    @ObservedObject var server: ServerManager

    var statusColor: Color {
        switch server.status {
        case .running:  return .spGreen
        case .starting: return .orange
        case .error:    return .red
        default:        return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(statusColor).frame(width: 6, height: 6)
            Text(server.status.label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
