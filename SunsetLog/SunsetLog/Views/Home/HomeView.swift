import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @Query(sort: \SunsetEntry.capturedAt, order: .reverse) private var entries: [SunsetEntry]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                GoldenHourCard()
                streakBlock
                recent
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Sunset Log")
                    .font(Typeface.display(20))
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
                .tracking(1.1)
                .foregroundStyle(Palette.ember)
            Text(greeting)
                .font(Typeface.display(34))
                .fixedSize(horizontal: false, vertical: true)
            if session.location.usesFallback {
                SoftBanner(text: "Using San Francisco for timing until location is allowed.")
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
                    Circle().fill(Palette.ember.opacity(0.16))
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Palette.ember)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(days == 0 ? "A quiet streak" : "\(days)-day streak")
                        .font(Typeface.display(22))
                    Text(days == 0
                         ? "Log tonight and the count begins."
                         : "Consecutive evenings you’ve looked up.")
                        .font(Typeface.body(14))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var recent: some View {
        let mine = entries.filter(\.isMine).prefix(4)
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(eyebrow: "The journal", title: "Recent evenings")
            if mine.isEmpty {
                QuietEmpty(
                    symbol: "book.closed",
                    title: "Nothing written yet",
                    detail: "Tonight is a good first page.",
                    actionTitle: "Log this sunset"
                ) {
                    session.logPresented = true
                }
            } else {
                ForEach(Array(mine), id: \.id) { entry in
                    Button {
                        router.open(.entry(entry.id), in: .journal)
                    } label: {
                        EntryCard(entry: entry, compact: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct GoldenHourCard: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GOLDEN HOUR")
                .font(Typeface.caption(11))
                .tracking(1.6)
                .foregroundStyle(Color.white.opacity(0.72))
            Text(headline)
                .font(Typeface.display(30))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            if let sunset = session.nextSunset {
                Text(sunset.formatted(date: .omitted, time: .shortened))
                    .font(Typeface.body(16, weight: .medium))
                    .foregroundStyle(Palette.gold)
                if case .waiting(let date) = session.phase {
                    Text(remaining(until: date))
                        .font(Typeface.display(42))
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
            Text(session.location.locality ?? (session.location.usesFallback ? LocationService.fallbackLocality : "Finding you…"))
                .font(Typeface.caption(12))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SkyGradient.dusk)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Palette.dusk.opacity(0.25), radius: 18, y: 10)
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
