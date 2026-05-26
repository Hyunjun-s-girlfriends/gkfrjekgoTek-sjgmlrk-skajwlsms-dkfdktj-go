import SwiftUI
import Charts

struct PersonalRankingResponse: Codable {
    let rankings: [PersonalRanking]
    let myRank: PersonalRanking?
}

// MARK: - RankingView
struct RankingView: View {
    @State private var selectedTab = 0
    @State private var personalRankings: [PersonalRanking] = []
    @State private var groupRankings: [GroupRanking] = []
    @State private var myRank: PersonalRanking?
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // ── Left: Rankings list ────────────────────────────────────────
            VStack(spacing: 0) {
                // Segment picker
                HStack {
                    SPSegmentPicker(
                        options: ["개인 랭킹", "그룹 랭킹"],
                        selected: $selectedTab
                    )
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider()

                if isLoading {
                    Spacer()
                    ProgressView("불러오는 중...")
                        .foregroundColor(.secondary)
                    Spacer()
                } else if let loadError {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .foregroundColor(.orange)
                        Text("로드 실패")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.spInk)
                        Text(loadError)
                            .font(.system(size: 12))
                            .foregroundColor(Color.spMuted)
                            .multilineTextAlignment(.center)
                        Button("다시 시도") { Task { await loadRankings() } }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.spGreen)
                    }
                    .padding(24)
                    Spacer()
                } else if selectedTab == 0 {
                    PersonalRankingListNew(rankings: personalRankings, myId: myRank?.id)
                } else {
                    GroupRankingListNew(rankings: groupRankings)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.spCard)

            Divider()

            // ── Right: My rank card ────────────────────────────────────────
            ScrollView {
                VStack(spacing: 16) {
                    if let myRank {
                        MyRankCardNew(rank: myRank)
                    } else {
                        NoRankCard()
                    }
                    RankingInfoCard(
                        totalUsers: personalRankings.count,
                        topStudyTime: personalRankings.first?.totalStudyToday ?? 0
                    )
                }
                .padding(16)
            }
            .frame(width: 290)
            .background(Color.spBG)
        }
        .task { await loadRankings() }
    }

    func loadRankings() async {
        isLoading = true
        loadError = nil
        var errors: [String] = []

        // 개인 랭킹 — 독립 try-catch (실패해도 그룹 랭킹에 영향 없음)
        do {
            let p: PersonalRankingResponse = try await APIClient.shared.get("/api/rankings/personal")
            personalRankings = p.rankings
            myRank = p.myRank
        } catch {
            let msg = error.localizedDescription
            print("⚠️ [Rankings] 개인 랭킹 로드 실패: \(error)")
            errors.append("개인: \(msg)")
        }
        // 그룹 랭킹 — 독립 try-catch
        do {
            groupRankings = try await APIClient.shared.get("/api/rankings/groups")
        } catch {
            let msg = error.localizedDescription
            print("⚠️ [Rankings] 그룹 랭킹 로드 실패: \(error)")
            errors.append("그룹: \(msg)")
        }

        // 둘 다 비어있고 에러가 있으면 표시
        if personalRankings.isEmpty && groupRankings.isEmpty && !errors.isEmpty {
            loadError = errors.joined(separator: "\n")
        }
        isLoading = false
    }
}

// MARK: - Segment Picker
struct SPSegmentPicker: View {
    let options: [String]
    @Binding var selected: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, title in
                Button { withAnimation(.easeInOut(duration: 0.15)) { selected = i } } label: {
                    Text(title)
                        .font(.system(size: 13, weight: selected == i ? .semibold : .regular))
                        .foregroundColor(selected == i ? .spGreen : Color.spMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            selected == i ? Color.spGreenLt : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.spBG, in: Capsule())
    }
}

// MARK: - Personal Ranking List
struct PersonalRankingListNew: View {
    let rankings: [PersonalRanking]
    let myId: Int?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // Top 3 podium (if we have enough data)
                if rankings.count >= 3 {
                    PodiumRow(rankings: Array(rankings.prefix(3)), myId: myId)
                        .padding(.bottom, 8)
                }

