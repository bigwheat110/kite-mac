import Foundation

struct HabitItem: Codable, Hashable, Identifiable {
    let id: UUID
    var title: String
    var createdAt: Date
    var titleHistory: [String: String]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        titleHistory: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.titleHistory = titleHistory
    }
}

enum ReminderRepeatMode: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekdays
    case weekends

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "每天"
        case .weekdays: return "工作日"
        case .weekends: return "周末"
        }
    }
}

struct ReminderItem: Codable, Hashable, Identifiable {
    let id: UUID
    var title: String
    var hour: Int
    var minute: Int
    var enabled: Bool
    var repeatMode: ReminderRepeatMode
    var linkedHabitId: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        hour: Int,
        minute: Int,
        enabled: Bool = true,
        repeatMode: ReminderRepeatMode = .daily,
        linkedHabitId: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.hour = hour
        self.minute = minute
        self.enabled = enabled
        self.repeatMode = repeatMode
        self.linkedHabitId = linkedHabitId
        self.createdAt = createdAt
    }
}

enum DisplayMode: String, Codable, CaseIterable, Identifiable {
    case normal
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return "常规"
        case .compact: return "紧凑"
        }
    }
}

struct UIPreferences: Codable {
    var displayMode: DisplayMode
    var alwaysOnTop: Bool
    var focusModeEnabled: Bool
    var lastSelectedDateKey: String

    static let `default` = UIPreferences(
        displayMode: .normal,
        alwaysOnTop: true,
        focusModeEnabled: false,
        lastSelectedDateKey: HabitDate.key(for: .now)
    )
}

struct FocusSessionState: Codable {
    var active: Bool
    var startedAt: Date?
    var durationMinutes: Int

    static let `default` = FocusSessionState(
        active: false,
        startedAt: nil,
        durationMinutes: 25
    )
}

struct AppState: Codable {
    var habits: [HabitItem]
    var entries: [String: [UUID: Bool]]
    var dailyOverrides: [String: [UUID: String]]
    var reminders: [ReminderItem]
    var uiPreferences: UIPreferences
    var focusSession: FocusSessionState

    static let `default` = AppState(
        habits: [
            HabitItem(title: "日语"),
            HabitItem(title: "梳头"),
            HabitItem(title: "英语"),
            HabitItem(title: "泡脚"),
            HabitItem(title: "读书/诗歌"),
            HabitItem(title: "艾灸/锻炼/跳舞"),
            HabitItem(title: "跑步/买菜/八段锦"),
            HabitItem(title: "晒太阳"),
            HabitItem(title: "喝水")
        ],
        entries: [:],
        dailyOverrides: [:],
        reminders: [
            ReminderItem(title: "早间检查今日待办", hour: 8, minute: 30),
            ReminderItem(title: "晚上完成收尾事项", hour: 21, minute: 0, repeatMode: .daily)
        ],
        uiPreferences: .default,
        focusSession: .default
    )
}

enum ToolbarPanel: String, Identifiable {
    case overview
    case calendar
    case reminders

    var id: String { rawValue }
}

enum HabitDate {
    static let calendar = Calendar(identifier: .gregorian)

    static func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func date(from key: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key) ?? .now
    }

    static func weekDates(containing date: Date) -> [Date] {
        let weekday = calendar.component(.weekday, from: date)
        let start = calendar.date(byAdding: .day, value: -(weekday - 1), to: startOfDay(date)) ?? date
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    static func weekdayTitle(_ date: Date) -> String {
        let titles = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return titles[calendar.component(.weekday, from: date) - 1]
    }

    static func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }

    static func monthDayWeekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }
}
