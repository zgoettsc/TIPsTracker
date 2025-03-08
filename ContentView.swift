import SwiftUI
import UserNotifications

struct ContentView: View {
    @ObservedObject var appData: AppData
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var treatmentCountdown: TimeInterval?
    @State private var showingSetupWizard = false
    @State private var showingCycleEndPopup = false
    @State private var notificationPermissionDenied = false
    @State private var isInitialSetupActive = false
    @State private var isNewCycleSetupActive = false
    @State private var showingSyncError = false

    var body: some View {
        NavigationView {
            VStack {
                Text("\(currentPatientName())’s TIPs Plan")
                    .font(.largeTitle)
                    .padding(.top)

                let (week, day) = currentWeekAndDay()
                Text("Cycle \(currentCycleNumber()), Week \(week), Day \(day)")
                    .font(.headline)

                if notificationPermissionDenied {
                    Text("Notifications are disabled. Go to iOS Settings > Notifications > TIPs App to enable them.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                if appData.cycles.isEmpty && appData.roomCode != nil && appData.syncError == nil {
                    ProgressView("Loading your plan...")
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            categorySection(for: .medicine)
                            categorySection(for: .maintenance)
                            treatmentCategorySection()
                            categorySection(for: .recommended)
                        }
                    }
                }

                HStack {
                    NavigationLink(destination: WeekView(appData: appData)) {
                        Text("Week View")
                            .font(.title3)
                    }
                    Spacer()
                    NavigationLink(destination: SettingsView(appData: appData)) {
                        Image(systemName: "gear")
                            .font(.title2)
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert(isPresented: $showingSyncError) {
                Alert(
                    title: Text("Sync Error"),
                    message: Text(appData.syncError ?? "Unknown error occurred."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .navigationViewStyle(.stack)
        .onReceive(timer) { _ in
            updateTreatmentCountdown()
        }
        .onAppear {
            initializeCollapsedState()
            updateTreatmentCountdown()
            checkSetupNeeded()
            checkNotificationPermissions()
            appData.checkAndResetIfNeeded()
            showingSyncError = appData.syncError != nil
            print("ContentView appeared, treatmentTimerEnd: \(String(describing: appData.treatmentTimerEnd))") // Debug
        }
        .onChange(of: appData.cycles) { _ in checkCycleEnd() }
        .onChange(of: appData.currentUser) { _ in checkCycleEnd() }
        .onChange(of: appData.consumptionLog) { _ in handleConsumptionLogChange() }
        .onChange(of: appData.treatmentTimerEnd) { newValue in
            updateTreatmentCountdown()
            print("treatmentTimerEnd changed to: \(String(describing: newValue))") // Debug
        }
        .onChange(of: appData.syncError) { newValue in showingSyncError = newValue != nil }
        .onChange(of: showingSetupWizard) { newValue in
            if !newValue && !showingCycleEndPopup {
                isInitialSetupActive = false
                isNewCycleSetupActive = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.checkCycleEnd()
                }
            }
        }
        .sheet(isPresented: $showingSetupWizard) {
            if showingCycleEndPopup {
                NewCycleSetupView(appData: appData, isNewCycleSetupActive: $isNewCycleSetupActive)
            } else {
                InitialSetupView(appData: appData, isInitialSetupActive: $isInitialSetupActive)
            }
        }
        .sheet(isPresented: $showingCycleEndPopup, onDismiss: {
            if !showingSetupWizard { showingCycleEndPopup = false }
        }) {
            VStack(spacing: 20) {
                Text("Your current cycle has ended. Would you like to set up a new cycle?")
                    .multilineTextAlignment(.center)
                    .padding()
                HStack(spacing: 20) {
                    Button("Yes") {
                        showingCycleEndPopup = false
                        showingSetupWizard = true
                        isNewCycleSetupActive = true
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Not Now") {
                        showingCycleEndPopup = false
                        showingSetupWizard = false
                    }
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
        }
    }

    private func categorySection(for category: Category) -> some View {
        ZStack {
            backgroundColor(for: category)
            categoryView(for: category)
        }
        .padding(.horizontal)
    }

    private func treatmentCategorySection() -> some View {
        ZStack {
            backgroundColor(for: .treatment)
            treatmentCategoryView()
        }
        .padding(.horizontal)
    }

    private func categoryView(for category: Category) -> some View {
        VStack(alignment: .leading) {
            Text("\(category.rawValue) \(timeOfDay(for: category))")
                .font(.title2)
                .foregroundColor(isCategoryComplete(category) ? .gray : .blue)
                .padding(.top, 10)
            if !isCollapsed(category) {
                let items = currentItems().filter { $0.category == category }
                if items.isEmpty {
                    Text("No items added")
                        .foregroundColor(.gray)
                } else {
                    ForEach(items) { item in
                        if category == .recommended {
                            recommendedItemRow(item: item)
                        } else {
                            itemRow(item: item, category: category)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { toggleCollapse(category) }
    }

    private func treatmentCategoryView() -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text("\(Category.treatment.rawValue) (PM)")
                    .font(.title2)
                    .foregroundColor(isCategoryComplete(.treatment) ? .gray : .blue)
                Spacer()
                if let countdown = treatmentCountdown, countdown > 0 {
                    Text(formattedTimeRemaining(countdown))
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .monospacedDigit()
                } else if appData.treatmentTimerEnd != nil && treatmentCountdown == 0 {
                    Text("Timer Done")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            .padding(.top, 10)
            if !isCollapsed(.treatment) {
                let items = currentItems().filter { $0.category == .treatment }
                if items.isEmpty {
                    Text("No items added")
                        .foregroundColor(.gray)
                } else {
                    ForEach(items) { item in
                        itemRow(item: item, category: .treatment)
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { toggleCollapse(.treatment) }
    }

    private func itemRow(item: Item, category: Category) -> some View {
        HStack {
            Text(itemDisplayText(item: item))
            Spacer()
            Button(action: { toggleCheck(item: item) }) {
                Image(systemName: isItemCheckedToday(item) ? "checkmark.square" : "square")
                    .font(.title2)
                    .accessibilityLabel(isItemCheckedToday(item) ? "Checked" : "Unchecked")
            }
        }
        .padding(.vertical, 2)
    }

    private func recommendedItemRow(item: Item) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(itemDisplayText(item: item))
                Spacer()
                Button(action: { toggleCheck(item: item) }) {
                    Image(systemName: isItemCheckedToday(item) ? "checkmark.square" : "square")
                        .font(.title2)
                        .accessibilityLabel(isItemCheckedToday(item) ? "Checked" : "Unchecked")
                }
            }
            let weeklyCount = weeklyDoseCount(for: item)
            ProgressView(value: min(Double(weeklyCount) / 5.0, 1.0))
                .progressViewStyle(LinearProgressViewStyle())
                .tint(progressBarColor(for: weeklyCount))
                .frame(height: 5)
            Text("\(weeklyCount)/5 this week")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 2)
    }

    private func checkCycleEnd() {
        if isInitialSetupActive || isNewCycleSetupActive || showingSetupWizard { return }
        guard let lastCycle = appData.cycles.last else { return }
        let foodChallengeDate = lastCycle.foodChallengeDate
        let today = Calendar.current.startOfDay(for: Date())
        let isPastDue = Calendar.current.isDate(foodChallengeDate, equalTo: today, toGranularity: .day) || foodChallengeDate < today
        if appData.currentUser?.isAdmin == true && isPastDue && !showingCycleEndPopup {
            showingCycleEndPopup = true
            showingSetupWizard = false
        } else if !isPastDue {
            showingCycleEndPopup = false
        }
    }

    private func checkSetupNeeded() {
        let isFirstUse = !UserDefaults.standard.bool(forKey: "hasCompletedSetup")
        showingSetupWizard = isFirstUse
        isInitialSetupActive = isFirstUse
    }

    private func backgroundColor(for category: Category) -> some View {
        isCategoryComplete(category) ?
            Color.gray.opacity(0.2).cornerRadius(10) :
            Color(UIColor.systemBlue).opacity(0.1).cornerRadius(10)
    }

    private func isCollapsed(_ category: Category) -> Bool {
        appData.categoryCollapsed[category.rawValue] ?? isCategoryComplete(category)
    }

    private func toggleCollapse(_ category: Category) {
        appData.setCategoryCollapsed(category, isCollapsed: !isCollapsed(category))
    }

    private func currentCycleNumber() -> Int {
        appData.cycles.last?.number ?? 0
    }

    private func currentPatientName() -> String {
        appData.cycles.last?.patientName ?? "TIPs"
    }

    private func isCategoryComplete(_ category: Category) -> Bool {
        let items = currentItems().filter { $0.category == category }
        return !items.isEmpty && items.allSatisfy { isItemCheckedToday($0) }
    }

    private func isItemCheckedToday(_ item: Item) -> Bool {
        guard let cycleId = appData.currentCycleId() else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        return appData.consumptionLog[cycleId]?[item.id]?.contains { Calendar.current.isDate($0.date, inSameDayAs: today) } ?? false
    }

    private func weeklyDoseCount(for item: Item) -> Int {
        guard let cycleId = appData.currentCycleId() else { return 0 }
        let (weekStart, weekEnd) = currentWeekRange()
        return appData.consumptionLog[cycleId]?[item.id]?.filter { $0.date >= weekStart && $0.date <= weekEnd }.count ?? 0
    }

    private func currentWeekRange() -> (start: Date, end: Date) {
        guard let cycle = appData.cycles.last else {
            let now = Date()
            let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (weekStart, Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!)
        }
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: cycle.startDate, to: Date()).day ?? 0
        let currentWeek = (daysSinceStart / 7)
        let weekStart = calendar.date(byAdding: .weekOfYear, value: currentWeek, to: cycle.startDate)!
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        return (weekStart, weekEnd)
    }

    private func progressBarColor(for count: Int) -> Color {
        switch count {
        case 0..<3: return .blue
        case 3...5: return .green
        default: return .red
        }
    }

    private func toggleCheck(item: Item) {
        guard let cycleId = appData.currentCycleId() else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let isChecked = isItemCheckedToday(item)

        if isChecked {
            if let log = appData.consumptionLog[cycleId]?[item.id]?.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
                appData.removeConsumption(itemId: item.id, cycleId: cycleId, date: log.date)
            }
            if item.category == .treatment && appData.treatmentFoodTimerEnabled {
                stopTreatmentTimer()
            }
        } else {
            appData.logConsumption(itemId: item.id, cycleId: cycleId)
            if item.category == .treatment && appData.treatmentFoodTimerEnabled {
                DispatchQueue.main.async {
                    let complete = self.isCategoryComplete(.treatment)
                    if !complete {
                        self.startTreatmentTimer()
                    } else {
                        self.stopTreatmentTimer()
                    }
                }
            }
        }
        if let category = Category(rawValue: item.category.rawValue) {
            appData.setCategoryCollapsed(category, isCollapsed: isCategoryComplete(category))
        }
    }

    private func startTreatmentTimer() {
        guard appData.treatmentFoodTimerEnabled else { return }
        stopTreatmentTimer() // Ensure clean slate
        let now = Date()
        let duration = appData.treatmentTimerDuration
        let endDate = now.addingTimeInterval(duration)
        appData.treatmentTimerEnd = endDate
        treatmentCountdown = duration
        print("Started timer: endDate = \(endDate), countdown = \(duration)") // Debug

        let content = UNMutableNotificationContent()
        content.title = "Time for the next treatment food"
        content.body = "Your \(Int(duration / 60)) minute treatment food timer has ended."
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "TREATMENT_TIMER"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let identifier = "treatment_timer_\(now.timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Scheduled notification for \(identifier)") // Debug
            }
        }
    }

    private func stopTreatmentTimer() {
        appData.treatmentTimerEnd = nil
        treatmentCountdown = nil
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("Stopped timer: treatmentTimerEnd and countdown cleared") // Debug
    }

    private func handleConsumptionLogChange() {
        if appData.treatmentFoodTimerEnabled && isCategoryComplete(.treatment) {
            stopTreatmentTimer()
        }
        Category.allCases.forEach { category in
            appData.setCategoryCollapsed(category, isCollapsed: isCategoryComplete(category))
        }
    }

    private func updateTreatmentCountdown() {
        guard appData.treatmentFoodTimerEnabled, let endDate = appData.treatmentTimerEnd else {
            treatmentCountdown = nil
            return
        }
        let remaining = max(0, endDate.timeIntervalSinceNow)
        treatmentCountdown = remaining
        print("Updated countdown: \(remaining) seconds remaining") // Debug
        if remaining <= 0 {
            stopTreatmentTimer()
        }
    }

    private func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionDenied = settings.authorizationStatus == .denied
            }
        }
    }

    private func formattedTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func itemDisplayText(item: Item) -> String {
        if let dose = item.dose, let unit = item.unit {
            return "\(item.name) - \(String(format: "%.1f", dose)) \(unit)"
        } else if item.category == .treatment, let unit = item.unit {
            let week = currentWeekAndDay().week
            if let weeklyDose = item.weeklyDoses?[week] {
                return "\(item.name) - \(String(format: "%.1f", weeklyDose)) \(unit) (Week \(week))"
            } else if let firstWeek = item.weeklyDoses?.keys.min(), let firstDose = item.weeklyDoses?[firstWeek] {
                return "\(item.name) - \(String(format: "%.1f", firstDose)) \(unit) (Week \(firstWeek))"
            }
        }
        return item.name
    }

    private func currentWeekAndDay() -> (week: Int, day: Int) {
        guard let cycle = appData.cycles.last else { return (0, 0) }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: cycle.startDate, to: Date()).day ?? 0
        return (week: (daysSinceStart / 7) + 1, day: (daysSinceStart % 7) + 1)
    }

    private func initializeCollapsedState() {
        Category.allCases.forEach { category in
            if appData.categoryCollapsed[category.rawValue] == nil {
                appData.setCategoryCollapsed(category, isCollapsed: isCategoryComplete(category))
            }
        }
    }

    private func timeOfDay(for category: Category) -> String {
        switch category {
        case .medicine, .maintenance: return "(AM)"
        case .treatment: return "(PM)"
        case .recommended: return "(Any Time)"
        }
    }

    private func currentItems() -> [Item] {
        guard let cycleId = appData.currentCycleId() else { return [] }
        return (appData.cycleItems[cycleId] ?? []).sorted { $0.order < $1.order }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(appData: AppData())
    }
}
