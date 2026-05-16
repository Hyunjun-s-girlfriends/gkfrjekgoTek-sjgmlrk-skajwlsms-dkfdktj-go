import Foundation
import SwiftUI

#if canImport(CoreMotion)
import CoreMotion
#endif

@MainActor
final class AirPodsMotionMonitor: ObservableObject {
    @Published var statusText = "대기 중"
    @Published var isConnected = false
    @Published var lastPitchDegrees = 0.0
    @Published var downDurationSeconds = 0
    @Published var lastEventText = "아직 감지된 졸림 이벤트가 없습니다."

    private let endpoint = URL(string: "http://127.0.0.1:3000/api/motion/headphone-sample")!
    private var downStartedAt: Date?
    private var lastSentAt: Date?

    #if canImport(CoreMotion)
    private let manager = CMHeadphoneMotionManager()
    private let queue = OperationQueue()
    #endif

    func connect() {
        Task {
            do {
                try await LocalServerManager.shared.ensureRunning()
                startMotionUpdates()
            } catch {
                statusText = "로컬 서버 확인 필요"
                lastEventText = error.localizedDescription
            }
        }
    }

    func disconnect() {
        #if canImport(CoreMotion)
        manager.stopDeviceMotionUpdates()
        #endif
        isConnected = false
        statusText = "연결 해제"
        downStartedAt = nil
        downDurationSeconds = 0
    }

    private func startMotionUpdates() {
        #if canImport(CoreMotion)
        guard manager.isDeviceMotionAvailable else {
            isConnected = false
            statusText = "지원 AirPods 연결 필요"
            lastEventText = "CoreMotion head tracking을 지원하는 AirPods가 연결되면 수집을 시작합니다."
            return
        }

        queue.name = "StudyPuls.AirPodsMotion"
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.isConnected = false
                    self.statusText = "연결 오류"
                    self.lastEventText = error.localizedDescription
                    return
                }
                guard let motion else { return }
                self.isConnected = true
                self.statusText = "CoreMotion 수신 중"
                self.handle(motion: motion)
            }
        }
        #else
        isConnected = false
        statusText = "CoreMotion 미지원"
        lastEventText = "이 빌드 환경에서는 CoreMotion을 사용할 수 없습니다."
        #endif
    }

    #if canImport(CoreMotion)
    private func handle(motion: CMDeviceMotion) {
        let pitch = motion.attitude.pitch
        let roll = motion.attitude.roll
        let yaw = motion.attitude.yaw
        let pitchDegrees = pitch * 180 / .pi
        lastPitchDegrees = pitchDegrees

        let isHeadDropped = abs(pitchDegrees) >= 35
        if isHeadDropped {
            if downStartedAt == nil {
                downStartedAt = Date()
            }
            downDurationSeconds = Int(Date().timeIntervalSince(downStartedAt ?? Date()))
        } else {
            downStartedAt = nil
            downDurationSeconds = 0
        }

        guard downDurationSeconds >= 60 else { return }
        if let lastSentAt, Date().timeIntervalSince(lastSentAt) < 90 {
            return
        }
        lastSentAt = Date()
        let sleepyScore = min(100, max(60, Int(abs(pitchDegrees) * 1.8)))
        lastEventText = "\(downDurationSeconds)초 동안 고개 숙임 감지"

        Task {
            await postMotionEvent(
                pitch: pitch,
                roll: roll,
                yaw: yaw,
                sleepyScore: sleepyScore,
                downDurationSeconds: downDurationSeconds
            )
        }
    }
    #endif

    private func postMotionEvent(
        pitch: Double,
        roll: Double,
        yaw: Double,
        sleepyScore: Int,
        downDurationSeconds: Int
    ) async {
        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "pitch": pitch,
                "roll": roll,
                "yaw": yaw,
                "sleepyScore": sleepyScore,
                "downDurationSeconds": downDurationSeconds,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "source": "airpods-core-motion"
            ])
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            lastEventText = "졸림 이벤트 전송 완료"
        } catch {
            lastEventText = error.localizedDescription
        }
    }
}
