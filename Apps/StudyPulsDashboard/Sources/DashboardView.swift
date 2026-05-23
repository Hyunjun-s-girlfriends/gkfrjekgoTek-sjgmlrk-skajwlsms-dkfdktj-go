import SwiftUI

struct DashboardView: View {
    @StateObject private var model = DashboardModel()
    @StateObject private var airPodsMonitor = AirPodsMotionMonitor()
    @State private var selectedTab: StudyPulsTab = .dashboard

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 860
            let contentPadding: CGFloat = compact ? 12 : 14

            VStack(spacing: 0) {
                AppChrome(
                    model: model,
                    selectedTab: $selectedTab,
                    compact: compact
                )

                Divider()

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                            Color.clear.frame(height: 1).id("top")

                            if let dashboard = model.dashboard {
                                TabContent(
                                    selectedTab: selectedTab,
                                    model: model,
                                    airPodsMonitor: airPodsMonitor,
                                    dashboard: dashboard,
                                    compact: compact
                                )
                            } else {
                                LoadingView(message: model.errorMessage)
                            }
                        }
                        .padding(contentPadding)
                        .foregroundStyle(Color.studyInk)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            scrollProxy.scrollTo("top", anchor: .top)
                        }
                    }
                    .onChange(of: model.dashboard?.totals.sessionCount ?? -1) {
                        DispatchQueue.main.async {
                            scrollProxy.scrollTo("top", anchor: .top)
                        }
                    }
                    .onChange(of: selectedTab) {
                        DispatchQueue.main.async {
                            scrollProxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
                .background(Color.studyBackground)
            }
        }
        .task {
            selectedTab = .dashboard
            await model.refresh()
            selectedTab = .dashboard
        }
        .onAppear {
            selectedTab = .dashboard
        }
    }
}

enum StudyPulsTab: String, CaseIterable, Identifiable {
    case dashboard = "대시보드"
    case coaching = "AI 코칭"
    case timer = "과목별 타이머"
    case group = "그룹"
    case settings = "설정"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2.fill"
        case .coaching: "sparkles"
        case .timer: "timer"
        case .group: "person.3.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct AppChrome: View {
    @ObservedObject var model: DashboardModel
    @Binding var selectedTab: StudyPulsTab
    let compact: Bool

    var body: some View {
        VStack(spacing: 10) {
            if compact {
                HStack(spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            tabButtons
                        }
                    }

                    refreshButton
                }
            } else {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        tabButtons
                    }

                    Spacer(minLength: 12)

                    if let user = model.dashboard?.user {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(user.name)
                                .font(.subheadline.bold())
                            Text("\(user.title) · \(user.xp)px · \(user.credits)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    refreshButton
                }
            }
        }
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, 10)
        .background(Color.studyPanel)
    }

    @ViewBuilder
    private var tabButtons: some View {
        ForEach(StudyPulsTab.allCases) { tab in
            Button {
                selectedTab = tab
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: tab.symbol)
                    Text(tab.rawValue)
                }
                .font(compact ? .caption.bold() : .subheadline.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(selectedTab == tab ? Color.studyBlue : Color.studyMuted)
                .background(selectedTab == tab ? Color.studyBlue.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await model.refresh() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .frame(width: 17, height: 17)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}

struct TabContent: View {
    let selectedTab: StudyPulsTab
    @ObservedObject var model: DashboardModel
    @ObservedObject var airPodsMonitor: AirPodsMotionMonitor
    let dashboard: DashboardResponse
    let compact: Bool

    var body: some View {
        switch selectedTab {
        case .dashboard:
            DashboardSummaryScreen(model: model, dashboard: dashboard, compact: compact)
        case .coaching:
            CoachingScreen(model: model, compact: compact)
        case .timer:
            TimerScreen(model: model, dashboard: dashboard, compact: compact)
        case .group:
            GroupScreen(model: model, compact: compact)
        case .settings:
            SettingsScreen(model: model, airPodsMonitor: airPodsMonitor, compact: compact)
        }
    }
}

struct MetricGrid: View {
    let dashboard: DashboardResponse
    let compact: Bool

    private var columns: [GridItem] {
        if compact {
            [GridItem(.adaptive(minimum: 138), spacing: 10)]
        } else {
            Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            MetricCard(title: "총 공부 시간", value: "\(dashboard.totals.totalMinutes)분", caption: "\(dashboard.totals.sessionCount) sessions")
            MetricCard(title: "평균 집중도", value: "\(dashboard.totals.avgFocus)점", caption: "100점에 가까울수록 좋음")
            MetricCard(title: "평균 스트레스", value: "\(dashboard.totals.avgStress)점", caption: "최적 구간 45-65")
            MetricCard(title: "졸림 감지", value: "\(dashboard.totals.drowsyCount ?? 0)회", caption: "AirPods head motion")
            MetricCard(title: "미션", value: "\(dashboard.totals.missionDone)/\(dashboard.totals.missionTotal)", caption: "완료 현황")
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 26, weight: .bold))
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding(13)
        .panelStyle()
    }
}

struct DashboardSummaryScreen: View {
    @ObservedObject var model: DashboardModel
    let dashboard: DashboardResponse
    let compact: Bool

    var body: some View {
        MetricGrid(dashboard: dashboard, compact: compact)
        MainGrid(model: model, dashboard: dashboard, compact: compact)
    }
}

struct MainGrid: View {
    @ObservedObject var model: DashboardModel
    let dashboard: DashboardResponse
    let compact: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                FocusPanel(model: model, dashboard: dashboard)
                StressPanel(samples: model.stress)
                    .frame(width: 260)
                DrowsinessPanel(points: model.drowsiness)
                    .frame(width: 260)
            }

            VStack(alignment: .leading, spacing: 10) {
                FocusPanel(model: model, dashboard: dashboard)
                StressPanel(samples: model.stress)
                DrowsinessPanel(points: model.drowsiness)
            }
        }
    }
}

