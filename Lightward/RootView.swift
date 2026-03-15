import SwiftUI

/// Root view managing the phoropter → chat flow.
struct RootView: View {
    @State private var store = Store()
    @State private var phase: Phase = .phoropter
    @State private var phoroptrVM: PhoropterViewModel?
    @State private var chatVM: ChatViewModel?

    enum Phase {
        case phoropter
        case chat
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            switch phase {
            case .phoropter:
                if let vm = phoroptrVM {
                    PhoropterView(vm: vm) {
                        dropToChat()
                    }
                    .transition(.opacity)
                }

            case .chat:
                if let vm = chatVM {
                    ChatView(vm: vm) {
                        startOver()
                    }
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            phoroptrVM = PhoropterViewModel(store: store)

            // Resume chat if we have existing messages
            if !store.session.chatMessages.isEmpty {
                chatVM = ChatViewModel(store: store, phoropterTrail: store.session.phoropterTrail)
                phase = .chat
            }
        }
    }

    private func dropToChat() {
        let trail = phoroptrVM?.trail ?? []
        chatVM = ChatViewModel(store: store, phoropterTrail: trail)
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .chat
        }
    }

    private func startOver() {
        store.reset()
        phoroptrVM = PhoropterViewModel(store: store)
        chatVM = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .phoropter
        }
    }
}
