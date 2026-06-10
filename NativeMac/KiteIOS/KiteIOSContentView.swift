import SwiftUI

private enum KiteIOSRenameMode {
    case todayOnly
    case fromToday
}

struct KiteIOSContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = KiteIOSViewModel()
    @State private var renamingHabit: HabitDaySnapshotItem?
    @State private var renameText = ""
    @State private var renameMode: KiteIOSRenameMode = .todayOnly
    @State private var customRepeatHabit: HabitDaySnapshotItem?
    @State private var selectedRepeatWeekdays: Set<Int> = []
    @State private var showingSyncSettings = false
    @State private var habitPendingDeleteFromDate: HabitDaySnapshotItem?
    @State private var habitPendingDeleteEverywhere: HabitDaySnapshotItem?
    @State private var menuHabit: HabitDaySnapshotItem?

    var body: some View {
        TabView {
            NavigationStack {
                List {
                    dateSection
                    addHabitSection
                    habitsSection
                }
                .navigationTitle("Kite")
                .toolbar { toolbarContent }
            }
            .tabItem {
                Label("今日", systemImage: "checklist")
            }

            NavigationStack {
                monthView
                    .navigationTitle("月历")
                    .toolbar { calendarToolbarContent }
            }
            .tabItem {
                Label("月历", systemImage: "calendar")
            }

            NavigationStack {
                weekPlanView
                    .navigationTitle("周计划")
                    .toolbar { weekPlanToolbarContent }
            }
            .tabItem {
                Label("周计划", systemImage: "rectangle.grid.1x2")
            }

            KiteIOSSyncSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("同步", systemImage: "icloud")
                }
        }
        .sheet(isPresented: $showingSyncSettings) {
                KiteIOSSyncSettingsView(viewModel: viewModel)
        }
        .sheet(item: $menuHabit, content: habitActionsSheet)
        .sheet(item: $customRepeatHabit, content: customRepeatSheet)
        .sheet(item: $renamingHabit, content: renameSheet)
        .confirmationDialog(
            "从选中日起删除？",
            isPresented: deleteFromDateDialogBinding,
            actions: deleteFromDateDialogActions,
            message: deleteFromDateDialogMessage
        )
        .confirmationDialog(
            "彻底删除？",
            isPresented: deleteEverywhereDialogBinding,
            actions: deleteEverywhereDialogActions,
            message: deleteEverywhereDialogMessage
        )
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.reload()
            }
        }
    }

    private var isDraftEmpty: Bool {
        viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var deleteFromDateDialogBinding: Binding<Bool> {
        Binding(
            get: { habitPendingDeleteFromDate != nil },
            set: { isPresented in
                if isPresented == false {
                    habitPendingDeleteFromDate = nil
                }
            }
        )
    }

    private var deleteEverywhereDialogBinding: Binding<Bool> {
        Binding(
            get: { habitPendingDeleteEverywhere != nil },
            set: { isPresented in
                if isPresented == false {
                    habitPendingDeleteEverywhere = nil
                }
            }
        )
    }

    private var dateSection: some View {
        Section {
            dateHeader
            weekStrip
        }
    }

    private var addHabitSection: some View {
        Section {
            HStack(spacing: 10) {
                TextField("添加一个习惯", text: $viewModel.draftTitle)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit {
                        viewModel.addHabit()
                    }

                Button {
                    viewModel.addHabit()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(isDraftEmpty)
            }

            Button {
                viewModel.addTodayOnlyHabit()
            } label: {
                Label("仅选中日", systemImage: "calendar.badge.plus")
            }
            .disabled(isDraftEmpty)

            if viewModel.snapshot.totalCount < viewModel.defaultHabitCount {
                Button {
                    viewModel.seedDefaultHabits()
                } label: {
                    Label("补齐默认习惯", systemImage: "sparkles")
                }
            }
        }
    }

    private var habitsSection: some View {
        Section {
            if let loadMessage = viewModel.loadMessage {
                Label(loadMessage, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }

            if viewModel.snapshot.habits.isEmpty {
                emptyHabitsView
            } else {
                habitRows
            }
        } header: {
            Text(viewModel.dateTitle)
        }
    }

    private var emptyHabitsView: some View {
        ContentUnavailableView {
            Label("选中日暂无习惯", systemImage: "checklist")
        } actions: {
            Button("添加默认习惯") {
                viewModel.seedDefaultHabits()
            }
        }
    }

    private var habitRows: some View {
        ForEach(viewModel.snapshot.habits) { habit in
            habitRow(habit)
        }
        .onMove(perform: viewModel.moveHabits)
    }

    private func habitRow(_ habit: HabitDaySnapshotItem) -> some View {
        Button {
            viewModel.toggle(habit)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: habit.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(habit.isDone ? Color.accentColor : Color.secondary)
                    .frame(width: 28)

                Text(habit.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .strikethrough(habit.isDone)

                Spacer()

                Button {
                    menuHabit = habit
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .contextMenu {
            habitContextMenu(for: habit)
        }
    }

    @ViewBuilder
    private func habitContextMenu(for habit: HabitDaySnapshotItem) -> some View {
        Button {
            startRename(habit, mode: .todayOnly)
        } label: {
            Label("仅选中日改名", systemImage: "pencil")
        }

        Button {
            startRename(habit, mode: .fromToday)
        } label: {
            Label("从选中日起改名", systemImage: "calendar.badge.plus")
        }

        repeatMenu(for: habit)

        Button {
            viewModel.hideToday(habit)
        } label: {
            Label("仅选中日隐藏", systemImage: "eye.slash")
        }

        Button(role: .destructive) {
            habitPendingDeleteFromDate = habit
        } label: {
            Label("从选中日起删除", systemImage: "trash")
        }

        Button(role: .destructive) {
            habitPendingDeleteEverywhere = habit
        } label: {
            Label("彻底删除", systemImage: "trash.slash")
        }
    }

    private func repeatMenu(for habit: HabitDaySnapshotItem) -> some View {
        Menu {
            Button {
                viewModel.setRepeatRule(.daily, for: habit)
            } label: {
                Label("每天", systemImage: "repeat")
            }

            Button {
                viewModel.setRepeatRule(.weekdays, for: habit)
            } label: {
                Label("工作日", systemImage: "briefcase")
            }

            Button {
                viewModel.setRepeatRule(.weekends, for: habit)
            } label: {
                Label("周末", systemImage: "sun.max")
            }

            Button {
                startCustomRepeat(habit)
            } label: {
                Label("自定义周几", systemImage: "calendar")
            }
        } label: {
            Label("重复", systemImage: "repeat")
        }
    }

    private func habitActionsSheet(for habit: HabitDaySnapshotItem) -> some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        menuHabit = nil
                        startRename(habit, mode: .todayOnly)
                    } label: {
                        Label("仅选中日改名", systemImage: "pencil")
                    }

                    Button {
                        menuHabit = nil
                        startRename(habit, mode: .fromToday)
                    } label: {
                        Label("从选中日起改名", systemImage: "calendar.badge.plus")
                    }
                }

                Section {
                    Button {
                        viewModel.setRepeatRule(.daily, for: habit)
                        menuHabit = nil
                    } label: {
                        Label("每天", systemImage: habit.repeatRule.kind == .daily ? "checkmark.circle.fill" : "repeat")
                    }

                    Button {
                        viewModel.setRepeatRule(.weekdays, for: habit)
                        menuHabit = nil
                    } label: {
                        Label("工作日", systemImage: habit.repeatRule.kind == .weekdays ? "checkmark.circle.fill" : "briefcase")
                    }

                    Button {
                        viewModel.setRepeatRule(.weekends, for: habit)
                        menuHabit = nil
                    } label: {
                        Label("周末", systemImage: habit.repeatRule.kind == .weekends ? "checkmark.circle.fill" : "sun.max")
                    }

                    Button {
                        menuHabit = nil
                        startCustomRepeat(habit)
                    } label: {
                        Label("自定义周几", systemImage: "calendar")
                    }
                } header: {
                    Text("重复")
                }

                Section {
                    Button {
                        viewModel.hideToday(habit)
                        menuHabit = nil
                    } label: {
                        Label("仅选中日隐藏", systemImage: "eye.slash")
                    }

                    Button(role: .destructive) {
                        menuHabit = nil
                        habitPendingDeleteFromDate = habit
                    } label: {
                        Label("从选中日起删除", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        menuHabit = nil
                        habitPendingDeleteEverywhere = habit
                    } label: {
                        Label("彻底删除", systemImage: "trash.slash")
                    }
                }
            }
            .navigationTitle(habit.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        menuHabit = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func deleteFromDateDialogActions() -> some View {
        if let habit = habitPendingDeleteFromDate {
            Button("从选中日起删除", role: .destructive) {
                viewModel.deleteFromToday(habit)
                habitPendingDeleteFromDate = nil
            }
        }

        Button("取消", role: .cancel) {
            habitPendingDeleteFromDate = nil
        }
    }

    @ViewBuilder
    private func deleteFromDateDialogMessage() -> some View {
        if let habit = habitPendingDeleteFromDate {
            Text("“\(habit.title)” 会从选中日之后不再出现。")
        }
    }

    @ViewBuilder
    private func deleteEverywhereDialogActions() -> some View {
        if let habit = habitPendingDeleteEverywhere {
            Button("彻底删除", role: .destructive) {
                viewModel.deleteEverywhere(habit)
                habitPendingDeleteEverywhere = nil
            }
        }

        Button("取消", role: .cancel) {
            habitPendingDeleteEverywhere = nil
        }
    }

    @ViewBuilder
    private func deleteEverywhereDialogMessage() -> some View {
        if let habit = habitPendingDeleteEverywhere {
            Text("“\(habit.title)” 和它的打卡、改名、隐藏记录都会从同步库删除。")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                Text("\(viewModel.countText) \(viewModel.progressText)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button {
                    showingSyncSettings = true
                } label: {
                    Image(systemName: "icloud")
                }

                EditButton()
            }
        }
    }

    @ToolbarContentBuilder
    private var calendarToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.jumpToToday()
            } label: {
                Image(systemName: "calendar.badge.clock")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            HStack {
                Button {
                    viewModel.shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button {
                    viewModel.shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var weekPlanToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.jumpToToday()
            } label: {
                Image(systemName: "calendar.badge.clock")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            HStack {
                Button {
                    viewModel.shiftWeek(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button {
                    viewModel.shiftWeek(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
        }
    }

    private var dateHeader: some View {
        HStack {
            Button {
                viewModel.shiftDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            VStack(spacing: 3) {
                Text(viewModel.dateTitle)
                    .font(.headline)
                if !viewModel.isSelectedDateToday {
                    Button("回到今天") {
                        viewModel.jumpToToday()
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            Spacer()

            Button {
                viewModel.shiftDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.weekItems) { item in
                Button {
                    viewModel.select(date: item.date)
                } label: {
                    VStack(spacing: 4) {
                        Text(item.weekdayTitle)
                            .font(.caption2.weight(.semibold))
                        Text(item.dayLabel)
                            .font(.caption2)
                        Text(item.countText)
                            .font(.caption2.monospacedDigit().weight(.medium))
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .foregroundStyle(item.isSelected ? Color.accentColor : .secondary)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(item.isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                    }
                    .overlay(alignment: .topTrailing) {
                        if item.hasProgress {
                            Circle()
                                .fill(item.isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                                .frame(width: 5, height: 5)
                                .padding(6)
                        }
                    }
                    .overlay {
                        if item.isToday {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.accentColor.opacity(item.isSelected ? 0.55 : 0.25), lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var monthView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(viewModel.monthTitle)
                        .font(.title2.bold())
                    Spacer()
                    Text(viewModel.dateTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { weekday in
                        Text(weekday)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(viewModel.monthItems) { item in
                        Button {
                            viewModel.select(date: item.date)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.dayNumber)
                                        .font(.subheadline.weight(.bold))
                                    Spacer()
                                    if item.isToday {
                                        Circle()
                                            .fill(item.isSelected ? Color.white : Color.accentColor)
                                            .frame(width: 6, height: 6)
                                    }
                                }

                                Text(item.completionText)
                                    .font(.caption.monospacedDigit().weight(.semibold))

                                Text(item.pendingText)
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(2)
                            }
                            .foregroundStyle(monthTextColor(for: item))
                            .padding(8)
                            .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
                            .background(monthBackground(for: item), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 18)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var weekPlanView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.weekPlanDays) { day in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.weekdayTitle)
                                    .font(.headline)
                                Text(day.dayLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(day.habits.count)")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        }

                        if day.habits.isEmpty {
                            Text("无")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(day.habits) { habit in
                                HStack(spacing: 10) {
                                    Image(systemName: habit.isDone ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(habit.isDone ? Color.accentColor : Color.secondary)
                                    Text(habit.title)
                                        .font(.subheadline.weight(.semibold))
                                        .strikethrough(habit.isDone)
                                    Spacer()
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onTapGesture {
                        viewModel.select(date: day.date)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func monthTextColor(for item: KiteIOSMonthDayItem) -> Color {
        if item.isSelected { return .white }
        if item.isCurrentMonth { return .primary }
        return .secondary
    }

    private func monthBackground(for item: KiteIOSMonthDayItem) -> Color {
        if item.isSelected { return .accentColor }
        if item.isToday { return Color.accentColor.opacity(0.12) }
        if item.isCurrentMonth { return Color(.secondarySystemGroupedBackground) }
        return Color(.tertiarySystemGroupedBackground)
    }

    private func customRepeatSheet(for habit: HabitDaySnapshotItem) -> some View {
        NavigationStack {
            List {
                ForEach(1...7, id: \.self) { weekday in
                    Button {
                        toggleRepeatWeekday(weekday)
                    } label: {
                        HStack {
                            Text(HabitDate.weekdayTitle(for: weekday) ?? "")
                            Spacer()
                            if selectedRepeatWeekdays.contains(weekday) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("自定义周几")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        customRepeatHabit = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        viewModel.setCustomRepeatWeekdays(Array(selectedRepeatWeekdays), for: habit)
                        customRepeatHabit = nil
                    }
                    .disabled(selectedRepeatWeekdays.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func renameSheet(for habit: HabitDaySnapshotItem) -> some View {
        NavigationStack {
            Form {
                TextField("名称", text: $renameText)
            }
            .navigationTitle(renameTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        renamingHabit = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRename(habit)
                        renamingHabit = nil
                    }
                    .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(180)])
    }

    private var renameTitle: String {
        switch renameMode {
        case .todayOnly:
            return "仅选中日改名"
        case .fromToday:
            return "从选中日起改名"
        }
    }

    private func startRename(_ habit: HabitDaySnapshotItem, mode: KiteIOSRenameMode) {
        renameText = habit.title
        renameMode = mode
        renamingHabit = habit
    }

    private func startCustomRepeat(_ habit: HabitDaySnapshotItem) {
        if habit.repeatRule.kind == .custom {
            selectedRepeatWeekdays = Set(habit.repeatRule.weekdays)
        } else {
            selectedRepeatWeekdays = [HabitDate.calendar.component(.weekday, from: viewModel.selectedDate)]
        }
        customRepeatHabit = habit
    }

    private func toggleRepeatWeekday(_ weekday: Int) {
        if selectedRepeatWeekdays.contains(weekday) {
            selectedRepeatWeekdays.remove(weekday)
        } else {
            selectedRepeatWeekdays.insert(weekday)
        }
    }

    private func saveRename(_ habit: HabitDaySnapshotItem) {
        switch renameMode {
        case .todayOnly:
            viewModel.renameToday(habit, title: renameText)
        case .fromToday:
            viewModel.renameFromToday(habit, title: renameText)
        }
    }
}

#Preview {
    KiteIOSContentView()
}
