import SwiftUI

struct ChecklistView: View {
    @EnvironmentObject private var store: HabitViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.06, blue: 0.12), Color(red: 0.02, green: 0.04, blue: 0.09)],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: store.displayMode == .compact ? 8 : 9) {
                HeaderBarView()
                if !store.isFocusModeEnabled {
                    ActionButtonsView()
                }
                WeekStripView()
                HabitListView()
                AddHabitBarView()
            }
            .padding(.horizontal, store.displayMode == .compact ? 12 : 18)
            .padding(.top, store.displayMode == .compact ? 6 : 8)
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

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kite 待办")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(red: 0.63, green: 0.69, blue: 0.81))
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

    var body: some View {
        HStack(spacing: 10) {
            Button(action: store.toggleFocusMode) {
                actionCard(title: store.focusButtonTitle)
            }
            .buttonStyle(.plain)

            Button(action: store.openReminders) {
                actionCard(title: "添加提醒")
            }
            .buttonStyle(.plain)

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
            .background(Color(red: 0.14, green: 0.18, blue: 0.27), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct WeekStripView: View {
    @EnvironmentObject private var store: HabitViewModel

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { store.shiftWeek(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 32, height: 68)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                ForEach(store.weekItems) { item in
                    Button(action: { store.select(date: item.date) }) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(item.hasMarker ? Color(red: 0.96, green: 0.74, blue: 0.08) : .clear)
                                    .frame(width: 8, height: 8)
                            }

                            Text(item.weekdayTitle)
                                .font(.system(size: 18, weight: .medium))
                            Text(item.dayLabel)
                                .font(.system(size: 14, weight: .regular))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(item.isSelected ? Color(red: 0.19, green: 0.83, blue: 0.42) : Color.white.opacity(0.72))
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            item.isSelected
                                ? Color(red: 0.03, green: 0.06, blue: 0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)

            Button(action: { store.shiftWeek(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 32, height: 68)
            }
            .buttonStyle(.plain)
        }
        .background(Color(red: 0.15, green: 0.19, blue: 0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct HabitListView: View {
    @EnvironmentObject private var store: HabitViewModel
    @FocusState private var focusedHabitId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(store.habits) { habit in
                HStack(spacing: 14) {
                    Button {
                        store.toggle(habit)
                    } label: {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.92), lineWidth: 1.8)
                            .fill(store.isDone(habit) ? Color.clear : Color.clear)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if store.isDone(habit) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(red: 0.19, green: 0.83, blue: 0.42))
                                        .padding(4)
                                }
                            }
                    }
                    .buttonStyle(.plain)

                    if store.editingHabitId == habit.id {
                        TextField("", text: $store.editingHabitText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .focused($focusedHabitId, equals: habit.id)
                            .onAppear {
                                DispatchQueue.main.async {
                                    focusedHabitId = habit.id
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
                        Text(store.title(for: habit))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .strikethrough(store.isDone(habit), color: .white.opacity(0.4))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if store.editingHabitId != habit.id {
                                    store.beginEdit(habit, mode: .todayOnly)
                                }
                            }
                    }
                }
                .padding(.horizontal, 22)
                .frame(height: 54)
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        store.beginEdit(habit, mode: .templateFromToday)
                    } label: {
                        Label("修改模板名（今天及以后）", systemImage: "calendar.badge.plus")
                    }

                    Button(role: .destructive) {
                        store.removeHabit(habit)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }

                if habit.id != store.habits.last?.id {
                    Divider()
                        .overlay(Color.white.opacity(0.05))
                        .padding(.horizontal, 18)
                }
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 0.8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.02, green: 0.04, blue: 0.08))
                )
        )
    }
}

private struct AddHabitBarView: View {
    @EnvironmentObject private var store: HabitViewModel

    var body: some View {
        HStack(spacing: 10) {
            TextField("添加一个每天都想做的事项", text: $store.draftTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .frame(height: 42)
                .background(Color(red: 0.15, green: 0.19, blue: 0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button(action: store.addHabit) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 42)
                    .background(Color(red: 0.15, green: 0.19, blue: 0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("日期选择")
                .font(.system(size: 20, weight: .semibold))
            DatePicker(
                "跳转到日期",
                selection: Binding(
                    get: { store.selectedDate },
                    set: { store.select(date: $0) }
                ),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)

            Button("回到今天") {
                store.jumpToToday()
                store.activePanel = nil
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 420)
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
                    ForEach(store.habits) { habit in
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
