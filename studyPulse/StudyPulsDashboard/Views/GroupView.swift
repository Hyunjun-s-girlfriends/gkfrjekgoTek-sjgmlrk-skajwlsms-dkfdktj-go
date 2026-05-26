import SwiftUI

// MARK: - ViewModel (logic unchanged)
@MainActor
class GroupViewModel: ObservableObject {
    @Published var myGroups: [StudyGroup] = []
    @Published var selectedGroup: StudyGroup?
    @Published var members: [GroupMember] = []
    @Published var messages: [GroupMessage] = []
    @Published var recommended: [StudyGroup] = []
    @Published var searchResults: [StudyGroup] = []
    @Published var searchQuery = ""
    @Published var newMessage = ""
    @Published var showCreateGroup = false
    @Published var showJoinByCode = false
    @Published var inviteCodeInput = ""
    @Published var errorMessage: String?

    private var messageTimer: Timer?

    func load() async {
        do {
            myGroups = try await APIClient.shared.get("/api/groups/my")
            recommended = try await APIClient.shared.get("/api/groups/recommended")
            if let first = myGroups.first, selectedGroup == nil {
                await selectGroup(first)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func selectGroup(_ group: StudyGroup) async {
        selectedGroup = group
        await loadGroupDetail(group.id)
        startPollingMessages(groupId: group.id)
    }

    func loadGroupDetail(_ id: Int) async {
        async let m: [GroupMember] = APIClient.shared.get("/api/groups/\(id)/members")
        async let msgs: [GroupMessage] = APIClient.shared.get("/api/groups/\(id)/messages")
        do {
            members  = try await m
            messages = try await msgs
        } catch { errorMessage = error.localizedDescription }
    }

    func sendMessage() async {
        guard let group = selectedGroup, !newMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let text = newMessage; newMessage = ""
        do {
            let msg: GroupMessage = try await APIClient.shared.post(
                "/api/groups/\(group.id)/messages", body: ["message": text]
            )
            messages.append(msg)
        } catch { errorMessage = error.localizedDescription }
    }

    func joinGroup(id: Int) async {
        struct JoinResult: Codable { let success: Bool }
        do { let _: JoinResult = try await APIClient.shared.post("/api/groups/\(id)/join"); await load() }
        catch { errorMessage = error.localizedDescription }
    }

    func joinByCode() async {
        struct JoinResult: Codable { let success: Bool; let group: StudyGroup }
        do {
            let result: JoinResult = try await APIClient.shared.post("/api/groups/join", body: ["inviteCode": inviteCodeInput])
            myGroups.append(result.group)
            inviteCodeInput = ""; showJoinByCode = false
        } catch { errorMessage = error.localizedDescription }
    }

    func leaveGroup(_ id: Int) async {
        do {
            try await APIClient.shared.delete("/api/groups/\(id)/leave")
            myGroups.removeAll { $0.id == id }
            if selectedGroup?.id == id { selectedGroup = nil }
        } catch { errorMessage = error.localizedDescription }
    }

    func search() async {
        guard !searchQuery.isEmpty else { searchResults = []; return }
        do {
            searchResults = try await APIClient.shared.get(
                "/api/groups/search?q=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            )
        } catch {}
    }

    func createGroup(name: String, description: String, icon: String,
                     color: String, maxMembers: Int, isPublic: Bool) async {
        struct GroupResult: Codable { let id: Int; let name: String }
        do {
            let _: GroupResult = try await APIClient.shared.post("/api/groups", body: [
                "name": name, "description": description, "icon": icon,
                "color": color, "maxMembers": maxMembers, "isPublic": isPublic,
            ] as [String: Any])
            await load()
            showCreateGroup = false
        } catch { errorMessage = error.localizedDescription }
    }

    private func startPollingMessages(groupId: Int) {
        messageTimer?.invalidate()
        messageTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.selectedGroup?.id == groupId else { return }
                let msgs: [GroupMessage]? = try? await APIClient.shared.get("/api/groups/\(groupId)/messages")
                if let msgs { self.messages = msgs }
            }
        }
    }
}

// MARK: - GroupView (top-level router)
struct GroupView: View {
    @StateObject private var vm = GroupViewModel()

    var body: some View {
        Group {
            if vm.showCreateGroup {
                CreateGroupView(vm: vm)
                    .transition(.opacity)
            } else if vm.myGroups.isEmpty {
                GroupSearchView(vm: vm)
            } else {
                GroupLeaderboardView(vm: vm)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showCreateGroup)
        .task { await vm.load() }
        .overlay(alignment: .bottom) {
            if let msg = vm.errorMessage {
                Text(msg)
                    .font(.subheadline)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 20)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            vm.errorMessage = nil
                        }
                    }
            }
        }
        .sheet(isPresented: $vm.showJoinByCode) { JoinByCodeSheet(vm: vm) }
    }
}

