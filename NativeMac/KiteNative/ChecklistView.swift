import SwiftUI

private struct ThemePalette {
    let backgroundTop: Color
    let backgroundBottom: Color
    let panel: Color
    let panelStrong: Color
    let card: Color
    let textPrimary: Color
    let textSecondary: Color
    let divider: Color
    let accent: Color
    let accentSoft: Color
    let success: Color
    let successSoft: Color

    static func palette(for theme: AppTheme) -> ThemePalette {
        switch theme {
        case .dark:
            return ThemePalette(
                backgroundTop: Color(red: 0.03, green: 0.06, blue: 0.12),
                backgroundBottom: Color(red: 0.02, green: 0.04, blue: 0.09),
                panel: Color(red: 0.15, green: 0.19, blue: 0.28),
                panelStrong: Color(red: 0.02, green: 0.04, blue: 0.08),
                card: Color(red: 0.14, green: 0.18, blue: 0.27),
                textPrimary: .white,
                textSecondary: Color(red: 0.63, green: 0.69, blue: 0.81),
                divider: Color.white.opacity(0.08),
                accent: Color(red: 0.19, green: 0.83, blue: 0.42),
                accentSoft: Color(red: 0.14, green: 0.46, blue: 0.99),
                success: Color(red: 0.19, green: 0.83, blue: 0.42),
                successSoft: Color(red: 0.19, green: 0.83, blue: 0.42).opacity(0.16)
            )
        case .light:
            return ThemePalette(
                backgroundTop: Color(red: 0.95, green: 0.97, blue: 1.0),
                backgroundBottom: Color(red: 0.90, green: 0.93, blue: 0.98),
                panel: Color.white,
                panelStrong: Color(red: 0.96, green: 0.97, blue: 0.99),
                card: Color(red: 0.92, green: 0.94, blue: 0.98),
                textPrimary: Color(red: 0.12, green: 0.16, blue: 0.24),
                textSecondary: Color(red: 0.39, green: 0.45, blue: 0.56),
                divider: Color.black.opacity(0.08),
                accent: Color(red: 0.11, green: 0.64, blue: 0.32),
                accentSoft: Color(red: 0.18, green: 0.48, blue: 0.96),
                success: Color(red: 0.11, green: 0.64, blue: 0.32),
                successSoft: Color(red: 0.11, green: 0.64, blue: 0.32).opacity(0.10)
            )
        }
    }
}

struct ChecklistView: View {
    @EnvironmentObject private var store: HabitViewModel
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: store.displayMode == .compact ? 8 : 9) {
                HeaderBarView()
                    .padding(.top, store.displayMode == .compact ? 6 : 12)
                Spacer()
                    .frame(height: store.displayMode == .compact ? 6 : 12)
                WeekStripView()
                HabitListView()
                    .frame(maxHeight: .infinity)
                AddHabitBarView()
            }
            .padding(.horizontal, store.displayMode == .compact ? 12 : 18)
            .padding(.top, store.displayMode == .compact ? 4 : 6)
            .padding(.bottom, store.displayMode == .compact ? 10 : 12)
        }
        .sheet(item: $store.activePanel) { panel in
            switch panel {
            case .overview:
                OverviewPanelView()
                    .environmentObject(store)
            case .calendar:
                CalendarPanelView()
                    .environmentObject(store)
            case .reminders:
                RemindersPanelView()
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $store.showingReminderEditor) {
            ReminderEditorView()
                .environmentObject(store)
        }
        .overlay(alignment: .bottom) {
            if let status = store.statusMessage {
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.10), in: Capsule())
                    .padding(.bottom, 10)
            }
        }
        .onAppear {
            store.applyWindowPreferences()
        }
    }
}

