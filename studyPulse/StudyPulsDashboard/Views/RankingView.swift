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
            // ── Left: Rankings list ───────────────────────────────────────
            VStack(spacing: 0) {
                HStack {
                    SPSegmentPicker(options: ["개인 랭킹", "그룹 랭킹"], selected: $selectedTab)
                    Spacer()
                    Button { Task { await loadRankings() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.spMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider().background(Color.spBorder)

                Group {
                    if isLoading {
                        loadingView
                    } else if let loadError {
                        errorView(loadError)
                    } else if selectedTab == 0 {
                        PersonalRankingListNew(rankings: personalRankings, myId: myRank?.id)
                    } else {
                        GroupRankingListNew(rankings: groupRankings)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.spBG)

            Divider().background(Color.spBorder)

            // ── Right: My rank card ───────────────────────────────────────
            ScrollView {
                VStack(spacing: 14) {
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

    // MARK: Loading / Error
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.9)
            Text("불러오는 중...")
                .font(.system(size: 13))
                .foregroundColor(Color.spMuted)
                .padding(.top, 8)
            Spacer()
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 32))
                .foregroundColor(Color.spMuted)
            Text("불러오기 실패")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.spInk)
            Text(msg)
                .font(.system(size: 12))
                .foregroundColor(Color.spMuted)
                .multilineTextAlignment(.center)
            Button {
                Task { await loadRankings() }
            } label: {
                Text("다시 시도")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.spGreen, in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(24)
    }

    // MARK: Load
    func loadRankings() async {
        isLoading = true
        loadError = nil
        var errors: [String] = []

        do {
            let p: PersonalRankingResponse = try await APIClient.shared.get("/api/rankings/personal")
            personalRankings = p.rankings
            myRank = p.myRank
        } catch {
            print("⚠️ [Rankings] 개인 랭킹 로드 실패: \(error)")
            errors.append("개인: \(error.localizedDescription)")
        }

        do {
            groupRankings = try await APIClient.shared.get("/api/rankings/groups")
        } catch {
            print("⚠️ [Rankings] 그룹 랭킹 로드 실패: \(error)")
            errors.append("그룹: \(error.localizedDescription)")
        }

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
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, title in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selected = i }
                } label: {
                    Text(title)
                        .font(.system(size: 13, weight: selected == i ? .semibold : .regular))
                        .foregroundColor(selected == i ? .spGreen : Color.spMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            selected == i ? Color.spGreenLt : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.spCard, in: Capsule())
        .overlay(Capsule().stroke(Color.spBorder, lineWidth: 0.5))
    }
}

// MARK: - Personal Ranking List
struct PersonalRankingListNew: View {
    let rankings: [PersonalRanking]
    let myId: Int?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if rankings.isEmpty {
                    emptyState
                } else if rankings.count >= 3 {
                    // 3명 이상이면 포디움 + 나머지 리스트
                    PodiumRow(rankings: Array(rankings.prefix(3)), myId: myId)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    ForEach(Array(rankings.dropFirst(3))) { r in
                        PersonalRankRow(ranking: r, isMe: r.id == myId)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }
                    Spacer().frame(height: 12)
                } else {
                    // 1~2명: 심플 리스트
                    ForEach(rankings) { r in
                        PersonalRankRow(ranking: r, isMe: r.id == myId)
                            .padding(.horizontal, 20)
                            .padding(.top, r.id == rankings.first?.id ? 20 : 0)
                            .padding(.bottom, 8)
                    }
                    Spacer().frame(height: 12)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 60)
            Image(systemName: "person.3")
                .font(.system(size: 36))
                .foregroundColor(Color.spBorder)
            Text("아직 참가자가 없어요")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.spInk)
            Text("오늘 공부를 시작하면\n랭킹에 등록됩니다")
                .font(.system(size: 13))
                .foregroundColor(Color.spMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

// MARK: - Top 3 Podium
struct PodiumRow: View {
    let rankings: [PersonalRanking]
    let myId: Int?

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
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
        .padding(.horizontal, 8)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [Color.spGreen.opacity(0.05), Color.spCard],
                startPoint: .top, endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.spBorder, lineWidth: 0.5))
    }
}

struct PodiumItem: View {
    let ranking: PersonalRanking
    let isMe: Bool
    var isFirst: Bool = false

    var medalColor: Color {
        switch ranking.rankPosition {
        case 1: return Color(hex: "#F6A623")   // 따뜻한 골드
        case 2: return Color(hex: "#9CA3AF")   // 실버 그레이
        case 3: return Color(hex: "#B87333")   // 브론즈
        default: return Color.spMuted
        }
    }

