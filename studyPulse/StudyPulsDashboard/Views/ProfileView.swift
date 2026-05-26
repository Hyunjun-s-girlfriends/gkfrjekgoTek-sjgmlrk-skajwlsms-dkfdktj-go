import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @ObservedObject private var server = ServerManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var editMode = false
    @State private var editName = ""
    @State private var editDescription = ""
    @State private var editOrganization = ""
    @State private var serverURL = UserDefaults.standard.string(forKey: "server_url") ?? "http://localhost:3000"
    @State private var serverDirectory = ServerManager.shared.serverDirectory
    @State private var showServerLogs = false

    var user: User? { auth.currentUser }

    var plantEmoji: String {
        let level = user?.level ?? 1
        if level < 3  { return "🌱" }
        if level < 7  { return "🌿" }
        if level < 15 { return "🌳" }
        return "🌲"
    }

    var serverStatusColor: Color {
        switch server.status {
        case .running:  return .spGreen
        case .starting: return .orange
        case .error:    return .red
        default:        return .secondary
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Sheet header ───────────────────────────────────────────────
            HStack {
                Text("프로필")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                if editMode {
                    Button("완료") { Task { await saveProfile(); editMode = false } }
                        .buttonStyle(.borderedProminent)
                        .tint(.spGreen)
                        .controlSize(.small)
                    Button("취소") {
                        editMode = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("편집") {
                        editName         = user?.name ?? ""
                        editDescription  = user?.description ?? ""
                        editOrganization = user?.organization ?? ""
                        editMode = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // ── Profile card ───────────────────────────────────────
                    VStack(spacing: 16) {
                        // Avatar + plant
                        ZStack(alignment: .bottomTrailing) {
                            ZStack {
                                Circle()
                                    .fill(Color.spGreen)
                                    .frame(width: 80, height: 80)
                                Text(user.map { String($0.name.prefix(1)) } ?? "?")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text(plantEmoji)
                                .font(.system(size: 22))
                                .offset(x: 4, y: 4)
                        }

                        if editMode {
                            VStack(spacing: 8) {
                                TextField("이름", text: $editName)
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.center)
                                TextField("소개", text: $editDescription, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(2...3)
                                TextField("소속", text: $editOrganization)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .frame(maxWidth: 280)
                        } else {
                            Text(user?.name ?? "이름 없음")
                                .font(.system(size: 20, weight: .bold))
                            if let desc = user?.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            if let org = user?.organization, !org.isEmpty {
                                Label(org, systemImage: "building.2")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .spCard()

                    // ── Stats row ──────────────────────────────────────────
                    HStack(spacing: 12) {
                        ProfileStatCard(icon: "star.fill",    color: Color(hex: "#FFD700"),
                                        title: "레벨",         value: "Lv.\(user?.level ?? 1)")
                        ProfileStatCard(icon: "bolt.fill",    color: .spGreen,
                                        title: "PX",           value: "\(user?.px ?? 0)")
                        ProfileStatCard(icon: "flame.fill",   color: .orange,
                                        title: "연속 접속",    value: "\(user?.streakDays ?? 0)일")
                        ProfileStatCard(icon: "trophy.fill",  color: Color(hex: "#AF52DE"),
                                        title: "최장 기록",    value: "\(user?.maxStreakDays ?? 0)일")
                    }

                    // ── PX Progress ────────────────────────────────────────
                    if let user {
                        let pxInLevel = user.px % 1000
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("다음 레벨까지")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Text("\(pxInLevel)/1000 PX")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.spGreen.opacity(0.15))
                                .frame(height: 10)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.spGreen)
                                        .scaleEffect(
                                            x: max(Double(pxInLevel) / 1000.0, 0.001),
                                            y: 1.0,
                                            anchor: .leading
                                        )
                                }
                        }
                        .spCard()
                    }

                    // ── Server settings ────────────────────────────────────
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(serverStatusColor)
                                .frame(width: 8, height: 8)
                            Text("서버 설정")
                                .font(.system(size: 15, weight: .semibold))
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(server.status.label)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Spacer()
                            if server.status.isRunning {
                                Button("정지") { server.stopServer() }
                                    .buttonStyle(.bordered)
                                    .foregroundColor(.red)
                                    .controlSize(.small)
                            } else {
                                Button("시작") { Task { await server.startServer() } }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.spGreen)
                                    .controlSize(.small)
                                    .disabled(server.status.isStarting)
                            }
                            Button("재시작") { Task { await server.restartServer() } }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(server.status.isStarting)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("서버 디렉토리").font(.caption).foregroundColor(.secondary)
                            HStack {
                                TextField("서버 경로", text: $serverDirectory)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.caption, design: .monospaced))
                                Button("저장") { server.serverDirectory = serverDirectory }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("접속 URL (iPhone/외부 기기용)").font(.caption).foregroundColor(.secondary)
                            HStack {
                                TextField("http://192.168.x.x:3000", text: $serverURL)
                                    .textFieldStyle(.roundedBorder)
                                Button("적용") {
                                    UserDefaults.standard.set(serverURL, forKey: "server_url")
                                    APIClient.shared.baseURL = serverURL
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.spGreen)
                                .controlSize(.small)
                            }
                            Text("같은 Wi-Fi 연결 시 맥북 IP 입력")
                                .font(.caption2).foregroundColor(.secondary)
                        }

                        DisclosureGroup("서버 로그 (\(server.logs.count)줄)", isExpanded: $showServerLogs) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(server.logs.suffix(50), id: \.self) { line in
                                        Text(line)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(line.contains("[stderr]") ? .red : .primary)
                                            .textSelection(.enabled)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                            }
                            .frame(height: 160)
                            .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .font(.system(size: 13))
                    }
                    .spCard()

                    // ── Logout ─────────────────────────────────────────────
                    Button {
                        auth.logout()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("로그아웃")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Color.spBG)
        }
        .onAppear {
            if let url = UserDefaults.standard.string(forKey: "server_url") {
                APIClient.shared.baseURL = url
            }
        }
    }

    func saveProfile() async {
        do {
            let _: User = try await APIClient.shared.put(
                "/api/auth/me",
                body: ["name": editName, "description": editDescription, "organization": editOrganization]
            )
            await auth.loadCurrentUser()
        } catch {
            await auth.loadCurrentUser()
        }
    }
}

// MARK: - Profile Stat Card
struct ProfileStatCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.spInk)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Color.spMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.spCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.spBorder, lineWidth: 0.5))
    }
}

// Legacy StatCard kept for compile compatibility
struct StatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View { ProfileStatCard(icon: icon, color: color, title: title, value: value) }
}
