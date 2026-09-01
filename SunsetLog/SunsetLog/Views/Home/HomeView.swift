import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @Query(sort: \SunsetEntry.capturedAt, order: .reverse) private var entries: [SunsetEntry]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                header
                GoldenHourCard()
                streakBlock
                recent
            }
            .padding(.top, 8)
            .padding(.bottom, 48)
        }
        .duskBackdrop()
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Sunset Log")
                    .font(Typeface.italic(22))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    session.scanPresented = true
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                }
                .accessibilityLabel("Scan camera roll")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(Typeface.caption(12))
                .tracking(1.6)
                .foregroundStyle(Palette.gold)
                .padding(.horizontal, 22)
            Text(greeting)
                .font(Typeface.italic(34))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 22)
            if session.location.usesFallback {
                SoftBanner(text: "Using San Francisco for timing until location is allowed.")
                    .padding(.horizontal, 22)
            }
        }
    }

    private var greeting: String {
        switch session.phase {
        case .goldenHour: return "The gold is happening."
        case .afterglow: return "The sky already left."
        case .waiting: return "The light is still gathering."
        case .polarNight: return "No sunset on this horizon."
        }
    }

    private var streakBlock: some View {
        let days = AppSession.streak(from: entries, now: session.now)
        return Button {
            router.open(.calendar, in: .journal)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    GlowOrb(color: Palette.ember, size: 56)
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Palette.gold)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(days == 0 ? "A quiet streak" : "\(days)-day streak")
                        .font(Typeface.italic(24))
                    Text(days == 0
                         ? "Log tonight and the count begins."
                         : "Consecutive evenings you’ve looked up.")
                        .font(Typeface.body(14))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 22)
        }
        .buttonStyle(.plain)
    }

    private var recent: some View {
        let mine = Array(entries.filter(\.isMine).prefix(4))
        return VStack(alignment: .leading, spacing: 4) {
            SectionHeader(eyebrow: "The journal", title: "Recent evenings")
                .padding(.horizontal, 22)
            if mine.isEmpty {
                QuietEmpty(
                    symbol: "moon.stars",
                    title: "Nothing written yet",
                    detail: "Tonight is a good first page.",
                    actionTitle: "Log this sunset"
                ) {
                    session.logPresented = true
                }
            } else {
                VStack(spacing: -72) {
                    ForEach(Array(mine.enumerated()), id: \.element.id) { index, entry in
                        Button {
                            router.open(.entry(entry.id), in: .journal)
                        } label: {
                            JournalVeil(entry: entry, style: .compact, staggered: index.isMultiple(of: 2) == false)
                        }
                        .buttonStyle(VeilPressStyle())
                    }
                }
            }
        }
    }
}

struct GoldenHourCard: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SkyGradient.dusk
            GlowOrb(color: Palette.gold, size: 220)
                .offset(x: 90, y: -30)
            GlowOrb(color: Palette.rose, size: 120)
                .offset(x: -40, y: 50)
            VStack(alignment: .leading, spacing: 14) {
                Text("GOLDEN HOUR")
                    .font(Typeface.caption(11))
                    .tracking(2.0)
                    .foregroundStyle(Color.white.opacity(0.72))
                Text(headline)
                    .font(Typeface.italic(32))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let sunset = session.nextSunset {
                    Text(sunset.formatted(date: .omitted, time: .shortened))
                        .font(Typeface.body(16, weight: .medium))
                        .foregroundStyle(Palette.gold)
                    countdown(sunset)
                }
                Text(session.location.locality ?? (session.location.usesFallback ? LocationService.fallbackLocality : "Finding you…"))
                    .font(Typeface.italic(13))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .padding(.horizontal, 16)
        .shadow(color: Palette.dusk.opacity(0.35), radius: 24, y: 12)
    }

    @ViewBuilder
    private func countdown(_ sunset: Date) -> some View {
        if case .waiting(let date) = session.phase {
            Text(remaining(until: date))
                .font(Typeface.display(44))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
        } else if case .goldenHour(let date) = session.phase {
            Text(remaining(until: date))
                .font(Typeface.display(36))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    private var headline: String {
        switch session.phase {
        case .waiting: return "Tonight falls in"
        case .goldenHour: return "You’re in it"
        case .afterglow: return "See you tomorrow"
        case .polarNight: return "The sun stays up"
        }
    }

    private func remaining(until date: Date) -> String {
        let interval = max(0, date.timeIntervalSince(session.now))
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
