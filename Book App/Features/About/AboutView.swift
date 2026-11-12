import SwiftUI

struct AboutView: View {
    // Developer details belong to the app, not the currently signed-in account.
    private let developerName = "Isabelle \"Sabi\" Fernan"
    private let studentID = "34095756"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Image("AppLogo").resizable().scaledToFit()
                        .frame(height: AppLayout.homeCoverWidth)
                        .padding(AppSpacing.sm)
                        .background(Color.surface, in: RoundedRectangle(cornerRadius: AppRadius.md))
                        .accessibilityHidden(true)
                    Text("Book Tracker").font(AppTypography.largeTitle)
                    Text("Every chapter counts.").font(AppTypography.title)
                    Text("A home for your books, your reading habits, and the stories that stay with you.")
                        .font(AppTypography.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.lg)
                .foregroundStyle(Color.onAccent)
                .background(Color.appAccent, in: RoundedRectangle(cornerRadius: AppRadius.md))

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Label("Build your own bookshelves", systemImage: "books.vertical")
                        Label("Capture notes and favourite moments", systemImage: "note.text")
                        Label("Watch your reading story grow", systemImage: "chart.bar.xaxis")
                        Text("Track sessions, set goals, revisit past reads and keep your library with you across devices.")
                            .font(AppTypography.body).foregroundStyle(Color.textSecondary)
                    }
                    .font(AppTypography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Label("Meet the creator", systemImage: "person.crop.circle").font(AppTypography.title).foregroundStyle(Color.appAccent)
                        detail("Name", value: developerName)
                        detail("Student ID", value: studentID)
                        if let url = URL(string: "https://ijfprojects.com") {
                            Link(destination: url) {
                                Label("Website · ijfprojects.com", systemImage: "globe")
                            }
                            .frame(minHeight: AppLayout.minimumTapTarget, alignment: .leading)
                            .accessibilityLabel("Visit Isabelle’s website")
                        }
                        if let url = URL(string: "https://www.linkedin.com/in/ijf03/") {
                            Link(destination: url) {
                                Label("LinkedIn · ijf03", systemImage: "arrow.up.right.square")
                            }
                            .frame(minHeight: AppLayout.minimumTapTarget, alignment: .leading)
                            .accessibilityLabel("View Isabelle’s LinkedIn profile")
                        }
                        Text("Developed for FIT3178 – iOS App Development at Monash University.")
                            .font(AppTypography.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Label("Made with thanks", systemImage: "heart").font(AppTypography.title).foregroundStyle(Color.appAccent)
                        credit("Open Library · Internet Archive",
                               description: "Book search, catalogue metadata, subjects and cover images. Catalogue information may be incomplete. Book covers belong to their respective rights holders.",
                               url: "https://openlibrary.org/developers/api")
                        Divider()
                        credit("Firebase",
                               description: "Firebase Authentication provides email and password accounts. Cloud Firestore provides account data synchronisation.",
                               url: "https://github.com/firebase/firebase-ios-sdk")
                        Divider()
                        credit("Apple frameworks and design resources",
                               description: "SwiftUI for the interface, Swift Charts for statistics, UserNotifications for reading reminders, and SF Symbols for interface icons. Apple’s documentation and Human Interface Guidelines informed navigation, accessibility and layout.",
                               url: "https://developer.apple.com/design/human-interface-guidelines")
                        Divider()
                        credit("Fable",
                               description: "Reading insights and chart concepts provided design inspiration. This app is an independent student project and is not affiliated with Fable.",
                               url: "https://fable.co")
                        Divider()
                        Text("Development assistance").font(AppTypography.headline)
                        Text("OpenAI ChatGPT and Codex assisted with implementation, debugging, tests and documentation.")
                            .font(AppTypography.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Supporting libraries").font(AppTypography.title)
                        Text("The Firebase package dependency graph includes GoogleUtilities, GoogleDataTransport, GoogleAppMeasurement, GoogleAdsOnDeviceConversion, AppCheck, InteropForGoogle, gRPC, abseil, GTMSessionFetcher, leveldb, nanopb and Promises. Package availability does not imply that every service is enabled in this app.")
                            .font(AppTypography.body)
                        if let url = URL(string: "https://github.com/firebase/firebase-ios-sdk/blob/main/LICENSE") {
                            Link("Firebase SDK licence", destination: url)
                        }
                        Text("Individual dependencies retain their respective licences and notices.")
                            .font(AppTypography.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: AppLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color.surfaceSecondary)
        .foregroundStyle(Color.textPrimary)
        .tint(Color.appAccent)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detail(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title).font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            Text(verbatim: value).font(AppTypography.body).textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }

    private func credit(_ title: LocalizedStringKey, description: LocalizedStringKey, url: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title).font(AppTypography.headline)
            Text(description).font(AppTypography.body)
            if let destination = URL(string: url) {
                Link(destination: destination) {
                    Label(title, systemImage: "arrow.up.right.square")
                }
                .frame(minHeight: AppLayout.minimumTapTarget, alignment: .leading)
            }
        }
    }
}

#Preview {
    NavigationStack { AboutView() }
}