struct BottomGrid: View {
    @ObservedObject var model: DashboardModel
    let compact: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) {
                TimerPanel(model: model)
                    .frame(width: compact ? 210 : 220)
                CoachPanel(coach: model.coach)
                    .frame(minWidth: 260, maxWidth: .infinity)
                RankingPanel(ranking: model.ranking)
                    .frame(width: compact ? 190 : 205)
            }

            VStack(alignment: .leading, spacing: 10) {
                TimerPanel(model: model)
                CoachPanel(coach: model.coach)
                RankingPanel(ranking: model.ranking)
            }
        }
    }
}

struct CoachingScreen: View {
    @ObservedObject var model: DashboardModel
    let compact: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                CoachPanel(coach: model.coach)
                    .frame(maxWidth: .infinity)
                CoachingActionsPanel(coach: model.coach)
                    .frame(width: compact ? 260 : 300)
            }

            VStack(alignment: .leading, spacing: 12) {
                CoachPanel(coach: model.coach)
                CoachingActionsPanel(coach: model.coach)
            }
        }
    }
}

struct TimerScreen: View {
    @ObservedObject var model: DashboardModel
    let dashboard: DashboardResponse
    let compact: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                TimerPanel(model: model)
                    .frame(width: compact ? 260 : 300)
                SubjectBreakdownPanel(subjects: dashboard.subjects)
                    .frame(maxWidth: .infinity)
                RecentSessionsPanel(sessions: dashboard.recentSessions)
                    .frame(width: compact ? 250 : 280)
            }

            VStack(alignment: .leading, spacing: 12) {
                TimerPanel(model: model)
                SubjectBreakdownPanel(subjects: dashboard.subjects)
                RecentSessionsPanel(sessions: dashboard.recentSessions)
            }
        }
    }
}

struct GroupScreen: View {
    @ObservedObject var model: DashboardModel
    let compact: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                RankingPanel(ranking: model.ranking)
                    .frame(width: compact ? 300 : 360)
                GroupMissionPanel()
                    .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 12) {
                RankingPanel(ranking: model.ranking)
                GroupMissionPanel()
            }
        }
    }
}

struct SettingsScreen: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject var airPodsMonitor: AirPodsMotionMonitor
    let compact: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                SettingsPanel(model: model)
                    .frame(width: compact ? 300 : 360)
                DeviceConnectionPanel(model: model, airPodsMonitor: airPodsMonitor)
                    .frame(maxWidth: .infinity)
                SystemStatusPanel(model: model, airPodsMonitor: airPodsMonitor)
                    .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 12) {
                SettingsPanel(model: model)
                DeviceConnectionPanel(model: model, airPodsMonitor: airPodsMonitor)
                SystemStatusPanel(model: model, airPodsMonitor: airPodsMonitor)
            }
        }
    }
}

