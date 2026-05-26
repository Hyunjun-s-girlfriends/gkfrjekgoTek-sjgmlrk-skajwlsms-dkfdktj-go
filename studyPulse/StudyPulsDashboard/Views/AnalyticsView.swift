import SwiftUI
import Charts

struct HRVHourResponse: Codable {
    let hrv: [HRVByHour]
    let sessions: [SessionHour]
}

struct SessionHour: Codable {
    let hour: Int
    let subjectName: String?
    let color: String?
    let durationSeconds: Int

    enum CodingKeys: String, CodingKey {
        case hour
        case subjectName = "subject_name"
        case color
        case durationSeconds = "duration_seconds"
    }
}

struct AnalyticsView: View {
    @State private var weeklyStress: [WeeklyStress] = []
    @State private var hvByHour: HRVHourResponse?
    @State private var monthlySubjects: [SubjectSummary] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 주간 스트레스 그래프
                WeeklyStressChart(data: weeklyStress)

                // 시간대별 HRV + 과목
                HRVByHourChart(data: hvByHour)

                // 과목별 공부 시간
                SubjectTimeChart(subjects: monthlySubjects)
            }
            .padding(20)
        }
        .background(Color.spBG)
        .task { await loadData() }
    }

    func loadData() async {
        async let ws: [WeeklyStress] = APIClient.shared.get("/api/analytics/weekly-stress")
        async let hourly: HRVHourResponse = APIClient.shared.get("/api/analytics/hrv-by-hour")
        async let monthly: [SubjectSummary] = APIClient.shared.get("/api/analytics/subjects-monthly")
        do {
            weeklyStress = try await ws
            hvByHour = try await hourly
            monthlySubjects = try await monthly
        } catch {}
    }
}

// MARK: - Weekly Stress Chart
struct WeeklyStressChart: View {
    let data: [WeeklyStress]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("주간 스트레스 지수").font(.headline)

            if data.isEmpty {
                Text("데이터 없음").font(.subheadline).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).frame(height: 120)
            } else {
                Chart {
                    ForEach(data, id: \.date) { item in
                        LineMark(
                            x: .value("날짜", item.date),
                            y: .value("스트레스", item.avgStress ?? 0)
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("날짜", item.date),
                            y: .value("스트레스", item.avgStress ?? 0)
                        )
                        .foregroundStyle(.red.opacity(0.1))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("날짜", item.date),
                            y: .value("스트레스", item.avgStress ?? 0)
                        )
                        .foregroundStyle(.red)
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 160)
            }
        }
        .padding(20)
        .spCard()
    }
}

// MARK: - HRV By Hour Chart
struct HRVByHourChart: View {
    let data: HRVHourResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("시간대별 HRV & 공부 과목").font(.headline)

            if let data, !data.hrv.isEmpty {
                Chart(data.hrv, id: \.hour) { item in
                    BarMark(
                        x: .value("시간", "\(item.hour)시"),
                        y: .value("HRV", item.avgHrv ?? 0)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .bottom, endPoint: .top)
                    )
                }
                .frame(height: 160)

                // 과목 오버레이 설명
                if !data.sessions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(data.sessions, id: \.hour) { session in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: session.color ?? "#007AFF"))
                                        .frame(width: 8, height: 8)
                                    Text("\(session.hour)시 \(session.subjectName ?? "미분류")")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.regularMaterial, in: Capsule())
                            }
                        }
                    }
                }
            } else {
                Text("HRV 데이터 없음 (Apple Watch 연동 필요)")
                    .font(.subheadline).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).frame(height: 100)
            }
        }
        .padding(20)
        .spCard()
    }
}

// MARK: - Subject Time Chart
struct SubjectTimeChart: View {
    let subjects: [SubjectSummary]

    var totalSeconds: Int { subjects.reduce(0) { $0 + $1.totalSeconds } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이번 달 과목별 공부 시간").font(.headline)

            if subjects.isEmpty {
                Text("데이터 없음").font(.subheadline).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).frame(height: 80)
            } else {
                ForEach(subjects) { subject in
                    let ratio = totalSeconds > 0 ? Double(subject.totalSeconds) / Double(totalSeconds) : 0
                    HStack(spacing: 12) {
                        Circle().fill(Color(hex: subject.color)).frame(width: 10, height: 10)
                        Text(subject.name).font(.subheadline).frame(width: 100, alignment: .leading)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: subject.color).opacity(0.2))
                            .frame(height: 16)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: subject.color))
                                    .scaleEffect(x: max(ratio, 0.001), y: 1.0, anchor: .leading)
                            }
                        Text(formatTime(subject.totalSeconds))
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .spCard()
    }

    func formatTime(_ s: Int) -> String {
        if s < 3600 { return "\(s / 60)분" }
        return String(format: "%d시간 %d분", s / 3600, (s % 3600) / 60)
    }
}
