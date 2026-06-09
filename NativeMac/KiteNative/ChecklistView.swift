import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ThemePalette {
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
                backgroundTop: Color(red: 0.08, green: 0.08, blue: 0.09),
                backgroundBottom: Color(red: 0.04, green: 0.04, blue: 0.05),
                panel: Color(red: 0.14, green: 0.14, blue: 0.16),
                panelStrong: Color(red: 0.09, green: 0.09, blue: 0.11),
                card: Color(red: 0.18, green: 0.18, blue: 0.20),
                textPrimary: .white,
                textSecondary: Color(red: 0.66, green: 0.67, blue: 0.72),
                divider: Color.white.opacity(0.075),
                accent: Color(red: 0.36, green: 0.70, blue: 1.0),
                accentSoft: Color(red: 0.25, green: 0.52, blue: 0.92),
                success: Color(red: 0.33, green: 0.82, blue: 0.58),
                successSoft: Color(red: 0.33, green: 0.82, blue: 0.58).opacity(0.11)
            )
        case .light:
            return ThemePalette(
                backgroundTop: Color(red: 0.97, green: 0.97, blue: 0.96),
                backgroundBottom: Color(red: 0.91, green: 0.92, blue: 0.94),
                panel: Color.white.opacity(0.86),
                panelStrong: Color(red: 0.94, green: 0.95, blue: 0.96),
                card: Color.white,
                textPrimary: Color(red: 0.10, green: 0.11, blue: 0.13),
                textSecondary: Color(red: 0.42, green: 0.44, blue: 0.49),
                divider: Color.black.opacity(0.075),
                accent: Color(red: 0.0, green: 0.45, blue: 0.95),
                accentSoft: Color(red: 0.0, green: 0.42, blue: 0.88),
                success: Color(red: 0.08, green: 0.57, blue: 0.34),
                successSoft: Color(red: 0.08, green: 0.57, blue: 0.34).opacity(0.08)
            )
        }
    }
}

struct ChecklistView: View {
    @EnvironmentObject private var store: HabitViewModel
    @Environment(\.scenePhase) private var scenePhase
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
                    .padding(.top, store.displayMode == .compact ? 8 : 14)
                Spacer()
                    .frame(height: store.displayMode == .compact ? 4 : 8)
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
            case .weekPlan:
                WeekPlanPanelView()
                    .environmentObject(store)
            case .reminders:
                RemindersPanelView()
                    .environmentObject(store)
            #if DEBUG
            case .coreDataExperiment:
                CoreDataExperimentPanelView()
                    .environmentObject(store)
            #endif
            }
        }
        .sheet(isPresented: $store.showingReminderEditor) {
            ReminderEditorView()
                .environmentObject(store)
        }
        .sheet(item: $store.repeatDraft) { _ in
            CustomRepeatEditorView()
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
        .background(
            MainWindowClickDismissHandler(activePanel: $store.activePanel)
        )
        .onAppear {
            store.applyWindowPreferences()
            store.refreshTodayIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshTodayIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            store.refreshTodayIfNeeded()
        }
    }
}

private struct MainWindowClickDismissHandler: NSViewRepresentable {
    @Binding var activePanel: ToolbarPanel?

    func makeCoordinator() -> Coordinator {
        Coordinator(activePanel: $activePanel)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        context.coordinator.hostView = view
        context.coordinator.update(activePanel: activePanel)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.update(activePanel: activePanel)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopListening()
    }

    final class Coordinator {
        private var activePanel: Binding<ToolbarPanel?>
        private var localMonitor: Any?
        weak var hostView: NSView?

        init(activePanel: Binding<ToolbarPanel?>) {
            self.activePanel = activePanel
        }

        func update(activePanel: ToolbarPanel?) {
            if Self.isDismissible(panel: activePanel) {
                startListeningIfNeeded()
            } else {
                stopListening()
            }
        }

        func stopListening() {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
        }

        private func startListeningIfNeeded() {
            guard localMonitor == nil else { return }

            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                guard let self else { return event }
                guard Self.isDismissible(panel: self.activePanel.wrappedValue) else {
                    self.stopListening()
                    return event
                }
                guard event.window === self.hostView?.window else {
                    return event
                }

                self.activePanel.wrappedValue = nil
                self.stopListening()
                return nil
            }
        }

        private static func isDismissible(panel: ToolbarPanel?) -> Bool {
            switch panel {
            case .overview, .calendar, .weekPlan:
                return true
            #if DEBUG
            case .coreDataExperiment:
                return false
            #endif
            case .reminders, nil:
                return false
            }
        }
    }
}