    var pedestalHeight: CGFloat { isFirst ? 52 : 32 }
    var avatarSize:     CGFloat { isFirst ? 60 : 46 }
    var fontSize:       CGFloat { isFirst ? 24 : 18 }

    var body: some View {
        VStack(spacing: 5) {
            // 왕관 / 메달 아이콘
            if ranking.rankPosition == 1 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(medalColor)
            } else {
                Color.clear.frame(height: 16)
            }

            // 아바타
            ZStack {
                Circle()
                    .fill(medalColor.opacity(0.12))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(Circle().stroke(medalColor, lineWidth: isFirst ? 2.5 : 1.5))
                Text(String(ranking.name.prefix(1)))
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(medalColor)
            }
            .scaleEffect(isMe ? 1.06 : 1.0)

            Text(ranking.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.spInk)
                .lineLimit(1)

            Text(formatTime(ranking.totalStudyToday))
                .font(.system(size: 11))
                .foregroundColor(Color.spMuted)

            // 받침대
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(medalColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(medalColor.opacity(0.35), lineWidth: 1))
                Text("#\(ranking.rankPosition)")
                    .font(.system(size: isFirst ? 15 : 12, weight: .bold))
                    .foregroundColor(medalColor)
            }
            .frame(height: pedestalHeight)
        }
    }

    func formatTime(_ s: Int) -> String {
        if s < 60   { return "\(s)초" }
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
        HStack(spacing: 12) {
            // 순위 번호
            Text("\(ranking.rankPosition)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.spMuted)
                .frame(width: 26, alignment: .center)

            // 아바타
            ZStack {
                Circle()
                    .fill(isMe ? Color.spGreen.opacity(0.12) : Color.spGreenLt)
                    .frame(width: 38, height: 38)
                    .overlay(Circle().stroke(isMe ? Color.spGreen.opacity(0.4) : Color.spBorder, lineWidth: 1))
                Text(String(ranking.name.prefix(1)))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isMe ? Color.spGreen : Color.spInk)
            }

            // 이름 + 레벨
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ranking.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.spInk)
                    if isMe {
                        Text("나")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.spGreen, in: Capsule())
                    }
                }
                Text("Lv.\(ranking.level)")
                    .font(.system(size: 11))
                    .foregroundColor(Color.spMuted)
            }

            Spacer()

            // PX + 공부시간
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(ranking.px) PX")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.spGreen)
                Text(formatTime(ranking.totalStudyToday))
                    .font(.system(size: 11))
                    .foregroundColor(Color.spMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isMe ? Color.spGreen.opacity(0.05) : Color.spCard)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(isMe ? Color.spGreen.opacity(0.3) : Color.spBorder, lineWidth: 0.5))
        )
    }
}

// MARK: - Group Ranking List
struct GroupRankingListNew: View {
    let rankings: [GroupRanking]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if rankings.isEmpty {
                    emptyState
                } else {
                    ForEach(rankings) { r in
                        GroupRankRow(ranking: r)
                            .padding(.horizontal, 20)
                            .padding(.top, r.id == rankings.first?.id ? 20 : 0)
                            .padding(.bottom, 8)
                    }
                    Spacer().frame(height: 12)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 60)
            Image(systemName: "person.3")
                .font(.system(size: 36))
                .foregroundColor(Color.spBorder)
            Text("가입한 그룹이 없어요")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.spInk)
            Text("그룹 탭에서 그룹을 만들거나\n참여해보세요")
                .font(.system(size: 13))
                .foregroundColor(Color.spMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

struct GroupRankRow: View {
    let ranking: GroupRanking

    var rankColor: Color {
        switch ranking.rankPosition {
        case 1: return Color(hex: "#F6A623")
        case 2: return Color(hex: "#9CA3AF")
        case 3: return Color(hex: "#B87333")
        default: return Color.spGreen
        }
    }

    var isTop3: Bool { ranking.rankPosition <= 3 }

    var body: some View {
        HStack(spacing: 12) {
            // 순위
            Group {
                if isTop3 {
                    Image(systemName: "medal.fill")
                        .foregroundColor(rankColor)
                        .font(.system(size: 16))
                } else {
                    Text("\(ranking.rankPosition)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.spMuted)
                }
            }
            .frame(width: 26, alignment: .center)

            // 그룹 아이콘
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isTop3 ? rankColor.opacity(0.10) : Color.spGreenLt)
                    .frame(width: 38, height: 38)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(isTop3 ? rankColor.opacity(0.3) : Color.spBorder, lineWidth: 0.5))
                Image(systemName: ranking.icon.isEmpty ? "person.3.fill" : ranking.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isTop3 ? rankColor : Color.spGreen)
            }

            // 그룹 이름 + 멤버 수
            VStack(alignment: .leading, spacing: 2) {
                Text(ranking.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.spInk)
                Text("멤버 \(ranking.memberCount)명")
                    .font(.system(size: 11))
                    .foregroundColor(Color.spMuted)
            }

            Spacer()

            // PX + 미션
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(ranking.totalPx) PX")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isTop3 ? rankColor : Color.spGreen)
                Text("미션 \(ranking.missionClearCount)회")
                    .font(.system(size: 11))
                    .foregroundColor(Color.spMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTop3 ? rankColor.opacity(0.04) : Color.spCard)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(isTop3 ? rankColor.opacity(0.2) : Color.spBorder, lineWidth: 0.5))
        )
    }
}

