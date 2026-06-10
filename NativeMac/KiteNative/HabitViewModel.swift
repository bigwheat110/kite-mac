import AppKit
import Foundation
import UserNotifications

struct WeekDayItem: Identifiable {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let completionCount: Int
    let hasMarker: Bool

    var id: String { HabitDate.key(for: date) }
    var weekdayTitle: String { HabitDate.weekdayTitle(date) }
    var dayLabel: String { HabitDate.dayLabel(date) }
}

struct MonthDayItem: Identifiable {
    let date: Date
    let isCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let completionCount: Int
    let totalCount: Int
    let pendingSummary: String

    var id: String { HabitDate.key(for: date) }
    var dayNumber: String {
        String(HabitDate.calendar.component(.day, from: date))
    }

    var completionSummary: String {
        "✓ \(completionCount)/\(totalCount)"
    }
}

struct ReminderDraft {
    var title = ""
    var hour = 20
    var minute = 0
    var repeatMode: ReminderRepeatMode = .daily
    var linkedHabitId: UUID?
}

struct HabitRepeatDraft: Identifiable {
    let habitId: UUID
    var weekdays: [Int]

    var id: UUID { habitId }
}

struct WeekPlanDay: Identifiable {
    let date: Date
    let habits: [HabitItem]

    var id: String { HabitDate.key(for: date) }
    var weekdayTitle: String { HabitDate.weekdayTitle(date) }
    var dayLabel: String { HabitDate.dayLabel(date) }
}

enum HabitEditMode: String {
    case todayOnly
    case templateFromToday
}

enum HabitDeleteMode: String {
    case todayOnly
    case fromSelectedDate
}

@MainActor
final class HabitViewModel: ObservableObject {
    @Published var state: AppState
    @Published var selectedDate: Date
    @Published var draftTitle = ""
    @Published var activePanel: ToolbarPanel?
    @Published var showingReminderEditor = false
    @Published var reminderDraft = ReminderDraft()
    @Published var statusMessage: String?
    @Published var editingHabitId: UUID?
    @Published var editingHabitText = ""
    @Published var editingMode: HabitEditMode = .todayOnly
    @Published var repeatDraft: HabitRepeatDraft?
    @Published private var currentToday: Date
    #if DEBUG
    @Published var usesCoreDataTrial = false
    #endif

    init() {
        let loaded = HabitStore.shared.load()
        let normalized = Self.normalize(loaded)
        let today = HabitDate.startOfDay(.now)
        state = normalized.state
        currentToday = today
        selectedDate = today
        if normalized.didChange {
            persist()
        }
    }