                // Rest of rankings
                let rest = rankings.count >= 3 ? Array(rankings.dropFirst(3)) : rankings
                ForEach(rest) { ranking in
                    PersonalRankRow(ranking: ranking, isMe: ranking.id == myId)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Top 3 Podium
struct PodiumRow: View {
    let rankings: [PersonalRanking]
    let myId: Int?

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if rankings.count > 1 {
                PodiumItem(ranking: rankings[1], isMe: rankings[1].id == myId)
                    .frame(maxWidth: .infinity)
            }
            if rankings.count > 0 {
                PodiumItem(ranking: rankings[0], isMe: rankings[0].id == myId, isFirst: true)
                    .frame(maxWidth: .infinity)
            }
            if rankings.count > 2 {
                PodiumItem(ranking: rankings[2], isMe: rankings[2].id == myId)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.spGreen.opacity(0.06), Color.spBG.opacity(0.3)],
                startPoint: .top, endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.spBorder, lineWidth: 1))
    }
}

struct PodiumItem: View {
    let ranking: PersonalRanking
    let isMe: Bool
    var isFirst: Bool = false

    var medalColor: Color {
        switch ranking.rankPosition {
        case 1: return Color(hex: "#FFD700")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return .secondary
        }
    }

    var pedestalHeight: CGFloat {
        switch ranking.rankPosition {
        case 1: return 48
        case 2: return 32
        case 3: return 20
        default: return 20
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Avatar
            ZStack {
                Circle()
                    .fill(isFirst ? Color(hex: "#FFD700").opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: isFirst ? 56 : 44, height: isFirst ? 56 : 44)
                    .overlay(Circle().stroke(medalColor, lineWidth: isFirst ? 2.5 : 1.5))
                Text(String(ranking.name.prefix(1)))
                    .font(.system(size: isFirst ? 22 : 17, weight: .bold))
                    .foregroundColor(medalColor)
            }

            Text(ranking.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.spInk)
                .lineLimit(1)

            Text(formatTime(ranking.totalStudyToday))
                .font(.system(size: 11))
                .foregroundColor(Color.spMuted)

            // Pedestal
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(medalColor.opacity(0.15))
                    .frame(height: pedestalHeight)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(medalColor.opacity(0.4), lineWidth: 1))
                Text("#\(ranking.rankPosition)")
                    .font(.system(size: isFirst ? 16 : 13, weight: .bold))
                    .foregroundColor(medalColor)
            }
        }
        .scaleEffect(isMe ? 1.04 : 1.0)
    }

    func formatTime(_ s: Int) -> String {
        if s < 60  { return "\(s)초" }
        if s < 3600 { return "\(s / 60)분" }
        return String(format: "%d시간 %d분", s / 3600, (s % 3600) / 60)
    }
}

// MARK: - Personal Rank Row (4th place and below)
struct PersonalRankRow: View {
    let ranking: PersonalRanking
    let isMe: Bool

    func formatTime(_ s: Int) -> String {
        if s < 60   { return "\(s)초" }
        if s < 3600 { return "\(s / 60)분" }
        return String(format: "%d시간 %d분", s / 3600, (s % 3600) / 60)
    }

    var body: some View {
        HStack(spacing: 14) {
            Text("\(ranking.rankPosition)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .center)

            ZStack {
                Circle()
                    .fill(isMe ? Color.spGreen.opacity(0.12) : Color.secondary.opacity(0.1))
                    .frame(width: 40, height: 40)
                Text(String(ranking.name.prefix(1)))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isMe ? .spGreen : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ranking.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.spInk)
                    if isMe {
                        Text("나")
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.spGreen, in: Capsule())
                    }
                }
                Text("Lv.\(ranking.level)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.spMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(ranking.px) PX")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.spGreen)
                Text(formatTime(ranking.totalStudyToday))
                    .font(.system(size: 11))
                    .foregroundColor(Color.spMuted)
            }
        }
        .padding(12)
        .background(isMe ? Color.spGreen.opacity(0.05) : Color.spCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isMe ? Color.spGreen.opacity(0.25) : Color.spBorder, lineWidth: 1)
        )
    }
}