// MARK: - My Rank Card (right panel)
struct MyRankCardNew: View {
    let rank: PersonalRanking

    var rankColor: Color {
        switch rank.rankPosition {
        case 1: return Color(hex: "#F6A623")
        case 2: return Color(hex: "#9CA3AF")
        case 3: return Color(hex: "#B87333")
        default: return Color.spGreen
        }
    }

    func formatTime(_ s: Int) -> String {
        if s < 60   { return "\(s)초" }
        if s < 3600 { return "\(s / 60)분" }
        return String(format: "%d시간 %d분", s / 3600, (s % 3600) / 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("내 순위")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.spInk)
                Spacer()
                if rank.rankPosition <= 3 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13))
                        .foregroundColor(rankColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // 순위 배지
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.10))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(rankColor.opacity(0.3), lineWidth: 1.5))
                Text("#\(rank.rankPosition)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(rankColor)
            }

            Text(rank.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.spInk)
                .padding(.top, 10)

            HStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color.spGreen)
                Text("Lv.\(rank.level)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.spMuted)
            }
            .padding(.top, 4)
            .padding(.bottom, 16)

            Divider().background(Color.spBorder).padding(.horizontal, 16)

            VStack(spacing: 0) {
                RankStatRow(label: "총 PX", value: "\(rank.px) PX",
                            color: Color.spGreen, icon: "bolt.fill")
                Divider().background(Color.spBorder)
                RankStatRow(label: "오늘 공부", value: formatTime(rank.totalStudyToday),
                            color: Color.spInk, icon: "timer")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .background(Color.spCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.spBorder, lineWidth: 0.5))
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
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color.spMuted)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - No Rank Card
struct NoRankCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.spGreenLt)
                    .frame(width: 68, height: 68)
                Image(systemName: "trophy")
                    .font(.system(size: 28))
                    .foregroundColor(Color.spGreen.opacity(0.5))
            }
            Text("순위 없음")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.spInk)
            Text("오늘 공부를 시작하면\n순위에 등록됩니다")
                .font(.system(size: 13))
                .foregroundColor(Color.spMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.spCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.spBorder, lineWidth: 0.5))
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
        VStack(alignment: .leading, spacing: 0) {
            Text("랭킹 정보")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.spInk)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider().background(Color.spBorder).padding(.horizontal, 16)

            VStack(spacing: 0) {
                RankStatRow(label: "전체 참여자",
                            value: "\(totalUsers)명",
                            color: Color.spInk,
                            icon: "person.2")
                Divider().background(Color.spBorder)
                RankStatRow(label: "1위 공부시간",
                            value: formatTime(topStudyTime),
                            color: Color(hex: "#F6A623"),
                            icon: "crown.fill")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .background(Color.spCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.spBorder, lineWidth: 0.5))
    }
}

// MARK: - Legacy aliases (compile compatibility)
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
        case 1: return Color(hex: "#F6A623")
        case 2: return Color(hex: "#9CA3AF")
        case 3: return Color(hex: "#B87333")
        default: return Color.spMuted
        }
    }
    var body: some View {
        if position <= 3 {
            Image(systemName: "medal.fill").foregroundColor(color).font(.title3).frame(width: 28)
        } else {
            Text("\(position)").font(.subheadline.bold()).foregroundColor(Color.spMuted).frame(width: 28)
        }
    }
}