struct CoachingActionsPanel: View {
    let coach: CoachResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelHeader(eyebrow: "NEXT", title: "추천 실행")
            ForEach(Array((coach?.nextActions ?? []).prefix(4).enumerated()), id: \.offset) { index, action in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .frame(width: 24, height: 24)
                        .background(Color.studyGreen.opacity(0.14))
                        .foregroundStyle(Color.studyGreen)
                        .clipShape(Circle())
                    Text(action)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(9)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .panelStyle()
    }
}

struct SubjectBreakdownPanel: View {
    let subjects: [SubjectSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelHeader(eyebrow: "SUBJECTS", title: "과목별 공부시간")
            ForEach(subjects) { subject in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(subject.name)
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(subject.totalMinutes)분")
                            .font(.subheadline.bold())
                    }
                    ProgressView(value: Double(min(subject.totalMinutes, 120)), total: 120)
                        .tint(Color(hex: subject.color) ?? .studyBlue)
                    Text("집중도 \(subject.avgFocus) · 스트레스 \(subject.avgStress)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .panelStyle()
    }
}

struct RecentSessionsPanel: View {
    let sessions: [StudySession]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelHeader(eyebrow: "RECENT", title: "최근 세션")
            ForEach(sessions.prefix(5)) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.subjectName)
                            .font(.subheadline.bold())
                        Text("HR \(session.avgHeartRate ?? 0) · HRV \(session.avgHrv ?? 0)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(session.totalMinutes)분")
                        .font(.subheadline.bold())
                }
                .padding(9)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .panelStyle()
    }
}

struct GroupMissionPanel: View {
    private let missions = [
        ("하루 접속률", 1.0, "1/1"),
        ("일주일 접속", 4.0 / 7.0, "4/7"),
        ("그룹 집중 120분", 0.72, "86/120")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(eyebrow: "MISSIONS", title: "그룹 미션")
            ForEach(missions, id: \.0) { mission in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(mission.0)
                            .font(.subheadline.bold())
                        Spacer()
                        Text(mission.2)
                            .font(.caption.bold())
                    }
                    ProgressView(value: mission.1)
                        .tint(mission.1 >= 1 ? Color.studyGreen : Color.studyInk)
                }
                .padding(12)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .panelStyle()
    }
}

struct SettingsPanel: View {
    @ObservedObject var model: DashboardModel
    @State private var focusAlert = true
    @State private var missionAlert = true
    @State private var drowsinessAlert = true
    @State private var launchServer = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(eyebrow: "SETTINGS", title: "설정")
            Toggle("집중도 알림", isOn: $focusAlert)
            Toggle("미션 알림", isOn: $missionAlert)
            Toggle("졸림 감지 알림", isOn: $drowsinessAlert)
            Toggle("앱 실행 시 로컬 서버 자동 시작", isOn: $launchServer)
            Divider()
            Button {
                Task { await model.refresh() }
            } label: {
                Label("데이터 새로고침", systemImage: "arrow.clockwise")
            }
        }
        .padding(14)
        .panelStyle()
    }
}

struct DeviceConnectionPanel: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject var airPodsMonitor: AirPodsMotionMonitor

    var watchStatus: String {
        model.devices.first(where: { $0.deviceType == "APPLE_WATCH_BRIDGE" })?.status ?? "waiting"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(eyebrow: "DEVICES", title: "기기 연결")

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("이어폰", systemImage: "airpodspro")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(airPodsMonitor.statusText)
                        .font(.caption.bold())
                        .foregroundStyle(airPodsMonitor.isConnected ? Color.studyGreen : Color.studyMuted)
                }
                Text("AirPods head tracking을 CoreMotion으로 직접 수신합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button {
                        airPodsMonitor.connect()
                    } label: {
                        Label("CoreMotion 연결", systemImage: "dot.radiowaves.left.and.right")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        airPodsMonitor.disconnect()
                    } label: {
                        Label("해제", systemImage: "xmark.circle")
                    }
                }
                Text("Pitch \(Int(airPodsMonitor.lastPitchDegrees))도 · 숙임 \(airPodsMonitor.downDurationSeconds)초")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(airPodsMonitor.lastEventText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Apple Watch", systemImage: "applewatch")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(watchStatus == "connected" ? "Bridge 연결됨" : "대기")
                        .font(.caption.bold())
                        .foregroundStyle(watchStatus == "connected" ? Color.studyGreen : Color.studyMuted)
                }
                Text("Watch 직접 수집 대신 HealthKit 유령 앱 브리지에서 HRV/심박 데이터를 받습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                InfoBlock(title: "iPhone 앱 서버 주소", text: LocalNetworkInfo.bridgeURL())
                Button {
                    Task { await model.connectWatchBridge() }
                } label: {
                    Label("Watch Bridge 연결", systemImage: "link")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .panelStyle()
    }
}

