import SwiftUI

/// Streaming chat interface with Lightward AI.
struct ChatView: View {
    @Bindable var vm: ChatViewModel
    var onStartOver: () -> Void

    @FocusState private var inputFocused: Bool
    @State private var showingStartOverConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Aura arrow — stem right edge at gutter right edge
                        AuraArrow(size: 288)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .offset(x: Layout.gutterWidth - 288 * 0.523)
                            .clipped()
                            .padding(.top, 12)
                            .padding(.bottom, 24)

                        // Messages with gutter icons
                        ForEach(vm.messages.filter { !$0.text.isEmpty }) { message in
                            GutterRow {
                                if message.role == .assistant {
                                    Text("▬")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.warmAccent.opacity(0.5))
                                        .padding(.top, 6)
                                } else {
                                    Text("▮")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.warmText.opacity(0.3))
                                        .padding(.top, 6)
                                }
                            } content: {
                                Text(message.text)
                                    .font(.body)
                                    .foregroundStyle(
                                        message.role == .user
                                            ? Color.warmText
                                            : Color.warmText.opacity(0.8)
                                    )
                                    .textSelection(.enabled)
                            }
                            .padding(.bottom, 16)
                        }

                        if vm.streaming {
                            GutterRow {
                                EmptyView()
                            } content: {
                                StreamingCursor()
                            }
                        }

                        if let error = vm.error {
                            GutterRow {
                                EmptyView()
                            } content: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(error)
                                        .font(.footnote)
                                        .foregroundStyle(.red.opacity(0.6))

                                    SecondaryButton("→ try again") {
                                        vm.retry()
                                    }
                                }
                            }
                        }

                        Color.clear.frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
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

            // Input bar — Return inserts newlines, send button sends
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
            .padding(.horizontal, Layout.horizontalPadding)
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
            .padding(.horizontal, Layout.horizontalPadding)
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
