import Foundation

struct DashboardResponse: Decodable {
    let user: StudyUser
    let totals: Totals
    let subjects: [SubjectSummary]
    let recentSessions: [StudySession]
    let currentSession: StudySession?
    let devices: [DeviceStatus]?

    struct Totals: Decodable {
        let totalMinutes: Int
        let sessionCount: Int
        let avgStress: Int
        let avgFocus: Int
        let bestHour: String
        let drowsyCount: Int?
        let missionDone: Int
        let missionTotal: Int
    }
}

struct StudyUser: Decodable {
    let id: String
    let username: String?
    let name: String
    let xp: Int
    let credits: Int
    let title: String
}

struct SubjectSummary: Decodable, Identifiable {
    let id: String
    let name: String
    let color: String
    let totalMinutes: Int
    let avgStress: Int
    let avgFocus: Int
}

struct StudySession: Decodable, Identifiable {
    let id: String
    let subjectName: String
    let startedAt: String
    let endedAt: String?
    let totalMinutes: Int
    let avgStress: Int?
    let avgFocus: Int?
    let avgHeartRate: Int?
    let avgHrv: Int?
}

struct FocusPoint: Decodable, Identifiable {
    var id: String { hour }
    let hour: String
    let focus: Int
}

struct StressSample: Decodable, Identifiable {
    var id: String { timestamp }
    let timestamp: String
    let hour: String
    let stress: Int
    let focus: Int
    let heartRate: Int
    let hrv: Int
}

struct DrowsinessPoint: Decodable, Identifiable {
    var id: String { hour }
    let hour: String
    let count: Int
    let avgSleepyScore: Int
    let totalMinutes: Int
}

struct MotionEvent: Decodable, Identifiable {
    let id: String
    let sessionId: String?
    let pitch: Double
    let roll: Double
    let yaw: Double
    let sleepyScore: Int
    let downDurationSeconds: Int
    let detectedAt: String
    let source: String
    let type: String
}

struct DeviceStatusResponse: Decodable {
    let devices: [DeviceStatus]
}

struct DeviceStatus: Decodable, Identifiable {
    let id: String
    let name: String
    let deviceType: String
    let status: String
    let bridgeMode: Bool
    let lastSyncedAt: String?
}

struct CoachResponse: Decodable {
    let provider: String
    let summary: String
    let bestTime: String
    let weakTime: String
    let coaching: String
    let nextActions: [String]
}

struct RankingResponse: Decodable {
    let groupId: String
    let rows: [RankingRow]
}

struct RankingRow: Decodable, Identifiable {
    var id: String { userId }
    let userId: String
    let name: String
    let xp: Int
    let totalMinutes: Int
    let rank: Int
    let rewardCredits: Int
}
