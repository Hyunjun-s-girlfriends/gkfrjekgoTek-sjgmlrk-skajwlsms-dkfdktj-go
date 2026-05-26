import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String  // "user" | "assistant"
    let content: String
}

// MARK: - AIView
struct AIView: View {
    @State private var chatMessages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isChatLoading = false

    let suggestedQuestions = [
        "오늘 공부 효율을 높이는 방법은?",
        "집중력이 떨어질 때 어떻게 해야 하나요?",
        "스트레스를 줄이면서 공부하는 방법은?",
        "포모도로 기법이 효과적인가요?",
        "암기 효율을 높이는 방법은?",
    ]

    var body: some View {
        HStack(spacing: 0) {
            // ── Left: Chat area ────────────────────────────────────────────
            VStack(spacing: 0) {
                // AI Header
                AIChatHeader()

                Divider()

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if chatMessages.isEmpty {
                                AIChatWelcome()
                                    .padding(.top, 8)
                            } else {
                                ForEach(chatMessages) { msg in
                                    AIChatBubbleNew(message: msg)
                                        .id(msg.id)
                                }
                            }

                            if isChatLoading {
                                AITypingIndicator()
                            }
                        }
                        .padding(20)
                    }
                    .onChange(of: chatMessages.count) { _ in
                        if let last = chatMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()

                // Input field
                HStack(spacing: 10) {
                    TextField("메세지를 입력하세요...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .lineLimit(1...4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.spBG, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.spBorder, lineWidth: 1))
                        .onSubmit {
                            if !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                                Task { await sendChat() }
                            }
                        }

                    Button {
                        Task { await sendChat() }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                inputText.trimmingCharacters(in: .whitespaces).isEmpty || isChatLoading
                                    ? Color.secondary.opacity(0.3)
                                    : Color.spGreen,
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isChatLoading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.spCard)
            }
            .frame(maxWidth: .infinity)
            .background(Color.spCard)

            Divider()

            // ── Right: Suggested questions ─────────────────────────────────
            VStack(alignment: .leading, spacing: 16) {
                Text("추천 질문")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.top, 20)
                    .padding(.horizontal, 16)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(suggestedQuestions, id: \.self) { q in
                            Button {
                                inputText = q
                                Task { await sendChat() }
                            } label: {
                                Text(q)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.spBG, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.spBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }

                Spacer()
            }
            .frame(width: 260)
            .background(Color.spBG)
        }
    }

    func sendChat() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        chatMessages.append(.init(role: "user", content: text))
        isChatLoading = true

        struct ChatRequest: Codable { let message: String; let history: [[String: String]] }
        struct ChatResponse: Codable { let reply: String }

        let history = chatMessages.dropLast().map { ["role": $0.role, "content": $0.content] }
        do {
            let resp: ChatResponse = try await APIClient.shared.post(
                "/api/ai/chat",
                body: ["message": text, "history": history] as [String: Any]
            )
            chatMessages.append(.init(role: "assistant", content: resp.reply))
        } catch {
            chatMessages.append(.init(role: "assistant", content: "오류가 발생했습니다. 서버 연결을 확인해주세요."))
        }
        isChatLoading = false
    }
}

// MARK: - AI Chat Header
struct AIChatHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            // AI Avatar
            ZStack {
                Circle()
                    .fill(Color.spGreenLt)
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.spGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("학습 도우미")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.spInk)
                Text("공부 전략 · 집중력 · 시험 준비")
                    .font(.system(size: 12))
                    .foregroundColor(Color.spMuted)
            }

            Spacer()

            // Online indicator
            HStack(spacing: 5) {
                Circle().fill(Color.spGreen).frame(width: 6, height: 6)
                Text("온라인").font(.system(size: 11)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.spBG, in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.spCard)
    }
}

// MARK: - Welcome state
struct AIChatWelcome: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.spGreenLt)
                    .frame(width: 64, height: 64)
                Text("📚")
                    .font(.system(size: 30))
            }
            Text("무엇이든 물어보세요")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color.spInk)
            Text("공부법, 암기 전략, 집중력 유지 방법까지\n솔직하게 답해드릴게요.")
                .font(.system(size: 13))
                .foregroundColor(Color.spMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Chat Bubble
struct AIChatBubbleNew: View {
    let message: ChatMessage
    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !isUser {
                // AI avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.spGreen.opacity(0.18), Color(hex: "#007AFF").opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.spGreen)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if !isUser {
                    Text("AI 어시스턴트")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Text(message.content)
                    .font(.system(size: 14))
                    .lineSpacing(5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser ? Color.spGreen : Color(red: 0.94, green: 0.94, blue: 0.96),
                        in: RoundedRectangle(cornerRadius: 16,
                                             style: isUser ? .continuous : .continuous)
                    )
                    .foregroundColor(isUser ? .white : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: 480, alignment: isUser ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if isUser {
                // User avatar
                ZStack {
                    Circle().fill(Color.secondary.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: "person.fill")
                        .font(.system(size: 14)).foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Typing indicator
struct AITypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.spGreen.opacity(0.18), Color(hex: "#007AFF").opacity(0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles").font(.system(size: 13, weight: .medium)).foregroundColor(.spGreen)
            }

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary.opacity(phase == i ? 0.8 : 0.3))
                        .frame(width: 7, height: 7)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 0.94, green: 0.94, blue: 0.96), in: RoundedRectangle(cornerRadius: 16))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                    phase = (phase + 1) % 3
                }
            }

            Spacer()
        }
    }
}

// Legacy AIChatBubble kept for compile compatibility
struct AIChatBubble: View {
    let message: ChatMessage
    var isUser: Bool { message.role == "user" }
    var body: some View {
        AIChatBubbleNew(message: message)
    }
}
