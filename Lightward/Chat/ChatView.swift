import SwiftUI

/// Streaming chat interface with Lightward AI.
struct ChatView: View {
    @Bindable var vm: ChatViewModel
    var onStartOver: () -> Void

    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Observer mark
                        Text("⏿")
                            .font(.title2)
                            .padding(.bottom, 8)

                        ForEach(vm.messages) { message in
                            MessageView(message: message)
                        }

                        if vm.streaming {
                            StreamingIndicator()
                        }

                        Spacer().frame(height: 80)
                            .id("bottom")
                    }
                    .padding(24)
                    .frame(maxWidth: 480, alignment: .leading)
                }
                .onChange(of: vm.streamingText) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: vm.messages.count) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Input bar
            HStack(spacing: 12) {
                TextField("", text: $vm.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.warmText)
                    .lineLimit(1...6)
                    .focused($inputFocused)
                    .onSubmit {
                        vm.send()
                    }

                if !vm.inputText.isEmpty {
                    Button(action: { vm.send() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.warmAccent)
                    }
                    .disabled(vm.streaming)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.background.opacity(0.95))

            // Footer
            HStack {
                Button(action: onStartOver) {
                    Text("→ start over")
                        .font(.caption)
                        .foregroundStyle(.warmText.opacity(0.3))
                }
                Spacer()
                Text("your conversation is private")
                    .font(.caption)
                    .foregroundStyle(.warmText.opacity(0.3))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Message View

struct MessageView: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.text)
                .font(.body)
                .foregroundStyle(
                    message.role == .user
                        ? Color.warmText
                        : Color.warmText.opacity(0.85)
                )
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Streaming Indicator

struct StreamingIndicator: View {
    @State private var visible = true

    var body: some View {
        Text("▍")
            .font(.body)
            .foregroundStyle(.warmAccent)
            .opacity(visible ? 1 : 0.3)
            .animation(.easeInOut(duration: 0.5).repeatForever(), value: visible)
            .onAppear { visible.toggle() }
    }
}