private struct HeaderBarView: View {
    @EnvironmentObject private var store: HabitViewModel
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kite 待办")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
                    .accessibilityIdentifier("app-title")
            }

            Spacer()

            HStack(spacing: 11) {
                IconButton(systemName: "sparkles", action: store.openOverview, symbolSize: 16)
                IconButton(systemName: "calendar", action: store.openCalendar, symbolSize: 15)
                IconButton(systemName: "rectangle.split.3x1", action: store.toggleDisplayMode, symbolSize: 15)
                IconButton(systemName: "moon", action: store.toggleFocusMode, symbolSize: 15, highlighted: store.isFocusModeEnabled)
                Divider()
                    .frame(width: 1, height: 18)
                    .overlay(Color.white.opacity(0.12))
                IconButton(systemName: "pin", action: store.toggleAlwaysOnTop, symbolSize: 15, highlighted: store.isAlwaysOnTop)
                IconButton(systemName: "minus", action: store.minimizeWindow, symbolSize: 15)
                IconButton(systemName: "xmark", action: store.closeWindow, symbolSize: 15)
            }
            .padding(.trailing, 4)
        }
    }
}

private struct ActionButtonsView: View {
    @EnvironmentObject private var store: HabitViewModel
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: store.toggleFocusMode) {
                actionCard(title: store.focusButtonTitle)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("focus-button")

            Button(action: store.openReminders) {
                actionCard(title: "添加提醒")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("reminder-button")

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.orange, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("😊")
                    .font(.system(size: 22))
            }
            .frame(width: 50, height: 50)
        }
    }

    private func actionCard(title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct WeekStripView: View {
    @EnvironmentObject private var store: HabitViewModel
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { store.shiftWeek(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 32, height: 54)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("week-prev-button")

            HStack(spacing: 8) {
                ForEach(store.weekItems) { item in
                    Button(action: { store.select(date: item.date) }) {
                        ZStack(alignment: .topLeading) {
                            if item.hasMarker {
                                Circle()
                                    .fill(Color(red: 0.96, green: 0.74, blue: 0.08))
                                    .frame(width: 8, height: 8)
                                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                                    .padding(.top, 6)
                                    .padding(.trailing, 6)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Spacer()
                                    .frame(height: 6)

                                Text(item.weekdayTitle)
                                    .font(.system(size: 17, weight: .medium))
                                    .frame(height: 22, alignment: .topLeading)

                                Text(item.dayLabel)
                                    .font(.system(size: 13, weight: .regular))
                                    .frame(height: 16, alignment: .topLeading)

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .foregroundStyle(item.isSelected ? palette.accent : palette.textPrimary.opacity(0.72))
                        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54, alignment: .topLeading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(item.isSelected ? palette.panelStrong : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("week-day-\(item.id)")
                }
            }
            .padding(.horizontal, 6)

            Button(action: { store.shiftWeek(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 32, height: 54)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("week-next-button")
        }
        .background(palette.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier("week-strip")
    }
}

private struct HabitListView: View {
    @EnvironmentObject private var store: HabitViewModel
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                habitSection(for: store.pendingHabits)

                if !store.completedHabits.isEmpty && !store.pendingHabits.isEmpty {
                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 4)
                }

                habitSection(for: store.completedHabits)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.orderedHabits.map(\.id))
        .animation(.easeInOut(duration: 0.18), value: store.doneCount)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 0.8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.panelStrong)
                )
        )
    }

    @ViewBuilder
    private func habitSection(for habits: [HabitItem]) -> some View {
        ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
            HabitRowView(habit: habit, isLast: index == habits.count - 1)
                .environmentObject(store)
        }
    }
}

private struct HabitRowView: View {
    @EnvironmentObject private var store: HabitViewModel
    @FocusState private var isEditorFocused: Bool
    private var palette: ThemePalette { .palette(for: store.theme) }

    let habit: HabitItem
    let isLast: Bool