// MARK: - Group Leaderboard View
struct GroupLeaderboardView: View {
    @ObservedObject var vm: GroupViewModel
    @EnvironmentObject var auth: AuthManager
    @State private var rightTab = 0   // 0=정보, 1=채팅

    var rankedMembers: [GroupMember] {
        vm.members.sorted { $0.todayStudySeconds > $1.todayStudySeconds }
    }

    var studyingCount: Int {
        vm.members.filter { $0.todayStudySeconds > 0 }.count
    }

    var body: some View {
        HStack(spacing: 0) {
            // ── Left: Leaderboard ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                // Group selector
                HStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.myGroups) { group in
                                Button { Task { await vm.selectGroup(group) } } label: {
                                    Text(group.name)
                                        .font(.system(size: 13, weight: vm.selectedGroup?.id == group.id ? .semibold : .regular))
                                        .foregroundColor(vm.selectedGroup?.id == group.id ? .white : .primary)
                                        .padding(.horizontal, 14).padding(.vertical, 7)
                                        .background(
                                            vm.selectedGroup?.id == group.id ? Color.spGreen : Color.spBG,
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 14)
                    }
                    Button { vm.showCreateGroup = true } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                            .padding(.trailing, 20)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("순위표")
                            .font(.system(size: 20, weight: .bold))
                        if let g = vm.selectedGroup {
                            Text(g.name).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if studyingCount > 0 {
                        Text("\(studyingCount)명 공부중")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.spGreen)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.spGreen.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)

                // Rankings
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(rankedMembers.enumerated()), id: \.element.id) { i, member in
                            LeaderboardRow(
                                rank: i + 1,
                                member: member,
                                isMe: member.id == auth.currentUser?.id
                            )
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.spCard)

            Divider()

            // ── Right: Info / Chat Panel ───────────────────────────────────
            VStack(spacing: 0) {
                // Tab strip
                HStack(spacing: 0) {
                    ForEach([("정보", 0), ("채팅", 1)], id: \.1) { title, idx in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { rightTab = idx }
                        } label: {
                            VStack(spacing: 6) {
                                Text(title)
                                    .font(.system(size: 13, weight: rightTab == idx ? .semibold : .regular))
                                    .foregroundColor(rightTab == idx ? Color.spGreen : Color.spMuted)
                                Rectangle()
                                    .fill(rightTab == idx ? Color.spGreen : Color.clear)
                                    .frame(height: 2)
                                    .cornerRadius(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                    }
                }
                .background(Color.spCard)

                Divider()

                if rightTab == 0 {
                    // 정보 탭
                    ScrollView {
                        VStack(spacing: 16) {
                            if let group = vm.selectedGroup {
                                GroupInfoCard(group: group, myId: auth.currentUser?.id, members: vm.members)
                                ActivityHeatmapCard()
                                StreakAchievementsCard(
                                    streakDays: auth.currentUser?.streakDays ?? 0,
                                    maxStreakDays: auth.currentUser?.maxStreakDays ?? 0
                                )
                            }
                        }
                        .padding(16)
                    }
                    .background(Color.spBG)
                } else {
                    // 채팅 탭
                    GroupChatPanel(vm: vm, myId: auth.currentUser?.id)
                }
            }
            .frame(width: 310)
        }
    }
}

// MARK: - Group Chat Panel
struct GroupChatPanel: View {
    @ObservedObject var vm: GroupViewModel
    let myId: Int?