    var habits: [HabitItem] { habits(on: selectedDate) }
    var reminders: [ReminderItem] { state.reminders.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) } }
    var isFocusModeEnabled: Bool { state.uiPreferences.focusModeEnabled }
    var isAlwaysOnTop: Bool { state.uiPreferences.alwaysOnTop }
    var displayMode: DisplayMode { state.uiPreferences.displayMode }
    var theme: AppTheme { state.uiPreferences.theme }
    var dateKey: String { HabitDate.key(for: selectedDate) }
    var orderedHabits: [HabitItem] {
        let orderMap = Dictionary(uniqueKeysWithValues: state.habits.enumerated().map { ($1.id, $0) })
        return habits.sorted { lhs, rhs in
            return shouldSort(lhs, before: rhs, on: selectedDate, orderMap: orderMap)
        }
    }

    var pendingHabits: [HabitItem] {
        orderedHabits.filter { !isDone($0) }
    }

    var completedHabits: [HabitItem] {
        orderedHabits.filter { isDone($0) }
    }

    var doneCount: Int {
        habits.filter { isDone($0) }.count
    }

    var pendingCount: Int {
        max(habits.count - doneCount, 0)
    }

    var progressText: String {
        guard !habits.isEmpty else { return "0%" }
        return "\(Int((Double(doneCount) / Double(habits.count)) * 100))%"
    }

    var selectedDateTitle: String {
        HabitDate.monthDayWeekLabel(selectedDate)
    }

    var weekItems: [WeekDayItem] {
        HabitDate.weekDates(containing: selectedDate).map { date in
            let key = HabitDate.key(for: date)
            let dayHabits = habits(on: date)
            let completion = dayHabits.filter { state.entries[key]?[$0.id] == true }.count
            let hasReminder = reminders.contains { reminder in
                reminder.enabled && reminderApplies(reminder, to: date)
            }

            return WeekDayItem(
                date: date,
                isSelected: HabitDate.startOfDay(date) == HabitDate.startOfDay(selectedDate),
                isToday: HabitDate.startOfDay(date) == currentToday,
                completionCount: completion,
                hasMarker: hasReminder || completion > 0
            )
        }
    }

    var monthTitle: String {
        HabitDate.monthTitle(selectedDate)
    }

    var monthItems: [MonthDayItem] {
        let monthAnchor = HabitDate.startOfMonth(for: selectedDate)
        return HabitDate.monthDates(containing: selectedDate).map { date in
            let key = HabitDate.key(for: date)
            let dayHabits = orderedHabits(on: date)
            let completion = dayHabits.filter { state.entries[key]?[$0.id] == true }.count
            let pending = dayHabits
                .filter { state.entries[key]?[$0.id] != true }
                .map { title(for: $0, on: date) }
            let pendingSummary: String
            switch pending.count {
            case 0:
                pendingSummary = "○ 无"
            case 1...2:
                pendingSummary = "○ \(pending.joined(separator: "、"))"
            default:
                pendingSummary = "○ \(pending.prefix(2).joined(separator: "、")) +\(pending.count - 2)"
            }

            return MonthDayItem(
                date: date,
                isCurrentMonth: HabitDate.isInSameMonth(date, as: monthAnchor),
                isSelected: HabitDate.startOfDay(date) == HabitDate.startOfDay(selectedDate),
                isToday: HabitDate.startOfDay(date) == currentToday,
                completionCount: completion,
                totalCount: dayHabits.count,
                pendingSummary: pendingSummary
            )
        }
    }

    var focusButtonTitle: String {
        state.focusSession.active ? "结束专注" : "开始专注"
    }

    var reminderSummary: String {
        "\(reminders.filter(\.enabled).count) 个提醒"
    }

    var weekPlanDays: [WeekPlanDay] {
        HabitDate.weekDates(containing: selectedDate).map { date in
            WeekPlanDay(date: date, habits: orderedHabits(on: date))
        }
    }

    func title(for habit: HabitItem) -> String {
        title(for: habit, on: selectedDate)
    }

    func title(for habit: HabitItem, on date: Date) -> String {
        HabitSnapshotBuilder.title(for: habit, in: state, on: date)
    }

    func isDone(_ habit: HabitItem) -> Bool {
        state.entries[dateKey]?[habit.id] == true
    }

    func select(date: Date) {
        selectedDate = HabitDate.startOfDay(date)
        var next = state
        next.uiPreferences.lastSelectedDateKey = HabitDate.key(for: selectedDate)
        state = next
        persist()
    }

    func shiftWeek(by offset: Int) {
        let next = Calendar.current.date(byAdding: .day, value: offset * 7, to: selectedDate) ?? selectedDate
        select(date: next)
    }

    func shiftMonth(by offset: Int) {
        let next = Calendar.current.date(byAdding: .month, value: offset, to: selectedDate) ?? selectedDate
        select(date: next)
    }

    func jumpToToday() {
        select(date: .now)
    }

    func refreshTodayIfNeeded() {
        let previousToday = currentToday
        let today = HabitDate.startOfDay(.now)
        guard today != previousToday else { return }

        currentToday = today
        if HabitDate.startOfDay(selectedDate) == previousToday {
            select(date: today)
        }
    }

    func toggle(_ habit: HabitItem) {
        #if DEBUG
        if usesCoreDataTrial {
            performCoreDataTrialWrite("打卡失败") {
                try coreDataTrialStore().toggleDone(habitID: habit.id, on: selectedDate)
            }
            return
        }
        #endif

        var next = state
        var day = next.entries[dateKey] ?? [:]
        day[habit.id] = !(day[habit.id] ?? false)
        next.entries[dateKey] = day
        state = next
        persist()
    }

    func moveVisibleHabit(_ movingHabitId: UUID, over targetHabitId: UUID) {
        var visibleIds = orderedHabits.map(\.id)
        guard let sourceIndex = visibleIds.firstIndex(of: movingHabitId),
              let targetIndex = visibleIds.firstIndex(of: targetHabitId),
              sourceIndex != targetIndex
        else { return }

        let movedId = visibleIds.remove(at: sourceIndex)
        let insertionIndex = targetIndex > sourceIndex ? targetIndex : targetIndex
        visibleIds.insert(movedId, at: insertionIndex)
        applyVisibleHabitOrder(visibleIds)
    }

    func addHabit() {
        addHabit(scope: .templateFromToday)
    }

    func addTodayOnlyHabit() {
        addHabit(scope: .todayOnly)
    }

    private func addHabit(scope: HabitEditMode) {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !hasVisibleHabit(named: trimmed, excluding: nil, on: selectedDate) else {
            statusMessage = "今天已有同名事项"
            return
        }
        #if DEBUG
        if usesCoreDataTrial {
            let didWrite = performCoreDataTrialWrite(scope == .todayOnly ? "仅今天新增失败" : "新增模板失败") {
                try coreDataTrialStore().addHabit(
                    title: trimmed,
                    startDate: selectedDate,
                    todayOnly: scope == .todayOnly
                )
            }
            if didWrite {
                draftTitle = ""
                statusMessage = scope == .todayOnly ? "Core Data 试运行：仅今天已新增" : "Core Data 试运行：已加入模板"
            }
            return
        }
        #endif

        var next = state
        switch scope {
        case .todayOnly:
            next.habits.append(HabitItem(title: trimmed, startDateKey: dateKey, endDateKey: dateKey))
            statusMessage = "仅今天已新增"
        case .templateFromToday:
            next.habits.append(HabitItem(title: trimmed, startDateKey: dateKey))
            statusMessage = "已加入模板，从这一天起生效"
        }
        state = next
        draftTitle = ""
        persist()
    }

    func removeHabit(_ habit: HabitItem) {
        #if DEBUG
        if usesCoreDataTrial {
            performCoreDataTrialWrite("删除失败") {
                try coreDataTrialStore().deleteHabit(habitID: habit.id)
            }
            return
        }
        #endif

        var next = state
        next.habits.removeAll { $0.id == habit.id }
        for key in next.entries.keys {
            next.entries[key]?[habit.id] = nil
            next.dailyOverrides[key]?[habit.id] = nil
        }
        next.reminders = next.reminders.map { reminder in
            var updated = reminder
            if updated.linkedHabitId == habit.id {
                updated.linkedHabitId = nil
            }
            return updated
        }
        state = next
        persist()
    }

    func hideHabitToday(_ habit: HabitItem) {
        #if DEBUG
        if usesCoreDataTrial {
            let didWrite = performCoreDataTrialWrite("隐藏失败") {
                try coreDataTrialStore().hideHabitForDay(habitID: habit.id, on: selectedDate)
            }
            if didWrite {
                statusMessage = "Core Data 试运行：仅今天已隐藏"
            }
            return
        }
        #endif

        var next = state
        var hidden = next.hiddenHabits[dateKey] ?? []
        if !hidden.contains(habit.id) {
            hidden.append(habit.id)
        }
        next.hiddenHabits[dateKey] = hidden
        state = next
        statusMessage = "仅今天已隐藏"
        persist()
    }

    func removeHabitFromSelectedDate(_ habit: HabitItem) {
        #if DEBUG
        if usesCoreDataTrial {
            let didWrite = performCoreDataTrialWrite("从这一天起删除失败") {
                try coreDataTrialStore().endHabitFromDate(habitID: habit.id, from: selectedDate)
            }
            if didWrite {
                statusMessage = "Core Data 试运行：已从这一天起删除"
            }
            return
        }
        #endif

        guard let index = state.habits.firstIndex(where: { $0.id == habit.id }) else { return }
        var next = state
        let previousDay = HabitDate.calendar.date(byAdding: .day, value: -1, to: HabitDate.startOfDay(selectedDate)) ?? selectedDate
        next.habits[index].endDateKey = HabitDate.key(for: previousDay)
        next.hiddenHabits[dateKey]?.removeAll { $0 == habit.id }
        state = next
        statusMessage = "已从这一天起删除"
        persist()
    }

    func setRepeatRule(_ rule: HabitRepeatRule, for habit: HabitItem) {
        #if DEBUG
        if usesCoreDataTrial {
            let normalized = normalizedRepeatRule(rule)
            let didWrite = performCoreDataTrialWrite("重复规则保存失败") {
                try coreDataTrialStore().updateRepeatRule(habitID: habit.id, rule: normalized)
            }
            if didWrite {
                statusMessage = "Core Data 试运行：重复规则已设为\(normalized.title)"
            }
            return
        }
        #endif

        guard let index = state.habits.firstIndex(where: { $0.id == habit.id }) else { return }
        var next = state
        next.habits[index].repeatRule = normalizedRepeatRule(rule)
        state = next
        statusMessage = "重复规则已设为\(next.habits[index].repeatRule.title)"
        persist()
    }

    func beginCustomRepeatEdit(for habit: HabitItem) {
        let weekdays: [Int]
        if habit.repeatRule.kind == .custom {
            weekdays = habit.repeatRule.weekdays
        } else {
            weekdays = [HabitDate.calendar.component(.weekday, from: selectedDate)]
        }
        repeatDraft = HabitRepeatDraft(habitId: habit.id, weekdays: Self.normalizedWeekdays(weekdays))
    }

    func toggleRepeatDraftWeekday(_ weekday: Int) {
        guard var draft = repeatDraft else { return }
        if draft.weekdays.contains(weekday) {
            draft.weekdays.removeAll { $0 == weekday }
        } else {
            draft.weekdays.append(weekday)
        }
        repeatDraft = draft
    }

    func saveRepeatDraft() {
        guard let draft = repeatDraft,
              let index = state.habits.firstIndex(where: { $0.id == draft.habitId })
        else { return }
        let weekdays = Self.normalizedWeekdays(draft.weekdays)
        guard !weekdays.isEmpty else {
            statusMessage = "至少选择一天"
            return
        }
        #if DEBUG
        if usesCoreDataTrial {
            let rule = HabitRepeatRule.custom(weekdays)
            let didWrite = performCoreDataTrialWrite("重复规则保存失败") {
                try coreDataTrialStore().updateRepeatRule(habitID: draft.habitId, rule: rule)
            }
            if didWrite {
                repeatDraft = nil
                statusMessage = "Core Data 试运行：重复规则已设为\(rule.title)"
            }
            return
        }
        #endif

        var next = state
        next.habits[index].repeatRule = .custom(weekdays)
        state = next
        repeatDraft = nil
        statusMessage = "重复规则已设为\(next.habits[index].repeatRule.title)"
        persist()
    }

    func cancelRepeatDraft() {
        repeatDraft = nil
    }

    func isRepeatRuleSelected(_ kind: HabitRepeatKind, for habit: HabitItem) -> Bool {
        habit.repeatRule.kind == kind
    }

    func isCustomWeekdaySelected(_ weekday: Int, for habit: HabitItem) -> Bool {
        if habit.repeatRule.kind == .custom {
            return habit.repeatRule.weekdays.contains(weekday)
        }
        return weekday == HabitDate.calendar.component(.weekday, from: selectedDate)
    }

    func toggleDisplayMode() {
        var next = state
        next.uiPreferences.displayMode = displayMode == .normal ? .compact : .normal
        state = next
        persist()
    }

    func setTheme(_ theme: AppTheme) {
        var next = state
        next.uiPreferences.theme = theme
        state = next
        persist()
    }

    func toggleTheme() {
        setTheme(theme == .dark ? .light : .dark)
    }

    func toggleFocusMode() {
        var next = state
        next.uiPreferences.focusModeEnabled.toggle()
        next.focusSession.active = next.uiPreferences.focusModeEnabled
        next.focusSession.startedAt = next.uiPreferences.focusModeEnabled ? .now : nil
        state = next
        persist()
    }

    func openOverview() {
        activePanel = .overview
    }

    func openCalendar() {
        activePanel = .calendar
    }

    func openWeekPlan() {
        activePanel = .weekPlan
    }

    #if DEBUG
    func openCoreDataExperiment() {
        activePanel = .coreDataExperiment
    }

    func setCoreDataTrialEnabled(_ enabled: Bool) {
        guard usesCoreDataTrial != enabled else { return }
        if enabled {
            do {
                state = try coreDataTrialStore().loadAppState()
                usesCoreDataTrial = true
                statusMessage = "Core Data 试运行已开启"
            } catch {
                statusMessage = "Core Data 试运行开启失败，请先导入实验库"
            }
        } else {
            let loaded = HabitStore.shared.load()
            state = Self.normalize(loaded).state
            usesCoreDataTrial = false
            statusMessage = "已回到 JSON 数据源"
        }
    }

    func reloadCoreDataTrialIfNeeded() {
        guard usesCoreDataTrial else { return }
        do {
            state = try coreDataTrialStore().loadAppState()
            statusMessage = "已刷新 Core Data 试运行数据"
        } catch {
            statusMessage = "Core Data 试运行刷新失败: \(error)"
        }
    }
    #endif

    func openReminders() {
        reminderDraft = ReminderDraft()
        showingReminderEditor = true
    }

    func beginEdit(_ habit: HabitItem, mode: HabitEditMode) {
        editingHabitId = habit.id
        editingMode = mode
        editingHabitText = title(for: habit)
    }

    func cancelEdit() {
        editingHabitId = nil
        editingHabitText = ""
    }

    func saveHabitEdit() {
        guard let habitId = editingHabitId,
              let habit = state.habits.first(where: { $0.id == habitId })
        else { return }
        let trimmed = editingHabitText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelEdit()
            return
        }
        guard !hasVisibleHabit(named: trimmed, excluding: habit.id, on: selectedDate) else {
            statusMessage = "今天已有同名事项"
            return
        }

        var next = state

        switch editingMode {
        case .todayOnly:
            #if DEBUG
            if usesCoreDataTrial {
                let didWrite = performCoreDataTrialWrite("仅今天改名失败") {
                    try coreDataTrialStore().renameHabitForDay(habitID: habit.id, title: trimmed, on: selectedDate)
                }
                if didWrite {
                    statusMessage = "Core Data 试运行：仅今天已改名"
                    cancelEdit()
                }
                return
            }
            #endif

            var overrides = next.dailyOverrides[dateKey] ?? [:]
            overrides[habit.id] = trimmed
            next.dailyOverrides[dateKey] = overrides
            statusMessage = "仅今天已改名"
        case .templateFromToday:
            #if DEBUG
            if usesCoreDataTrial {
                let didWrite = performCoreDataTrialWrite("模板改名失败") {
                    try coreDataTrialStore().renameHabitFromDate(habitID: habit.id, title: trimmed, from: selectedDate)
                }
                if didWrite {
                    statusMessage = "Core Data 试运行：模板名已更新"
                    cancelEdit()
                }
                return
            }
            #endif

            if let index = next.habits.firstIndex(where: { $0.id == habit.id }) {
                let oldTitle = title(for: next.habits[index])
                next.habits[index].title = trimmed
                next.habits[index].titleHistory[dateKey] = trimmed
                if next.habits[index].baseTitle.isEmpty {
                    next.habits[index].baseTitle = oldTitle
                }
                next.dailyOverrides[dateKey]?[habit.id] = nil
                statusMessage = "模板名已更新，从这一天起生效"
            }
        }

        state = next
        cancelEdit()
        persist()
    }

    func saveReminder() {
        let trimmed = reminderDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let reminder = ReminderItem(
            title: trimmed,
            hour: reminderDraft.hour,
            minute: reminderDraft.minute,
            repeatMode: reminderDraft.repeatMode,
            linkedHabitId: reminderDraft.linkedHabitId
        )
        var next = state
        next.reminders.append(reminder)
        state = next
        persist()
        showingReminderEditor = false
        Task { await scheduleReminder(reminder) }
    }

    func removeReminder(_ reminder: ReminderItem) {
        var next = state
        next.reminders.removeAll { $0.id == reminder.id }
        state = next
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        persist()
    }

    func toggleReminder(_ reminder: ReminderItem) {
        var next = state
        guard let index = next.reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        next.reminders[index].enabled.toggle()
        let updated = next.reminders[index]
        state = next
        persist()

        if updated.enabled {
            Task { await scheduleReminder(updated) }
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [updated.id.uuidString])
        }
    }

    func toggleAlwaysOnTop() {
        var next = state
        next.uiPreferences.alwaysOnTop.toggle()
        state = next
        applyWindowPreferences()
        persist()
    }

    func minimizeWindow() {
        NSApplication.shared.keyWindow?.miniaturize(nil)
    }

    func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }

    func applyWindowPreferences() {
        guard let window = NSApplication.shared.windows.first else { return }
        window.level = state.uiPreferences.alwaysOnTop ? .floating : .normal
    }

    var weeklyCompletionSummary: String {
        let total = weekItems.reduce(0) { $0 + $1.completionCount }
        return "本周完成 \(total) 项"
    }

    var reminderPanelItems: [ReminderItem] {
        reminders
    }

    private func reminderApplies(_ reminder: ReminderItem, to date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch reminder.repeatMode {
        case .daily:
            return true
        case .weekdays:
            return (2...6).contains(weekday)
        case .weekends:
            return weekday == 1 || weekday == 7
        }
    }

    private func scheduleReminder(_ reminder: ReminderItem) async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                statusMessage = "提醒权限未开启"
                return
            }

            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = "Kite 待办提醒你查看今天的事项"
            content.sound = .default

            var components = DateComponents()
            components.hour = reminder.hour
            components.minute = reminder.minute

            switch reminder.repeatMode {
            case .daily:
                break
            case .weekdays:
                components.weekday = 2
            case .weekends:
                components.weekday = 1
            }

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: reminder.id.uuidString,
                content: content,
                trigger: trigger
            )
            try await center.add(request)
            statusMessage = "提醒已保存"
        } catch {
            statusMessage = "提醒保存失败"
        }
    }

    private func persist() {
        #if DEBUG
        guard !usesCoreDataTrial else { return }
        #endif
        HabitStore.shared.save(state)
    }

    private func habits(on date: Date) -> [HabitItem] {
        uniqueVisibleHabits(HabitSnapshotBuilder.visibleHabits(from: state, on: date), on: date)
    }

    private func orderedHabits(on date: Date) -> [HabitItem] {
        let orderMap = Dictionary(uniqueKeysWithValues: state.habits.enumerated().map { ($1.id, $0) })
        return habits(on: date).sorted { lhs, rhs in
            shouldSort(lhs, before: rhs, on: date, orderMap: orderMap)
        }
    }

    private func shouldSort(
        _ lhs: HabitItem,
        before rhs: HabitItem,
        on date: Date,
        orderMap: [UUID: Int]
    ) -> Bool {
        return (orderMap[lhs.id] ?? 0) < (orderMap[rhs.id] ?? 0)
    }

    private func applyVisibleHabitOrder(_ visibleIds: [UUID]) {
        #if DEBUG
        if usesCoreDataTrial {
            performCoreDataTrialWrite("排序保存失败") {
                try coreDataTrialStore().reorderHabits(orderedIDs: visibleIds)
            }
            return
        }
        #endif

        let visibleSet = Set(visibleIds)
        let habitById = Dictionary(uniqueKeysWithValues: state.habits.map { ($0.id, $0) })
        var remainingVisibleIds = visibleIds
        var next = state

        next.habits = state.habits.compactMap { habit in
            guard visibleSet.contains(habit.id) else { return habit }
            guard !remainingVisibleIds.isEmpty else { return habit }
            let nextId = remainingVisibleIds.removeFirst()
            return habitById[nextId]
        }

        state = next
        persist()
    }

    private func normalizedRepeatRule(_ rule: HabitRepeatRule) -> HabitRepeatRule {
        if rule.kind == .custom {
            let weekdays = Self.normalizedWeekdays(rule.weekdays)
            if weekdays.isEmpty {
                return .custom([HabitDate.calendar.component(.weekday, from: selectedDate)])
            }
            return .custom(weekdays)
        }
        return rule
    }

    private static func normalizedWeekdays(_ weekdays: [Int]) -> [Int] {
        Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
    }

    private func hasVisibleHabit(named name: String, excluding excludedId: UUID?, on date: Date) -> Bool {
        let candidateKey = Self.duplicateTitleKey(name)
        return habits(on: date).contains { habit in
            guard habit.id != excludedId else { return false }
            return Self.duplicateTitleKey(title(for: habit, on: date)) == candidateKey
        }
    }

    private func uniqueVisibleHabits(_ habits: [HabitItem], on date: Date) -> [HabitItem] {
        var seenTitles = Set<String>()
        return habits.filter { habit in
            let key = Self.duplicateTitleKey(title(for: habit, on: date))
            return seenTitles.insert(key).inserted
        }
    }

    private static func normalize(_ state: AppState) -> (state: AppState, didChange: Bool) {
        var normalized = state
        var didChange = false
        normalized.habits = normalized.habits.map { habit in
            var updated = habit
            if updated.baseTitle.isEmpty {
                updated.baseTitle = updated.title
                didChange = true
            }
            let normalizedRule = normalizedRuleForStoredHabit(updated.repeatRule)
            if updated.repeatRule != normalizedRule {
                didChange = true
            }
            updated.repeatRule = normalizedRule
            return updated
        }
        if mergeKnownDuplicateDays(into: &normalized) {
            didChange = true
        }
        return (normalized, didChange)
    }

    private static func normalizedRuleForStoredHabit(_ rule: HabitRepeatRule) -> HabitRepeatRule {
        if rule.kind == .custom {
            let weekdays = normalizedWeekdays(rule.weekdays)
            return weekdays.isEmpty ? .daily : .custom(weekdays)
        }
        return rule
    }

    @discardableResult
    private static func mergeKnownDuplicateDays(into state: inout AppState) -> Bool {
        let knownDateKeys = Set(
            Array(state.entries.keys) +
            Array(state.dailyOverrides.keys) +
            Array(state.hiddenHabits.keys) +
            [HabitDate.key(for: .now), state.uiPreferences.lastSelectedDateKey]
        )

        var didChange = false
        var replacementByHabitId: [UUID: UUID] = [:]
        for dateKey in knownDateKeys {
            let date = HabitDate.date(from: dateKey)
            var keeperByTitle: [String: UUID] = [:]
            for habit in HabitSnapshotBuilder.visibleHabits(from: state, on: date) {
                let titleKey = duplicateTitleKey(HabitSnapshotBuilder.title(for: habit, in: state, on: date))
                if let keeperId = keeperByTitle[titleKey] {
                    didChange = true
                    replacementByHabitId[habit.id] = keeperId
                    if state.entries[dateKey]?[habit.id] == true {
                        state.entries[dateKey]?[keeperId] = true
                    }
                    state.entries[dateKey]?[habit.id] = nil

                    if state.hiddenHabits[dateKey]?.contains(habit.id) == true,
                       state.hiddenHabits[dateKey]?.contains(keeperId) != true {
                        state.hiddenHabits[dateKey]?.append(keeperId)
                    }
                    state.hiddenHabits[dateKey]?.removeAll { $0 == habit.id }
                    state.dailyOverrides[dateKey]?[habit.id] = nil
                } else {
                    keeperByTitle[titleKey] = habit.id
                }
            }
        }

        guard !replacementByHabitId.isEmpty else { return didChange }
        for entryKey in Array(state.entries.keys) {
            for (duplicateId, keeperId) in replacementByHabitId {
                if state.entries[entryKey]?[duplicateId] == true {
                    state.entries[entryKey]?[keeperId] = true
                }
                state.entries[entryKey]?[duplicateId] = nil
                state.dailyOverrides[entryKey]?[duplicateId] = nil
                state.hiddenHabits[entryKey]?.removeAll { $0 == duplicateId }
            }
        }
        state.reminders = state.reminders.map { reminder in
            var updated = reminder
            if let linkedHabitId = updated.linkedHabitId,
               let keeperId = replacementByHabitId[linkedHabitId] {
                updated.linkedHabitId = keeperId
            }
            return updated
        }
        return didChange
    }

    private static func duplicateTitleKey(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var normalized = ""
        for scalar in trimmed.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .control, .format, .surrogate, .unassigned:
                continue
            default:
                normalized.unicodeScalars.append(scalar)
            }
        }
        return normalized.precomposedStringWithCanonicalMapping
    }

    #if DEBUG
    private func coreDataTrialStore() -> HabitCoreDataStore {
        HabitSyncStoreFactory.makeStore(
            directoryName: HabitCoreDataExperiment.directoryName,
            fileName: HabitCoreDataExperiment.storeFileName,
            mode: HabitSyncStoreMode.current
        )
    }

    @discardableResult
    private func performCoreDataTrialWrite(
        _ failureMessage: String,
        operation: () throws -> Void
    ) -> Bool {
        do {
            try operation()
            state = try coreDataTrialStore().loadAppState()
            return true
        } catch {
            statusMessage = "\(failureMessage): \(error)"
            return false
        }
    }
    #endif
}