private struct HeaderBarView: View {
    @EnvironmentObject private var store: HabitViewModel
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("Kite")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .accessibilityIdentifier("app-title")

                    Text(store.progressText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(palette.accent.opacity(0.12), in: Capsule())
                }

                Text("\(store.selectedDateTitle) · \(store.pendingCount) 项待完成")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .accessibilityIdentifier("app-subtitle")
            }

            Spacer()

            HStack(spacing: 6) {
                IconButton(systemName: "sparkles", action: store.openOverview, symbolSize: 16, tint: palette.textSecondary)
                IconButton(systemName: "calendar", action: store.openCalendar, symbolSize: 15, tint: palette.textSecondary)
                IconButton(systemName: "calendar.day.timeline.left", action: store.openWeekPlan, symbolSize: 15, tint: palette.textSecondary)
                #if DEBUG
                IconButton(systemName: "externaldrive.badge.icloud", action: store.openCoreDataExperiment, symbolSize: 15, tint: palette.accent)
                #endif
                IconButton(systemName: "rectangle.split.3x1", action: store.toggleDisplayMode, symbolSize: 15, tint: palette.textSecondary)
                IconButton(
                    systemName: store.theme == .dark ? "circle.lefthalf.filled" : "circle.righthalf.filled",
                    action: store.toggleTheme,
                    symbolSize: 15,
                    tint: palette.textSecondary
                )
                IconButton(
                    systemName: "pin",
                    action: store.toggleAlwaysOnTop,
                    symbolSize: 15,
                    highlighted: store.isAlwaysOnTop,
                    tint: palette.textSecondary,
                    tiltWhenHighlighted: true
                )
                IconButton(systemName: "minus", action: store.minimizeWindow, symbolSize: 15, tint: palette.textSecondary)
                IconButton(systemName: "xmark", action: store.closeWindow, symbolSize: 15, tint: palette.textSecondary)
            }
            .padding(5)
            .background(palette.panel.opacity(0.78), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(palette.divider, lineWidth: 0.8)
            }
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
                    .foregroundStyle(palette.textSecondary.opacity(0.9))
                    .frame(width: 30, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("week-prev-button")

            HStack(spacing: 8) {
                ForEach(store.weekItems) { item in
                    Button(action: { store.select(date: item.date) }) {
                        ZStack(alignment: .topLeading) {
                            if item.hasMarker {
                                Circle()
                                    .fill(item.isSelected ? palette.accent : palette.textSecondary.opacity(0.55))
                                    .frame(width: 5, height: 5)
                                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                                    .padding(.top, 7)
                                    .padding(.trailing, 7)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Spacer()
                                    .frame(height: 6)

                                Text(item.weekdayTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(height: 22, alignment: .topLeading)

                                Text(item.dayLabel)
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(height: 16, alignment: .topLeading)

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .foregroundStyle(item.isSelected ? palette.textPrimary : palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52, alignment: .topLeading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(item.isSelected ? palette.card : Color.clear)
                        )
                        .overlay {
                            if item.isSelected {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(palette.divider, lineWidth: 0.8)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("week-day-\(item.id)")
                }
            }
            .padding(.horizontal, 6)

            Button(action: { store.shiftWeek(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.textSecondary.opacity(0.9))
                    .frame(width: 30, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("week-next-button")
        }
        .padding(4)
        .background(palette.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.divider, lineWidth: 0.8)
        }
    }
}

private struct HabitListView: View {
    @EnvironmentObject private var store: HabitViewModel
    @State private var draggingHabitId: UUID?
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                habitSection(for: store.orderedHabits)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.orderedHabits.map(\.id))
        .animation(.easeInOut(duration: 0.18), value: store.doneCount)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.divider, lineWidth: 0.8)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(palette.panel.opacity(0.78))
                )
        )
    }

    @ViewBuilder
    private func habitSection(for habits: [HabitItem]) -> some View {
        ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
            HabitRowView(habit: habit, isLast: index == habits.count - 1)
                .environmentObject(store)
                .opacity(draggingHabitId == habit.id ? 0.55 : 1)
                .onDrag {
                    draggingHabitId = habit.id
                    return NSItemProvider(object: habit.id.uuidString as NSString)
                } preview: {
                    HabitDragPreview(title: store.title(for: habit), theme: store.theme)
                }
                .onDrop(
                    of: [.text],
                    delegate: HabitDropDelegate(
                        targetHabit: habit,
                        draggingHabitId: $draggingHabitId,
                        store: store
                    )
                )
        }
    }
}

