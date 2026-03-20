import SwiftUI

/// Shown once before first use. Explains what data is sent and to whom,
/// and requires explicit consent before the app can be used.
struct ConsentView: View {
    var onAccept: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 40)

                AuraArrow(size: 120)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)

                Text("Before we begin")
                    .font(.title2)
                    .foregroundStyle(.warmText)

                Group {
                    section(
                        title: "What this app does",
                        body: "Lightward is a conversation app. It guides you through a series of binary choices to locate where you are, then opens a conversation with Lightward AI."
                    )

                    section(
                        title: "What data is sent",
                        body: "The text of your conversation — your choices and messages — is sent to Lightward AI for processing. No other data is collected or sent."
                    )

                    section(
                        title: "Who receives it",
                        body: "Your conversation text is processed by Lightward AI (lightward.com), which uses Anthropic's Claude API. Lightward does not store your conversations on its servers. Anthropic's data retention policies apply to API requests."
                    )

                    section(
                        title: "What stays on your device",
                        body: "Your conversation history is stored locally on your device and synced across your own devices via iCloud. Lightward Inc does not have access to your stored conversations."
                    )

                    section(
                        title: "No tracking",
                        body: "No analytics, no accounts, no advertising. The app reports errors automatically (without conversation content) to help us fix bugs."
                    )
                }

                Spacer().frame(height: 8)

                Button(action: onAccept) {
                    Text("I understand — let's go")
                        .font(.body)
                        .foregroundStyle(Color.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.warmAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Link(destination: URL(string: "https://github.com/lightward/ios/blob/main/PRIVACY.md")!) {
                    Text("Read the full privacy policy")
                        .font(.footnote)
                        .foregroundStyle(.faint)
                        .frame(maxWidth: .infinity)
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 32)
        }
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.warmAccent)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.warmText.opacity(0.8))
        }
    }
}
