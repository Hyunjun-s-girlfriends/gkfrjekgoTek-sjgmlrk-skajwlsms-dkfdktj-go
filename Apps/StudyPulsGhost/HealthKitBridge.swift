import Foundation
import HealthKit

@MainActor
final class HealthKitBridge: ObservableObject {
    private let healthStore = HKHealthStore()
    private let bridgeClient = StudyPulsBridgeClient()

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

    func syncRecentSamples(serverURL: URL) async throws -> Int {
        let since = Calendar.current.date(byAdding: .hour, value: -12, to: Date()) ?? Date()
        let hrvSamples = try await quantitySamples(type: hrvType, since: since)
        let heartRateSamples = try await quantitySamples(type: heartRateType, since: since)

        var sent = 0
        for hrv in hrvSamples {
            let nearestHeartRate = nearest(sample: hrv, in: heartRateSamples)
            let payload = HealthPayload(
                heartRate: nearestHeartRate.map { Int($0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))) } ?? 0,
                hrv: Int(hrv.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))),
                timestamp: ISO8601DateFormatter().string(from: hrv.startDate)
            )
            try await bridgeClient.send(payload: payload, serverURL: serverURL)
            sent += 1
        }
        return sent
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
