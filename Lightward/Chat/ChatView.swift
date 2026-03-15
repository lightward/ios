import SwiftUI

/// Streaming chat interface with Lightward AI.
struct ChatView: View {
    @Bindable var vm: ChatViewModel
    var onStartOver: () -> Void

    @FocusState private var inputFocused: Bool
    @State private var showingStartOverConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Messages — bottom-anchored so content hugs the input area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Aura arrow
                        AuraArrow(size: 48)
                            .padding(.top, 12)
                            .padding(.bottom, 16)

                        // All messages as one selectable text block
                        // so users can select across message boundaries
                        conversationText

                        if vm.streaming {
                            StreamingCursor()
                                .padding(.top, 4)
                        }

                        if let error = vm.error {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(.red.opacity(0.6))

                                SecondaryButton("→ try again") {
                                    vm.retry()
                                }
                            }
                            .padding(.top, 16)
                        }

                        Color.clear.frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 28)
                    .frame(maxWidth: 500, alignment: .leading)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.displayedText) {
                    withAnimation(.spring(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: vm.messages.count) {
                    withAnimation(.spring(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            Divider()
                .overlay(Color.warmText.opacity(0.08))

            // Input bar — Return key inserts newlines, send button sends
            HStack(alignment: .bottom, spacing: 12) {
                TextField("say something", text: $vm.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.warmText)
                    .lineLimit(1...8)
                    .focused($inputFocused)

                if !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: { vm.send() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.warmAccent)
                    }
                    .disabled(vm.streaming)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .animation(.spring(duration: 0.2), value: vm.inputText.isEmpty)

            // Footer
            HStack {
                SecondaryButton("→ start over") {
                    showingStartOverConfirmation = true
                }
                Spacer()
                Text("your conversation is private")
                    .font(.caption2)
                    .foregroundStyle(.faint)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 8)
        }
        .onAppear {
            vm.initiateIfNeeded()
        }
        .confirmationDialog("Start over?", isPresented: $showingStartOverConfirmation) {
            Button("Start over", role: .destructive) {
                onStartOver()
            }
        } message: {
            Text("This will clear your current conversation.")
        }
    }

    // MARK: - Conversation as one selectable text

    /// Renders all messages as a single Text view with gutter icons,
    /// enabling cross-message text selection.
    @ViewBuilder
    private var conversationText: some View {
        let messages = vm.messages.filter { !$0.text.isEmpty }
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(messages) { message in
                    HStack(alignment: .top, spacing: 10) {
                        // Left gutter — arrow for Lightward, dot for user
                        if message.role == .assistant {
                            LightwardArrowView(size: 12, color: .warmAccent.opacity(0.4))
                                .padding(.top, 4)
                        } else {
                            Circle()
                                .fill(Color.warmText.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                                .padding(.horizontal, 3)
                        }

                        Text(message.text)
                            .font(.body)
                            .foregroundStyle(
                                message.role == .user
                                    ? Color.warmText
                                    : Color.warmText.opacity(0.8)
                            )
                    }
                }
            }
            .textSelection(.enabled)
        }
    }
}

// MARK: - Streaming Cursor

struct StreamingCursor: View {
    @State private var visible = true

    var body: some View {
        Text("▍")
            .font(.body)
            .foregroundStyle(.warmAccent.opacity(0.7))
            .opacity(visible ? 1 : 0.2)
            .animation(
                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                value: visible
            )
            .onAppear { visible = false }
    }
}
