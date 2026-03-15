import SwiftUI

/// The phoropter binary choice interface.
/// Users navigate binary pairs to locate where they are,
/// then optionally drop to chat or auto-transition on convergence.
struct PhoropterView: View {
    @Bindable var vm: PhoropterViewModel
    var onDropToChat: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Push content toward vertical center on first screen
                        if vm.trail.isEmpty {
                            Spacer().frame(height: max(geo.size.height * 0.3, 80))
                        }

                        // Observer mark
                        Text("⏿")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.warmAccent.opacity(0.6))
                            .padding(.bottom, 32)

                        // Trail of past choices
                        ForEach(Array(vm.trail.enumerated()), id: \.offset) { _, choice in
                            Text(choice)
                                .font(.body)
                                .foregroundStyle(.faint)
                                .padding(.bottom, 10)
                        }

                        if !vm.trail.isEmpty {
                            Spacer().frame(height: 20)
                        }

                        // Current options or loading
                        if vm.loading {
                            LoadingDots()
                                .padding(.vertical, 16)
                        } else if vm.converged {
                            convergenceView
                        } else if let options = vm.currentOptions {
                            sessionView(options: options)
                        } else {
                            entryView
                        }

                        if let error = vm.error {
                            errorView(error)
                        }

                        Spacer().frame(height: 120)
                            .id("bottom")
                    }
                    .padding(.horizontal, 28)
                    .frame(maxWidth: 500, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.trail.count) {
                    withAnimation(.spring(duration: 0.4)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var entryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ChoiceButton(text: vm.entryPair.0) {
                vm.selectEntry(vm.entryPair.0)
            }

            ChoiceButton(text: vm.entryPair.1) {
                vm.selectEntry(vm.entryPair.1)
            }

            SecondaryButton("→ different question") {
                vm.cycleEntry()
            }
            .padding(.top, 8)
        }
    }

    private func sessionView(options: (String, String)) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ChoiceButton(text: vm.revealedOption1) {
                vm.select(options.0)
            }
            .disabled(vm.revealing)

            ChoiceButton(text: vm.revealedOption2) {
                vm.select(options.1)
            }
            .disabled(vm.revealing)

            VStack(alignment: .leading, spacing: 10) {
                SecondaryButton("→ different question") {
                    vm.cycle()
                }

                if vm.aiResponseCount >= 1 {
                    SecondaryButton("→ just talk") {
                        onDropToChat()
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var convergenceView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("⏿")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.warmAccent)

            Button(action: onDropToChat) {
                Text("→ talk")
                    .font(.body)
                    .foregroundStyle(.warmAccent)
            }

            SecondaryButton("→ start over") {
                vm.startOver()
            }
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red.opacity(0.6))
                .padding(.top, 16)

            SecondaryButton("→ try again") {
                vm.retry()
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
            HStack(alignment: .top, spacing: 10) {
                Text("☛")
                    .foregroundStyle(.warmAccent)
                Text(text)
                    .foregroundStyle(.warmText)
                    .multilineTextAlignment(.leading)
            }
            .font(.body)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.faint)
        }
    }
}

// MARK: - Loading Dots

struct LoadingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.warmText.opacity(phase == i ? 0.6 : 0.15))
                    .frame(width: 5, height: 5)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}
