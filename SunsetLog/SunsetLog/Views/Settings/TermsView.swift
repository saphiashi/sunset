import SwiftUI

/// In-app Terms of Use. Bump `version` when the text changes materially so
/// people agree again at their next sign-in.
struct TermsView: View {
    static let version = 1
    static let acceptedKey = "acceptedTermsVersion"

    private let sections: [(String, String)] = [
        ("Agreeing to these terms",
         "By creating an account or signing in to Sunset Log, you agree to these Terms of Use. If you don’t agree, you can keep using the journal on your phone without an account."),
        ("Who can use Sunset Log",
         "You must be at least 13 years old, or the minimum age to use online services where you live, to create an account. You’re responsible for what happens under your account."),
        ("Your sunsets and photos",
         "You own the photos and notes you post. By sharing them, you give us permission to store them and show them to the people your settings allow, only so the app can work. Only post photos you took or have the right to share."),
        ("No tolerance for objectionable content",
         "Sunset Log has zero tolerance for objectionable content or abusive users. Don’t post or send anything that is sexual, violent, hateful, harassing, threatening, illegal, spam, or that shares someone’s private information without consent. Don’t impersonate others or use the app to stalk or track someone’s location."),
        ("Reporting and blocking",
         "You can report a sunset or a person from its ⋯ menu, and block anyone from their profile. Blocked people can’t find you, follow you, or send you pins. We review reports within 24 hours. We remove content that breaks these terms and may suspend or remove the accounts that posted it."),
        ("Privacy",
         "Your journal is visible to people you accept as followers. Turn on Private account in Settings to approve each follower. Spots you log may include locations, so choose what you share with care."),
        ("Deleting your account",
         "You can delete your account at any time in Settings → Delete account. This permanently removes your profile, sunsets, photos, collections, and follows from our servers and this phone."),
        ("Changes and availability",
         "We may update these terms; if the changes matter, we’ll ask you to agree again. Sunset Log is provided as is, without warranties, and we may change or stop features. To the extent the law allows, we aren’t liable for indirect or incidental damages from using the app."),
        ("Contact",
         "Questions or concerns? Reach us through the support link on Sunset Log’s App Store page."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Terms of Use")
                    .font(Typeface.italic(32))
                ForEach(sections, id: \.0) { title, text in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(Typeface.body(17, weight: .semibold))
                        Text(text)
                            .font(Typeface.body(15))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(22)
        }
        .duskBackdrop()
        .navigationTitle("Terms")
        .navigationBarTitleDisplayMode(.inline)
    }
}
