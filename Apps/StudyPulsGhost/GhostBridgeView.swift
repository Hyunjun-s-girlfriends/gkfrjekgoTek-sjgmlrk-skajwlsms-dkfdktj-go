import SwiftUI

struct GhostBridgeView: View {
    @StateObject private var bridge = HealthKitBridge()
    @State private var serverURL = "http://127.0.0.1:3000"
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

                Button("HRV 샘플 전송") {
                    Task {
                        do {
                            let count = try await bridge.syncRecentSamples(serverURL: URL(string: serverURL)!)
                            status = "\(count)개 샘플 전송 완료"
                        } catch {
                            status = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.bordered)
            }

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
