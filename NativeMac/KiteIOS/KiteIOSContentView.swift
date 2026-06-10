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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    dateHeader

                    weekStrip
                }

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
                        .disabled(viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Button {
                        viewModel.addTodayOnlyHabit()
                    } label: {
                        Label("仅选中日", systemImage: "calendar.badge.plus")
                    }
                    .disabled(viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section {
                    if let loadMessage = viewModel.loadMessage {
                        Label(loadMessage, systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.snapshot.habits.isEmpty {
                        ContentUnavailableView {
                            Label("选中日暂无习惯", systemImage: "checklist")
                        } actions: {
                            Button("添加默认习惯") {
                                viewModel.seedDefaultHabits()
                            }
                        }
                    } else {
                        ForEach(viewModel.snapshot.habits) { habit in
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
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
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
                        }
                        .onMove(perform: viewModel.moveHabits)
                    }
                } header: {
                    Text(viewModel.dateTitle)
                }
            }
            .navigationTitle("Kite")
            .toolbar {
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
            .sheet(isPresented: $showingSyncSettings) {
                KiteIOSSyncSettingsView(viewModel: viewModel)
            }
            .sheet(item: $customRepeatHabit) { habit in
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
            .sheet(item: $renamingHabit) { habit in
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
            .confirmationDialog("从选中日起删除？", item: $habitPendingDeleteFromDate) { habit in
                Button("从选中日起删除", role: .destructive) {
                    viewModel.deleteFromToday(habit)
                }
                Button("取消", role: .cancel) { }
            } message: { habit in
                Text("“\(habit.title)” 会从选中日之后不再出现。")
            }
            .confirmationDialog("彻底删除？", item: $habitPendingDeleteEverywhere) { habit in
                Button("彻底删除", role: .destructive) {
                    viewModel.deleteEverywhere(habit)
                }
                Button("取消", role: .cancel) { }
            } message: { habit in
                Text("“\(habit.title)” 和它的打卡、改名、隐藏记录都会从同步库删除。")
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.reload()
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