struct SystemStatusPanel: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject var airPodsMonitor: AirPodsMotionMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(eyebrow: "SYSTEM", title: "연결 상태")
            StatusRow(title: "로컬 서버", value: model.errorMessage == nil ? "연결됨" : "확인 필요", color: model.errorMessage == nil ? .studyGreen : .studyRose)
            StatusRow(title: "AI 코칭", value: model.coach?.provider ?? "대기", color: .studyBlue)
            StatusRow(title: "AirPods CoreMotion", value: airPodsMonitor.statusText, color: airPodsMonitor.isConnected ? .studyGreen : .studyAmber)
            StatusRow(title: "HealthKit Bridge", value: "유령 앱 수신 대기", color: .studyAmber)
            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.studyRose)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .panelStyle()
    }
}

struct StatusRow: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.subheadline.bold())
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct FocusPanel: View {
    @ObservedObject var model: DashboardModel
    let dashboard: DashboardResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader(eyebrow: "OPTIMAL AROUSAL", title: "시간대별 집중도", badge: "추천 \(dashboard.totals.bestHour)")
            FocusChart(points: model.focus)
                .frame(height: 170)
        }
        .frame(maxWidth: .infinity, minHeight: 258, alignment: .topLeading)
        .padding(14)
        .panelStyle()
    }
}

struct StressPanel: View {
    let samples: [StressSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PanelHeader(eyebrow: "STRESS & HRV", title: "최근 생체 지표")
            ForEach(Array(samples.suffix(4).reversed())) { sample in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sample.hour)
                            .font(.headline)
                        Text("HR \(sample.heartRate) · HRV \(sample.hrv)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StressBadge(value: sample.stress)
                }
                .padding(8)
                .background(Color.white.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 258, alignment: .topLeading)
        .padding(14)
        .panelStyle()
    }
}

struct DrowsinessPanel: View {
    let points: [DrowsinessPoint]

