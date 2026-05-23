import SwiftUI

struct GhostBridgeView: View {
    @StateObject private var bridge = HealthKitBridge()
    @AppStorage("StudyPulsGhost.serverURL") private var serverURL = "http://맥북IP:3000"
    @State private var status = "대기 중"

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            VStack(spacing: 8) {
                Text("StudyPuls Ghost")
                    .font(.title.bold())
                Text("Apple Watch HRV를 StudyPuls로 넘기는 브리지")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("StudyPuls 서버 URL", text: $serverURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            VStack(spacing: 10) {
                Button("HealthKit 권한 요청") {
                    Task {
                        do {
                            try await bridge.requestAuthorization()
                            status = "HealthKit 권한 확인 완료"
                        } catch {
                            status = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("최근 HRV 바로 전송") {
                    Task {
                        do {
                            let count = try await bridge.syncRecentSamples(serverURL: URL(string: serverURL)!, forceRecentHours: 12)
                            status = "\(count)개 샘플 전송 완료"
                        } catch {
                            status = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.bordered)

                Button(bridge.isAutoSyncing ? "자동 전송 중지" : "실제 HRV 자동 전송 시작") {
                    guard let url = URL(string: serverURL) else {
                        status = "서버 URL을 확인하세요."
                        return
                    }
                    if bridge.isAutoSyncing {
                        bridge.stopAutoSync()
                        status = "자동 전송 중지됨"
                    } else {
                        bridge.startAutoSync(serverURL: url)
                        status = "Apple Watch HRV 자동 전송 중"
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if let hrv = bridge.lastHrv {
                Text("최근 전송 HRV \(hrv)ms · HR \(bridge.lastHeartRate ?? 0)")
                    .font(.headline)
            }

            Text(bridge.lastSyncSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}
