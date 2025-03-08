import SwiftUI

struct WeekView: View {
    @ObservedObject var appData: AppData
    @State private var currentWeekOffset: Int
    @State private var currentCycleOffset = 0
    @Environment(\.dismiss) var dismiss

    init(appData: AppData) {
        self.appData = appData
        if let currentCycle = appData.cycles.last {
            let daysSinceStart = Calendar.current.dateComponents([.day], from: currentCycle.startDate, to: Date()).day ?? 0
            let currentWeek = max(0, daysSinceStart / 7)
            self._currentWeekOffset = State(initialValue: currentWeek)
        } else {
            self._currentWeekOffset = State(initialValue: 0)
        }
    }

    var body: some View {
        VStack {
            // Cycle Navigation
            HStack {
                Button(action: {
                    if currentCycleOffset > -maxCyclesBefore() {
                        currentCycleOffset -= 1
                        adjustWeekOffsetForCycle()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                .disabled(currentCycleOffset <= -maxCyclesBefore())
                
                Spacer()
                
                Text("Cycle \(displayedCycleNumber())")
                    .font(.title2)
                
                Spacer()
                
                Button(action: {
                    if currentCycleOffset < 0 {
                        currentCycleOffset += 1
                        adjustWeekOffsetForCycle()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
                .disabled(currentCycleOffset >= 0)
            }
            .padding(.horizontal)
            .padding(.top)

            Spacer().frame(height: 20)

            // Week Navigation
            HStack {
                Button(action: {
                    if currentWeekOffset > 0 {
                        currentWeekOffset -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                .disabled(currentWeekOffset <= 0)
                
                Spacer()
                
                Text("Week \(displayedWeekNumber())")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    if currentWeekOffset < maxWeeksBefore() {
                        currentWeekOffset += 1
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
                .disabled(currentWeekOffset >= maxWeeksBefore())
            }
            .padding(.horizontal)
            .padding(.bottom)

            ScrollView {
                VStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: 160)
                        ForEach(0..<7) { offset in
                            let date = dayDate(for: offset)
                            let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                            VStack(spacing: 2) {
                                Text(dateFormatter.string(from: date))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(weekDays()[offset])
                                    .font(.caption2)
                            }
                            .frame(width: 30, height: 40, alignment: .center)
                            .border(Color.gray.opacity(0.5), width: 1)
                            .background(isToday ? Color.yellow.opacity(0.3) : Color.clear)
                        }
                    }
                    .padding(.vertical, 5)

                    ForEach(Category.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(category.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.top, 10)
                            let categoryItems = itemsForSelectedCycle().filter { $0.category == category }
                            if categoryItems.isEmpty {
                                Text("No items added")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 10)
                            } else {
                                ForEach(categoryItems) { item in
                                    HStack(spacing: 0) {
                                        Text(itemDisplayText(item: item))
                                            .font(.caption2)
                                            .frame(width: 150, alignment: .leading)
                                            .padding(.leading, 10)
                                        ForEach(0..<7) { dayOffset in
                                            let date = dayDate(for: dayOffset)
                                            let isLogged = isItemLogged(item: item, on: date)
                                            let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                                            Image(systemName: isLogged ? "checkmark" : "")
                                                .frame(width: 30, height: 20, alignment: .center)
                                                .border(Color.gray.opacity(0.5), width: 1)
                                                .background(isToday ? Color.yellow.opacity(0.3) : Color.clear)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Week View")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .onAppear {
            print("WeekView appeared with cycles: \(appData.cycles.map { $0.id })")
            print("WeekView cycleItems: \(appData.cycleItems)")
            print("Selected cycle: \(selectedCycle()?.id ?? UUID())")
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()

    func displayedCycleNumber() -> Int {
        guard !appData.cycles.isEmpty else { return 0 }
        let index = max(0, appData.cycles.count - 1 + currentCycleOffset)
        return appData.cycles[index].number
    }

    func currentWeekAndDay() -> (week: Int, day: Int) {
        guard let currentCycle = selectedCycle() else { return (0, 0) }
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: currentCycle.startDate, to: Date()).day ?? 0
        let week = max(1, (daysSinceStart / 7) + 1)
        let day = max(1, (daysSinceStart % 7) + 1)
        return (week, day)
    }

    func weekStartDate() -> Date {
        guard let currentCycle = selectedCycle() else { return startOfWeek(for: Date()) }
        let calendar = Calendar.current
        return calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: currentCycle.startDate) ?? currentCycle.startDate
    }

    func dayDate(for offset: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: offset, to: weekStartDate()) ?? weekStartDate()
    }

    func weekDays() -> [String] {
        let calendar = Calendar.current
        let weekStart = weekStartDate()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE"
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
            return dateFormatter.string(from: date)
        }
    }

    func maxWeeksBefore() -> Int {
        guard let currentCycle = selectedCycle() else { return 0 }
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: currentCycle.startDate, to: currentCycle.foodChallengeDate).day ?? 0
        return max(0, daysSinceStart / 7)
    }

    func maxCyclesBefore() -> Int {
        return appData.cycles.count - 1
    }

    func displayedWeekNumber() -> Int {
        guard let currentCycle = selectedCycle() else { return 1 }
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: currentCycle.startDate, to: weekStartDate()).day ?? 0
        return max(1, (daysSinceStart / 7) + 1)
    }

    func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
    }

    func isItemLogged(item: Item, on date: Date) -> Bool {
        guard let cycle = selectedCycle() else { return false }
        let calendar = Calendar.current
        let logs = appData.consumptionLog[cycle.id]?[item.id] ?? []
        return logs.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func itemDisplayText(item: Item) -> String {
        if let dose = item.dose, let unit = item.unit {
            return "\(item.name) - \(String(format: "%.1f", dose)) \(unit)"
        } else if item.category == .treatment, let unit = item.unit {
            let week = displayedWeekNumber()
            if let weeklyDose = item.weeklyDoses?[week] {
                return "\(item.name) - \(String(format: "%.1f", weeklyDose)) \(unit)"
            }
        }
        return item.name
    }

    private func selectedCycle() -> Cycle? {
        guard !appData.cycles.isEmpty else { return nil }
        let index = max(0, appData.cycles.count - 1 + currentCycleOffset)
        return appData.cycles[index]
    }

    private func itemsForSelectedCycle() -> [Item] {
        guard let cycle = selectedCycle() else { return [] }
        let items = appData.cycleItems[cycle.id] ?? []
        print("Items for cycle \(cycle.id): \(items)")
        return items
    }

    private func adjustWeekOffsetForCycle() {
        let maxWeeks = maxWeeksBefore()
        if currentWeekOffset > maxWeeks {
            currentWeekOffset = maxWeeks
        } else if currentWeekOffset < 0 {
            currentWeekOffset = 0
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct WeekView_Previews: PreviewProvider {
    static var previews: some View {
        WeekView(appData: AppData())
    }
}
