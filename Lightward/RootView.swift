import SwiftUI

/// Root view managing consent → phoropter → chat flow.
struct RootView: View {
    @State private var store = Store()
    @State private var phase: Phase = .phoropter
    @State private var phoropterVM: PhoropterViewModel?
    @State private var chatVM: ChatViewModel?
    @State private var hasConsented = UserDefaults.standard.bool(forKey: "hasConsented")

    enum Phase {
        case phoropter
        case chat
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            if !hasConsented {
                ConsentView {
                    UserDefaults.standard.set(true, forKey: "hasConsented")
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasConsented = true
                    }
                }
                .transition(.opacity)
            } else {
                switch phase {
                case .phoropter:
                    if let vm = phoropterVM {
                        PhoropterView(vm: vm) {
                            dropToChat()
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                    }

                case .chat:
                    if let vm = chatVM {
                        ChatView(vm: vm) {
                            startOver()
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            phoropterVM = PhoropterViewModel(store: store)

            // Resume chat if we have existing messages
            if !store.session.chatMessages.isEmpty {
                chatVM = ChatViewModel(store: store, phoropterTrail: store.session.phoropterTrail)
                phase = .chat
            }
        }
    }

    private func dropToChat() {
        let trail = phoropterVM?.trail ?? []
        chatVM = ChatViewModel(store: store, phoropterTrail: trail)
        withAnimation(.easeInOut(duration: 0.4)) {
            phase = .chat
        }
    }

    private func startOver() {
        store.reset()
        phoropterVM = PhoropterViewModel(store: store)
        chatVM = nil
        withAnimation(.easeInOut(duration: 0.4)) {
            phase = .phoropter
        }
    }
}