private struct HabitDragPreview: View {
    let title: String
    let theme: AppTheme

    private var palette: ThemePalette { .palette(for: theme) }

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(palette.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(palette.panelStrong.opacity(0.94), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(palette.divider, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

private struct HabitDropDelegate: DropDelegate {
    let targetHabit: HabitItem
    @Binding var draggingHabitId: UUID?
    let store: HabitViewModel

    func dropEntered(info: DropInfo) {
        guard let draggingHabitId,
              draggingHabitId != targetHabit.id
        else { return }
        store.moveVisibleHabit(draggingHabitId, over: targetHabit.id)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingHabitId = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
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
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(store.isDone(habit) ? palette.success : Color.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(
                                    store.isDone(habit)
                                        ? palette.success
                                        : palette.textSecondary.opacity(0.72),
                                    lineWidth: 1.5
                                )
                        }

                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(store.isDone(habit) ? 1 : 0)
                }
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(store.isDone(habit) ? "标记未完成" : "标记完成")
            .accessibilityIdentifier("habit-toggle-\(habit.id.uuidString)")

            if store.editingHabitId == habit.id {
                TextField("", text: $store.editingHabitText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
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
                    .onChange(of: isEditorFocused) { _, focused in
                        if !focused && store.editingHabitId == habit.id {
                            store.saveHabitEdit()
                        }
                    }
                    .onDisappear {
                        if store.editingHabitId == habit.id {
                            store.saveHabitEdit()
                        }
                    }
            } else {
                Button {
                    store.toggle(habit)
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
        .padding(.horizontal, 20)
        .frame(height: 52)
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

            Menu {
                Button {
                    store.setRepeatRule(.daily, for: habit)
                } label: {
                    Label("每天", systemImage: store.isRepeatRuleSelected(.daily, for: habit) ? "checkmark" : "circle")
                }

                Button {
                    store.setRepeatRule(.weekdays, for: habit)
                } label: {
                    Label("工作日", systemImage: store.isRepeatRuleSelected(.weekdays, for: habit) ? "checkmark" : "circle")
                }

                Button {
                    store.setRepeatRule(.weekends, for: habit)
                } label: {
                    Label("周末", systemImage: store.isRepeatRuleSelected(.weekends, for: habit) ? "checkmark" : "circle")
                }

                Button {
                    store.beginCustomRepeatEdit(for: habit)
                } label: {
                    Label("自定义周几...", systemImage: store.isRepeatRuleSelected(.custom, for: habit) ? "checkmark" : "calendar")
                }
            } label: {
                Label("重复规则：\(habit.repeatRule.title)", systemImage: "repeat")
            }

            Button {
                store.hideHabitToday(habit)
            } label: {
                Label("仅今天隐藏", systemImage: "eye.slash")
            }

            Button(role: .destructive) {
                store.removeHabitFromSelectedDate(habit)
            } label: {
                Label("从这一天起删除", systemImage: "trash")
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
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 15)
                .frame(height: 44)
                .background(palette.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(palette.divider, lineWidth: 0.8)
                }
                .accessibilityIdentifier("add-habit-input")
                .onSubmit {
                    store.addHabit()
                }

            Button(action: store.addTodayOnlyHabit) {
                Text("仅今天")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 60, height: 44)
                    .background(palette.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(palette.divider, lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("add-today-habit-button")

            Button(action: store.addHabit) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 44)
                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("add-habit-button")
        }
    }
}

private struct OverviewPanelView: View {
    @EnvironmentObject private var store: HabitViewModel
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 42, height: 42)
                    .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("总览")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    Text("\(store.selectedDateTitle) · \(store.progressText) 完成")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                OverviewStatCard(
                    title: "已完成",
                    value: "\(store.doneCount)",
                    systemName: "checkmark",
                    tint: palette.success
                )

                OverviewStatCard(
                    title: "待完成",
                    value: "\(store.pendingCount)",
                    systemName: "circle.dashed",
                    tint: palette.accent
                )

                OverviewStatCard(
                    title: "完成率",
                    value: store.progressText,
                    systemName: "chart.bar.fill",
                    tint: palette.accentSoft
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("本周")

                HStack(alignment: .center, spacing: 12) {
                    Text(store.weeklyCompletionSummary)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)

                    Spacer()

                    Text("7 天视图")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(palette.panelStrong, in: Capsule())
                }
            }
            .padding(14)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.divider, lineWidth: 0.8)
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("提醒")

                if store.reminders.isEmpty {
                    Text("还没有提醒")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.reminders.prefix(3).enumerated()), id: \.element.id) { index, reminder in
                            HStack(spacing: 10) {
                                Image(systemName: reminder.enabled ? "bell.fill" : "bell.slash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(reminder.enabled ? palette.accent : palette.textSecondary)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        (reminder.enabled ? palette.accent.opacity(0.10) : palette.panelStrong),
                                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    )

                                Text(reminder.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(palette.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Text(String(format: "%02d:%02d", reminder.hour, reminder.minute))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(palette.textSecondary)
                            }
                            .padding(.vertical, 9)

                            if index < min(store.reminders.count, 3) - 1 {
                                Divider()
                                    .overlay(palette.divider)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.divider, lineWidth: 0.8)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(width: 430)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(palette.textSecondary)
    }
}

private struct OverviewStatCard: View {
    let title: String
    let value: String
    let systemName: String
    let tint: Color
    @EnvironmentObject private var store: HabitViewModel
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(palette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.divider, lineWidth: 0.8)
        }
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

private struct WeekPlanPanelView: View {
    @EnvironmentObject private var store: HabitViewModel
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("本周安排")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                    Text("按周查看每天会出现的事项。")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        store.shiftWeek(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)

                    Button("本周") {
                        store.jumpToToday()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        store.shiftWeek(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                ForEach(store.weekPlanDays) { day in
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(day.weekdayTitle)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(palette.textPrimary)
                            Text(day.dayLabel)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()
                            .overlay(palette.divider)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                if day.habits.isEmpty {
                                    Text("无")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(palette.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    ForEach(day.habits) { habit in
                                        Text(store.title(for: habit, on: day.date))
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(palette.textPrimary)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 11)
                                            .padding(.vertical, 9)
                                            .background(
                                                palette.panelStrong,
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 460, alignment: .topLeading)
                    .background(palette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(palette.divider, lineWidth: 1)
                    )
                }
            }
        }
        .padding(28)
        .background(
            LinearGradient(
                colors: [palette.backgroundTop.opacity(0.96), palette.backgroundBottom.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(minWidth: 1140, minHeight: 680)
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

private struct CustomRepeatEditorView: View {
    @EnvironmentObject private var store: HabitViewModel
    private var palette: ThemePalette { .palette(for: store.theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("自定义周几")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                Text(repeatHabitTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                ForEach(1...7, id: \.self) { weekday in
                    Button {
                        store.toggleRepeatDraftWeekday(weekday)
                    } label: {
                        Text(shortWeekdayTitle(for: weekday))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSelected(weekday) ? Color.white : palette.textPrimary)
                            .frame(width: 48, height: 42)
                            .background(
                                isSelected(weekday) ? palette.accentSoft : palette.panel,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("至少选择一天")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textSecondary)

            HStack {
                Spacer()
                Button("取消") {
                    store.cancelRepeatDraft()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    store.saveRepeatDraft()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(store.repeatDraft?.weekdays.isEmpty ?? true)
            }
        }
        .padding(24)
        .background(
            LinearGradient(colors: [palette.backgroundTop.opacity(0.96), palette.backgroundBottom.opacity(0.96)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .frame(width: 480)
    }

    private var repeatHabitTitle: String {
        guard let habitId = store.repeatDraft?.habitId,
              let habit = store.state.habits.first(where: { $0.id == habitId })
        else { return "" }
        return store.title(for: habit)
    }

    private func isSelected(_ weekday: Int) -> Bool {
        store.repeatDraft?.weekdays.contains(weekday) == true
    }

    private func shortWeekdayTitle(for weekday: Int) -> String {
        switch weekday {
        case 1: return "日"
        case 2: return "一"
        case 3: return "二"
        case 4: return "三"
        case 5: return "四"
        case 6: return "五"
        case 7: return "六"
        default: return ""
        }
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
    var tint: Color = Color.white.opacity(0.72)
    var tiltWhenHighlighted = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint.opacity(0.82))
                .frame(width: 20, height: 20)
                .padding(5)
                .rotationEffect(highlighted && tiltWhenHighlighted ? .degrees(-20) : .degrees(0))
                .offset(y: highlighted && tiltWhenHighlighted ? -0.5 : 0)
                .animation(.spring(response: 0.22, dampingFraction: 0.72), value: highlighted)
                .background {
                    if highlighted {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(tint.opacity(0.10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(tint.opacity(0.12), lineWidth: 0.8)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
