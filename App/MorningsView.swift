import SwiftUI
import Charts
import SleepCore

struct MorningsView: View {
    @Environment(AppModel.self) private var model
    @State private var checkIn: NightWindow?
    var body: some View {
        NavigationStack {
            ZStack {
                NightBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Eyebrow(text: "A LITTLE REFLECTION")
                        Text("How did\nyour night feel?").font(.system(.largeTitle, design: .default))
                        Text("A brief check-in. A clearer picture over time.")
                            .foregroundStyle(SleepTheme.secondary)
                        if let night = model.pendingNights.first {
                            SleepCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    Label("Your morning check-in", systemImage: "sun.horizon")
                                        .font(.headline).foregroundStyle(SleepTheme.lavender)
                                    Text("For the night starting \(night.start.formatted(date: .abbreviated, time: .omitted)).")
                                        .font(.subheadline).foregroundStyle(SleepTheme.secondary)
                                    PrimaryButton(title: "Take a moment", symbol: "arrow.right") { checkIn = night }
                                }
                            }
                        }
                        WeeklyReflection(entries: model.mornings, revisions: model.snapshot.revisions, now: model.now)
                        if model.mornings.isEmpty {
                            SleepCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(systemName: "sun.max").font(.title).foregroundStyle(SleepTheme.lavender)
                                    Text("Your mornings begin here.").font(.headline)
                                    Text("After your first planned bedtime, you can record when you tried to sleep and how rested you feel. There is no score to chase.")
                                        .font(.subheadline).foregroundStyle(SleepTheme.secondary)
                                }
                            }
                        } else {
                            Eyebrow(text: "RECENT MORNINGS")
                            ForEach(model.mornings.prefix(14)) { entry in
                                SleepCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(entry.window.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                            .font(.headline)
                                        Text("Tried sleeping at \(entry.attemptedSleepAt.formatted(date: .omitted, time: .shortened))")
                                            .font(.subheadline)
                                        Text("Bedtime delay: \(Int(entry.delayMinutes.rounded())) min · Rested: \(entry.restfulness)/5")
                                            .font(.footnote).foregroundStyle(SleepTheme.secondary)
                                        if entry.constraint != .none {
                                            Text(entry.constraint.rawValue).font(.footnote).foregroundStyle(SleepTheme.lavender)
                                        }
                                    }
                                }
                            }
                        }
                        if model.pendingNights.count > 1 {
                            Eyebrow(text: "OTHER NIGHTS TO REFLECT ON")
                            ForEach(model.pendingNights.dropFirst()) { night in
                                Button { checkIn = night } label: {
                                    HStack {
                                        Text(night.start.formatted(date: .abbreviated, time: .omitted))
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                    }.frame(minHeight: 44)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(24).frame(maxWidth: 540).frame(maxWidth: .infinity)
                }
            }
            .sheet(item: $checkIn) { MorningCheckInView(night: $0) }
        }
    }
}

struct WeeklyReflection: View {
    let entries: [MorningEntry]
    let revisions: [PlanRevision]
    let now: Date
    private var weekStart: Date { Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: now))! }
    private var weekEntries: [MorningEntry] { entries.filter { $0.window.intendedBedtime >= weekStart } }
    private var expected: Int {
        NightHistory.recentNights(before: now, revisions: revisions)
            .filter { $0.intendedBedtime >= weekStart }.count
    }
    var body: some View {
        SleepCard {
            VStack(alignment: .leading, spacing: 18) {
                Eyebrow(text: "THE PAST SEVEN DAYS")
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 30) { metrics }
                    VStack(alignment: .leading, spacing: 20) { metrics }
                }
                if !weekEntries.isEmpty {
                    Chart(weekEntries) { entry in
                        BarMark(
                            x: .value("Night", entry.window.intendedBedtime, unit: .day),
                            y: .value("Reported bedtime delay in minutes", entry.delayMinutes)
                        )
                        .foregroundStyle(SleepTheme.lavender)
                        .accessibilityLabel(entry.window.intendedBedtime.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("\(Int(entry.delayMinutes.rounded())) minutes of reported bedtime delay")
                    }
                    .chartYAxisLabel("Minutes after planned bedtime")
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.abbreviated)) }
                    }
                    .frame(height: 160)
                    .accessibilityLabel("Reported bedtime delay for nights with check-ins.")
                }
                Text("Based on your check-ins. Missing entries stay missing; these times do not measure when you fell asleep.")
                    .font(.footnote).foregroundStyle(SleepTheme.secondary)
            }
        }
    }
    @ViewBuilder private var metrics: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NightHistory.averageDelay(weekEntries).map { "\(Int($0.rounded())) min" } ?? "—")
                .font(.title2.weight(.medium))
            Text("Average bedtime delay").font(.caption).foregroundStyle(SleepTheme.secondary)
        }
        VStack(alignment: .leading, spacing: 6) {
            Text("\(weekEntries.count) of \(expected)").font(.title2.weight(.medium))
            Text("Planned nights checked in").font(.caption).foregroundStyle(SleepTheme.secondary)
        }
    }
}

struct MorningCheckInView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let night: NightWindow
    @State private var attempted: Date
    @State private var rested: Int?
    @State private var constraint = MorningConstraint.none
    // This edit buffer intentionally captures the selected night's target once.
    init(night: NightWindow) {
        self.night = night
        _attempted = State(initialValue: night.intendedBedtime)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Good morning.").font(.system(.largeTitle, design: .default))
                    Text("You planned to try sleeping at \(night.intendedBedtime.formatted(date: .abbreviated, time: .shortened)).")
                        .foregroundStyle(SleepTheme.secondary)
                    SleepCard {
                        DatePicker("When did you start trying to sleep?", selection: $attempted,
                                   in: night.start.addingTimeInterval(-12*3600)...min(Date(), night.end.addingTimeInterval(12*3600)),
                                   displayedComponents: [.date, .hourAndMinute])
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Text("How rested do you feel?").font(.headline)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { score in
                                Button { rested = score } label: {
                                    Text("\(score)").font(.headline)
                                        .frame(maxWidth: .infinity, minHeight: 52)
                                        .background(rested == score ? SleepTheme.lavender : SleepTheme.card,
                                                    in: .rect(cornerRadius: 14))
                                        .foregroundStyle(rested == score ? SleepTheme.background : SleepTheme.text)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Restfulness \(score) out of 5")
                                .accessibilityAddTraits(rested == score ? .isSelected : [])
                            }
                        }
                        HStack { Text("Not rested"); Spacer(); Text("Very rested") }
                            .font(.caption).foregroundStyle(SleepTheme.secondary)
                    }
                    Picker("Anything affect your night?", selection: $constraint) {
                        ForEach(MorningConstraint.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    PrimaryButton(title: "Save my check-in") {
                        guard let rested else { return }
                        if model.recordMorning(MorningEntry(window: night, attemptedSleepAt: attempted,
                                                           restfulness: rested, constraint: constraint)) { dismiss() }
                    }.disabled(rested == nil).opacity(rested == nil ? 0.5 : 1)
                }
                .padding(24).frame(maxWidth: 540).frame(maxWidth: .infinity)
            }
            .background(SleepTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Later") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 390, minHeight: 640)
        #endif
    }
}
