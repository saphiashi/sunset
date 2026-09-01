import SwiftUI
import SwiftData

struct CalendarJournalView: View {
    @Query(sort: \SunsetEntry.capturedAt, order: .reverse) private var entries: [SunsetEntry]
    @State private var month: Date = Date()
    @State private var selectedDay: Date?

    var body: some View {
        let mine = entries.filter(\.isMine)
        let grouped = Dictionary(grouping: mine) { Calendar.current.startOfDay(for: $0.capturedAt) }
        let day = selectedDay ?? Calendar.current.startOfDay(for: Date())
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(month.formatted(.dateTime.month(.wide).year()))
                        .font(Typeface.display(24))
                    Spacer()
                    Button { shift(1) } label: { Image(systemName: "chevron.right") }
                }
                .foregroundStyle(.primary)

                weekdayHeader
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, cell in
                        if let cell {
                            let key = Calendar.current.startOfDay(for: cell)
                            let hit = grouped[key] ?? []
                            Button {
                                selectedDay = key
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(Calendar.current.component(.day, from: cell))")
                                        .font(Typeface.body(14, weight: key == day ? .bold : .regular))
                                    Circle()
                                        .fill(hit.isEmpty ? Color.clear : Palette.ember)
                                        .frame(width: 6, height: 6)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(key == day ? Palette.ember.opacity(0.12) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }

                let shown = grouped[day] ?? []
                if shown.isEmpty {
                    QuietEmpty(
                        symbol: "sun.haze",
                        title: "No sky this day",
                        detail: "A blank square is also a kind of weather."
                    )
                } else {
                    ForEach(shown, id: \.id) { entry in
                        NavigationLink(value: Route.entry(entry.id)) {
                            EntryCard(entry: entry, compact: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationTitle("Days")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var weekdayHeader: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        let ordered = Array(symbols[first...]) + Array(symbols[..<first])
        return HStack {
            ForEach(ordered, id: \.self) { symbol in
                Text(symbol)
                    .font(Typeface.caption(11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func shift(_ value: Int) {
        month = Calendar.current.date(byAdding: .month, value: value, to: month) ?? month
    }

    private func daysInMonth() -> [Date?] {
        let cal = Calendar.current
        guard
            let interval = cal.dateInterval(of: .month, for: month),
            let count = cal.range(of: .day, in: .month, for: month)?.count
        else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let pad = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: pad)
        for day in 0..<count {
            cells.append(cal.date(byAdding: .day, value: day, to: interval.start))
        }
        return cells
    }
}
