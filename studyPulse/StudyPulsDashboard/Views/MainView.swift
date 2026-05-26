import SwiftUI

// MARK: - ViewModel (unchanged logic)
@MainActor
class MainViewModel: ObservableObject {
    @Published var subjects: [Subject] = []
    @Published var missions: [Mission] = []
    @Published var latestHRV: HRVData?
    @Published var timerStates: [Int: TimerState] = [:]
    @Published var user: User?
    @Published var showAddSubject = false
    @Published var newSubjectName = ""
    @Published var newSubjectColor = "#34C759"
    @Published var errorMessage: String?

    struct TimerState {
        var sessionId: Int?
        var isRunning = false
        var elapsedSeconds = 0
        var timer: Timer?
    }

    func load() async {
        async let s: [Subject] = APIClient.shared.get("/api/subjects")
        async let m: [Mission] = APIClient.shared.get("/api/missions/personal")
        async let h: HRVData? = (try? await APIClient.shared.get("/api/health/hrv-latest")) as HRVData?
        async let u: User = APIClient.shared.get("/api/auth/me")
        do {
            subjects = try await s
            missions = try await m
            latestHRV = await h
            user = try await u
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startTimer(subjectId: Int) async {
        struct StartResponse: Codable { let id: Int }
        do {
            let resp: StartResponse = try await APIClient.shared.post("/api/timers/start", body: ["subjectId": subjectId])
            var state = TimerState()
            state.sessionId = resp.id
            state.isRunning = true
            timerStates[subjectId] = state
            startTicking(subjectId: subjectId)
        } catch { errorMessage = error.localizedDescription }
    }

    func stopTimer(subjectId: Int) async {
        guard var state = timerStates[subjectId], let sessionId = state.sessionId else { return }
        state.timer?.invalidate()
        state.isRunning = false
        timerStates[subjectId] = state

        struct StopResponse: Codable { let pxEarned: Int }
        do {
            let resp: StopResponse = try await APIClient.shared.put(
                "/api/timers/\(sessionId)/stop",
                body: ["durationSeconds": state.elapsedSeconds]
            )
            if resp.pxEarned > 0 { errorMessage = "+\(resp.pxEarned) PX 획득!" }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    private func startTicking(subjectId: Int) {
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.timerStates[subjectId]?.elapsedSeconds += 1 }
        }
        timerStates[subjectId]?.timer = timer
    }

    func addSubject() async {
        guard !newSubjectName.isEmpty else { return }
        do {
            let subject: Subject = try await APIClient.shared.post(
                "/api/subjects",
                body: ["name": newSubjectName, "color": newSubjectColor]
            )
            subjects.append(subject)
            newSubjectName = ""
            showAddSubject = false
        } catch { errorMessage = error.localizedDescription }
    }

    func completeMission(id: Int) async {
        struct MissionResult: Codable { let pxEarned: Int }
        do {
            let result: MissionResult = try await APIClient.shared.post("/api/missions/\(id)/complete")
            errorMessage = "미션 완료! +\(result.pxEarned) PX"
            await load()
        } catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - MainView
struct MainView: View {
    @StateObject private var vm = MainViewModel()
    @State private var selectedSubjectId: Int? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // ── Left column ────────────────────────────────────────────────
            ScrollView {
                VStack(spacing: 20) {
                    SubjectTimerCard(vm: vm, selectedId: $selectedSubjectId)
                    DailyMissionCard(missions: vm.missions) { id in
                        Task { await vm.completeMission(id: id) }
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)

            // ── Right column ───────────────────────────────────────────────
            ScrollView {
                VStack(spacing: 16) {
                    GrowthCard(user: vm.user)
                    HRVStatusCard(hrv: vm.latestHRV)
                    TodayStatsCard(vm: vm)
                }
                .padding(20)
            }
            .frame(width: 270)
        }
        .task { await vm.load() }
        .overlay(alignment: .bottom) {
            if let msg = vm.errorMessage {
                Text(msg)
                    .font(.subheadline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { vm.errorMessage = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: $vm.showAddSubject) { AddSubjectSheet(vm: vm) }
    }
}

// MARK: - Subject Timer Card
struct SubjectTimerCard: View {
    @ObservedObject var vm: MainViewModel
    @Binding var selectedId: Int?

    var selectedSubject: Subject? { vm.subjects.first { $0.id == selectedId } }
    var selectedState: MainViewModel.TimerState { selectedId.flatMap { vm.timerStates[$0] } ?? .init() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("과목별 타이머")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(vm.subjects.count)/10")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button { vm.showAddSubject = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.spGreen)
                }
                .buttonStyle(.plain)
            }

            // Subject pills
            if vm.subjects.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 32))
                        .foregroundColor(Color.secondary.opacity(0.3))
                    Text("+ 버튼으로 과목을 추가하세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.spBG, in: RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.subjects) { subject in
                            SubjectPill(subject: subject, isSelected: selectedId == subject.id) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedId = selectedId == subject.id ? nil : subject.id
                                }
                            }
                        }
                    }
                }

