import SwiftUI

struct HistoryView: View {
    @ObservedObject var appData: AppData
    @State private var editingEntry: DisplayLogEntry?
    @State private var newTimestamp: Date = Date()
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            ForEach(groupedLogEntries(), id: \.date) { group in
                Section(header: Text(group.date, style: .date)) {
                    ForEach(group.entries) { entry in
                        VStack(alignment: .leading) {
                            Text("\(entry.itemName) (\(entry.category.rawValue))")
                                .font(.headline)
                            Text("Logged by: \(entry.userName) at \(entry.timestamp, style: .time)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if appData.currentUser?.isAdmin ?? false || entry.userId == appData.currentUser?.id {
                                editingEntry = entry
                                newTimestamp = entry.timestamp
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .sheet(item: $editingEntry) { entry in
            NavigationView {
                Form {
                    DatePicker("Edit Timestamp",
                               selection: $newTimestamp,
                               displayedComponents: [.date, .hourAndMinute])
                }
                .navigationTitle("Edit Log Time")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editingEntry = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            updateLogTimestamp(entry: entry, newTime: newTimestamp)
                            editingEntry = nil
                            appData.objectWillChange.send()
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                        .alert("Delete Log Entry", isPresented: $showingDeleteConfirmation) {
                            Button("Cancel", role: .cancel) { }
                            Button("Delete", role: .destructive) {
                                deleteLogEntry(entry: entry)
                                editingEntry = nil
                                appData.objectWillChange.send()
                            }
                        } message: {
                            Text("Are you sure you want to delete the log for \(entry.itemName) at \(entry.timestamp, style: .date) \(entry.timestamp, style: .time)?")
                        }
                    }
                }
            }
        }
    }

    // DisplayLogEntry for UI purposes, distinct from Models.LogEntry
    private struct DisplayLogEntry: Identifiable {
        let id = UUID()
        let cycleId: UUID
        let itemId: UUID
        let itemName: String
        let category: Category
        let timestamp: Date
        let userId: UUID
        let userName: String
    }

    private struct LogGroup: Identifiable {
        let date: Date
        let entries: [DisplayLogEntry]
        var id: Date { date }
    }

    private func groupedLogEntries() -> [LogGroup] {
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        var entries: [DisplayLogEntry] = []
        for (cycleId, itemsLog) in appData.consumptionLog {
            guard let cycleItems = appData.cycleItems[cycleId] else { continue }
            for (itemId, logs) in itemsLog {
                if let item = cycleItems.first(where: { $0.id == itemId }) {
                    for log in logs where log.date >= sevenDaysAgo {
                        if let user = appData.users.first(where: { $0.id == log.userId }) {
                            entries.append(DisplayLogEntry(
                                cycleId: cycleId,
                                itemId: itemId,
                                itemName: item.name,
                                category: item.category,
                                timestamp: log.date,
                                userId: log.userId,
                                userName: user.name
                            ))
                        }
                    }
                }
            }
        }
        entries.sort { $0.timestamp > $1.timestamp }

        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        return grouped.map { date, groupEntries in
            LogGroup(date: date, entries: groupEntries)
        }.sorted { $0.date > $1.date }
    }

    private func updateLogTimestamp(entry: DisplayLogEntry, newTime: Date) {
        if var itemLogs = appData.consumptionLog[entry.cycleId]?[entry.itemId] {
            if let index = itemLogs.firstIndex(where: { $0.date == entry.timestamp && $0.userId == entry.userId }) {
                itemLogs[index] = LogEntry(date: newTime, userId: entry.userId)
                appData.setConsumptionLog(itemId: entry.itemId, cycleId: entry.cycleId, entries: itemLogs)
            }
        }
    }

    private func deleteLogEntry(entry: DisplayLogEntry) {
        if var itemLogs = appData.consumptionLog[entry.cycleId]?[entry.itemId] {
            itemLogs.removeAll { $0.date == entry.timestamp && $0.userId == entry.userId }
            appData.setConsumptionLog(itemId: entry.itemId, cycleId: entry.cycleId, entries: itemLogs)
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(appData: AppData())
    }
}
