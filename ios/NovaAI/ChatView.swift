import SwiftUI

struct ChatView: View {
    let isChinese: Bool
    @State private var input = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "Hi! I'm Nova. How can I help?")
    ]
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            if isSending {
                                HStack {
                                    ProgressView()
                                    Text(isChinese ? "Nova 正在思考…" : "Nova is thinking…")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                HStack(alignment: .bottom, spacing: 10) {
                    TextField(isChinese ? "向 Nova 提问…" : "Message Nova…", text: $input, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.roundedBorder)

                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
                .padding()
            }
            .navigationTitle("Nova AI")
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(ChatMessage(role: .user, content: text))
        input = ""
        errorMessage = nil
        isSending = true

        Task {
            do {
                let reply = try await APIClient.shared.sendMessage(messages: messages)
                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant, content: reply))
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = isChinese ? "连接服务失败，请检查服务器地址和网络。" : "Could not reach the server. Check the server URL and network."
                    isSending = false
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant { bubble }
            else {
                Spacer(minLength: 36)
                bubble
            }
            if message.role == .assistant { Spacer(minLength: 36) }
        }
    }

    private var bubble: some View {
        Text(message.content)
            .padding(12)
            .background(message.role == .user ? Color.indigo : Color(.secondarySystemBackground))
            .foregroundStyle(message.role == .user ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