                // Timer area
                if let subject = selectedSubject {
                    TimerDisplay(
                        subject: subject,
                        state: selectedState,
                        onStart: { Task { await vm.startTimer(subjectId: subject.id) } },
                        onStop:  { Task { await vm.stopTimer(subjectId: subject.id) } }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.system(size: 28))
                            .foregroundColor(Color.secondary.opacity(0.3))
                        Text("위에서 과목을 선택하세요")
                            .font(.system(size: 14))
                            .foregroundColor(Color.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color.spBG, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .spCard()
    }
}

struct SubjectPill: View {
    let subject: Subject
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: subject.color))
                    .frame(width: 7, height: 7)
                Text(subject.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                isSelected ? Color(hex: subject.color) : Color.spCard,
                in: Capsule()
            )
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color(hex: subject.color).opacity(0.35), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }
}

struct TimerDisplay: View {
    let subject: Subject
    let state: MainViewModel.TimerState
    let onStart: () -> Void
    let onStop: () -> Void
    @State private var pulse = false

    var elapsed: String {
        let s = state.elapsedSeconds
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Timer block
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(hex: subject.color))
                        .frame(width: 8, height: 8)
                    Text(subject.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    if state.isRunning {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.spGreen)
                                .frame(width: 6, height: 6)
                                .opacity(pulse ? 1 : 0.25)
                                .animation(.easeInOut(duration: 0.8).repeatForever(), value: pulse)
                                .onAppear { pulse = true }
                                .onDisappear { pulse = false }
                            Text("공부중")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.spGreen)
                        }
                    }
                }

                Text(elapsed)
                    .font(.system(size: 50, weight: .light, design: .monospaced))
                    .foregroundColor(state.isRunning ? Color(hex: subject.color) : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: subject.color).opacity(state.isRunning ? 0.07 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: subject.color).opacity(state.isRunning ? 0.25 : 0), lineWidth: 1.5)
            )

            // Action button
            Button(action: state.isRunning ? onStop : onStart) {
                HStack(spacing: 8) {
                    Image(systemName: state.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(state.isRunning ? "종료" : "시작")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(state.isRunning ? Color.red : Color.spGreen)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Daily Mission Card
struct DailyMissionCard: View {
    let missions: [Mission]
    let onComplete: (Int) -> Void

    var completedCount: Int { missions.filter { $0.isCompleted }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("일일 미션")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(completedCount)/\(missions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if missions.isEmpty {
                Text("오늘의 미션이 없습니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(missions.enumerated()), id: \.element.id) { i, mission in
                        MissionRowItem(mission: mission, onComplete: onComplete)
                        if i < missions.count - 1 {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
        }
        .spCard()
    }
}

struct MissionRowItem: View {
    let mission: Mission
    let onComplete: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 커스텀 체크박스
            Button {
                if !mission.isCompleted { onComplete(mission.id) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(mission.isCompleted ? Color.spGreen : Color.clear)
                        .frame(width: 20, height: 20)
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            mission.isCompleted ? Color.spGreen : Color.spBorder,
                            lineWidth: 1.5
                        )
                        .frame(width: 20, height: 20)
                    if mission.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(mission.title)
                .font(.system(size: 14))
                .foregroundColor(mission.isCompleted ? .secondary : .primary)
                .strikethrough(mission.isCompleted, color: Color.secondary.opacity(0.5))

            Spacer()

            Text("+\(mission.pxReward) PX")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(mission.isCompleted ? Color.secondary.opacity(0.6) : .spGreen)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(
                    (mission.isCompleted ? Color.secondary : Color.spGreen).opacity(0.08),
                    in: Capsule()
                )
        }
        .padding(.vertical, 10)
        .opacity(mission.isCompleted ? 0.7 : 1)
    }
}

// MARK: - Growth Card
struct GrowthCard: View {
    let user: User?

    struct PlantStage {
        let emoji: String
        let name: String
        let nextName: String
        let pxNeeded: Int
    }

    var stage: PlantStage {
        let level = user?.level ?? 1
        if level < 3  { return PlantStage(emoji: "🌱", name: "새싹", nextName: "모목", pxNeeded: 2000) }
        if level < 7  { return PlantStage(emoji: "🌿", name: "모목", nextName: "나무", pxNeeded: 5000) }
        if level < 15 { return PlantStage(emoji: "🌳", name: "나무", nextName: "고목", pxNeeded: 10000) }
        return           PlantStage(emoji: "🌲", name: "고목",  nextName: "전설", pxNeeded: 20000)
    }

    var progress: Double { min(Double(user?.px ?? 0) / Double(stage.pxNeeded), 1.0) }
    var pxToNext: Int    { max(stage.pxNeeded - (user?.px ?? 0), 0) }

    var body: some View {
        VStack(spacing: 0) {
            // 상단: 레벨 + 제목
            HStack {
                Text("성장")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.spMuted)
                Spacer()
                if let user {
                    HStack(spacing: 3) {
                        Text("Lv.\(user.level)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.spGreen)
                        Text("·")
                            .foregroundColor(Color.spMuted)
                        Text("\(user.px) PX")
                            .font(.system(size: 11))
                            .foregroundColor(Color.spMuted)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // 원형 진행 + 식물
            ZStack {
                Circle()
                    .stroke(Color.spGreen.opacity(0.1), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.spGreen, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)
                VStack(spacing: 4) {
                    Text(stage.emoji)
                        .font(.system(size: 40))
                    Text(stage.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.spInk)
                }
            }
            .frame(width: 110, height: 110)
            .padding(.bottom, 14)

            // 하단: 다음 단계
            HStack {
                Text("다음: \(stage.nextName)")
                    .font(.system(size: 11))
                    .foregroundColor(Color.spMuted)
                Spacer()
                Text("\(pxToNext) PX 남음")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.spGreen)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color.spCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color(hex: "#1A1A2E").opacity(0.06), radius: 6, x: 0, y: 1)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.spBorder.opacity(0.6), lineWidth: 0.5))
    }
}

// MARK: - HRV Status Card
struct HRVStatusCard: View {
    let hrv: HRVData?

    var stressColor: Color {
        guard let s = hrv?.stressIndex else { return .secondary }
        if s < 30 { return .spGreen }
        if s < 60 { return .orange }
        return .red
    }

    var stressLabel: String {
        guard let s = hrv?.stressIndex else { return "-" }
        if s < 30 { return "편안함" }
        if s < 60 { return "보통" }
        return "긴장됨"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                Text("컨디션")
                    .font(.system(size: 15, weight: .semibold))
            }

            if let hrv {
                HStack(spacing: 0) {
                    VStack(spacing: 3) {
                        Text("\(Int(hrv.stressIndex ?? 0))")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(stressColor)
                        Text("스트레스")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.spBorder)
                        .frame(width: 1, height: 36)

                    VStack(spacing: 3) {
                        Text("\(hrv.heartRate ?? 0)")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.red)
                        Text("BPM")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.spBorder)
                        .frame(width: 1, height: 36)

                    VStack(spacing: 3) {
                        Text(stressLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(stressColor)
                        Text("상태")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 24))
                        .foregroundColor(Color.secondary.opacity(0.35))
                    VStack(spacing: 3) {
                        Text("Watch 미연결")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("모바일 앱으로 HRV 측정")
                            .font(.system(size: 11))
                            .foregroundColor(Color.secondary.opacity(0.65))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
        }
        .spCard()
    }
}

// MARK: - Today Stats Card
struct TodayStatsCard: View {
    @ObservedObject var vm: MainViewModel

    var totalStudySeconds: Int {
        vm.timerStates.values.map { $0.elapsedSeconds }.reduce(0, +)
    }

    var totalFormatted: String {
        let s = totalStudySeconds
        if s < 60 { return "\(s)초" }
        if s < 3600 { return "\(s / 60)분" }
        return String(format: "%d시간 %d분", s / 3600, (s % 3600) / 60)
    }

    var completedMissions: Int { vm.missions.filter { $0.isCompleted }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("오늘의 통계")
                .font(.system(size: 15, weight: .semibold))

            VStack(spacing: 0) {
                TodayStatRow(icon: "timer",             iconColor: .spGreen,
                             label: "공부 시간",         value: totalStudySeconds > 0 ? totalFormatted : "0분")
                Divider().padding(.leading, 26)
                TodayStatRow(icon: "checkmark.circle",  iconColor: .orange,
                             label: "미션 완료",         value: "\(completedMissions)/\(vm.missions.count)")
                Divider().padding(.leading, 26)
                TodayStatRow(icon: "book.closed",       iconColor: Color(hex: "#007AFF"),
                             label: "등록 과목",         value: "\(vm.subjects.count)/10")
            }
        }
        .spCard()
    }
}

struct TodayStatRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
                .frame(width: 18, alignment: .center)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.vertical, 9)
    }
}

// MARK: - Add Subject Sheet
struct AddSubjectSheet: View {
    @ObservedObject var vm: MainViewModel

    let colors = [
        "#34C759", "#007AFF", "#FF9500", "#FF3B30",
        "#AF52DE", "#FF2D55", "#5AC8FA", "#FFCC00",
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("과목 추가")
                .font(.system(size: 20, weight: .bold))

            TextField("과목 이름", text: $vm.newSubjectName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("색상").font(.caption).foregroundColor(.secondary)
                HStack(spacing: 10) {
                    ForEach(colors, id: \.self) { color in
                        Button {
                            vm.newSubjectColor = color
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 30, height: 30)
                                if vm.newSubjectColor == color {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2.5)
                                        .frame(width: 30, height: 30)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("취소") { vm.showAddSubject = false }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button("추가") { Task { await vm.addSubject() } }
                    .buttonStyle(.borderedProminent)
                    .tint(.spGreen)
                    .frame(maxWidth: .infinity)
                    .disabled(vm.newSubjectName.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 360)
    }
}
