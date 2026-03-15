import SwiftUI

/// The phoropter binary choice interface.
/// Users navigate binary pairs to locate where they are,
/// then optionally drop to chat or auto-transition on convergence.
struct PhoropterView: View {
    @Bindable var vm: PhoropterViewModel
    var onDropToChat: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Observer mark
                    Text("⏿")
                        .font(.title2)
                        .padding(.bottom, 24)

                    // Trail of past choices
                    ForEach(Array(vm.trail.enumerated()), id: \.offset) { _, choice in
                        Text(choice)
                            .font(.body)
                            .foregroundStyle(Color.warmText.opacity(0.5))
                            .padding(.bottom, 8)
                    }

                    if !vm.trail.isEmpty {
                        Spacer().frame(height: 16)
                    }

                    // Current options or loading
                    if vm.loading {
                        LoadingDots()
                            .padding(.vertical, 12)
                    } else if vm.converged {
                        // Convergence — offer transition to chat
                        VStack(alignment: .leading, spacing: 16) {
                            Text("⏿")
                                .font(.body)
                                .foregroundStyle(.warmAccent)

                            Button(action: onDropToChat) {
                                Text("→ talk")
                                    .font(.body)
                                    .foregroundStyle(.warmAccent)
                            }
                            .id("converged")

                            Button(action: { vm.startOver() }) {
                                Text("→ start over")
                                    .font(.body)
                                    .foregroundStyle(.warmText.opacity(0.4))
                            }
                        }
                    } else if let options = vm.currentOptions {
                        VStack(alignment: .leading, spacing: 12) {
                            ChoiceButton(text: options.0) {
                                vm.select(options.0)
                            }

                            ChoiceButton(text: options.1) {
                                vm.select(options.1)
                            }
                        }

                        // Secondary actions
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: { vm.cycle() }) {
                                Text("→ different question")
                                    .font(.body)
                                    .foregroundStyle(.warmText.opacity(0.4))
                            }

                            // Show "just talk" once the first AI-generated pair arrives
                            if vm.aiResponseCount >= 1 {
                                Button(action: onDropToChat) {
                                    Text("→ just talk")
                                        .font(.body)
                                        .foregroundStyle(.warmText.opacity(0.4))
                                }
                            }
                        }
                        .padding(.top, 16)
                    } else {
                        // Entry pairs
                        VStack(alignment: .leading, spacing: 12) {
                            ChoiceButton(text: vm.entryPair.0) {
                                vm.selectEntry(vm.entryPair.0)
                            }

                            ChoiceButton(text: vm.entryPair.1) {
                                vm.selectEntry(vm.entryPair.1)
                            }
                        }

                        Button(action: { vm.cycleEntry() }) {
                            Text("→ different question")
                                .font(.body)
                                .foregroundStyle(.warmText.opacity(0.4))
                        }
                        .padding(.top, 16)
                    }

                    if let error = vm.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                            .padding(.top, 12)

                        Button(action: { vm.retry() }) {
                            Text("→ try again")
                                .font(.body)
                                .foregroundStyle(.warmAccent)
                        }
                        .padding(.top, 4)
                    }

                    Spacer().frame(height: 100)
                        .id("bottom")
                }
                .padding(24)
                .frame(maxWidth: 480, alignment: .leading)
            }
            .onChange(of: vm.trail.count) {
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Choice Button

struct ChoiceButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Text("☛")
                    .foregroundStyle(.warmAccent)
                Text(text)
                    .foregroundStyle(.warmText)
                    .multilineTextAlignment(.leading)
            }
            .font(.body)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Loading Dots

struct LoadingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.warmText.opacity(phase == i ? 0.8 : 0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}