    var body: some View {
        VStack(spacing: 0) {
            // 메시지 목록
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if vm.messages.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color.spBorder)
                                Text("아직 메시지가 없어요")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.spMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            ForEach(vm.messages) { msg in
                                GroupChatBubble(message: msg, isMe: msg.userId == myId)
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(14)
                }
                .background(Color.spBG)
                .onChange(of: vm.messages.count) { _ in
                    if let last = vm.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // 입력창
            HStack(spacing: 8) {
                TextField("메시지 입력...", text: $vm.newMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1...3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.spBG, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.spBorder, lineWidth: 1))
                    .onSubmit { Task { await vm.sendMessage() } }

                Button {
                    Task { await vm.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            vm.newMessage.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.secondary.opacity(0.3)
                                : Color.spGreen,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .disabled(vm.newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.spCard)
        }
    }
}

// MARK: - Group Chat Bubble
struct GroupChatBubble: View {
    let message: GroupMessage
    let isMe: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if !isMe {
                // 상대방 아바타
                ZStack {
                    Circle()
                        .fill(Color.spGreenLt)
                        .frame(width: 28, height: 28)
                    Text(String(message.userName.prefix(1)))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.spGreen)
                }
            }

            if isMe { Spacer(minLength: 40) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                if !isMe {
                    Text(message.userName)
                        .font(.system(size: 10))
                        .foregroundColor(Color.spMuted)
                        .padding(.leading, 4)
                }

                Text(message.message)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isMe ? Color.spGreen : Color.spCard,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isMe ? Color.clear : Color.spBorder, lineWidth: 0.5)
                    )
                    .foregroundColor(isMe ? .white : Color.spInk)
                    .textSelection(.enabled)
            }

            if !isMe { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Leaderboard Row
struct LeaderboardRow: View {
    let rank: Int
    let member: GroupMember
    let isMe: Bool

    var statusText: String {
        if member.todayStudySeconds > 3600 { return "열공중" }
        if member.todayStudySeconds > 0    { return "공부중" }
        return "쉬는중"
    }

    var statusColor: Color {
        member.todayStudySeconds > 0 ? .spGreen : Color.secondary.opacity(0.5)
    }

    var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "#FFD700")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return .secondary
        }
    }

    var studyTimeFormatted: String {
        let h = member.todayStudySeconds / 3600
        let m = (member.todayStudySeconds % 3600) / 60
        if h > 0 { return "\(h)시간 \(m)분" }
        if m > 0 { return "\(m)분" }
        return "오늘 공부 없음"
    }

    var body: some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(.system(size: rank <= 3 ? 22 : 18, weight: .bold))
                .foregroundColor(rankColor)
                .frame(width: 28, alignment: .center)

            ZStack {
                Circle().fill(Color.secondary.opacity(0.12)).frame(width: 44, height: 44)
                Text(String(member.name.prefix(1)))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.name).font(.system(size: 15, weight: .semibold))
                    if isMe {
                        Text("나")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.spGreen, in: Capsule())
                    }
                }
                Text(studyTimeFormatted).font(.system(size: 12)).foregroundColor(.secondary)
            }

            Spacer()

            Text(statusText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(statusColor)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(statusColor.opacity(0.1), in: Capsule())
        }
        .padding(14)
        .background(isMe ? Color.spGreen.opacity(0.05) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isMe ? Color.spGreen.opacity(0.3) : Color.spBorder, lineWidth: 1)
        )
    }
}

// MARK: - Group Info Card
struct GroupInfoCard: View {
    let group: StudyGroup
    let myId: Int?
    let members: [GroupMember]

    // My rank position (1-based) among today's members
    var myRankPosition: Int? {
        guard let myId else { return nil }
        let sorted = members.sorted { $0.todayStudySeconds > $1.todayStudySeconds }
        guard let idx = sorted.firstIndex(where: { $0.id == myId }) else { return nil }
        return idx + 1
    }

