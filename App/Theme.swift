import SwiftUI
import SleepCore

enum SleepTheme {
    static let background = Color(red: 0.047, green: 0.059, blue: 0.098)
    static let card = Color(red: 0.090, green: 0.106, blue: 0.165)
    static let lavender = Color(red: 0.773, green: 0.745, blue: 0.965)
    static let text = Color(red: 0.945, green: 0.937, blue: 0.965)
    static let secondary = Color(red: 0.667, green: 0.690, blue: 0.773)
    static let mint = Color(red: 0.631, green: 0.812, blue: 0.757)
}

struct NightBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.09, green: 0.10, blue: 0.18), SleepTheme.background],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct MoonIllustration: View {
    var compact = false
    var body: some View {
        ZStack {
            Circle().fill(SleepTheme.lavender.opacity(0.035)).frame(width: 224, height: 224)
            Circle().stroke(SleepTheme.lavender.opacity(0.12), lineWidth: 1).frame(width: 190, height: 190)
            Circle().stroke(SleepTheme.lavender.opacity(0.07), lineWidth: 1).frame(width: 240, height: 240)
            Image(systemName: "moon.fill")
                .font(.system(size: 92, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(colors: [Color(red: 0.91, green: 0.89, blue: 1), SleepTheme.lavender],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .rotationEffect(.degrees(-18))
            Circle().fill(SleepTheme.lavender.opacity(0.7)).frame(width: 3, height: 3).offset(x: 99, y: -46)
            Circle().fill(SleepTheme.lavender.opacity(0.5)).frame(width: 2, height: 2).offset(x: -98, y: 30)
            Circle().fill(SleepTheme.lavender.opacity(0.4)).frame(width: 3, height: 3).offset(x: 67, y: 92)
        }
        .scaleEffect(compact ? 0.62 : 1)
        .frame(height: compact ? 138 : 230)
        .accessibilityHidden(true)
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let symbol { Image(systemName: symbol) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 12)
            .foregroundStyle(SleepTheme.background)
            .background(SleepTheme.lavender, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

struct SleepCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(SleepTheme.card, in: .rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.05), lineWidth: 1))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text).font(.caption.weight(.semibold)).tracking(2)
            .foregroundStyle(SleepTheme.secondary)
    }
}

extension ClockTime {
    var display: String {
        (date(on: Date()) ?? Date()).formatted(date: .omitted, time: .shortened)
    }
}

struct ClockPicker: View {
    let title: String
    @Binding var time: ClockTime
    var body: some View {
        DatePicker(title, selection: Binding(
            get: { time.date(on: Date()) ?? Date() },
            set: { time = ClockTime.from($0) }
        ), displayedComponents: .hourAndMinute)
            .datePickerStyle(.compact)
            .padding(.vertical, 6)
    }
}

struct WeekdayPicker: View {
    @Binding var days: Set<Int>
    private let order = [2, 3, 4, 5, 6, 7, 1]
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) { dayButtons }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) { dayButtons }
        }
    }
    @ViewBuilder private var dayButtons: some View {
        ForEach(order, id: \.self) { day in
            Button {
                if days.contains(day) { days.remove(day) } else { days.insert(day) }
            } label: {
                Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                    .font(.subheadline.weight(.medium))
                    .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
                    .background(days.contains(day) ? SleepTheme.lavender : SleepTheme.background,
                                in: .rect(cornerRadius: 12))
                    .foregroundStyle(days.contains(day) ? SleepTheme.background : SleepTheme.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
            .accessibilityAddTraits(days.contains(day) ? .isSelected : [])
        }
    }
}