    var body: some View {
        HStack(spacing: 14) {
            Button {
                store.toggle(habit)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(store.isDone(habit) ? palette.success : Color.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(
                                    store.isDone(habit)
                                        ? palette.success
                                        : palette.textPrimary.opacity(0.92),
                                    lineWidth: 1.8
                                )
                        }

                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(store.isDone(habit) ? 1 : 0)
                }
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(store.isDone(habit) ? "标记未完成" : "标记完成")
            .accessibilityIdentifier("habit-toggle-\(habit.id.uuidString)")

            if store.editingHabitId == habit.id {
                TextField("", text: $store.editingHabitText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .focused($isEditorFocused)
                    .accessibilityIdentifier("habit-editor-\(habit.id.uuidString)")
                    .onAppear {
                        DispatchQueue.main.async {
                            isEditorFocused = true
                        }
                    }
                    .onSubmit {
                        store.saveHabitEdit()
                    }
                    .onDisappear {
                        if store.editingHabitId == habit.id {
                            store.saveHabitEdit()
                        }
                    }
            } else {
                Button {
                    if store.editingHabitId != habit.id {
                        store.beginEdit(habit, mode: .todayOnly)
                    }
                } label: {
                    Text(store.title(for: habit))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(store.isDone(habit) ? palette.textSecondary.opacity(0.85) : palette.textPrimary)
                        .strikethrough(store.isDone(habit), color: palette.textSecondary.opacity(0.82))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(store.title(for: habit))
                .accessibilityIdentifier("habit-title-\(habit.id.uuidString)")
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 54)
        .background(store.isDone(habit) ? palette.successSoft : Color.clear)
        .opacity(store.isDone(habit) ? 0.82 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("habit-row-\(habit.id.uuidString)")
        .contextMenu {
            Button {
                if store.editingHabitId != habit.id {
                    store.beginEdit(habit, mode: .todayOnly)
                }
            } label: {
                Label("仅修改今天", systemImage: "pencil")
            }

            Button {
                store.beginEdit(habit, mode: .templateFromToday)
            } label: {
                Label("修改模板名（从这一天起）", systemImage: "calendar.badge.plus")
            }

            Button(role: .destructive) {
                store.removeHabit(habit)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }

        if !isLast {
            Divider()
                .overlay(palette.divider)
                .padding(.horizontal, 18)
        }
    }
}

private struct AddHabitBarView: View {
    @EnvironmentObject private var store: HabitViewModel
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        HStack(spacing: 10) {
            TextField("从这一天起添加一个固定事项", text: $store.draftTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 15)
                .frame(height: 42)
                .background(palette.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("add-habit-input")
                .onSubmit {
                    store.addHabit()
                }

            Button(action: store.addTodayOnlyHabit) {
                Text("仅今天")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: 58, height: 42)
                    .background(palette.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("add-today-habit-button")

            Button(action: store.addHabit) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: 48, height: 42)
                    .background(palette.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("add-habit-button")
        }
    }
}

private struct OverviewPanelView: View {
    @EnvironmentObject private var store: HabitViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("今日") {
                    Label("已完成 \(store.doneCount) 项", systemImage: "checkmark.circle")
                    Label("待完成 \(store.pendingCount) 项", systemImage: "circle.dashed")
                    Label(store.progressText, systemImage: "chart.bar")
                }

                Section("本周") {
                    Text(store.weeklyCompletionSummary)
                }

                Section("提醒") {
                    ForEach(store.reminders.prefix(3)) { reminder in
                        Text("\(reminder.title) \(String(format: "%02d:%02d", reminder.hour, reminder.minute))")
                    }
                }
            }
            .navigationTitle("总览")
        }
        .frame(minWidth: 360, minHeight: 360)
    }
}

private struct CalendarPanelView: View {
    @EnvironmentObject private var store: HabitViewModel
    private let weekdayHeaders = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("日期总览")
                        .font(.system(size: 26, weight: .bold))
                    Text("按月查看每天的完成情况，并可直接跳转到当天。")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        store.shiftMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.borderless)

                        Text(store.monthTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(minWidth: 120)

                    Button {
                        store.shiftMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                }
            }

            VStack(spacing: 0) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(weekdayHeaders, id: \.self) { weekday in
                        Text(weekday)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(palette.panelStrong)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(store.monthItems) { item in
                        Button {
                            store.select(date: item.date)
                            store.activePanel = nil
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.dayNumber)
                                        .font(.system(size: 16, weight: item.isSelected ? .bold : .semibold))
                                        .foregroundStyle(dayTextColor(for: item))
                                    Spacer()
                                    if item.isToday {
                                        Circle()
                                            .fill(item.isSelected ? Color.white.opacity(0.9) : palette.accent)
                                            .frame(width: 8, height: 8)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.completionSummary)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(item.isSelected ? Color.white : palette.success)

                                    Text(item.pendingSummary)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(item.isSelected ? Color.white.opacity(0.88) : palette.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                            .background(dayBackground(for: item))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(palette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.divider, lineWidth: 1)
            )

            HStack(spacing: 12) {
                Button("回到今天") {
                    store.jumpToToday()
                    store.activePanel = nil
                }
                .buttonStyle(.borderedProminent)

                Text("当前选中：\(store.selectedDateTitle)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(24)
        .background(
            LinearGradient(colors: [palette.backgroundTop.opacity(0.92), palette.backgroundBottom.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .frame(minWidth: 1100, minHeight: 760)
    }

    private func dayTextColor(for item: MonthDayItem) -> Color {
        if item.isSelected {
            return .white
        }
        if item.isToday {
            return palette.accent
        }
        return item.isCurrentMonth ? palette.textPrimary : palette.textSecondary.opacity(0.55)
    }

    @ViewBuilder
    private func dayBackground(for item: MonthDayItem) -> some View {
        if item.isSelected {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(LinearGradient(colors: [palette.accentSoft, palette.accentSoft.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
        } else if item.isToday {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(palette.successSoft)
        } else if item.isCurrentMonth {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(palette.panel)
        } else {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(palette.panelStrong)
        }
    }
}

private struct RemindersPanelView: View {
    @EnvironmentObject private var store: HabitViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.reminderPanelItems) { reminder in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.title)
                            Text("\(String(format: "%02d:%02d", reminder.hour, reminder.minute)) · \(reminder.repeatMode.title)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { reminder.enabled },
                            set: { _ in store.toggleReminder(reminder) }
                        ))
                        .labelsHidden()
                        Button(role: .destructive) {
                            store.removeReminder(reminder)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .navigationTitle("提醒")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("新增") {
                        store.openReminders()
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
    }
}

private struct ReminderEditorView: View {
    @EnvironmentObject private var store: HabitViewModel

    var body: some View {
        NavigationStack {
            Form {
                TextField("提醒标题", text: $store.reminderDraft.title)

                HStack {
                    Stepper("小时 \(store.reminderDraft.hour)", value: $store.reminderDraft.hour, in: 0...23)
                    Stepper("分钟 \(store.reminderDraft.minute)", value: $store.reminderDraft.minute, in: 0...59, step: 5)
                }

                Picker("重复", selection: $store.reminderDraft.repeatMode) {
                    ForEach(ReminderRepeatMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Picker("关联事项", selection: $store.reminderDraft.linkedHabitId) {
                    Text("无").tag(UUID?.none)
                    ForEach(store.orderedHabits) { habit in
                        Text(habit.title).tag(Optional(habit.id))
                    }
                }
            }
            .navigationTitle("添加提醒")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        store.showingReminderEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.saveReminder()
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 260)
    }
}

private struct IconButton: View {
    let systemName: String
    let action: () -> Void
    var symbolSize: CGFloat = 16
    var highlighted = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(highlighted ? Color.yellow : Color.white.opacity(0.72))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
    }
}
