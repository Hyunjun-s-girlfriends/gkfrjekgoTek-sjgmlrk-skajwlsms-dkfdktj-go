import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var isLoading = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e"), Color(hex: "#0f3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // 로고
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 100, height: 100)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }

                    Text("StudyPulse")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("AI 기반 통합 학습 분석 플랫폼")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                // 기능 소개
                VStack(spacing: 12) {
                    FeatureRow(icon: "applewatch", text: "Apple Watch HRV 실시간 분석")
                    FeatureRow(icon: "chart.bar.fill", text: "공부 효율 시각화 & AI 피드백")
                    FeatureRow(icon: "person.3.fill", text: "그룹 학습 & 랭킹 시스템")
                    FeatureRow(icon: "leaf.fill", text: "게임화된 성장 시스템")
                }
                .padding(.horizontal, 60)

                Spacer()

                // Google 로그인 버튼
                Button(action: {
                    isLoading = true
                    Task {
                        await auth.loginWithGoogle()
                        isLoading = false
                    }
                }) {
                    HStack(spacing: 12) {
                        if isLoading {
                            ProgressView().controlSize(.small).tint(.gray)
                        } else {
                            Image(systemName: "globe")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        Text(isLoading ? "로그인 중..." : "Google로 계속하기")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 280, height: 50)
                    .background(.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                if let err = auth.loginError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Text("로그인 시 이용약관에 동의하게 됩니다")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))

                Spacer().frame(height: 40)
            }
        }
        .frame(width: 500, height: 700)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