// MARK: - Group Ranking List
struct GroupRankingListNew: View {
    let rankings: [GroupRanking]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(rankings) { ranking in
                    GroupRankRow(ranking: ranking)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

struct GroupRankRow: View {
    let ranking: GroupRanking

    var rankColor: Color {
        switch ranking.rankPosition {
        case 1: return Color(hex: "#FFD700")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return .secondary
        }
    }

    var isTop3: Bool { ranking.rankPosition <= 3 }

    var body: some View {
        HStack(spacing: 14) {
            // Rank
            if isTop3 {
                Image(systemName: "medal.fill")
                    .foregroundColor(rankColor)
                    .font(.system(size: 17))
                    .frame(width: 28, alignment: .center)
            } else {
                Text("\(ranking.rankPosition)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, alignment: .center)
            }

            // Group icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isTop3 ? rankColor.opacity(0.12) : Color.spGreen.opacity(0.08))
                    .frame(width: 40, height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(isTop3 ? rankColor.opacity(0.3) : Color.spBorder, lineWidth: 1))
                Image(systemName: ranking.icon.isEmpty ? "person.3.fill" : ranking.icon)
                    .font(.system(size: 15))
                    .foregroundColor(isTop3 ? rankColor : .spGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(ranking.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.spInk)
                Text("\(ranking.memberCount)명")
                    .font(.system(size: 12))
                    .foregroundColor(Color.spMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(ranking.totalPx) PX")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isTop3 ? rankColor : Color.spGreen)
                Text("미션 \(ranking.missionClearCount)회")
                    .font(.system(size: 11))
                    .foregroundColor(Color.spMuted)
            }
        }
        .padding(12)
        .background(isTop3 ? rankColor.opacity(0.05) : Color.spCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            isTop3 ? rankColor.opacity(0.2) : Color.spBorder, lineWidth: 1
        ))
    }
}

// MARK: - My Rank Card (right panel)
struct MyRankCardNew: View {
    let rank: PersonalRanking

    var rankColor: Color {
        switch rank.rankPosition {
        case 1: return Color(hex: "#FFD700")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return .spGreen
        }
    }

    func formatTime(_ s: Int) -> String {
        if s < 60   { return "\(s)초" }
        if s < 3600 { return "\(s / 60)분" }
        return String(format: "%d시간 %d분", s / 3600, (s % 3600) / 60)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("내 순위")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Rank badge
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(rankColor.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Text("#\(rank.rankPosition)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(rankColor)
                }

                Text(rank.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.spInk)

                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.spGreen)
                    Text("Lv.\(rank.level)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Stats
            VStack(spacing: 0) {
                RankStatRow(label: "총 PX", value: "\(rank.px) PX", color: .spGreen, icon: "bolt.fill")
                Divider()
                RankStatRow(label: "오늘 공부", value: formatTime(rank.totalStudyToday), color: .primary, icon: "timer")
            }
        }
        .spCard()
    }
}

struct RankStatRow: View {
    let label: String
    let value: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                    .frame(width: 16)
            }
            Text(label).font(.system(size: 13)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(color)
        }
        .padding(.vertical, 9)
    }
}

struct NoRankCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.08)).frame(width: 64, height: 64)
                Image(systemName: "trophy").font(.system(size: 28)).foregroundColor(Color.secondary.opacity(0.3))
            }
            Text("순위 없음").font(.system(size: 16, weight: .semibold))
            Text("오늘 공부를 시작하면\n순위에 등록됩니다")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .spCard()
    }
}

// MARK: - Ranking Info Card
struct RankingInfoCard: View {
    let totalUsers: Int
    let topStudyTime: Int

    func formatTime(_ s: Int) -> String {
        if s < 60   { return "\(s)초" }
        if s < 3600 { return "\(s / 60)분" }
        return String(format: "%d시간 %d분", s / 3600, (s % 3600) / 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("랭킹 정보")
                .font(.system(size: 16, weight: .semibold))

            VStack(spacing: 0) {
                RankStatRow(label: "전체 참여자", value: "\(totalUsers)명", color: .primary, icon: "person.2")
                Divider()
                RankStatRow(label: "1위 공부시간", value: formatTime(topStudyTime), color: Color(hex: "#FFD700"), icon: "crown.fill")
            }
        }
        .spCard()
    }
}

// MARK: - Legacy structs (kept for compile compatibility)
struct MyRankCard: View {
    let rank: PersonalRanking
    var body: some View { MyRankCardNew(rank: rank) }
}

struct PersonalRankingList: View {
    let rankings: [PersonalRanking]; let myId: Int?
    var body: some View { PersonalRankingListNew(rankings: rankings, myId: myId) }
}

struct GroupRankingList: View {
    let rankings: [GroupRanking]
    var body: some View { GroupRankingListNew(rankings: rankings) }
}

struct RankBadge: View {
    let position: Int
    var color: Color {
        switch position {
        case 1: return .yellow; case 2: return Color(hex: "#C0C0C0"); case 3: return Color(hex: "#CD7F32")
        default: return .secondary
        }
    }
    var body: some View {
        if position <= 3 {
            Image(systemName: "medal.fill").foregroundColor(color).font(.title3).frame(width: 28)
        } else {
            Text("\(position)").font(.subheadline.bold()).foregroundColor(.secondary).frame(width: 28)
        }
    }
}