    var peakHour: String {
        points.sorted { $0.count > $1.count }.first?.hour ?? "-"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelHeader(eyebrow: "AIRPODS MOTION", title: "졸림 시간대", badge: peakHour == "-" ? nil : "피크 \(peakHour)")
            if points.isEmpty {
                InfoBlock(title: "감지 대기", text: "AirPods CoreMotion 연결 후 고개 숙임이 1분 이상 유지되면 이곳에 시간대별로 기록됩니다.")
            } else {
                ForEach(points.prefix(5)) { point in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(point.hour)
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(point.count)회 · \(point.totalMinutes)분")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(min(point.avgSleepyScore, 100)), total: 100)
                            .tint(Color.studyAmber)
                        Text("졸림 점수 \(point.avgSleepyScore)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(9)
                    .background(Color.white.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 258, alignment: .topLeading)
        .padding(14)
        .panelStyle()
    }
}

struct TimerPanel: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PanelHeader(eyebrow: "SUBJECT TIMER", title: "과목별 타이머")

            Picker("과목", selection: $model.selectedSubjectId) {
                ForEach(model.dashboard?.subjects ?? []) { subject in
                    Text(subject.name).tag(subject.id)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150, alignment: .leading)

            HStack(spacing: 8) {
                Button("시작") {
                    Task { await model.startTimer() }
                }
                .buttonStyle(.borderedProminent)

                Button("종료") {
                    Task { await model.endTimer() }
                }
            }

            Divider()

            Text(model.dashboard?.currentSession?.subjectName ?? "진행 중인 타이머가 없습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let latest = model.stress.last {
                InfoBlock(title: "최근 Watch HRV", text: "HR \(latest.heartRate) · HRV \(latest.hrv) · 스트레스 \(latest.stress)")
            } else {
                InfoBlock(title: "Watch HRV 대기", text: "iPhone 유령 앱에서 Apple Watch HRV가 들어오면 자동으로 스트레스가 계산됩니다.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .panelStyle()
    }
}

struct CoachPanel: View {
    let coach: CoachResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PanelHeader(eyebrow: "AI COACH", title: "학습 코칭", badge: coach?.provider)

            Text(coach?.summary ?? "분석 대기 중")
                .font(.subheadline)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
            InfoBlock(title: "잘되는 시간", text: coach?.bestTime ?? "-")
            InfoBlock(title: "약한 시간", text: coach?.weakTime ?? "-")
            InfoBlock(title: "코칭", text: coach?.coaching ?? "-")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .panelStyle()
    }
}

struct RankingPanel: View {
    let ranking: RankingResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PanelHeader(eyebrow: "GROUP", title: "그룹 랭킹")
            ForEach(ranking?.rows ?? []) { row in
                HStack {
                    Text("\(row.rank)")
                        .font(.headline)
                        .frame(width: 28, height: 28)
                        .background(Color.studyBlue.opacity(0.1))
                        .clipShape(Circle())
                    VStack(alignment: .leading) {
                        Text(row.name)
                            .font(.subheadline.bold())
                        Text("\(row.totalMinutes)분 · \(row.xp)px · 보상 \(row.rewardCredits)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .panelStyle()
    }
}

struct PanelHeader: View {
    let eyebrow: String
    let title: String
    var badge: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline.bold())
            }
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption.bold())
                    .foregroundStyle(Color.studyGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.studyGreen.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}

struct InfoBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StressBadge: View {
    let value: Int

    var color: Color {
        if value >= 70 { return .studyRose }
        if value >= 45 { return .studyAmber }
        return .studyGreen
    }

    var body: some View {
        Text("\(value)")
            .font(.headline)
            .foregroundStyle(color)
    }
}

struct FocusChart: View {
    let points: [FocusPoint]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let padding: CGFloat = 28
            let chartWidth = max(1, size.width - padding * 2)
            let chartHeight = max(1, size.height - padding * 2)
            let step = points.count <= 1 ? 0 : chartWidth / CGFloat(points.count - 1)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: padding, y: padding))
                    path.addLine(to: CGPoint(x: padding, y: size.height - padding))
                    path.addLine(to: CGPoint(x: size.width - padding, y: size.height - padding))
                }
                .stroke(Color.studyLine, lineWidth: 1)

                Path { path in
                    for index in points.indices {
                        let x = padding + CGFloat(index) * step
                        let y = size.height - padding - CGFloat(points[index].focus) / 100 * chartHeight
                        if index == points.startIndex {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.studyBlue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let x = padding + CGFloat(index) * step
                    let y = size.height - padding - CGFloat(point.focus) / 100 * chartHeight
                    Circle()
                        .fill(Color.studyInk)
                        .frame(width: 10, height: 10)
                        .position(x: x, y: y)
                    Text(point.hour)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .position(x: x, y: size.height - 8)
                }
            }
        }
    }
}

struct LoadingView: View {
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProgressView()
            Text(message ?? "StudyPuls를 준비하는 중입니다.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .panelStyle()
    }
}

extension View {
    func panelStyle() -> some View {
        self
            .background(Color.studyPanel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.studyLine)
            )
            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
    }
}

extension Color {
    static let studyBackground = Color(red: 0.965, green: 0.972, blue: 0.988)
    static let studyPanel = Color.white
    static let studyLine = Color(red: 0.86, green: 0.89, blue: 0.93)
    static let studyInk = Color(red: 0.09, green: 0.13, blue: 0.2)
    static let studyMuted = Color(red: 0.43, green: 0.48, blue: 0.57)
    static let studyBlue = Color(red: 0.18, green: 0.44, blue: 0.93)
    static let studyGreen = Color(red: 0.06, green: 0.62, blue: 0.43)
    static let studyRose = Color(red: 0.87, green: 0.25, blue: 0.38)
    static let studyAmber = Color(red: 0.79, green: 0.51, blue: 0.03)

    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") {
            text.removeFirst()
        }

        guard text.count == 6, let value = Int(text, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xff) / 255.0
        let green = Double((value >> 8) & 0xff) / 255.0
        let blue = Double(value & 0xff) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
