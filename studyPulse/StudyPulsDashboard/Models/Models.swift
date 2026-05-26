import Foundation

// MARK: - User
struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let name: String
    let profileImage: String?
    let description: String?
    let organization: String?
    let level: Int
    let px: Int
    let streakDays: Int
    let maxStreakDays: Int

    enum CodingKeys: String, CodingKey {
        case id, email, name, description, organization, level, px
        case profileImage = "profile_image"
        case streakDays = "streak_days"
        case maxStreakDays = "max_streak_days"
    }
}

// MARK: - Subject
struct Subject: Codable, Identifiable {
    let id: Int
    var name: String
    var color: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, color
        case sortOrder = "sort_order"
    }
}

// MARK: - TimerSession
struct TimerSession: Codable, Identifiable {
    let id: Int
    let userId: Int
    let subjectId: Int?
    let subjectName: String?
    let subjectColor: String?
    let startTime: String
    let endTime: String?
    let durationSeconds: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case subjectId = "subject_id"
        case subjectName = "subject_name"
        case subjectColor = "subject_color"
        case startTime = "start_time"
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
    }
}

struct SubjectSummary: Codable, Identifiable {
    let id: Int
    let name: String
    let color: String
    let totalSeconds: Int

    enum CodingKeys: String, CodingKey {
        case id, name, color
        case totalSeconds = "total_seconds"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id    = try c.decode(Int.self,    forKey: .id)
        name  = try c.decode(String.self, forKey: .name)
        color = try c.decode(String.self, forKey: .color)
        // MySQL SUM()은 String으로 내려올 수 있음
        if let intVal = try? c.decode(Int.self, forKey: .totalSeconds) {
            totalSeconds = intVal
        } else if let strVal = try? c.decode(String.self, forKey: .totalSeconds) {
            totalSeconds = Int(strVal) ?? 0
        } else {
            totalSeconds = 0
        }
    }
}

// MARK: - HRV
struct HRVData: Codable, Identifiable {
    let id: Int
    let userId: Int
    let hrvSdnn: Double?
    let heartRate: Int?
    let stressIndex: Double?
    let recordedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case hrvSdnn = "hrv_sdnn"
        case heartRate = "heart_rate"
        case stressIndex = "stress_index"
        case recordedAt = "recorded_at"
    }
}

// MARK: - Group
struct StudyGroup: Codable, Identifiable {
    let id: Int
    var name: String
    var description: String?
    var icon: String
    let inviteCode: String
    let ownerId: Int
    let maxMembers: Int
    let totalPx: Int
    let missionClearCount: Int
    var memberCount: Int?
    var ownerName: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon
        case inviteCode = "invite_code"
        case ownerId = "owner_id"
        case maxMembers = "max_members"
        case totalPx = "total_px"
        case missionClearCount = "mission_clear_count"
        case memberCount = "member_count"
        case ownerName = "owner_name"
    }

    // MySQL COUNT/SUM 집계 필드가 문자열로 올 수 있어 방어적 디코딩
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(Int.self,    forKey: .id)
        name             = try c.decode(String.self, forKey: .name)
        description      = try c.decodeIfPresent(String.self, forKey: .description)
        icon             = (try? c.decode(String.self, forKey: .icon)) ?? "person.3.fill"
        inviteCode       = try c.decode(String.self, forKey: .inviteCode)
        ownerId          = try c.decode(Int.self,    forKey: .ownerId)
        maxMembers       = Self.decodeFlexInt(c, key: .maxMembers)  ?? 8
        totalPx          = Self.decodeFlexInt(c, key: .totalPx)     ?? 0
        missionClearCount = Self.decodeFlexInt(c, key: .missionClearCount) ?? 0
        memberCount      = Self.decodeFlexInt(c, key: .memberCount)
        ownerName        = try c.decodeIfPresent(String.self, forKey: .ownerName)
    }

    // Int 또는 String("42") 모두 허용하는 헬퍼
    private static func decodeFlexInt(
        _ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys
    ) -> Int? {
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let s = try? c.decode(String.self, forKey: key) { return Int(s) }
        return nil
    }
}

struct GroupMember: Codable, Identifiable {
    let id: Int
    let name: String
    let profileImage: String?
    let level: Int
    let px: Int
    let todayStudySeconds: Int   // 서버가 "0" (String)으로 내려올 수 있음

    enum CodingKeys: String, CodingKey {
        case id, name, level, px
        case profileImage = "profile_image"
        case todayStudySeconds = "today_study_seconds"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(Int.self,    forKey: .id)
        name         = try c.decode(String.self, forKey: .name)
        profileImage = try c.decodeIfPresent(String.self, forKey: .profileImage)
        level        = try c.decode(Int.self,    forKey: .level)
        px           = try c.decode(Int.self,    forKey: .px)
        // today_study_seconds: Int 또는 String "0" 모두 허용
        if let intVal = try? c.decode(Int.self, forKey: .todayStudySeconds) {
            todayStudySeconds = intVal
        } else if let strVal = try? c.decode(String.self, forKey: .todayStudySeconds) {
            todayStudySeconds = Int(strVal) ?? 0
        } else {
            todayStudySeconds = 0
        }
    }
}