    var activeCount: Int { members.filter { $0.todayStudySeconds > 0 }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.spGreen.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: group.icon.isEmpty ? "person.3.fill" : group.icon)
                        .font(.system(size: 18))
                        .foregroundColor(.spGreen)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name).font(.system(size: 16, weight: .bold)).lineLimit(1)
                    Text("\(group.memberCount ?? members.count)/\(group.maxMembers) 멤버")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                if activeCount > 0 {
                    Text("\(activeCount)명 공부중")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.spGreen)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.spGreen.opacity(0.1), in: Capsule())
                }
            }

            if let desc = group.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Stats row
            HStack(spacing: 0) {
                GroupStatMini(label: "내 순위",
                              value: myRankPosition.map { "\($0)위" } ?? "-",
                              color: .spGreen)
                Divider().frame(height: 28)
                GroupStatMini(label: "총 PX",
                              value: "\(group.totalPx)",
                              color: Color(hex: "#FF9500"))
                Divider().frame(height: 28)
                GroupStatMini(label: "초대코드",
                              value: group.inviteCode,
                              color: Color(hex: "#007AFF"))
            }
            .background(Color.spBG, in: RoundedRectangle(cornerRadius: 10))
        }
        .spCard()
    }
}

struct GroupStatMini: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Activity Heatmap
struct ActivityHeatmapCard: View {
    @State private var activityData: [Int: Int] = [:]

    private var today: Int { Calendar.current.component(.day, from: Date()) }

    private var monthName: String {
        let fmt = DateFormatter(); fmt.locale = Locale(identifier: "ko_KR"); fmt.dateFormat = "M월"
        return fmt.string(from: Date())
    }

    private var year: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy"; return fmt.string(from: Date())
    }

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: Date())!.count
    }

    private var firstWeekday: Int {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: Date()); comps.day = 1
        let firstDay = cal.date(from: comps)!
        var wd = cal.component(.weekday, from: firstDay) - 2
        if wd < 0 { wd += 7 }
        return wd
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(monthName) 활동").font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(year).font(.system(size: 13)).foregroundColor(.secondary)
            }

            // Day labels
            HStack(spacing: 4) {
                ForEach(["월","화","수","목","금","토","일"], id: \.self) { d in
                    Text(d).font(.system(size: 9)).foregroundColor(.secondary).frame(maxWidth: .infinity)
                }
            }

            // Grid — LazyVGrid avoids GeometryReader / aspectRatio issues in ScrollView
            let gridColumns = Array(repeating: GridItem(.flexible(minimum: 18, maximum: 50), spacing: 4), count: 7)
            LazyVGrid(columns: gridColumns, spacing: 4) {
                // Leading empty cells for the first weekday offset
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
                // Day cells
                ForEach(1...max(daysInMonth, 1), id: \.self) { day in
                    let intensity = day > today ? 0 : (activityData[day] ?? 0)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(heatColor(day: day, intensity: intensity))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .spCard()
        .onAppear {
            for d in 1...max(today, 1) {
                if Int.random(in: 0...3) > 0 { activityData[d] = Int.random(in: 1...4) }
            }
        }
    }

    private func heatColor(day: Int, intensity: Int) -> Color {
        if day == today { return Color.spGreen }
        switch intensity {
        case 0: return Color.spGreen.opacity(0.08)
        case 1: return Color.spGreen.opacity(0.25)
        case 2: return Color.spGreen.opacity(0.50)
        case 3: return Color.spGreen.opacity(0.75)
        default: return Color.spGreen
        }
    }
}

// MARK: - Streak Achievements
struct StreakAchievementsCard: View {
    let streakDays: Int
    let maxStreakDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
                Text("연속 기록").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(streakDays)일 연속")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1), in: Capsule())
            }

            VStack(spacing: 12) {
                ForEach([
                    ("일주일 모두 접속", min(streakDays, 7),      7),
                    ("한달 연속 공부",  min(streakDays, 30),     30),
                    ("최고 연속 기록",  min(maxStreakDays, 100), 100),
                ], id: \.0) { name, current, goal in
                    let ratio = goal > 0 ? Double(current) / Double(goal) : 0
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(name).font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(current)/\(goal)일")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(current >= goal ? .spGreen : .secondary)
                        }
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.spGreen.opacity(0.12))
                            .frame(height: 6)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.spGreen)
                                    .scaleEffect(x: max(ratio, 0.001), y: 1.0, anchor: .leading)
                            }
                    }
                }
            }
        }
        .spCard()
    }
}

