import Foundation
import HealthKit

@MainActor
final class HealthKitBridge: ObservableObject {
    private let healthStore = HKHealthStore()
    private let bridgeClient = StudyPulsBridgeClient()
    @Published var isAutoSyncing = false
    @Published var lastSyncSummary = "아직 전송한 HealthKit 샘플이 없습니다."
    @Published var lastHrv: Int?
    @Published var lastHeartRate: Int?
    private var syncTask: Task<Void, Never>?
    private var lastSyncedAt: Date {
        get { UserDefaults.standard.object(forKey: "StudyPulsGhost.lastSyncedAt") as? Date ?? .distantPast }
        set { UserDefaults.standard.set(newValue, forKey: "StudyPulsGhost.lastSyncedAt") }
    }

    private var hrvType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    }

    private var heartRateType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .heartRate)!
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw GhostBridgeError.healthKitUnavailable
        }

        try await healthStore.requestAuthorization(
            toShare: [],
            read: [hrvType, heartRateType]
        )

        try await healthStore.enableBackgroundDelivery(for: hrvType, frequency: .hourly)
        try await healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .hourly)
    }

    func syncRecentSamples(serverURL: URL, forceRecentHours: Int? = nil) async throws -> Int {
        let since = forceRecentHours
            .flatMap { Calendar.current.date(byAdding: .hour, value: -$0, to: Date()) }
            ?? max(lastSyncedAt, Calendar.current.date(byAdding: .hour, value: -12, to: Date()) ?? Date())
        let hrvSamples = try await quantitySamples(type: hrvType, since: since)
        let heartRateSamples = try await quantitySamples(type: heartRateType, since: since)

        var sent = 0
        var newestDate = lastSyncedAt
        for hrv in hrvSamples {
            let nearestHeartRate = nearest(sample: hrv, in: heartRateSamples)
            let heartRate = nearestHeartRate.map { Int($0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))) } ?? 0
            let hrvValue = Int(hrv.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)))
            let payload = HealthPayload(
                heartRate: heartRate,
                hrv: hrvValue,
                timestamp: ISO8601DateFormatter().string(from: hrv.startDate)
            )
            try await bridgeClient.send(payload: payload, serverURL: serverURL)
            lastHeartRate = heartRate
            lastHrv = hrvValue
            newestDate = max(newestDate, hrv.startDate)
            sent += 1
        }
        if newestDate > lastSyncedAt {
            lastSyncedAt = newestDate
        }
        lastSyncSummary = sent == 0
            ? "새 HRV 샘플이 없습니다. Apple Watch가 HRV를 기록하면 자동 전송됩니다."
            : "\(sent)개 HRV 샘플 전송 완료"
        return sent
    }

    func startAutoSync(serverURL: URL) {
        guard !isAutoSyncing else { return }
        isAutoSyncing = true
        syncTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.requestAuthorization()
            } catch {
                await MainActor.run {
                    self.isAutoSyncing = false
                    self.lastSyncSummary = error.localizedDescription
                }
                return
            }

            while !Task.isCancelled {
                do {
                    _ = try await self.syncRecentSamples(serverURL: serverURL)
                } catch {
                    await MainActor.run {
                        self.lastSyncSummary = error.localizedDescription
                    }
                }
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    func stopAutoSync() {
        syncTask?.cancel()
        syncTask = nil
        isAutoSyncing = false
        lastSyncSummary = "자동 전송 중지됨"
    }

    private func quantitySamples(type: HKQuantityType, since: Date) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: since,
                end: Date(),
                options: [.strictStartDate]
            )
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func nearest(sample: HKQuantitySample, in samples: [HKQuantitySample]) -> HKQuantitySample? {
        samples.min { lhs, rhs in
            abs(lhs.startDate.timeIntervalSince(sample.startDate)) < abs(rhs.startDate.timeIntervalSince(sample.startDate))
        }
    }
}

enum GhostBridgeError: LocalizedError {
    case healthKitUnavailable

    var errorDescription: String? {
        switch self {
        case .healthKitUnavailable:
            "HealthKit을 사용할 수 없는 기기입니다."
        }
    }
}