struct GroupMessage: Codable, Identifiable {
    let id: Int
    let groupId: Int
    let userId: Int
    let message: String
    let userName: String
    let profileImage: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, message
        case groupId = "group_id"
        case userId = "user_id"
        case userName = "user_name"
        case profileImage = "profile_image"
        case createdAt = "created_at"
    }
}

// MARK: - Mission
struct Mission: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let type: String
    let missionType: String
    let targetValue: Double
    let pxReward: Int
    let completedToday: Int   // LEFT JOIN 결과 — 미완료 행에서는 null/누락될 수 있음

    var isCompleted: Bool { completedToday > 0 }

    enum CodingKeys: String, CodingKey {
        case id, title, description, type
        case missionType = "mission_type"
        case targetValue = "target_value"
        case pxReward = "px_reward"
        case completedToday = "completed_today"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(Int.self,    forKey: .id)
        title       = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        type        = try c.decode(String.self, forKey: .type)
        missionType = try c.decode(String.self, forKey: .missionType)
        targetValue = try c.decode(Double.self, forKey: .targetValue)
        pxReward    = try c.decode(Int.self,    forKey: .pxReward)
        // completed_today: 없거나 null이면 0으로 처리
        completedToday = (try? c.decodeIfPresent(Int.self, forKey: .completedToday)) ?? 0
    }
}

// MARK: - Ranking
struct PersonalRanking: Codable, Identifiable {
    let id: Int
    let name: String
    let profileImage: String?
    let level: Int
    let px: Int
    let totalStudyToday: Int   // 서버가 "0" (String)으로 내려올 수 있으므로 커스텀 디코딩
    let rankPosition: Int

    enum CodingKeys: String, CodingKey {
        case id, name, level, px
        case profileImage = "profile_image"
        case totalStudyToday = "total_study_today"
        case rankPosition = "rank_position"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(Int.self,    forKey: .id)
        name         = try c.decode(String.self, forKey: .name)
        profileImage = try c.decodeIfPresent(String.self, forKey: .profileImage)
        level        = try c.decode(Int.self,    forKey: .level)
        px           = try c.decode(Int.self,    forKey: .px)
        // rank_position: RANK() OVER — mysql2가 String으로 줄 수 있음
        if let intVal = try? c.decode(Int.self, forKey: .rankPosition) {
            rankPosition = intVal
        } else if let strVal = try? c.decode(String.self, forKey: .rankPosition) {
            rankPosition = Int(strVal) ?? 0
        } else {
            rankPosition = 0
        }
        // total_study_today: Int 또는 String "0" 모두 허용
        if let intVal = try? c.decode(Int.self, forKey: .totalStudyToday) {
            totalStudyToday = intVal
        } else if let strVal = try? c.decode(String.self, forKey: .totalStudyToday) {
            totalStudyToday = Int(strVal) ?? 0
        } else {
            totalStudyToday = 0
        }
    }
}

struct GroupRanking: Codable, Identifiable {
    let id: Int
    let name: String
    let icon: String
    let totalPx: Int
    let missionClearCount: Int
    let memberCount: Int
    let rankPosition: Int

    enum CodingKeys: String, CodingKey {
        case id, name, icon
        case totalPx = "total_px"
        case missionClearCount = "mission_clear_count"
        case memberCount = "member_count"
        case rankPosition = "rank_position"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(Int.self,    forKey: .id)
        name             = try c.decode(String.self, forKey: .name)
        icon             = (try? c.decode(String.self, forKey: .icon)) ?? "person.3.fill"
        totalPx          = Self.flexInt(c, .totalPx)          ?? 0
        missionClearCount = Self.flexInt(c, .missionClearCount) ?? 0
        memberCount      = Self.flexInt(c, .memberCount)      ?? 0
        rankPosition     = Self.flexInt(c, .rankPosition)     ?? 0
    }

    private static func flexInt(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let v = try? c.decode(Int.self,    forKey: key) { return v }
        if let s = try? c.decode(String.self, forKey: key) { return Int(s) }
        return nil
    }
}

// MARK: - Analytics
struct HRVByHour: Codable {
    let hour: Int
    let avgHrv: Double?
    let avgHr: Double?
    let avgStress: Double?

    enum CodingKeys: String, CodingKey {
        case hour
        case avgHrv = "avg_hrv"
        case avgHr = "avg_hr"
        case avgStress = "avg_stress"
    }
}

struct WeeklyStress: Codable {
    let date: String
    let avgStress: Double?
    let avgHrv: Double?
    let avgHr: Double?

    enum CodingKeys: String, CodingKey {
        case date
        case avgStress = "avg_stress"
        case avgHrv = "avg_hrv"
        case avgHr = "avg_hr"
    }
}

// MARK: - Auth Response
struct AuthResponse: Codable {
    let token: String
    let user: User
}