// MARK: - Group Search View
struct GroupSearchView: View {
    @ObservedObject var vm: GroupViewModel

    var displayList: [StudyGroup] { vm.searchQuery.isEmpty ? vm.recommended : vm.searchResults }

    var body: some View {
        HStack(spacing: 0) {
            // ── 왼쪽: 검색 + 생성 ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {

                // 안내 헤더
                VStack(alignment: .leading, spacing: 6) {
                    Text("그룹 찾기")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.spInk)
                    Text("함께 공부하면 더 오래 집중할 수 있어요")
                        .font(.system(size: 13))
                        .foregroundColor(Color.spMuted)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)

                Divider().padding(.horizontal, 24)

                ScrollView {
                    VStack(spacing: 20) {
                        // 검색
                        VStack(alignment: .leading, spacing: 10) {
                            Text("그룹 검색")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.spInk)

                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.spMuted)
                                TextField("그룹 이름 입력...", text: $vm.searchQuery)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .onSubmit { Task { await vm.search() } }
                                    .onChange(of: vm.searchQuery) { _ in
                                        Task { await vm.search() }
                                    }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.spBG, in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.spBorder, lineWidth: 1))
                        }

                        Divider()

                        // 생성 / 참가
                        VStack(alignment: .leading, spacing: 10) {
                            Text("직접 시작하기")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.spInk)

                            Button { vm.showCreateGroup = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("새 그룹 만들기")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.spGreen)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)

                            Button { vm.showJoinByCode = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "ticket")
                                        .font(.system(size: 13))
                                    Text("초대코드로 참가")
                                        .font(.system(size: 14))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .foregroundColor(Color.spGreen)
                                .background(Color.spGreenLt, in: RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.spGreen.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                }

                Spacer()
            }
            .frame(width: 300)
            .background(Color.spCard)

            Divider()

            // ── 오른쪽: 추천 그룹 목록 ──────────────────────────────────────
            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Text(vm.searchQuery.isEmpty ? "추천 그룹" : "검색 결과")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.spInk)
                    Spacer()
                    Button { Task { await vm.load() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundColor(Color.spMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                if displayList.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.3")
                            .font(.system(size: 36))
                            .foregroundColor(Color.spBorder)
                        Text("그룹이 없습니다")
                            .font(.system(size: 14))
                            .foregroundColor(Color.spMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(displayList.enumerated()), id: \.element.id) { i, group in
                                GroupSearchRow(rank: i + 1, group: group) {
                                    Task { await vm.joinGroup(id: group.id) }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.spBG)
        }
    }
}

// MARK: - Group Search Row
struct GroupSearchRow: View {
    let rank: Int
    let group: StudyGroup
    let onJoin: () -> Void
    @State private var isHovered = false

    var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "#B8860B")
        case 2: return Color(hex: "#808080")
        case 3: return Color(hex: "#8B5A2B")
        default: return Color.spMuted
        }
    }

    var iconColor: Color {
        let palette = ["#2B7A4B","#2563EB","#D97706","#DC2626","#7C3AED","#0891B2"]
        return Color(hex: palette[rank % palette.count])
    }

    var body: some View {
        HStack(spacing: 12) {
            // 순위
            Text("\(rank)")
                .font(.system(size: rank <= 3 ? 16 : 14, weight: .bold))
                .foregroundColor(rankColor)
                .frame(width: 24, alignment: .center)

            // 그룹 아이콘
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(iconColor.opacity(0.2), lineWidth: 1))
                Image(systemName: group.icon.isEmpty ? "person.3.fill" : group.icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            // 이름 + 멤버 수
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.spInk)
                    .lineLimit(1)
                Text("멤버 \(group.memberCount ?? 0)명")
                    .font(.system(size: 11))
                    .foregroundColor(Color.spMuted)
            }

            Spacer()

            // PX score
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#F59E0B"))
                    Text("\(group.totalPx) PX")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#F59E0B"))
                }
                Text("\(group.memberCount ?? 0)/\(group.maxMembers)명")
                    .font(.system(size: 10))
                    .foregroundColor(Color.spMuted)
            }

            // 참가 버튼
            Button {
                onJoin()
            } label: {
                Text("참가")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.spGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.spGreenLt, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.spGreen.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            isHovered ? Color.spGreen.opacity(0.04) : Color.spCard,
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? Color.spGreen.opacity(0.2) : Color.spBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// Legacy stubs kept for compile compatibility
struct GroupPreviewCard: View {
    let group: StudyGroup; let onJoin: () -> Void
    var body: some View {
        VStack { Text(group.name); Button("참가", action: onJoin).buttonStyle(.plain) }
    }
}
struct EmptyGroupPreview: View { var body: some View { EmptyView() } }
struct GroupListRow: View {
    let group: StudyGroup; let isHovered: Bool; let onHover: () -> Void; let onJoin: () -> Void
    var body: some View { EmptyView() }
}

// MARK: - Create Group View
struct CreateGroupView: View {
    @ObservedObject var vm: GroupViewModel
    @State private var name = ""
    @State private var desc = ""
    @State private var selectedIcon = "pencil"
    @State private var selectedColor = "#34C759"
    @State private var maxMembers: Double = 8
    @State private var isPublic = true

    let icons = ["plus", "book.fill", "pencil", "graduationcap.fill", "star.fill"]
    let colors = ["#34C759", "#007AFF", "#AF52DE", "#FF2D55", "#FF9500", "#5AC8FA"]

    var body: some View {
        HStack(spacing: 0) {
            // ── Form ───────────────────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Back + title
                    HStack(spacing: 12) {
                        Button { vm.showCreateGroup = false } label: {
                            Image(systemName: "arrow.left").font(.system(size: 16)).foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("기본 설정").font(.system(size: 20, weight: .bold))
                            Text("기존에 없던 새로운 그룹을 만들어 보아요").font(.caption).foregroundColor(.secondary)
                        }
                    }

                    // Name
                    SPFormField(label: "그룹 이름") {
                        HStack {
                            TextField("그룹 이름을 입력하세요", text: $name)
                                .textFieldStyle(.plain).font(.system(size: 14))
                            Text("\(name.count)/20").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color.spBG, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.spBorder, lineWidth: 1))
                    }

                    // Description
                    SPFormField(label: "그룹 설명") {
                        ZStack(alignment: .topLeading) {
                            if desc.isEmpty {
                                Text("그룹 설명을 입력하세요").font(.system(size: 14))
                                    .foregroundColor(Color.secondary.opacity(0.5)).padding(12)
                            }
                            TextEditor(text: $desc)
                                .scrollContentBackground(.hidden).font(.system(size: 14))
                                .frame(height: 80).padding(8)
                        }
                        .background(Color.spBG, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.spBorder, lineWidth: 1))
                        .overlay(HStack { Spacer(); VStack { Spacer()
                            Text("\(desc.count)/100").font(.system(size: 10)).foregroundColor(.secondary).padding(8)
                        }})
                    }

                    // Icon + Color
                    HStack(alignment: .top, spacing: 24) {
                        SPFormField(label: "아이콘") {
                            HStack(spacing: 10) {
                                ForEach(icons, id: \.self) { icon in
                                    Button { selectedIcon = icon } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedIcon == icon ? Color.spGreen.opacity(0.12) : Color.spBG)
                                                .frame(width: 44, height: 44)
                                                .overlay(RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedIcon == icon ? Color.spGreen : Color.spBorder, lineWidth: 1))
                                            Image(systemName: icon).font(.system(size: 18))
                                                .foregroundColor(selectedIcon == icon ? .spGreen : .secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        SPFormField(label: "색상") {
                            HStack(spacing: 10) {
                                ForEach(colors, id: \.self) { color in
                                    Button { selectedColor = color } label: {
                                        ZStack {
                                            Circle().fill(Color(hex: color)).frame(width: 30, height: 30)
                                            if selectedColor == color {
                                                Circle().strokeBorder(.white, lineWidth: 2).frame(width: 30, height: 30)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Max members + visibility
                    HStack(alignment: .top, spacing: 24) {
                        SPFormField(label: "최대 인원") {
                            VStack(spacing: 6) {
                                Slider(value: $maxMembers, in: 2...20, step: 1).tint(.spGreen)
                                HStack {
                                    Text("그룹 최대인원 설정").font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(maxMembers)) 명").font(.system(size: 13, weight: .semibold)).foregroundColor(.spGreen)
                                }
                            }
                        }

                        SPFormField(label: "공개 여부") {
                            HStack(spacing: 8) {
                                VisibilityButton(title: "공개", subtitle: "누구나 검색하고 기입가능", isSelected: isPublic)  { isPublic = true }
                                VisibilityButton(title: "비공개", subtitle: "초대코드만 가입가능", isSelected: !isPublic) { isPublic = false }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity)
            .background(Color.spCard)

            Divider()

            // ── Preview ────────────────────────────────────────────────────
            VStack(spacing: 16) {
                Text("그룹 미리보기").font(.system(size: 15, weight: .semibold)).padding(.top, 24)

                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(hex: selectedColor).opacity(0.12)).frame(width: 72, height: 72)
                        Image(systemName: selectedIcon).font(.system(size: 30)).foregroundColor(Color(hex: selectedColor))
                    }
                    Text(name.isEmpty ? "그룹 이름" : name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(name.isEmpty ? Color.secondary.opacity(0.4) : .primary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(desc.isEmpty ? "그룹 설명" : desc)
                        .font(.system(size: 13))
                        .foregroundColor(desc.isEmpty ? Color.secondary.opacity(0.4) : .secondary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                        .padding(14)
                        .background(Color.spBG, in: RoundedRectangle(cornerRadius: 12))

                    Toggle("최대 인원 \(Int(maxMembers))명", isOn: .constant(false))
                        .toggleStyle(.checkbox).font(.caption).foregroundColor(.secondary).disabled(true)
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    Task { await vm.createGroup(name: name, description: desc, icon: selectedIcon,
                                                color: selectedColor, maxMembers: Int(maxMembers), isPublic: isPublic) }
                } label: {
                    Text("생성하기").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(name.isEmpty ? Color.secondary.opacity(0.3) : Color.spGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain).disabled(name.isEmpty)
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            .frame(width: 300).background(Color.spBG)
        }
    }
}

// MARK: - Shared helpers
struct SPFormField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 14, weight: .semibold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VisibilityButton: View {
    let title: String; let subtitle: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(isSelected ? Color.spGreen : Color.clear).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(isSelected ? Color.spGreen : Color.secondary, lineWidth: 1.5))
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                }
                Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.spGreen.opacity(0.08) : Color.spBG, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.spGreen : Color.spBorder, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheets
struct JoinByCodeSheet: View {
    @ObservedObject var vm: GroupViewModel
    var body: some View {
        VStack(spacing: 24) {
            Text("초대코드로 참가").font(.system(size: 20, weight: .bold))
            VStack(alignment: .leading, spacing: 8) {
                Text("초대코드").font(.caption).foregroundColor(.secondary)
                TextField("초대코드 입력 (예: A1B2C3D4)", text: $vm.inviteCodeInput).textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 12) {
                Button("취소") { vm.showJoinByCode = false }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                Button("참가") { Task { await vm.joinByCode() } }
                    .buttonStyle(.borderedProminent).tint(.spGreen)
                    .frame(maxWidth: .infinity).disabled(vm.inviteCodeInput.isEmpty)
            }
        }
        .padding(30).frame(width: 360)
    }
}

// Legacy ChatBubble — kept for compile compatibility, delegates to GroupChatBubble
struct ChatBubble: View {
    let message: GroupMessage
    @EnvironmentObject var auth: AuthManager
    var isMe: Bool { message.userId == auth.currentUser?.id }
    var body: some View {
        GroupChatBubble(message: message, isMe: isMe)
    }
}
